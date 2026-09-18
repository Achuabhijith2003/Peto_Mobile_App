import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../screens/main_shell.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback? onSuccess;

  const GoogleSignInButton({
    super.key,
    this.onSuccess,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      const redirectUrl = 'https://peto-web.onrender.com/auth/callback?source=mobile';
      String? authUrl = await _apiService.getGoogleAuthUrl(redirectUrl: redirectUrl);
      authUrl ??= 'https://peto-web.onrender.com/auth/google-launch';

      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch browser for Google sign in.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCodeInputDialog() {
    final codeController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Enter Login Code',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the 6-digit code shown on the browser completion page:',
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                    decoration: InputDecoration(
                      hintText: '123456',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length < 6) return;

                          final dialogNav = Navigator.of(dialogContext);
                          final appNav = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);

                          setDialogState(() => isVerifying = true);
                          final success = await authProvider.loginWithGoogleCode(code);

                          setDialogState(() => isVerifying = false);

                          if (success) {
                            dialogNav.pop();
                            if (widget.onSuccess != null) {
                              widget.onSuccess!();
                            } else {
                              if (appNav.canPop()) {
                                appNav.pop();
                              } else {
                                appNav.pushReplacement(
                                  MaterialPageRoute(builder: (_) => const MainShell()),
                                );
                              }
                            }
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(authProvider.errorMessage ?? 'Invalid code entered.'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Verify & Sign In'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Continue with Google Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Logo SVG representation via network image or icon
                      Image.network(
                        'https://www.svgrepo.com/show/475656/google-color.svg',
                        width: 22,
                        height: 22,
                        errorBuilder: (ctx, err, stack) => const Icon(
                          Icons.g_mobiledata_rounded,
                          size: 26,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Continue with Google',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 6),

        // Fallback option to enter code manually
        TextButton(
          onPressed: _showCodeInputDialog,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Have a Google login code? Enter code',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
