import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> showDownloadStarted(String url) async {
    await _plugin.show(
      url.hashCode,
      'Downloading...',
      'Grabbing reel from Instagram',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instagrab_downloads',
          'Downloads',
          channelDescription: 'Download progress notifications',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          showProgress: true,
          indeterminate: true,
        ),
      ),
    );
  }

  static Future<void> showDownloadComplete(String url) async {
    await _plugin.cancel(url.hashCode);
    await _plugin.show(
      url.hashCode + 1,
      'Download Complete',
      'Reel saved to gallery',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instagrab_downloads',
          'Downloads',
          channelDescription: 'Download progress notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

  static Future<void> showDownloadFailed(String url, String error) async {
    await _plugin.cancel(url.hashCode);
    await _plugin.show(
      url.hashCode + 2,
      'Download Failed',
      error,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'instagrab_downloads',
          'Downloads',
          channelDescription: 'Download progress notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }
}
