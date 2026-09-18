import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/policy_model.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class PolicyScreen extends StatefulWidget {
  final String initialSlug;

  const PolicyScreen({
    super.key,
    this.initialSlug = 'terms-of-service',
  });

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final ApiService _apiService = ApiService();
  late String _currentSlug;
  PolicyModel? _policy;
  bool _isLoading = true;

  final List<Map<String, String>> _availablePolicies = [
    {'slug': 'terms-of-service', 'title': 'Terms of Service'},
    {'slug': 'privacy-policy', 'title': 'Privacy Policy'},
    {'slug': 'community-guidelines', 'title': 'Community Guidelines'},
    {'slug': 'content-policy', 'title': 'Content Policy'},
    {'slug': 'advertising-policy', 'title': 'Advertising Policy'},
    {'slug': 'cookie-policy', 'title': 'Cookie Policy'},
  ];

  @override
  void initState() {
    super.initState();
    _currentSlug = widget.initialSlug;
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() => _isLoading = true);
    try {
      final policy = await _apiService.fetchPolicyBySlug(_currentSlug);
      if (mounted) {
        setState(() {
          _policy = policy ?? _getFallbackPolicy(_currentSlug);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _policy = _getFallbackPolicy(_currentSlug);
          _isLoading = false;
        });
      }
    }
  }

  PolicyModel _getFallbackPolicy(String slug) {
    if (slug == 'privacy-policy') {
      return PolicyModel(
        id: 'fallback-privacy',
        slug: 'privacy-policy',
        policyType: 'PRIVACY_POLICY',
        title: 'Privacy Policy',
        version: '1.0.0',
        effectiveDate: DateTime.now(),
        regionCode: 'GLOBAL',
        status: 'PUBLISHED',
        content: '''# Privacy Policy

Peto is committed to safeguarding your privacy and protecting your personal data across our web and mobile applications.

## 1. Information Collection
We collect information provided when registering, setting up your pet profiles, and interacting with community feeds.

## 2. Usage & AI Services
Collected health signals and user inputs are used strictly to provide veterinary recommendations, pet dietary advice, and safety alerts.

## 3. Data Protection
All telemetry is encrypted with TLS 1.3 in transit and AES-256 at rest. You may request data access or account deletion at any time via Profile Settings.

## 4. Contact
For privacy questions, reach out to privacy@peto.app.''',
      );
    }

    return PolicyModel(
      id: 'fallback-terms',
      slug: 'terms-of-service',
      policyType: 'TERMS_OF_SERVICE',
      title: 'Terms of Service',
      version: '1.0.0',
      effectiveDate: DateTime.now(),
      regionCode: 'GLOBAL',
      status: 'PUBLISHED',
      content: '''# Terms of Service

Welcome to Peto. By accessing our mobile app and platform services, you agree to comply with these terms.

## 1. Account Responsibilities
You must be at least 13 years of age. You are responsible for keeping your login credentials confidential and secure.

## 2. Veterinary Disclaimer
Peto AI health assistance and member discussions are strictly informational and do not substitute for licensed veterinary medical treatment.

## 3. Animal Welfare Commitment
Peto maintains zero tolerance for animal cruelty, neglect, or unlawful trade. Accounts violating animal safety will be banned immediately.

## 4. Contact
For legal inquiries, contact legal@peto.app.''',
    );
  }

  Future<void> _downloadPdf() async {
    final url = _apiService.getPolicyPdfUrl(_currentSlug);
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF viewer.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error launching PDF download.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Compliance & Policies',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.onBackground,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.onBackground,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            color: AppColors.secondary,
            tooltip: 'Download PDF',
            onPressed: _downloadPdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // Policy selector chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _availablePolicies.map((item) {
                  final isSelected = item['slug'] == _currentSlug;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        item['title']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.secondary,
                      backgroundColor: AppColors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.secondary : AppColors.surfaceContainerHigh,
                        ),
                      ),
                      onSelected: (selected) {
                        if (selected && _currentSlug != item['slug']!) {
                          setState(() => _currentSlug = item['slug']!);
                          _loadPolicy();
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Main Policy Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.secondary),
                  )
                : _policy == null
                    ? const Center(child: Text('Policy document not available.'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Card
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.surfaceContainerHigh),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x08000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondaryFixed,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Version ${_policy!.version}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.secondary,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      if (_policy!.effectiveDate != null)
                                        Text(
                                          'Effective: ${DateFormat.yMMMd().format(_policy!.effectiveDate!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _policy!.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onBackground,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: _downloadPdf,
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text('Download PDF'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.secondary,
                                          side: const BorderSide(color: AppColors.secondary),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Document Content Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.surfaceContainerHigh),
                              ),
                              child: _renderMarkdownContent(_policy!.content),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _renderMarkdownContent(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              line.substring(2).trim(),
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              line.substring(3).trim(),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              line.substring(4).trim(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.onBackground,
              ),
            ),
          ),
        );
      } else if (line.startsWith('>')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppColors.secondary, width: 4),
              ),
            ),
            child: Text(
              line.replaceFirst(RegExp(r'^>\s*'), ''),
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: const TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: AppColors.onSurface,
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
