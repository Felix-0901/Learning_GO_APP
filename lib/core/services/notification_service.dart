// lib/services/notification_service.dart
// All identifiers in English; comments in 中文。

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';

/// 單例通知服務：負責初始化、權限、立即與排程通知
class NotificationService {
  // ===== Singleton =====
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();
  bool _inited = false;

  /// 初始化：權限 + 時區
  Future<void> init() async {
    if (_inited) return;

    // 1) iOS 初始化設定
    const ios = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    // 2) Android 初始化設定
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const init = InitializationSettings(iOS: ios, android: android);
    await _fln.initialize(init);

    // 3) iOS 16+ 臨時權限（若需要）
    if (Platform.isIOS) {
      await _fln
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    // Android 13+：不主動請求，交由 Manifest 控制

    // 5) time zone
    tz.initializeTimeZones();
    // 設定為系統時區
    tz.setLocalLocation(tz.local);

    _inited = true;
  }

  /// 立即顯示通知
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'general_channel', // channel id
        'General', // channel name
        channelDescription: 'General notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );
    await _fln.show(id, title, body, details, payload: payload);
  }

  /// 計時器完成通知（帶音效和震動）
  Future<void> showTimerComplete({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'timer_channel',
        'Timer',
        channelDescription: 'Timer notifications',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true, // 播放音效
        presentBadge: true,
        // iOS 通知會自動震動（如果系統設定允許）
      ),
    );
    await _fln.show(9999, title, body, details);
  }

  /// 震動一次（注意：iOS 上這是觸覺反饋，不是真正的震動）
  Future<void> vibrate() async {
    // iOS: 觸覺反饋（較輕微）
    // Android: 標準震動
    if (Platform.isIOS) {
      // iOS 使用 notificationOccurred 會有較明顯的反饋
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.vibrate();
    }
  }

  /// 輕震動（用於按鈕反饋等）
  Future<void> lightVibrate() async {
    await HapticFeedback.lightImpact();
  }

  /// 播放系統提示音
  Future<void> playSystemSound() async {
    // iOS/Android 都支援的系統音效
    await SystemSound.play(SystemSoundType.alert);
  }

  /// 指定時間排程（本地時區）
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime when, // local time
    String? payload,
  }) async {
    final tzTime = tz.TZDateTime.from(when, tz.local);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'schedule_channel',
        'Scheduled',
        channelDescription: 'Scheduled notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _fln.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: payload,
    );
  }

  /// 每天 00:00 觸發（使用 matchDateTimeComponents 保持每日重覆）
  Future<void> scheduleDailyMidnight({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 0, 0);
    if (!now.isBefore(next)) next = next.add(const Duration(days: 1));

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel',
        'Daily',
        channelDescription: 'Daily checker',
        importance: Importance.low,
        priority: Priority.low,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _fln.zonedSchedule(
      id,
      title,
      body,
      next,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 每天同一時間
      payload: payload,
    );
  }

  /// 取消指定 id
  Future<void> cancel(int id) => _fln.cancel(id);

  /// 取消全部
  Future<void> cancelAll() => _fln.cancelAll();
}
