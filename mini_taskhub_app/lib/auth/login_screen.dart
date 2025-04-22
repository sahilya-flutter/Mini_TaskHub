import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mini_taskhub_app/services/supabase_service.dart';
import 'package:provider/provider.dart';

import '../utils/validators.dart';
import 'auth_service.dart';
import 'signup_screen.dart';
import '../dashboard/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _resendInProgress = false;
  DateTime? _lastResendTime;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      final authService = context.read<AuthService>();

      try {
        // Clear any previous errors
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        final success = await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (success && mounted) {
          print("Login successful, navigating to dashboard");

          // Explicitly navigate to dashboard on successful login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else if (!success && mounted) {
          print("Login failed: ${authService.errorMessage}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authService.errorMessage ?? 'Login failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(
                  seconds: 6), // Longer duration for confirmation errors
              action: authService.errorMessage?.contains('email') == true
                  ? SnackBarAction(
                      label: 'Resend Email',
                      textColor: Colors.white,
                      onPressed: () async {
                        // Show resend confirmation dialog
                        _showResendConfirmationDialog();
                      },
                    )
                  : null,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    }
  }

  void _showResendConfirmationDialog() {
    // Calculate remaining cooldown time (if any)
    int remainingSeconds = 0;
    if (_lastResendTime != null) {
      final cooldownPeriod =
          const Duration(seconds: 60); // Set a reasonable cooldown
      final elapsed = DateTime.now().difference(_lastResendTime!);
      if (elapsed < cooldownPeriod) {
        remainingSeconds = (cooldownPeriod - elapsed).inSeconds;
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Timer to update cooldown display
          if (remainingSeconds > 0) {
            Future.delayed(const Duration(seconds: 1), () {
              if (remainingSeconds > 0) {
                setDialogState(() {
                  remainingSeconds--;
                });
              }
            });
          }

          return AlertDialog(
            title: const Text('Email Confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please check your email for a confirmation link. '
                    'We can resend the confirmation email if needed.'),
                if (remainingSeconds > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'You can request another email in $remainingSeconds seconds',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (remainingSeconds > 0 || _resendInProgress)
                    ? null
                    : () async {
                        setDialogState(() {
                          _resendInProgress = true;
                        });
                        Navigator.of(context).pop();
                        try {
                          await SupabaseService().client.auth.resend(
                                type: OtpType.signup,
                                email: _emailController.text.trim(),
                              );

                          setState(() {
                            _lastResendTime = DateTime.now();
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Confirmation email sent. Please check your inbox.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send email: $e'),
                                backgroundColor:
                                    Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        } finally {
                          setState(() {
                            _resendInProgress = false;
                          });
                        }
                      },
                child: _resendInProgress
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend Email'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 80.r,
                    color: Theme.of(context).colorScheme.primary,
                  ).animate().fadeIn(duration: 600.ms).slideY(
                        begin: -0.3,
                        end: 0,
                        curve: Curves.easeOutBack,
                        duration: 600.ms,
                      ),
                  SizedBox(height: 16.h),
                  Text(
                    'Mini TaskHub',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ).animate().fadeIn(delay: 200.ms),
                  Text(
                    'Welcome back!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ).animate().fadeIn(delay: 300.ms),
                  SizedBox(height: 40.h),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.validateEmail,
                  ).animate().fadeIn(delay: 400.ms).slideX(
                        begin: -0.1,
                        end: 0,
                        duration: 400.ms,
                      ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    validator: Validators.validatePassword,
                  ).animate().fadeIn(delay: 500.ms).slideX(
                        begin: 0.1,
                        end: 0,
                        duration: 400.ms,
                      ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: authService.isLoading ? null : _signIn,
                    child: authService.isLoading
                        ? SizedBox(
                            height: 24.h,
                            width: 24.w,
                            child: const CircularProgressIndicator(),
                          )
                        : const Text('Sign In'),
                  ).animate().fadeIn(delay: 600.ms),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
