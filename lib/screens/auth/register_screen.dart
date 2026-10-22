import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import '../main_shell.dart';
import '../../widgets/google_sign_in_button.dart';
import '../policy/policy_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _ageConfirmed = false;
  String? _ageConfirmedError;

  bool _acceptedTerms = false;
  String? _acceptedTermsError;

  bool _marketingConsent = false;
  String? _localErrorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated && !authProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainShell()),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    setState(() {
      _localErrorMessage = null;
      _ageConfirmedError = null;
      _acceptedTermsError = null;
    });

    bool hasErrors = false;

    if (!_formKey.currentState!.validate()) {
      hasErrors = true;
    }

    if (!_ageConfirmed) {
      setState(() {
        _ageConfirmedError = 'You must confirm that you are at least 13 years old.';
      });
      hasErrors = true;
    }

    if (!_acceptedTerms) {
      setState(() {
        _acceptedTermsError = 'Please affirmatively accept the Terms of Service and Privacy Policy.';
      });
      hasErrors = true;
    }

    if (hasErrors) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // Generate clean alphanumeric username fallback matching web flow:
    // Web does: fullName.toLowerCase().replace(/\s+/g, "")
    String rawGeneratedUsername = fullName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (rawGeneratedUsername.length < 3) {
      final emailPrefix = email.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '');
      rawGeneratedUsername = emailPrefix.length >= 3 ? emailPrefix : 'user_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }
    if (rawGeneratedUsername.length > 20) {
      rawGeneratedUsername = rawGeneratedUsername.substring(0, 20);
    }

    final success = await authProvider.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      username: rawGeneratedUsername,
      acceptedTerms: _acceptedTerms,
      ageConfirmed: _ageConfirmed,
      marketingConsent: _marketingConsent,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CreateProfileScreen(
            prefilledFullName: fullName,
            prefilledUsername: rawGeneratedUsername,
            prefilledEmail: email,
          ),
        ),
      );
    } else if (mounted && authProvider.errorMessage != null) {
      setState(() {
        _localErrorMessage = authProvider.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final displayedError = _localErrorMessage ?? authProvider.errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Peto Logo Header
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/peto_logo.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(Icons.pets, size: 36, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),

                // Step Indicator Badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.looks_one_rounded, size: 15, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text(
                          'Step 1 of 2 • Account Info',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title & Subtitle (matching Web exactly)
                const Center(
                  child: Text(
                    'Create Your Account',
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Join Peto and start giving your pet the best care.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // User-Friendly Error Banner (Explaining the specific reason clearly)
                if (displayedError != null && displayedError.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Registration Problem',
                                    style: TextStyle(
                                      color: Color(0xFF991B1B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    displayedError,
                                    style: const TextStyle(
                                      color: Color(0xFFB91C1C),
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Quick Action Shortcut for Existing Account
                        if (displayedError.toLowerCase().contains('already exists') ||
                            displayedError.toLowerCase().contains('sign in')) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(
                                      initialEmail: _emailController.text.trim(),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.login_rounded, size: 16, color: Color(0xFF991B1B)),
                              label: const Text(
                                'Sign In with this Email',
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // First Name & Last Name (Grid row matching Web)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'First Name',
                        hint: 'John',
                        controller: _firstNameController,
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.outline),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'First name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        label: 'Last Name',
                        hint: 'Doe',
                        controller: _lastNameController,
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.outline),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Last name is required';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Email Address
                CustomTextField(
                  label: 'Email',
                  hint: 'john@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.outline),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email is required';
                    }
                    final cleanEmail = val.trim();
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(cleanEmail)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password (Min 8 chars, matching Web)
                CustomTextField(
                  label: 'Password',
                  hint: 'Create password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.outline,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Password is required';
                    }
                    if (val.length < 8) {
                      return 'Minimum 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password (must match Password)
                CustomTextField(
                  label: 'Confirm Password',
                  hint: 'Confirm password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  prefixIcon: const Icon(Icons.lock_reset_outlined, color: AppColors.outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.outline,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (val != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Checkbox 1: Age Eligibility Affirmation (Mandatory, matching Web)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _ageConfirmed,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) => setState(() {
                          _ageConfirmed = val ?? false;
                          if (_ageConfirmed) _ageConfirmedError = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _ageConfirmed = !_ageConfirmed;
                          if (_ageConfirmed) _ageConfirmedError = null;
                        }),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12.5, color: AppColors.onSurface, height: 1.35),
                            children: [
                              TextSpan(text: 'I confirm that I am '),
                              TextSpan(
                                text: 'at least 13 years old',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              TextSpan(text: ' (or the minimum legal age for digital services in my jurisdiction).'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_ageConfirmedError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 34, top: 4),
                    child: Text(
                      _ageConfirmedError!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Checkbox 2: Mandatory Terms & Privacy Affirmation (matching Web)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) => setState(() {
                          _acceptedTerms = val ?? false;
                          if (_acceptedTerms) _acceptedTermsError = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'I agree to Peto\'s ',
                            style: TextStyle(fontSize: 12.5, color: AppColors.onSurface),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PolicyScreen(initialSlug: 'terms-of-service'),
                              ),
                            ),
                            child: const Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(
                            ' and acknowledge the ',
                            style: TextStyle(fontSize: 12.5, color: AppColors.onSurface),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PolicyScreen(initialSlug: 'privacy-policy'),
                              ),
                            ),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text('.', style: TextStyle(fontSize: 12.5, color: AppColors.onSurface)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_acceptedTermsError != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 34, top: 4),
                    child: Text(
                      _acceptedTermsError!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Checkbox 3: Optional Marketing Consent (matching Web)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _marketingConsent,
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (val) => setState(() => _marketingConsent = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _marketingConsent = !_marketingConsent),
                        child: const Text(
                          '(Optional) Send me pet care insights, product updates, and community highlights by email. You can unsubscribe anytime.',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.35),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button (matching Web)
                CustomButton(
                  text: 'Create Account',
                  width: double.infinity,
                  isLoading: authProvider.isLoading,
                  onPressed: _handleRegister,
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign-In
                const GoogleSignInButton(),

                const SizedBox(height: 20),

                // Login Link (matching Web)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13.5),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
