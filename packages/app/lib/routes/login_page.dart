import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/theme_color.dart';
import '../services/auth_service.dart';
import '../widgets/auth_input_field.dart';
import 'root_layout.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.loginWithEmailAndPassword(email, password);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result != null && result.works) {
        // Login successful - navigate to main app as logged in
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => const RootLayout(isLoggedIn: true),
          ),
        );
      } else {
        // Login failed - show error dialog
        _showError(result?.errorMessage ?? 'Incorrect email or password');
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
        title: const Text('Login Failed'),
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

  void _handleRegister() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const RegisterPage(),
      ),
    );
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
                'Travel\nwith AI',
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
                'Have the best experience with traveling\nusing optional supported AI.',
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

              const SizedBox(height: 24),

              // Connect Button
              GestureDetector(
                onTap: _isLoading ? null : _handleLogin,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: ThemeColor.primary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CupertinoActivityIndicator(
                            color: ThemeColor.background,
                          ),
                        )
                      : const Text(
                          'Connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: ThemeColor.background,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Register / Start as guest
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _handleRegister,
                    child: const Text(
                      'Register',
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
