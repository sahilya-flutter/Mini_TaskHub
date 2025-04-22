import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'task_model.dart';

class TaskProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _supabaseService.getTasks();

      // Add debug logs to check descriptions
      print("Fetched ${_tasks.length} tasks");
      if (_tasks.isNotEmpty) {
        for (var task in _tasks) {
          print(
              "Task ${task.id}: title='${task.title}', description='${task.description}'");
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addTask({
    required String title,
    String description = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newTask = await _supabaseService.createTask(
        title: title,
        description: description,
      );

      _tasks.insert(0, newTask);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      print('Error adding task: $e');
      if (e.toString().contains('PostgresException')) {
        _errorMessage =
            'Database error: ${e.toString().split('PostgresException:').last.trim()}';
      } else {
        _errorMessage = 'Error: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _supabaseService.deleteTask(taskId);
      _tasks.removeWhere((task) => task.id == taskId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTaskCompletion(Task task) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedTask = await _supabaseService.toggleTaskCompletion(task);

      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> editTask({
    required String taskId,
    required String title,
    String description = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Find the task in the list
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index == -1) {
        throw Exception('Task not found');
      }

      // Get the current task
      final existingTask = _tasks[index];

      // Create an updated task with new title and description
      final updatedTask = existingTask.copyWith(
        title: title,
        description: description,
      );

      // Update in Supabase
      final result = await _supabaseService.updateTask(updatedTask);

      // Update in local list
      _tasks[index] = result;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
