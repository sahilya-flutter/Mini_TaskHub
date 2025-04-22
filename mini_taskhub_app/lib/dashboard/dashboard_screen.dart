import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'task_tile.dart';
import '../app/theme_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _taskController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch tasks when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddTaskSheet(),
    );
  }

  Widget _buildAddTaskSheet() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add New Task',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ).animate().fadeIn().scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 300.ms,
                ),
            SizedBox(height: 20.h),
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                hintText: 'Enter task title',
                prefixIcon: Icon(Icons.task_alt),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ).animate().fadeIn(delay: 100.ms).slideX(
                  begin: -0.1,
                  end: 0,
                  duration: 300.ms,
                ),
            SizedBox(height: 16.h),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Add details (optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 1,
            ).animate().fadeIn(delay: 200.ms).slideX(
                  begin: -0.1,
                  end: 0,
                  duration: 300.ms,
                ),
            SizedBox(height: 24.h),
            Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                return ElevatedButton(
                  onPressed: taskProvider.isLoading
                      ? null
                      : () async {
                          if (taskProvider.isLoading) return;

                          // Get the values before clearing controllers
                          final title = _taskController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Task title is required'),
                              ),
                            );
                            return;
                          }

                          final description =
                              _descriptionController.text.trim();
                          print(
                              'Adding task with title: "$title" and description: "$description"');

                          // Close the dialog immediately
                          _taskController.clear();
                          _descriptionController.clear();
                          Navigator.pop(context);

                          // Then add the task
                          final success = await taskProvider.addTask(
                            title: title,
                            description: description,
                          );

                          // Show error if needed
                          if (!success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  taskProvider.errorMessage ??
                                      'Failed to add task',
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        },
                  child: taskProvider.isLoading
                      ? SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: const CircularProgressIndicator(),
                        )
                      : const Text('Add Task'),
                );
              },
            ).animate().fadeIn(delay: 300.ms).slideY(
                  begin: 0.3,
                  end: 0,
                  duration: 300.ms,
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini TaskHub'),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthService>().signOut();
              // Explicitly navigate back to login screen after signout
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false, // Remove all previous routes
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<TaskProvider>(
          builder: (context, taskProvider, child) {
            if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (taskProvider.tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 80.r,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'No tasks yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Tap the + button to add a new task',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: taskProvider.fetchTasks,
              child: ListView.builder(
                padding: EdgeInsets.all(16.r),
                itemCount: taskProvider.tasks.length,
                itemBuilder: (context, index) {
                  final task = taskProvider.tasks[index];
                  return TaskTile(
                    task: task,
                    onDelete: () async {
                      await taskProvider.deleteTask(task.id);
                    },
                    onToggleComplete: () async {
                      await taskProvider.toggleTaskCompletion(task);
                    },
                    onEdit: (title, description) async {
                      final success = await taskProvider.editTask(
                        taskId: task.id,
                        title: title,
                        description: description,
                      );

                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              taskProvider.errorMessage ??
                                  'Failed to update task',
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
