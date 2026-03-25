import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';

class HistoryService {
  static const _key = 'download_history';

  static Future<List<DownloadItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => DownloadItem.fromJson(jsonDecode(e))).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> addItem(DownloadItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(item.toJson()));
    // Keep last 100 items
    if (raw.length > 100) raw.removeRange(100, raw.length);
    await prefs.setStringList(_key, raw);
  }

  static Future<void> updateItem(DownloadItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final idx = raw.indexWhere((e) {
      final decoded = jsonDecode(e);
      return decoded['id'] == item.id;
    });
    if (idx != -1) {
      raw[idx] = jsonEncode(item.toJson());
      await prefs.setStringList(_key, raw);
    }
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
