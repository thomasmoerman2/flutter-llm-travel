import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/theme_color.dart';
import '../services/auth_service.dart';
import '../widgets/auth_input_field.dart';
import 'root_layout.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final repeatPassword = _repeatPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || repeatPassword.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (password != repeatPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.createUserWithEmailAndPassword(
        email,
        password,
        repeatPassword,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.works) {
        // Registration successful - navigate to main app as logged in
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => const RootLayout(isLoggedIn: true),
          ),
        );
      } else {
        // Registration failed - show error dialog
        _showError(result?.errorMessage ?? 'Registration failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showError('An error occurred. Please try again.');
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleStartAsGuest() {
    // Navigate to main app as guest (not logged in)
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (context) => const RootLayout(isLoggedIn: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ThemeColor.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // Title
              const Text(
                'Welcome\nuser!',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  color: ThemeColor.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              const Text(
                'Repeat your password to complete the\nregistration as new user.',
                style: TextStyle(
                  fontSize: 16,
                  color: ThemeColor.textSecondary,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // Email Input
              AuthInputField(
                controller: _emailController,
                hintText: 'E-mail',
                icon: LucideIcons.atSign,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 12),

              // Password Input
              AuthInputField(
                controller: _passwordController,
                hintText: 'Password',
                icon: LucideIcons.lock,
                isPassword: true,
              ),

              const SizedBox(height: 12),

              // Repeat Password Input
              AuthInputField(
                controller: _repeatPasswordController,
                hintText: 'Repeat Password',
                icon: LucideIcons.lock,
                isPassword: true,
              ),

              const SizedBox(height: 24),

              // Register Button
              GestureDetector(
                onTap: _isLoading ? null : _handleRegister,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: ThemeColor.inputBackground,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: ThemeColor.textPrimary,
                          ),
                        )
                      : const Text(
                          'Register',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.textPrimary,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Back / Start as guest
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _handleBack,
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 15,
                        color: ThemeColor.textPrimary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: _handleStartAsGuest,
                    child: const Text(
                      'Start as guest',
                      style: TextStyle(
                        fontSize: 15,
                        color: ThemeColor.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
