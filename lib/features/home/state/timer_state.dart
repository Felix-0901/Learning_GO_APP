import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/timer_record.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/app_constants.dart';

/// 計時器狀態管理
class TimerState extends ChangeNotifier {
  static const _timerDailyKey = AppConstants.timerDailyStorageKey;
  static const _cfgKey = AppConstants.timerConfigStorageKey;
  static const _activeSessionKey = AppConstants.activeSessionStorageKey;

  List<TimerRecord> _timerDaily = [];
  int? _todayGoalSeconds;
  String? _lastTimerMode; // 'stopwatch' | 'countdown'
  int? _lastCountdownSeconds;

  // === 進行中的 Session 狀態 ===
  DateTime? _sessionStartedAt; // 本次按 Start 的時間（null = 暫停中或未開始）
  int _sessionAccumulatedSeconds = 0; // 已累積的秒數（Pause 時累加）
  String? _sessionStartTimeKey; // Session 開始的 "HH:mm"（用於記錄 StudySession）
  int _lastSavedSeconds = 0; // 上次自動儲存時的累積秒數（避免重複儲存）

  // === 自動儲存 Timer ===
  Timer? _autoSaveTimer;

  /// 今日目標秒數
  int? get todayGoalSeconds => _todayGoalSeconds;

  /// 上次使用的計時模式
  String? get lastTimerMode => _lastTimerMode;

  /// 上次倒數的秒數
  int? get lastCountdownSeconds => _lastCountdownSeconds;

  /// 是否有進行中的 Session（不論是否正在計時）
  bool get hasActiveSession =>
      _sessionStartedAt != null || _sessionAccumulatedSeconds > 0;

  /// 是否正在計時中（Start 狀態）
  bool get isRunning => _sessionStartedAt != null;

  /// 當前 session 的總學習秒數（包含正在跑的）
  int get currentSessionSeconds {
    if (_sessionStartedAt == null) return _sessionAccumulatedSeconds;
    final running = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    return _sessionAccumulatedSeconds + running;
  }

  /// 取得指定日期的學習秒數
  int secondsForDate(DateTime date) {
    final key = _dateKey(date);
    final record = _timerDaily.where((r) => r.date == key).firstOrNull;
    return record?.seconds ?? 0;
  }

  /// 今天的學習秒數（包含進行中的 session）
  int get todaySeconds {
    final saved = secondsForDate(DateTime.now());
    // 加上進行中但尚未儲存的部分
    final unsaved = currentSessionSeconds - _lastSavedSeconds;
    return saved + (unsaved > 0 ? unsaved : 0);
  }

  /// 今天的學習進度比例 (0.0 ~ 1.0)
  double get todayProgress {
    if (_todayGoalSeconds == null || _todayGoalSeconds == 0) return 0.0;
    return (todaySeconds / _todayGoalSeconds!).clamp(0.0, 1.0);
  }

  /// 是否達成今日目標
  bool get goalReached =>
      _todayGoalSeconds != null && todaySeconds >= _todayGoalSeconds!;

