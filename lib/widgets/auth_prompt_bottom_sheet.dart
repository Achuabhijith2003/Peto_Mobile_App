import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import 'custom_button.dart';

class AuthPromptBottomSheet extends StatelessWidget {
  final String? actionTitle;

  const AuthPromptBottomSheet({super.key, this.actionTitle});

  static void show(BuildContext context, {String? actionTitle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AuthPromptBottomSheet(actionTitle: actionTitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryFixed,
            child: Icon(Icons.pets, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            actionTitle != null
                ? 'Sign in to $actionTitle'
                : 'Join Peto Companion Community',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect with fellow pet lovers, post photos, join pet communities, and get health tips for your beloved pets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Sign In',
            width: double.infinity,
            variant: CustomButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Create an Account',
            width: double.infinity,
            variant: CustomButtonVariant.outline,
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
