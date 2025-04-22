import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/task_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static const String tableName = 'tasks';

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  // Authentication Methods
  Future<User?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null,
        // Disable email confirmation for development
        data: {"confirm": true}, // Add metadata to auto-confirm
      );

      // For development only: If we get a user back but email isn't confirmed,
      // we can try to auto-confirm it by signing in directly
      if (response.user != null) {
        print("User signed up: ${response.user?.email}");

        // Let's keep the user signed out to maintain the workflow
        await client.auth.signOut();
        print("Signed out after signup to force login");

        // For Supabase v2, you can't directly confirm emails from client code
        // This is a workaround message for users in development
        print(
            "IMPORTANT: In production, the user would need to confirm their email.");
        print("For development, we're proceeding as if email was confirmed.");
      }

      return response.user;
    } catch (e) {
      print("Error in signUp: $e");
      rethrow;
    }
  }

  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print("Sign in response: ${response.user?.email}");
      return response.user;
    } catch (e) {
      print("Error in signIn: $e");

      // Special handling for email not confirmed error
      if (e is AuthException && e.message.contains('Email not confirmed')) {
        // For development: We need to tell users to check their email
        print(
            "Email not confirmed. User needs to check their email for confirmation link.");

        // You could implement a resend confirmation email feature here
        try {
          await client.auth.resend(
            type: OtpType.signup,
            email: email,
          );
          print("Confirmation email resent to $email");

          // Rethrow a more user-friendly error message
          throw Exception(
              "Please check your email and click the confirmation link to activate your account. "
              "We've sent a new confirmation email.");
        } catch (resendError) {
          print("Failed to resend confirmation email: $resendError");

          // Handle rate limiting specifically
          if (resendError is AuthException &&
              resendError.message.contains('security purposes') &&
              resendError.message.contains('seconds')) {
            // Extract the waiting time if possible
            final regex = RegExp(r'after (\d+) seconds');
            final match = regex.firstMatch(resendError.message);
            final waitTime = match?.group(1) ?? '60';

            throw Exception(
                "Too many email requests. Please wait $waitTime seconds before requesting "
                "another confirmation email. Check your inbox for the previous confirmation link.");
          } else {
            throw Exception(
                "Your email is not confirmed. Please check your inbox for a confirmation link or try signing up again.");
          }
        }
      }

      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
  }

  // Task Methods
  Future<List<Task>> getTasks() async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await client
          .from(tableName)
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      print('Retrieved ${response.length} tasks from database');
      if (response.isNotEmpty) {
        print('First task raw data: ${response.first}');

        // Check if description exists in the raw data
        if (response.first.containsKey('description')) {
          print(
              'Description field exists with value: "${response.first['description']}"');
        } else {
          print('Description field does not exist in response');
        }
      }

      return (response as List).map((task) => Task.fromJson(task)).toList();
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        _printTableCreationInstructions();
        return []; // Return empty list instead of crashing
      }
      rethrow;
    }
  }

  Future<Task> createTask({
    required String title,
    String description = '',
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    print('Creating task with description: "$description"');

    final taskData = {
      'title': title,
      'description': description,
      'is_completed': false,
      'user_id': user.id,
    };

    print('Task data being sent: $taskData');

    try {
      final response =
          await client.from(tableName).insert(taskData).select().single();

      print('Task created with raw data: $response');

      // Check if description exists in the response
      if (response.containsKey('description')) {
        print(
            'Description field returned with value: "${response['description']}"');
      } else {
        print('Description field not returned in response');
      }

      final task = Task.fromJson(response);
      print('Task object created with description: "${task.description}"');

      // If description is empty but we sent a non-empty one, suggest table reset
      if (description.isNotEmpty && task.description.isEmpty) {
        print(
            'WARNING: Description was not saved correctly. Table schema might be incorrect.');
        _printResetTableInstructions();
      }

      return task;
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        _printTableCreationInstructions();
        throw Exception(
            'The tasks table does not exist. Please create it in the Supabase dashboard.');
      }
      rethrow;
    }
  }

  void _printTableCreationInstructions() {
    print('''
+----------------------------------------------------------------------+
| IMPORTANT: You need to create the tasks table in Supabase dashboard  |
+----------------------------------------------------------------------+
1. Go to your Supabase dashboard: https://app.supabase.com/
2. Select your project
3. Go to the SQL Editor
4. Create a new query and paste the following SQL:

CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own tasks" ON public.tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tasks" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tasks" ON public.tasks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tasks" ON public.tasks FOR DELETE USING (auth.uid() = user_id);

5. Click "Run" to execute the SQL
''');
  }

  Future<Task> updateTask(Task task) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    if (task.userId != user.id) {
      throw Exception('Not authorized to update this task');
    }

    final response = await client
        .from(tableName)
        .update(task.toJson())
        .eq('id', task.id)
        .select()
        .single();

    return Task.fromJson(response);
  }

  Future<void> deleteTask(String taskId) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    await client
        .from(tableName)
        .delete()
        .eq('id', taskId)
        .eq('user_id', user.id);
  }

  Future<Task> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    return await updateTask(updatedTask);
  }

  void _printResetTableInstructions() {
    print('''
+----------------------------------------------------------------------+
| IMPORTANT: You should reset your tasks table in Supabase dashboard   |
+----------------------------------------------------------------------+
1. Go to your Supabase dashboard: https://app.supabase.com/
2. Select your project
3. Go to the SQL Editor
4. Create a new query and paste the following SQL:

-- Drop existing table (WARNING: This will delete all data!)
DROP TABLE IF EXISTS public.tasks;

-- Create tasks table with proper description field
CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  is_completed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Enable RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own tasks" ON public.tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tasks" ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tasks" ON public.tasks FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tasks" ON public.tasks FOR DELETE USING (auth.uid() = user_id);

5. Click "Run" to execute the SQL
''');
  }
}
