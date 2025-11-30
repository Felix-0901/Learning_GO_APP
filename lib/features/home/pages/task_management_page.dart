import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/todo.dart';
import '../../../core/models/homework.dart';
import '../../../core/utils/format.dart';
import '../state/todo_state.dart';
import '../state/homework_state.dart';
import '../widgets/todo_homework_sheets.dart';

/// 任務篩選類型
enum TaskFilter { all, active, completed }

/// 任務管理頁面 - 查看所有作業和待辦事項
class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TaskFilter _filter = TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'To-Do', icon: Icon(Icons.check_circle_outline)),
            Tab(text: 'Homework', icon: Icon(Icons.assignment_outlined)),
          ],
        ),
      ),
      body: Column(
        children: [
          // 篩選器
          _buildFilterChips(),
          // 內容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TodoListView(filter: _filter),
                _HomeworkListView(filter: _filter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: _filter == TaskFilter.all,
            onTap: () => setState(() => _filter = TaskFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Active',
            selected: _filter == TaskFilter.active,
            onTap: () => setState(() => _filter = TaskFilter.active),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Completed',
            selected: _filter == TaskFilter.completed,
            onTap: () => setState(() => _filter = TaskFilter.completed),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[700],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// To-Do 列表視圖
class _TodoListView extends StatelessWidget {
  final TaskFilter filter;

  const _TodoListView({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoState>(
      builder: (context, state, _) {
        final todos = _filterTodos(state.todos, filter);

        if (todos.isEmpty) {
          return _EmptyState(
            icon: Icons.check_circle_outline,
            message: _getEmptyMessage(filter, 'to-do'),
          );
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final todo = todos[index];
              return _TodoCard(todo: todo);
            },
          ),
        );
      },
    );
  }

  List<Todo> _filterTodos(List<Todo> todos, TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return todos.toList()..sort((a, b) {
          // 未完成的排前面，然後按到期日排序
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return a.due.compareTo(b.due);
        });
      case TaskFilter.active:
        return todos.where((t) => !t.isDone).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
      case TaskFilter.completed:
        return todos.where((t) => t.isDone).toList()
          ..sort((a, b) => (b.doneAt ?? b.due).compareTo(a.doneAt ?? a.due));
    }
  }

  String _getEmptyMessage(TaskFilter filter, String type) {
    switch (filter) {
      case TaskFilter.all:
        return 'No $type items';
      case TaskFilter.active:
        return 'No active $type items';
      case TaskFilter.completed:
        return 'No completed $type items';
    }
  }
}

/// Homework 列表視圖
class _HomeworkListView extends StatelessWidget {
  final TaskFilter filter;

  const _HomeworkListView({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeworkState>(
      builder: (context, state, _) {
        final homeworks = _filterHomeworks(state.homeworks, filter);

        if (homeworks.isEmpty) {
          return _EmptyState(
            icon: Icons.assignment_outlined,
            message: _getEmptyMessage(filter, 'homework'),
          );
        }

        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: homeworks.length,
            itemBuilder: (context, index) {
              final homework = homeworks[index];
              return _HomeworkCard(homework: homework);
            },
          ),
        );
      },
    );
  }

  List<Homework> _filterHomeworks(List<Homework> homeworks, TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return homeworks.toList()..sort((a, b) {
          // 未完成的排前面，然後按到期日排序
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return a.due.compareTo(b.due);
        });
      case TaskFilter.active:
        return homeworks.where((h) => !h.isDone).toList()
          ..sort((a, b) => a.due.compareTo(b.due));
      case TaskFilter.completed:
        return homeworks.where((h) => h.isDone).toList()
          ..sort((a, b) => (b.doneAt ?? b.due).compareTo(a.doneAt ?? a.due));
    }
  }

  String _getEmptyMessage(TaskFilter filter, String type) {
    switch (filter) {
      case TaskFilter.all:
        return 'No $type items';
      case TaskFilter.active:
        return 'No active $type items';
      case TaskFilter.completed:
        return 'No completed $type items';
    }
  }
}

