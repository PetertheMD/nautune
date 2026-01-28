import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const int _downloadNotificationId = 888;
  static const String _channelId = 'nautune_downloads';
  static const String _channelName = 'Downloads';
  static const String _channelDescription = 'Show download progress';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Android setup
    // Note: Ensure @mipmap/ic_launcher exists. 
    // If nautune uses a custom icon name, update here.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS setup
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    // Linux setup
    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
    
    // Create channel for Android
    if (Platform.isAndroid) {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.low, // Low importance for progress (no sound)
          showBadge: false,
        );
        
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
    }
    
    _initialized = true;
  }
  
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
       await _flutterLocalNotificationsPlugin
           .resolvePlatformSpecificImplementation<
               IOSFlutterLocalNotificationsPlugin>()
           ?.requestPermissions(
             alert: true,
             badge: true,
             sound: true,
           );
    }
  }

  /// Show or update progress notification
  Future<void> showProgress({
    required String title,
    required String body,
    int? progress, // 0-100, null for indeterminate
    int maxProgress = 100,
  }) async {
    if (!_initialized) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      channelShowBadge: false,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      indeterminate: progress == null,
      maxProgress: maxProgress,
      progress: progress ?? 0,
      ongoing: true, // Prevent dismissal while downloading
      autoCancel: false,
      silent: true,
    );
    
    final LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.low,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      linux: linuxPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: _downloadNotificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Show download complete notification
  Future<void> showComplete({required String title, required String body}) async {
    if (!_initialized) return;

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showProgress: false,
      ongoing: false,
      autoCancel: true,
    );
    
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: _downloadNotificationId,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Cancel the download notification
  Future<void> cancel() async {
    if (!_initialized) return;
    await _flutterLocalNotificationsPlugin.cancel(id: _downloadNotificationId);
  }
}
