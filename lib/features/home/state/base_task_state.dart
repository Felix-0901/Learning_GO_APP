import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';

/// 任務項目共用介面
/// 定義 Todo 和 Homework 的共同屬性
abstract class TaskItem {
  String get id;
  DateTime get due;
  bool get isDone;
  DateTime? get doneAt;

  Map<String, dynamic> toJson();
  TaskItem copyWith({DateTime? doneAt, bool clearDoneAt});
}

/// 任務狀態管理基礎類別
/// 抽取 TodoState 和 HomeworkState 的共用邏輯
abstract class BaseTaskState<T extends TaskItem> extends ChangeNotifier {
  final String storageKey;

  BaseTaskState({required this.storageKey});

  List<T> _items = [];

  /// 所有項目（不可修改的副本）
  List<T> get items => List.unmodifiable(_items);

  /// 未完成的項目（依到期日排序）
  List<T> get visibleItems =>
      _items.where((item) => !item.isDone).toList()
        ..sort((a, b) => a.due.compareTo(b.due));

  /// 今天到期的項目
  List<T> todayItems(DateTime now) {
    return _items.where((item) {
      return item.due.year == now.year &&
          item.due.month == now.month &&
          item.due.day == now.day;
    }).toList();
  }

  /// 今天的完成數量
  int todayDoneCount(DateTime now) {
    return todayItems(now).where((item) => item.isDone).length;
  }

  /// 今天的總數量
  int todayTotalCount(DateTime now) {
    return todayItems(now).length;
  }

  /// 從 JSON 建立項目（子類別實作）
  T fromJson(Map<String, dynamic> json);

  /// 載入資料
  Future<void> load() async {
    final list = await StorageService.instance.getList(storageKey);
    _items = list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    sort();
    notifyListeners();

    // 載入後的額外處理（子類別可覆寫）
    await onLoaded();
  }

  /// 載入後的額外處理（子類別可覆寫）
  @protected
  Future<void> onLoaded() async {}

  /// 儲存資料
  @protected
  Future<void> save() async {
    await StorageService.instance.setJson(
      storageKey,
      _items.map((item) => item.toJson()).toList(),
    );
  }

  /// 排序項目
  @protected
  void sort() {
    _items.sort((a, b) => a.due.compareTo(b.due));
  }

  /// 新增項目
  @protected
  Future<void> addItem(T item) async {
    _items.add(item);
    sort();
    await save();
    notifyListeners();
  }

  /// 更新項目
  @protected
  Future<void> updateItem(T item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      _items[index] = item;
      sort();
      await save();
      notifyListeners();
    }
  }

  /// 標記完成
  Future<void> complete(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(doneAt: DateTime.now()) as T;
      await save();
      notifyListeners();
    }
  }

  /// 取消完成
  Future<void> uncomplete(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(clearDoneAt: true) as T;
      await save();
      notifyListeners();
    }
  }

  /// 刪除項目
  Future<void> remove(String id) async {
    // 刪除前的額外處理（子類別可覆寫）
    await onBeforeRemove(id);

    _items.removeWhere((item) => item.id == id);
    await save();
    notifyListeners();
  }

  /// 刪除前的額外處理（子類別可覆寫）
  @protected
  Future<void> onBeforeRemove(String id) async {}

  /// 根據 ID 取得項目
  T? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