/// To-Do 卡片
class _TodoCard extends StatelessWidget {
  final Todo todo;

  const _TodoCard({required this.todo});

  @override
  Widget build(BuildContext context) {
    final isOverdue = !todo.isDone && todo.due.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            todo.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: todo.isDone ? Colors.green : Colors.grey,
          ),
          onPressed: () {
            if (todo.isDone) {
              context.read<TodoState>().uncomplete(todo.id);
            } else {
              context.read<TodoState>().complete(todo.id);
            }
          },
        ),
        title: Text(
          todo.title,
          style: TextStyle(
            decoration: todo.isDone ? TextDecoration.lineThrough : null,
            color: todo.isDone ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (todo.desc.isNotEmpty)
              Text(
                todo.desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: todo.isDone ? Colors.grey : Colors.grey[600],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isOverdue ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  humanDue(todo.due),
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue ? Colors.red : Colors.grey,
                    fontWeight: isOverdue ? FontWeight.bold : null,
                  ),
                ),
                if (todo.isDone && todo.doneAt != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.done, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    humanDue(todo.doneAt!),
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: todo.isDone ? 'uncomplete' : 'complete',
              child: Text(todo.isDone ? 'Mark as Active' : 'Mark as Done'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: () => _showEditSheet(context),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        _showEditSheet(context);
        break;
      case 'complete':
        context.read<TodoState>().complete(todo.id);
        break;
      case 'uncomplete':
        context.read<TodoState>().uncomplete(todo.id);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTodoSheet(existing: todo),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete To-Do'),
        content: Text('Are you sure you want to delete "${todo.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<TodoState>().remove(todo.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Homework 卡片
class _HomeworkCard extends StatelessWidget {
  final Homework homework;

  const _HomeworkCard({required this.homework});

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) {
      return AppColors.softOrange;
    }
    try {
      // 支援多種格式: #RRGGBB, 0xFFRRGGBB, RRGGBB, 或純數字
      String hex = colorStr.replaceFirst('#', '').replaceFirst('0x', '');
      if (hex.length == 6) {
        hex = 'FF$hex'; // 加上 alpha
      }
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return AppColors.softOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue = !homework.isDone && homework.due.isBefore(DateTime.now());
    final color = _parseColor(homework.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: IconButton(
            icon: Icon(
              homework.isDone
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: homework.isDone ? Colors.green : Colors.grey,
            ),
            onPressed: () {
              if (homework.isDone) {
                context.read<HomeworkState>().uncomplete(homework.id);
              } else {
                context.read<HomeworkState>().complete(homework.id);
              }
            },
          ),
          title: Text(
            homework.title,
            style: TextStyle(
              decoration: homework.isDone ? TextDecoration.lineThrough : null,
              color: homework.isDone ? Colors.grey : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (homework.content.isNotEmpty)
                Text(
                  homework.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: homework.isDone ? Colors.grey : Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: isOverdue ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    humanDue(homework.due),
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : Colors.grey,
                      fontWeight: isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                  if (homework.isDone && homework.doneAt != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.done, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      humanDue(homework.doneAt!),
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: homework.isDone ? 'uncomplete' : 'complete',
                child: Text(
                  homework.isDone ? 'Mark as Active' : 'Mark as Done',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          onTap: () => _showEditSheet(context),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        _showEditSheet(context);
        break;
      case 'complete':
        context.read<HomeworkState>().complete(homework.id);
        break;
      case 'uncomplete':
        context.read<HomeworkState>().uncomplete(homework.id);
        break;
      case 'delete':
        _showDeleteConfirmation(context);
        break;
    }
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddHomeworkSheet(existing: homework),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Homework'),
        content: Text('Are you sure you want to delete "${homework.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HomeworkState>().remove(homework.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// 空狀態顯示
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
