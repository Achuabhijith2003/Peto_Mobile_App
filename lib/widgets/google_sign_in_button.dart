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
                        const GoogleLogoWidget(size: 20),
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

/// Native vector Google 'G' logo painter - 100% offline, resolution-independent, zero network errors.
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Google logo',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _GoogleLogoPainter(),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Blue: horizontal bar and upper right arc
    final bluePaint = Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..cubicTo(23.745, 11.48, 23.68, 10.73, 23.55, 10.01)
      ..lineTo(12.0, 10.01)
      ..lineTo(12.0, 14.51)
      ..lineTo(18.6, 14.51)
      ..cubicTo(18.31, 16.03, 17.46, 17.33, 16.2, 18.19)
      ..lineTo(16.2, 21.24)
      ..lineTo(20.08, 21.24)
      ..cubicTo(22.35, 19.15, 23.745, 16.07, 23.745, 12.27)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green: bottom arc
    final greenPaint = Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill;
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.93, 21.09)
      ..lineTo(16.05, 18.04)
      ..cubicTo(14.97, 18.76, 13.6, 19.2, 12.0, 19.2)
      ..cubicTo(8.88, 19.2, 6.23, 17.1, 5.28, 14.27)
      ..lineTo(1.25, 14.27)
      ..lineTo(1.25, 17.42)
      ..cubicTo(3.26, 21.36, 7.33, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow: left arc
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(5.28, 14.27)
      ..cubicTo(5.03, 13.55, 4.9, 12.78, 4.9, 12.0)
      ..cubicTo(4.9, 11.22, 5.03, 10.45, 5.28, 9.73)
      ..lineTo(5.28, 6.58)
      ..lineTo(1.25, 6.58)
      ..cubicTo(0.45, 8.18, 0.0, 9.98, 0.0, 12.0)
      ..cubicTo(0.0, 14.02, 0.45, 15.82, 1.25, 17.42)
      ..lineTo(5.28, 14.27)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red: top arc
    final redPaint = Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill;
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.02, 3.13)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.33, 0.0, 3.26, 2.64, 1.25, 6.58)
      ..lineTo(5.28, 9.73)
      ..cubicTo(6.23, 6.9, 8.88, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