  /// 取得指定日期的學習時段
  List<StudySession> sessionsForDate(DateTime date) {
    final key = _dateKey(date);
    final record = _timerDaily.where((r) => r.date == key).firstOrNull;
    return record?.sessions ?? [];
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _timeKey(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// 載入資料
  Future<void> load() async {
    final list = await StorageService.instance.getList(_timerDailyKey);
    _timerDaily = list
        .map((e) => TimerRecord.fromJson(e as Map<String, dynamic>))
        .toList();

    final cfg = await StorageService.instance.getMap(_cfgKey);
    _todayGoalSeconds = cfg['todayGoalSeconds'] as int?;
    _lastTimerMode = cfg['lastTimerMode'] as String?;
    _lastCountdownSeconds = cfg['lastCountdownSeconds'] as int?;

    // 載入進行中的 session（App 重啟恢復）
    final activeSession = await StorageService.instance.getMap(
      _activeSessionKey,
    );
    if (activeSession.isNotEmpty) {
      final startedAtStr = activeSession['startedAt'] as String?;
      if (startedAtStr != null) {
        _sessionStartedAt = DateTime.tryParse(startedAtStr);
      }
      _sessionAccumulatedSeconds = activeSession['accumulated'] as int? ?? 0;
      _sessionStartTimeKey = activeSession['startTimeKey'] as String?;
      _lastSavedSeconds = activeSession['lastSaved'] as int? ?? 0;
    }

    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.instance.setJson(
      _timerDailyKey,
      _timerDaily.map((r) => r.toJson()).toList(),
    );
    await StorageService.instance.setJson(_cfgKey, {
      'todayGoalSeconds': _todayGoalSeconds,
      'lastTimerMode': _lastTimerMode,
      'lastCountdownSeconds': _lastCountdownSeconds,
    });
  }

  /// 儲存進行中的 session 狀態
  Future<void> _saveActiveSession() async {
    if (!hasActiveSession) {
      await StorageService.instance.remove(_activeSessionKey);
      return;
    }
    await StorageService.instance.setJson(_activeSessionKey, {
      'startedAt': _sessionStartedAt?.toIso8601String(),
      'accumulated': _sessionAccumulatedSeconds,
      'startTimeKey': _sessionStartTimeKey,
      'lastSaved': _lastSavedSeconds,
    });
  }

  /// 增加今天的學習秒數
  Future<void> _addTodaySeconds(int secs) async {
    if (secs <= 0) return;

    final todayKey = _dateKey(DateTime.now());
    final index = _timerDaily.indexWhere((r) => r.date == todayKey);

    if (index < 0) {
      _timerDaily.add(TimerRecord(date: todayKey, seconds: secs));
    } else {
      _timerDaily[index] = _timerDaily[index].addSeconds(secs);
    }

    await _save();
    notifyListeners();
  }

  /// 設定今日目標
  Future<void> setGoalSeconds(int? secs) async {
    _todayGoalSeconds = secs;
    await _save();
    notifyListeners();
  }

  /// 設定上次使用的計時模式
  Future<void> setLastTimerMode(String mode) async {
    _lastTimerMode = mode;
    await _save();
  }

  /// 設定上次倒數秒數
  Future<void> setLastCountdownSeconds(int secs) async {
    _lastCountdownSeconds = secs;
    await _save();
  }

  // =========================================================
  // 新的 Session 管理 API
  // =========================================================

  /// 開始計時（Start 按鈕）
  Future<void> startTimer() async {
    if (_sessionStartedAt != null) return; // 已經在跑了

    final now = DateTime.now();
    _sessionStartedAt = now;

    // 如果是全新的 session，記錄開始時間
    _sessionStartTimeKey ??= _timeKey(now);

    // 啟動自動儲存 Timer
    _startAutoSaveTimer();

    await _saveActiveSession();
    notifyListeners();
  }

  /// 暫停計時（Pause 按鈕）- 立即儲存進度
  Future<void> pauseTimer() async {
    if (_sessionStartedAt == null) return; // 沒在跑

    // 停止自動儲存 Timer
    _stopAutoSaveTimer();

    // 累加這段時間
    final elapsed = DateTime.now().difference(_sessionStartedAt!).inSeconds;
    _sessionAccumulatedSeconds += elapsed;
    _sessionStartedAt = null;

    // 立即儲存進度
    await _saveProgress();
    await _saveActiveSession();
    notifyListeners();
  }

  /// 啟動自動儲存 Timer
  void _startAutoSaveTimer() {
    _stopAutoSaveTimer(); // 先停止既有的
    _autoSaveTimer = Timer.periodic(
      AppConstants.autoSaveInterval,
      (_) => autoSave(),
    );
  }

  /// 停止自動儲存 Timer
  void _stopAutoSaveTimer() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// 儲存進度（自動儲存或 Pause 時呼叫）
  Future<void> _saveProgress() async {
    final total = currentSessionSeconds;
    final toSave = total - _lastSavedSeconds;

    if (toSave >= AppConstants.minStudySessionSeconds) {
      // 至少達到最小時段才儲存（四捨五入到分鐘）
      final rounded =
          ((toSave + 30) ~/ AppConstants.studyTimeRoundingSeconds) *
          AppConstants.studyTimeRoundingSeconds;
      await _addTodaySeconds(rounded);
      _lastSavedSeconds += rounded;
    }
  }

  /// 自動儲存（由 Timer 定期呼叫）
  Future<void> autoSave() async {
    if (!hasActiveSession) return;
    await _saveProgress();
    await _saveActiveSession();
  }

  /// 結束 Session（Done 按鈕或 Sheet 關閉時）
  Future<void> finishSession() async {
    if (!hasActiveSession) return;

    // 停止自動儲存 Timer
    _stopAutoSaveTimer();

    // 如果還在跑，先暫停
    if (_sessionStartedAt != null) {
      final elapsed = DateTime.now().difference(_sessionStartedAt!).inSeconds;
      _sessionAccumulatedSeconds += elapsed;
      _sessionStartedAt = null;
    }

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final endTimeKey = _timeKey(now);

    // 計算最終要儲存的秒數
    final total = _sessionAccumulatedSeconds;
    final toSave = total - _lastSavedSeconds;

    if (toSave > 0) {
      // 儲存剩餘的時間（四捨五入到分鐘）
      final rounded = toSave >= 30
          ? ((toSave + 30) ~/ AppConstants.studyTimeRoundingSeconds) *
                AppConstants.studyTimeRoundingSeconds
          : 0;
      if (rounded > 0) {
        await _addTodaySeconds(rounded);
      }
    }

    // 記錄學習時段（如果有開始時間且總時間 >= 最小時段）
    if (_sessionStartTimeKey != null &&
        total >= AppConstants.minStudySessionSeconds) {
      final session = StudySession(
        start: _sessionStartTimeKey!,
        end: endTimeKey,
      );
      final index = _timerDaily.indexWhere((r) => r.date == todayKey);

      if (index < 0) {
        _timerDaily.add(
          TimerRecord(date: todayKey, seconds: 0, sessions: [session]),
        );
      } else {
        _timerDaily[index] = _timerDaily[index].addSession(session);
      }
      await _save();
    }

    // 清除 session 狀態
    _sessionStartedAt = null;
    _sessionAccumulatedSeconds = 0;
    _sessionStartTimeKey = null;
    _lastSavedSeconds = 0;

    await StorageService.instance.remove(_activeSessionKey);
    notifyListeners();
  }

  /// 取消 Session（不儲存，直接放棄）
  Future<void> cancelSession() async {
    // 停止自動儲存 Timer
    _stopAutoSaveTimer();

    _sessionStartedAt = null;
    _sessionAccumulatedSeconds = 0;
    _sessionStartTimeKey = null;
    _lastSavedSeconds = 0;

    await StorageService.instance.remove(_activeSessionKey);
    notifyListeners();
  }

  /// 取得所有記錄（用於圖表等）
  List<TimerRecord> get allRecords => List.unmodifiable(_timerDaily);

  /// 釋放資源（當 State 被銷毀時呼叫）
  @override
  void dispose() {
    _stopAutoSaveTimer();
    super.dispose();
  }
}
