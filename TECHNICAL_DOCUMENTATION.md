# LearningGO 技術文檔

> 本文檔詳細記錄 LearningGO Flutter 學習管理應用程式的架構設計、資料模型、服務層與功能模組。

---

## 目錄

1. [架構總覽](#1-架構總覽)
2. [資料模型 (Models)](#2-資料模型-models)
3. [服務層 (Services)](#3-服務層-services)
4. [功能模組 (Features)](#4-功能模組-features)
5. [輔助程式碼](#5-輔助程式碼)
6. [資料流向圖](#6-資料流向圖)

---

## 1. 架構總覽

### 1.1 專案結構

```
lib/
├── main.dart                 # 應用程式入口
├── app.dart                  # MaterialApp 與導航配置
├── core/                     # 核心共用程式碼
│   ├── constants/            # 常數定義
│   ├── models/               # 資料模型
│   ├── services/             # 服務層
│   ├── utils/                # 工具函數
│   └── widgets/              # 共用 Widget
├── features/                 # 功能模組
│   ├── home/                 # 首頁功能
│   ├── voice/                # 語音轉文字功能
│   ├── image_tool/           # 圖片處理功能
│   └── settings/             # 設定與圖表功能
└── shared/                   # 跨功能共享資源
```

### 1.2 狀態管理模式

LearningGO 採用 **Provider + ChangeNotifier** 模式進行狀態管理：

```
┌─────────────────────────────────────────────────────────┐
│                     MultiProvider                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │
│  │  TodoState  │ │HomeworkState│ │    TimerState       │ │
│  └─────────────┘ └─────────────┘ └─────────────────────┘ │
│  ┌─────────────┐ ┌─────────────────┐ ┌───────────────┐   │
│  │ MediaState  │ │AnnouncementState│ │  VoiceState   │   │
│  └─────────────┘ └─────────────────┘ └───────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
               ┌─────────────────────┐
               │   LearningGOApp     │
               │   (MaterialApp)     │
               └─────────────────────┘
```

### 1.3 三層架構

```
┌─────────────────────────────────────────┐
│              UI Layer (Pages)           │
│   HomePage, VoicePage, ImageToolPage,   │
│   SettingsPage                          │
└─────────────────┬───────────────────────┘
                  │ Consumer / Selector
                  ▼
┌─────────────────────────────────────────┐
│           State Layer (States)          │
│   TodoState, HomeworkState, TimerState, │
│   MediaState, AnnouncementState,        │
│   VoiceState                            │
└─────────────────┬───────────────────────┘
                  │ 呼叫
                  ▼
┌─────────────────────────────────────────┐
│         Service Layer (Services)        │
│   StorageService, NotificationService,  │
│   MediaService, OnnxService, STTService │
└─────────────────────────────────────────┘
```

### 1.4 應用程式入口

#### `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化通知服務
  await NotificationService().init();

  // 2. 建立所有 State 實例
  final todoState = TodoState();
  final homeworkState = HomeworkState();
  // ... 其他 State

  // 3. 載入所有資料
  await Future.wait([
    todoState.load(),
    homeworkState.load(),
    // ...
  ]);

  // 4. 安排每日午夜檢查
  await announcementState.scheduleDailyMidnightCheck();

  // 5. 啟動應用程式
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => todoState),
        // ...
      ],
      child: const LearningGOApp(),
    ),
  );
}
```

#### `app.dart`

- 使用 `IndexedStack` 配合延遲載入機制
- 底部導航列包含四個頁面：Home、Voice to Text、Image Tool、Charts
- 主題配置：Material 3、iOS 風格日期選擇器

---

## 2. 資料模型 (Models)

所有資料模型位於 `lib/core/models/`，皆為不可變類別（immutable class），支援：
- JSON 序列化/反序列化
- `copyWith` 方法
- `==` 與 `hashCode` 覆寫

### 2.1 Todo（待辦事項）

**檔案**: `lib/core/models/todo.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | `String` | ✓ | 唯一識別碼 (UUID) |
| `title` | `String` | ✓ | 待辦標題 |
| `desc` | `String` | ✓ | 詳細描述 |
| `due` | `DateTime` | ✓ | 到期日期時間 |
| `doneAt` | `DateTime?` | ✗ | 完成時間（null 表示未完成） |

**計算屬性**:
- `isDone`: `bool` - 是否已完成 (`doneAt != null`)

**JSON 格式**:
```json
{
  "id": "uuid-string",
  "title": "完成作業",
  "desc": "數學第三章",
  "due": "2025-11-30T23:59:00.000",
  "doneAt": null
}
```

---

### 2.2 Homework（作業）

**檔案**: `lib/core/models/homework.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | `String` | ✓ | 唯一識別碼 (UUID) |
| `title` | `String` | ✓ | 作業標題 |
| `content` | `String` | ✓ | 作業內容描述 |
| `due` | `DateTime` | ✓ | 截止日期時間 |
| `reminderType` | `String?` | ✗ | 提醒類型：`'none'`, `'custom'` 等 |
| `reminderAt` | `DateTime?` | ✗ | 自訂提醒時間 |
| `color` | `String?` | ✗ | 顏色標籤（hex 或名稱） |
| `doneAt` | `DateTime?` | ✗ | 完成時間 |

**計算屬性**:
- `isDone`: `bool` - 是否已完成

---

### 2.3 TimerRecord（計時記錄）

**檔案**: `lib/core/models/timer_record.dart`

#### StudySession（學習時段）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `start` | `String` | ✓ | 開始時間 (`"HH:mm"` 格式) |
| `end` | `String` | ✓ | 結束時間 (`"HH:mm"` 格式) |

#### TimerRecord（每日計時記錄）

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `date` | `String` | ✓ | 日期 (`"yyyy-MM-dd"` 格式) |
| `seconds` | `int` | ✓ | 當日累計學習秒數 |
| `sessions` | `List<StudySession>` | ✗ | 學習時段列表 |

**方法**:
- `addSession(StudySession)`: 新增學習時段
- `addSeconds(int)`: 增加秒數

---

### 2.4 AudioFile（音檔）

**檔案**: `lib/core/models/audio_file.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | `String` | ✓ | 唯一識別碼 |
| `name` | `String` | ✓ | 檔案顯示名稱 |
| `path` | `String` | ✓ | 檔案完整路徑 |
| `createdAt` | `DateTime?` | ✗ | 建立時間 |
| `recordedAt` | `DateTime?` | ✗ | 錄音時間 |

---

### 2.5 ImageFile（圖片檔案）

**檔案**: `lib/core/models/image_file.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | `String` | ✓ | 唯一識別碼 |
| `name` | `String` | ✓ | 檔案顯示名稱 |
| `path` | `String` | ✓ | 檔案完整路徑 |
| `createdAt` | `DateTime` | ✓ | 建立時間 |

---

### 2.6 Announcement（公告）

**檔案**: `lib/core/models/announcement.dart`

| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `id` | `String` | ✓ | 唯一識別碼 |
| `title` | `String` | ✓ | 公告標題 |
| `body` | `String` | ✓ | 公告內容 |
| `at` | `DateTime` | ✓ | 發布時間 |

---

## 3. 服務層 (Services)

服務層位於 `lib/core/services/`，採用**單例模式**提供全域存取。

### 3.1 StorageService（本地儲存服務）

**檔案**: `lib/core/services/storage_service.dart`

**依賴**: `shared_preferences`

**責任**: 封裝 SharedPreferences，提供 JSON 資料的本地持久化。

| 方法 | 參數 | 回傳 | 說明 |
|------|------|------|------|
| `init()` | - | `Future<void>` | 初始化（可選，首次使用時自動初始化） |
| `setJson(key, value)` | `String`, `Object` | `Future<void>` | 儲存 JSON 物件 |
| `getList(key)` | `String` | `Future<List>` | 讀取 List 資料 |
| `getMap(key)` | `String` | `Future<Map>` | 讀取 Map 資料 |
| `getString(key)` | `String` | `Future<String?>` | 讀取字串 |
| `setString(key, value)` | `String`, `String` | `Future<void>` | 儲存字串 |
| `getInt(key)` | `String` | `Future<int?>` | 讀取整數 |
| `setInt(key, value)` | `String`, `int` | `Future<void>` | 儲存整數 |
| `getBool(key)` | `String` | `Future<bool?>` | 讀取布林值 |
| `setBool(key, value)` | `String`, `bool` | `Future<void>` | 儲存布林值 |
| `remove(key)` | `String` | `Future<void>` | 刪除指定鍵值 |
| `clear()` | - | `Future<void>` | 清除所有資料 |

**使用方式**:
```dart
await StorageService.instance.setJson('todos', todoList);
final list = await StorageService.instance.getList('todos');
```

**向後相容**:
保留 `KV` 類別作為舊版 API 的別名。

---

### 3.2 NotificationService（通知服務）

**檔案**: `lib/core/services/notification_service.dart`

**依賴**: `flutter_local_notifications`, `timezone`

**責任**: 管理本地通知的初始化、排程與顯示。

| 方法 | 參數 | 回傳 | 說明 |
|------|------|------|------|
| `init()` | - | `Future<void>` | 初始化通知與時區 |
| `showNow(id, title, body, payload?)` | `int`, `String`, `String`, `String?` | `Future<void>` | 立即顯示通知 |
| `scheduleAt(id, title, body, when, payload?)` | `int`, `String`, `String`, `DateTime`, `String?` | `Future<void>` | 指定時間排程通知 |
| `scheduleDailyMidnight(id, title, body, payload?)` | `int`, `String`, `String`, `String?` | `Future<void>` | 每日午夜重複通知 |
| `cancel(id)` | `int` | `Future<void>` | 取消指定通知 |
| `cancelAll()` | - | `Future<void>` | 取消所有通知 |

**通知頻道**:
- `general_channel`: 一般通知
- `schedule_channel`: 排程通知
- `daily_channel`: 每日通知

---

### 3.3 MediaService（媒體服務）

**檔案**: `lib/core/services/media_service.dart`

**依賴**: `path_provider`, `record`, `image_picker`, `gal`

**責任**: 管理圖片與音檔的儲存、錄音、相機拍照等操作。

#### 目錄結構
```
Documents/
├── originals/    # 原始圖片
├── processed/    # 處理後圖片
└── audios/       # 音檔
```

#### 圖片操作

| 方法 | 說明 |
|------|------|
| `listOriginalImages()` | 列出所有原始圖片 |
| `listProcessedImages()` | 列出所有處理後圖片 |
| `saveAsOriginal(file)` | 儲存為原始圖片 |
| `saveAsProcessed(file)` | 儲存為處理後圖片 |
| `deleteOriginal(file)` | 刪除原始圖片 |
| `deleteProcessed(file)` | 刪除處理後圖片 |
| `saveProcessedToDevice(file, album?)` | 匯出至系統相簿 |
| `pickFromGallery()` | 從相簿選取圖片 |
| `captureFromCamera()` | 使用相機拍照 |
| `saveBytesToApp(bytes, name)` | 儲存二進位資料 |

#### 錄音操作

| 方法 | 說明 |
|------|------|
| `canRecord()` | 檢查麥克風權限 |
| `startRecord()` | 開始錄音，回傳檔案路徑 |
| `stopRecord()` | 停止錄音，回傳檔案路徑 |
| `ingestAudio(source)` | 匯入外部音檔到 App |

**錄音格式**: AAC-LC, 128kbps, 44.1kHz, 單聲道

---

### 3.4 OnnxService（ONNX 推論服務）

**檔案**: `lib/core/services/onnx_service.dart`

**依賴**: `onnxruntime`, `image`

**責任**: 載入 ONNX 模型並執行圖片處理推論。

| 方法 | 參數 | 回傳 | 說明 |
|------|------|------|------|
| `run(imageBytes, modelName)` | `Uint8List`, `String` | `Future<Uint8List>` | 執行推論並回傳處理後圖片 |

**可用模型**:
- `medium.onnx` - 中等強度
- `sub-conservative.onnx` - 次保守
- `conservative.onnx` - 保守
- `radical.onnx` - 激進

**處理流程**:
1. 載入/切換模型（延遲載入，模型不變則不重複載入）
2. 前處理：調整為 224×224，正規化為 Float32
3. 執行推論
4. 後處理：還原至原始尺寸，輸出 PNG

---

### 3.5 STTService（語音轉文字服務）

**檔案**: `lib/core/services/stt_service.dart`

**依賴**: `whisper_ggml`

**責任**: 使用 Whisper 模型進行離線語音轉文字。

| 方法 | 參數 | 回傳 | 說明 |
|------|------|------|------|
| `init()` | - | `Future<bool>` | 初始化模型 |
| `transcribeFile(filePath, lang?)` | `String`, `String` | `Future<String>` | 轉寫音檔 |

**屬性**:
- `isReady`: `bool` - 模型是否已載入

**模型**: `ggml-base.bin`（從 assets 載入或自動下載）

**支援語言**: `'auto'`（自動偵測，支援中英混合）

---

## 4. 功能模組 (Features)

### 4.1 Home 模組

**路徑**: `lib/features/home/`

#### 頁面

| 頁面 | 檔案 | 說明 |
|------|------|------|
| `HomePage` | `pages/home_page.dart` | 主頁面，顯示 Daily Task、To-Do、Homework、Study Timer |
| `NotificationsPage` | `pages/notifications_page.dart` | 通知中心頁面 |

#### 狀態類別

##### TodoState

**檔案**: `state/todo_state.dart`

**Storage Key**: `'todos'`

| 屬性/方法 | 說明 |
|----------|------|
| `todos` | 所有待辦事項（不可變列表） |
| `visibleTodos` | 未完成的待辦（依到期日排序） |
| `todayTodos(now)` | 今天到期的待辦 |
| `todayDoneCount(now)` | 今天完成數量 |
| `todayTotalCount(now)` | 今天總數量 |
| `load()` | 從 Storage 載入資料 |
| `add(title, desc, due)` | 新增待辦 |
| `update(id, title, desc, due)` | 更新待辦 |
| `complete(id)` | 標記完成 |
| `uncomplete(id)` | 取消完成 |
| `remove(id)` | 刪除待辦 |
| `getById(id)` | 根據 ID 取得待辦 |

##### HomeworkState

**檔案**: `state/homework_state.dart`

**Storage Key**: `'homeworks'`

| 屬性/方法 | 說明 |
|----------|------|
| `homeworks` | 所有作業（不可變列表） |
| `visibleHomeworks` | 未完成的作業（依到期日排序） |
| `todayHomeworks(now)` | 今天到期的作業 |
| `load()` | 從 Storage 載入並重新安排提醒 |
| `add(...)` | 新增作業（含提醒排程） |
| `update(homework)` | 更新作業 |
| `complete(id)` | 標記完成 |
| `uncomplete(id)` | 取消完成 |
| `remove(id)` | 刪除作業 |

**特殊功能**: 自動安排本地通知提醒

##### TimerState

**檔案**: `state/timer_state.dart`

**Storage Keys**: `'timerDaily'`, `'cfg'`

| 屬性/方法 | 說明 |
|----------|------|
| `todayGoalSeconds` | 今日目標秒數 |
| `lastTimerMode` | 上次計時模式（`'stopwatch'` / `'countdown'`） |
| `lastCountdownSeconds` | 上次倒數秒數 |
| `isStudying` | 是否正在學習中 |
| `todaySeconds` | 今天學習秒數 |
| `todayProgress` | 今日進度比例 (0.0 ~ 1.0) |
| `goalReached` | 是否達成目標 |
| `secondsForDate(date)` | 取得指定日期學習秒數 |
| `sessionsForDate(date)` | 取得指定日期學習時段 |
| `addTodaySeconds(secs)` | 增加今天學習秒數 |
| `setGoalSeconds(secs)` | 設定今日目標 |
| `startStudySession()` | 開始學習時段 |
| `endStudySession()` | 結束學習時段 |
| `allRecords` | 所有計時記錄 |

##### MediaState

**檔案**: `state/media_state.dart`

**Storage Keys**: `'audioFiles'`, `'images'`

| 屬性/方法 | 說明 |
|----------|------|
| `audioFiles` | 所有音檔 |
| `images` | 所有圖片 |
| `currentImage` | 當前選擇的圖片 |
| `isImageProcessed` | 圖片是否已處理 |
| `addAudio(name, path)` | 新增音檔 |
| `renameAudio(id, name)` | 重新命名音檔 |
| `removeAudio(id)` | 刪除音檔 |
| `addImage(name, path)` | 新增圖片 |
| `removeImage(id)` | 刪除圖片 |
| `setCurrentImage(file)` | 設定當前圖片 |
| `markProcessed(value)` | 標記圖片已處理 |
| `clearCurrentImage()` | 清除當前圖片 |

##### AnnouncementState

**檔案**: `state/announcement_state.dart`

**Storage Key**: `'announcements'`

| 屬性/方法 | 說明 |
|----------|------|
| `announcements` | 所有公告（最新在前） |
| `push(title, body)` | 新增公告 |
| `remove(id)` | 刪除公告 |
| `clearAll()` | 清除所有公告 |
| `scheduleDailyMidnightCheck()` | 安排每日午夜檢查通知 |

#### 小工具

| 小工具 | 檔案 | 說明 |
|--------|------|------|
| `SectionCard` | `widgets/section_card.dart` | 區塊卡片容器 |
| `TodoListItem` | `widgets/todo_list_item.dart` | 待辦事項列表項 |
| `HomeworkListItem` | `widgets/homework_list_item.dart` | 作業列表項 |
| `RingProgress` | `widgets/ring_progress.dart` | 環形進度指示器 |
| `AddTodoSheet` | `widgets/todo_homework_sheets.dart` | 新增/編輯待辦的 Bottom Sheet |
| `AddHomeworkSheet` | `widgets/todo_homework_sheets.dart` | 新增/編輯作業的 Bottom Sheet |
| `TimerSheet` | `widgets/timer_sheets.dart` | 計時器 Bottom Sheet |

---

### 4.2 Voice 模組

**路徑**: `lib/features/voice/`

#### 頁面

| 頁面 | 檔案 | 說明 |
|------|------|------|
| `VoicePage` | `pages/voice_page.dart` | 語音轉文字主頁面 |
| `AudioLibraryPage` | `pages/audio_library_page.dart` | 音檔庫頁面 |

#### 狀態類別

##### VoiceState

**檔案**: `state/voice_state.dart`

| 屬性/方法 | 說明 |
|----------|------|
| `voiceText` | 轉寫後的文字 |
| `voiceTranscribing` | 是否正在轉寫中 |
| `recording` | 是否正在錄音 |
| `recordingPath` | 當前錄音檔路徑 |
| `setVoiceText(value)` | 設定轉寫文字 |
| `setVoiceTranscribing(value)` | 設定轉寫狀態 |
| `setRecording(value, path?)` | 設定錄音狀態 |
| `clear()` | 清除所有狀態 |
| `clearRecordingPath()` | 清除錄音路徑 |

#### 資料流向

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ VoicePage   │────▶│ VoiceState  │     │  STTService │
│             │     │             │     │             │
│ • 錄音按鈕  │     │ • recording │     │ • Whisper   │
│ • 轉寫按鈕  │     │ • voiceText │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                       ▲
       │                                       │
       ▼                                       │
┌─────────────┐                                │
│MediaService │────────────────────────────────┘
│ • 錄音功能  │       音檔路徑
└─────────────┘
```

---

### 4.3 ImageTool 模組

**路徑**: `lib/features/image_tool/`

#### 頁面

| 頁面 | 檔案 | 說明 |
|------|------|------|
| `ImageToolPage` | `pages/image_tool_page.dart` | 圖片處理主頁面 |
| `ImageLibraryPage` | `pages/image_library_page.dart` | 圖片庫頁面 |

#### 功能流程

```
┌───────────────────┐
│   選擇圖片來源    │
│ • 相簿 / 相機     │
└─────────┬─────────┘
          ▼
┌───────────────────┐
│   選擇處理模型    │
│ • Medium          │
│ • Sub-Conservative│
│ • Conservative    │
│ • Radical         │
└─────────┬─────────┘
          ▼
┌───────────────────┐
│   OnnxService     │
│   執行推論        │
└─────────┬─────────┘
          ▼
┌───────────────────┐
│   顯示處理結果    │
│ • 下載到相簿      │
│ • 儲存到 App      │
└───────────────────┘
```

---

### 4.4 Settings 模組（圖表）

**路徑**: `lib/features/settings/`

#### 頁面

| 頁面 | 檔案 | 說明 |
|------|------|------|
| `SettingsPage` | `pages/settings_page.dart` | 學習統計圖表頁面 |

#### 圖表類型

| 圖表 | 說明 |
|------|------|
| Today's Study | 今日學習時間軸（中心 ± 3 小時） |
| This Week | 本週學習長條圖 |
| This Month | 本月學習長條圖 |
| Distribution | 學習時段分布表 |

**依賴**: `fl_chart`

---

## 5. 輔助程式碼

### 5.1 AppColors（顏色常數）

**檔案**: `lib/core/constants/app_colors.dart`

```dart
class AppColors {
  // iOS 主要藍色
  static const accent = Color(0xFF007AFF);

  // 主色系
  static const primary = Color(0xFFFFD54F);

  // 柔和背景色
  static const softBlue = Color(0xFFD9ECFF);
  static const softCyan = Color(0xFFE4F7F4);
  static const softOrange = Color(0xFFFFEFE2);
  static const softGray = Color(0xFFF0F1F3);
  static const softRed = Color(0xFFFFEBEE);
  static const lightBlue = Color(0xFFD6E6FF);

  // 功能色
  static const green = Color(0xFF1DB954);
  static const gold = Color(0xFFFFC107);
  static const error = Color(0xFFE53935);

  // 文字色
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textHint = Color(0xFFBDBDBD);
}
```

**共用輸入框樣式**:
```dart
InputDecoration inputDecoration({
  String? hint,
  EdgeInsetsGeometry? contentPadding,
  String? errorText,
});
```

---

### 5.2 FormatUtils（格式化工具）

**檔案**: `lib/core/utils/format.dart`

**依賴**: `intl`

| 方法 | 說明 | 範例 |
|------|------|------|
| `humanDue(DateTime)` | 人類可讀到期日 | `"Mon, Dec 25"` |
| `hhmm(int seconds)` | 秒數轉 HH:mm | `"02:30"` |
| `hhmmss(int seconds)` | 秒數轉 HH:mm:ss | `"02:30:45"` |
| `todayKey()` | 今天日期字串 | `"2025-11-30"` |
| `isSameDay(a, b)` | 判斷同一天 | `true/false` |
| `isToday(DateTime)` | 判斷是否今天 | `true/false` |

**預設格式化器**:
- `dateFmt`: `yyyy-MM-dd`
- `timeFmt`: `HH:mm`
- `dateTimeFmt`: `yyyy-MM-dd HH:mm`

---

### 5.3 IdUtils（ID 產生工具）

**檔案**: `lib/core/utils/id.dart`

**依賴**: `uuid`

| 方法 | 說明 |
|------|------|
| `generate()` | 產生新的 UUID v4 |
| `hashId(String seed)` | 根據種子產生 hash ID（用於通知 ID） |

---

### 5.4 ios_time_picker（iOS 風格時間選擇器）

**檔案**: `lib/core/widgets/ios_time_picker.dart`

提供跨平台的時間、日期、倒數選擇器，在 iOS/macOS 上使用 Cupertino 風格，其他平台使用 Material 風格。

| 函數 | 說明 |
|------|------|
| `pickTime(context, initial, ...)` | 時間選擇器 |
| `pickDate(context, initial, ...)` | 日期選擇器 |
| `pickCountdown(context, initial, ...)` | 倒數時間選擇器 |

---

### 5.5 SectionCard（區塊卡片）

**檔案**: `lib/features/home/widgets/section_card.dart`

通用的卡片容器元件，用於首頁各區塊。

| 參數 | 型別 | 說明 |
|------|------|------|
| `title` | `String` | 左上角標題 |
| `child` | `Widget` | 內容區塊 |
| `trailing` | `Widget?` | 右上角小按鈕 |
| `tint` | `Color?` | 卡片底色 |
| `expandChild` | `bool` | 是否讓 child 撐滿剩餘高度 |
| `height` | `double?` | 卡片固定高度 |
| `outerMargin` | `EdgeInsetsGeometry` | 卡片外圍間距 |
| `headerPadding` | `EdgeInsetsGeometry` | 標題列內距 |
| `contentPadding` | `EdgeInsetsGeometry` | 內容區域內距 |
| `borderRadius` | `BorderRadius` | 邊角圓角 |
| `titleStyle` | `TextStyle?` | 標題樣式 |

---

## 6. 資料流向圖

### 6.1 整體資料流

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────────┐ ┌────────────┐  │
│  │ HomePage │ │VoicePage │ │ImageToolPage │ │SettingsPage│  │
│  └────┬─────┘ └────┬─────┘ └──────┬───────┘ └─────┬──────┘  │
└───────┼────────────┼───────────────┼───────────────┼─────────┘
        │            │               │               │
        │ Consumer   │ Consumer      │ Consumer      │ Consumer
        │ Selector   │               │               │
        ▼            ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                       State Layer                            │
│  ┌───────────┐ ┌─────────────┐ ┌───────────┐ ┌───────────┐  │
│  │ TodoState │ │HomeworkState│ │TimerState │ │ MediaState│  │
│  └─────┬─────┘ └──────┬──────┘ └─────┬─────┘ └─────┬─────┘  │
│  ┌─────┴─────────────────────────────┴─────────────┴─────┐  │
│  │              AnnouncementState, VoiceState            │  │
│  └───────────────────────────┬───────────────────────────┘  │
└──────────────────────────────┼───────────────────────────────┘
                               │
                               │ 呼叫服務
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐ ┌───────────────────┐ ┌──────────────┐    │
│  │StorageService│ │NotificationService│ │ MediaService │    │
│  └──────────────┘ └───────────────────┘ └──────────────┘    │
│  ┌──────────────┐ ┌──────────────┐                          │
│  │ OnnxService  │ │  STTService  │                          │
│  └──────────────┘ └──────────────┘                          │
└─────────────────────────────────────────────────────────────┘
                               │
                               │ 持久化
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     Storage Layer                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │               SharedPreferences (JSON)               │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           File System (Documents 目錄)               │   │
│  │   • originals/  • processed/  • audios/              │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 狀態更新流程

```
┌─────────────┐
│  使用者操作  │
│  (UI 事件)   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ State 方法   │
│ (add, update,│
│  remove...)  │
└──────┬──────┘
       │
       ├──────────────────┐
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│ 更新內部狀態 │    │ 持久化資料   │
│ (List/Map)  │    │ (Storage)   │
└──────┬──────┘    └─────────────┘
       │
       ▼
┌─────────────┐
│notifyListeners│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  UI 重建    │
│ (Consumer/  │
│  Selector)  │
└─────────────┘
```

---

## 附錄

### A. 主要依賴套件

| 套件 | 用途 |
|------|------|
| `provider` | 狀態管理 |
| `shared_preferences` | 本地 Key-Value 儲存 |
| `flutter_local_notifications` | 本地通知 |
| `timezone` | 時區處理 |
| `record` | 錄音功能 |
| `image_picker` | 圖片選取/拍照 |
| `gal` | 匯出圖片到相簿 |
| `onnxruntime` | ONNX 模型推論 |
| `image` | 圖片處理 |
| `whisper_ggml` | 語音轉文字 |
| `fl_chart` | 圖表繪製 |
| `uuid` | UUID 產生 |
| `intl` | 國際化/日期格式化 |
| `file_picker` | 檔案選取 |

### B. Storage Keys 對照表

| Key | 對應 State | 資料類型 |
|-----|-----------|----------|
| `'todos'` | `TodoState` | `List<Todo>` |
| `'homeworks'` | `HomeworkState` | `List<Homework>` |
| `'timerDaily'` | `TimerState` | `List<TimerRecord>` |
| `'cfg'` | `TimerState` | `Map` (目標、模式設定) |
| `'audioFiles'` | `MediaState` | `List<AudioFile>` |
| `'images'` | `MediaState` | `List<ImageFile>` |
| `'announcements'` | `AnnouncementState` | `List<Announcement>` |

---

*文檔最後更新：2025-11-30*
