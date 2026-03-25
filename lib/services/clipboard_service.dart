import 'dart:async';
import 'package:flutter/services.dart';

class ClipboardWatcherService {
  static const _methodChannel = MethodChannel('com.instagrab/clipboard');
  static const _eventChannel = EventChannel('com.instagrab/clipboard_events');
  static const _serviceChannel = MethodChannel('com.instagrab/service');

  static Stream<String> get clipboardStream {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }

  static Future<String?> getClipboard() async {
    try {
      return await _methodChannel.invokeMethod<String>('getClipboard');
    } catch (_) {
      return null;
    }
  }

  static Future<void> startBackgroundService() async {
    try {
      await _serviceChannel.invokeMethod('startService');
    } catch (e) {
      print('Failed to start background service: $e');
    }
  }

  static Future<void> stopBackgroundService() async {
    try {
      await _serviceChannel.invokeMethod('stopService');
    } catch (e) {
      print('Failed to stop background service: $e');
    }
  }
}
