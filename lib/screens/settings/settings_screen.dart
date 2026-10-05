import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../policy/policy_screen.dart';
import '../business/business_profile_screen.dart';
import 'verification_screen.dart';
import '../../widgets/identity_switcher_bottom_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isMarketplaceEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    final features = await _apiService.fetchAdFeatures();
    if (mounted) {
      setState(() {
        _isMarketplaceEnabled = features['petoAdsMarketplace'] == true;
      });
    }
  }

  Future<void> _launchAdvertiserPortal() async {
    const urlString = 'https://peto-web.onrender.com/advertiser';
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch Advertiser Portal in external browser.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching browser: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showChangePasswordBottomSheet() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(modalContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter your current password and choose a secure new one.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),

                    // Current password
                    const Text(
                      'Current Password',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        hintText: 'Enter current password',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Current password is required' : null,
                    ),

                    const SizedBox(height: 14),

                    // New password
                    const Text(
                      'New Password',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Minimum 6 characters',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: const Color(0xFF94A3B8),
                          ),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Confirm password
                    const Text(
                      'Confirm New Password',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        hintText: 'Repeat new password',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (v) {
                        if (v != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 22),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(modalContext);

                                setModalState(() => isSubmitting = true);

                                final res = await _apiService.changePassword(
                                  currentPassword: currentPasswordController.text,
                                  newPassword: newPasswordController.text,
                                );

                                setModalState(() => isSubmitting = false);

                                if (res['success'] == true) {
                                  nav.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Password updated successfully!'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['message']?.toString() ?? 'Failed to update password'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ACCOUNT & SECURITY SECTION
          if (authProvider.isAuthenticated) ...[
            _buildSectionHeader('SECURITY & CREDENTIALS'),
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              iconColor: const Color(0xFF3B82F6),
              title: 'Change Password',
              subtitle: 'Update your login password and manage credentials',
              onTap: _showChangePasswordBottomSheet,
            ),
            const SizedBox(height: 18),

            // VERIFICATION SECTION
            _buildSectionHeader('IDENTITY & RECOGNITION'),
            _buildSettingsTile(
              icon: Icons.verified_outlined,
              iconColor: const Color(0xFF2563EB),
              title: 'Verification',
              subtitle: 'Apply for personal identity verification (Blue Tick)',
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                );
              },
            ),
            const SizedBox(height: 18),
          ],

          // LEGAL & PRIVACY POLICIES SECTION
          _buildSectionHeader('COMPLIANCE & LEGAL'),
          _buildSettingsTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF10B981),
            title: 'Privacy Policy & Terms',
            subtitle: 'Read official Peto policies, terms of service & guidelines',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PolicyScreen(initialSlug: 'privacy-policy'),
                ),
              );
            },
          ),
          const SizedBox(height: 18),

          // BUSINESS & PROMOTION SECTION
          _buildSectionHeader('BUSINESS & PROMOTION'),
          if (authProvider.managedBusinesses.isNotEmpty) ...[
            _buildSettingsTile(
              icon: Icons.storefront_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'My Business Profiles (${authProvider.managedBusinesses.length})',
              subtitle: 'Switch identity or manage your business profile page',
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                if (authProvider.managedBusinesses.length == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BusinessProfileScreen(
                        businessId: authProvider.managedBusinesses.first.id,
                      ),
                    ),
                  );
                } else {
                  IdentitySwitcherBottomSheet.show(context);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          if (_isMarketplaceEnabled) ...[
            _buildSettingsTile(
              icon: Icons.campaign_outlined,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Advertiser Portal',
              subtitle: 'Launch targeted ads and sponsor reels (opens in browser)',
              trailing: const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
              onTap: _launchAdvertiserPortal,
            ),
            const SizedBox(height: 18),
          ],

          // SIGN OUT / APP INFO
          if (authProvider.isAuthenticated) ...[
            _buildSectionHeader('SESSION'),
            _buildSettingsTile(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Log Out',
              subtitle: 'Sign out of @${authProvider.user?.username ?? "user"} on this device',
              onTap: () => authProvider.logout(),
            ),
          ],

          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Text(
                  'Peto v1.0.0 • Community First',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All policies and verified guidelines legally binding.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
        onTap: onTap,
      ),
    );
  }
}
