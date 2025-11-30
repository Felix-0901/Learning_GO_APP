/// 應用程式常數定義
/// 將分散在各處的魔術數字集中管理
class AppConstants {
  AppConstants._(); // 防止實例化

  // ========== 時間相關 ==========

  /// 自動儲存間隔
  static const autoSaveInterval = Duration(seconds: 60);

  /// Checkbox 勾選後自動完成的延遲時間
  static const checkboxCompletionDelay = Duration(seconds: 3);

  /// 最小有效學習時段秒數（低於此值不計入）
  static const minStudySessionSeconds = 60;

  /// 學習時間四捨五入基準（秒）
  static const studyTimeRoundingSeconds = 60;

  // ========== 圖片處理 ==========

  /// ONNX 模型輸入尺寸
  static const onnxInputSize = 224;

  /// ONNX 輸入通道數
  static const onnxInputChannels = 3;

  // ========== UI 相關 ==========

  /// 列表項目固定高度（用於 ListView 優化）
  static const listItemHeight = 56.0;

  /// 卡片圓角半徑
  static const cardBorderRadius = 22.0;

  /// 輸入框圓角半徑
  static const fieldBorderRadius = 12.0;

  // ========== 儲存鍵值 ==========

  /// To-Do 儲存鍵
  static const todoStorageKey = 'todos';

  /// Homework 儲存鍵
  static const homeworkStorageKey = 'homeworks';

  /// Timer 每日記錄儲存鍵
  static const timerDailyStorageKey = 'timerDaily';

  /// Timer 設定儲存鍵
  static const timerConfigStorageKey = 'cfg';

  /// 進行中 Session 儲存鍵
  static const activeSessionStorageKey = 'activeSession';

  /// 公告儲存鍵
  static const announcementStorageKey = 'announcements';

  /// 音檔儲存鍵
  static const audioStorageKey = 'audio_files';

  /// 圖片儲存鍵
  static const imageStorageKey = 'image_files';
}
