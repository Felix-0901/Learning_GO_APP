import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/ios_time_picker.dart';
import '../../../core/services/notification_service.dart';
import '../state/timer_state.dart';

class SetGoalSheet extends StatefulWidget {
  const SetGoalSheet({super.key});
  @override
  State<SetGoalSheet> createState() => _SetGoalSheetState();
}

class _SetGoalSheetState extends State<SetGoalSheet> {
  late Duration _goal;

  @override
  void initState() {
    super.initState();
    final timer = context.read<TimerState>();
    final last = timer.todayGoalSeconds;
    _goal = Duration(seconds: (last ?? 3600).clamp(0, 24 * 3600));
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.read<TimerState>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Set today's study goal",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          inlineDurationPicker(
            initial: _goal,
            minuteInterval: 5,
            onChanged: (d) => setState(() => _goal = d),
          ),

          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              timer.setGoalSeconds(_goal.inSeconds);
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class NumberPicker extends StatelessWidget {
  final int value;
  final String label;
  final int max;
  final int step;
  final void Function(int) onChanged;
  const NumberPicker({
    super.key,
    required this.value,
    required this.label,
    this.max = 23,
    this.step = 1,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onChanged((value - step).clamp(0, max)),
          icon: const Icon(Icons.remove),
        ),
        Text('$value$label', style: const TextStyle(fontSize: 18)),
        IconButton(
          onPressed: () => onChanged((value + step).clamp(0, max)),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class TimerModeSheet extends StatefulWidget {
  const TimerModeSheet({super.key});
  @override
  State<TimerModeSheet> createState() => _TimerModeSheetState();
}

class _TimerModeSheetState extends State<TimerModeSheet> {
  String mode = 'stopwatch';
  int countdownInitial = 1500; // 25min - 倒數模式的初始值
  Timer? _ticker;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    final timer = context.read<TimerState>();

    // 恢復上次的模式和倒數設定
    mode = timer.lastTimerMode ?? 'stopwatch';
    countdownInitial = timer.lastCountdownSeconds ?? 1500;

    // 如果有進行中的 session 且正在跑，啟動 ticker
    if (timer.isRunning) {
      _startTicker();
    }

    // 啟動自動儲存（每 60 秒）
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => timer.autoSave(),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {}); // 更新 UI
      _checkCountdownComplete();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _checkCountdownComplete() {
    if (mode != 'countdown') return;
    final timer = context.read<TimerState>();
    final remaining = countdownInitial - timer.currentSessionSeconds;
    if (remaining <= 0 && timer.isRunning) {
      // 倒數結束，自動暫停
      timer.pauseTimer();
      _stopTicker();

      // 延遲一點點讓 UI 先顯示 00:00:00，再執行提醒
      Future.delayed(const Duration(milliseconds: 100), () {
        _onCountdownComplete();
      });
    }
  }

  /// 倒數完成時的提醒效果
  void _onCountdownComplete() {
    final notificationService = NotificationService();

    // 1. 觸覺反饋（不等待，立即執行）
    notificationService.vibrate();

    // 2. 發送系統通知（不等待）
    notificationService.showTimerComplete(
      title: "Time's Up! ⏰",
      body: 'Great job! You completed your study session.',
    );

    // 3. 顯示 App 內對話框
    if (mounted) {
      _showCountdownCompleteDialog();
    }
  }

  void _showCountdownCompleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Time\'s Up! 🎉'),
        content: const Text('Great job! You completed your study session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _hhmmss(int totalSeconds) {
    final h = totalSeconds.abs() ~/ 3600;
    final m = (totalSeconds.abs() % 3600) ~/ 60;
    final s = totalSeconds.abs() % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleClose(TimerState timer) async {
    // Sheet 被關閉時，自動結束 session
    if (timer.hasActiveSession) {
      await timer.finishSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = context.watch<TimerState>();

    // 計算顯示的秒數
    final int displaySeconds;
    if (mode == 'stopwatch') {
      displaySeconds = timer.currentSessionSeconds;
    } else {
      displaySeconds = (countdownInitial - timer.currentSessionSeconds).clamp(
        0,
        countdownInitial,
      );
    }

    final bool isRunning = timer.isRunning;
    final bool canStart = !(mode == 'countdown' && displaySeconds <= 0);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _handleClose(timer);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: MediaQuery.of(
          context,
        ).viewInsets.add(const EdgeInsets.all(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header：左 Title、右 Segmented pill
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Study Timer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ModeSwitch(
                  isStopwatch: mode == 'stopwatch',
                  enabled: !timer.hasActiveSession, // 有 session 時不能切換
                  onChanged: (v) {
                    final newMode = v ? 'stopwatch' : 'countdown';
                    setState(() => mode = newMode);
                    timer.setLastTimerMode(newMode);
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 時間顯示（倒數模式可點擊設定）
            GestureDetector(
              onTap: () async {
                if (mode != 'countdown') return;
                if (timer.hasActiveSession) return; // 有 session 時不能改

                final initial = Duration(seconds: countdownInitial);
                final picked = await pickCountdownHMS(
                  context,
                  initial: initial,
                  title: 'Set countdown',
                  minuteInterval: 1,
                  secondInterval: 1,
                );

                if (picked != null) {
                  setState(() {
                    countdownInitial = picked.inSeconds;
                  });
                  timer.setLastCountdownSeconds(countdownInitial);
                }
              },
              child: Text(
                _hhmmss(displaySeconds),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // 兩個按鈕：Start/Pause + Done
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  // Start / Pause 按鈕
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning
                            ? Colors.orange
                            : Colors.green,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: !canStart
                          ? null
                          : () async {
                              if (isRunning) {
                                await timer.pauseTimer();
                                _stopTicker();
                              } else {
                                await timer.startTimer();
                                _startTicker();
                              }
                            },
                      child: Text(isRunning ? 'Pause' : 'Start'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Done 按鈕
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(
                          color: AppColors.accent,
                          width: 1.5,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () async {
                        _stopTicker();
                        await timer.finishSession();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),

            // 提示文字
            if (timer.hasActiveSession) ...[
              const SizedBox(height: 12),
              Text(
                'Auto-saving every minute',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// iOS 風格滑動藥丸切換（Stopwatch / Countdown）
class _ModeSwitch extends StatelessWidget {
  final bool isStopwatch;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({
    required this.isStopwatch,
    this.enabled = true,
    required this.onChanged,
  });

  static const _blue = Color(0xFF007AFF);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        height: 38,
        width: 200,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 🔵 藍色滑動小藥丸背景
            AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              alignment: isStopwatch
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: Container(
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),

            // ⏱ 兩側文字（保持可點擊）
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onChanged(true) : null,
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isStopwatch ? Colors.white : Colors.black87,
                        ),
                        child: const Text('Stopwatch'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: enabled ? () => onChanged(false) : null,
                    behavior: HitTestBehavior.translucent,
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isStopwatch ? Colors.black87 : Colors.white,
                        ),
                        child: const Text('Countdown'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
