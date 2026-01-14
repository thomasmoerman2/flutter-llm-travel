import 'package:flutter/cupertino.dart';
import '../services/theme_color.dart';

class AuthInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextInputType keyboardType;

  const AuthInputField({
    super.key,
    this.controller,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColor.inputBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 12),
            child: Icon(
              icon,
              size: 20,
              color: ThemeColor.textSecondary,
            ),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: controller,
              placeholder: hintText,
              obscureText: isPassword,
              keyboardType: keyboardType,
              decoration: null,
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 0,
              ),
              placeholderStyle: const TextStyle(
                color: ThemeColor.textSecondary,
                fontSize: 16,
              ),
              style: const TextStyle(
                color: ThemeColor.textPrimary,
                fontSize: 16,
              ),
              cursorColor: ThemeColor.primary,
              cursorWidth: 2.0,
              cursorHeight: 20,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}
