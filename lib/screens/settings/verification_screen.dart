import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _application;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _docNumberController = TextEditingController();

  String _selectedCountry = 'US';
  String _selectedDocType = 'NATIONAL_ID';
  File? _selectedFile;

  final List<Map<String, String>> _countries = [
    {'code': 'US', 'name': 'United States'},
    {'code': 'IN', 'name': 'India'},
    {'code': 'GB', 'name': 'United Kingdom'},
    {'code': 'CA', 'name': 'Canada'},
    {'code': 'AU', 'name': 'Australia'},
    {'code': 'DE', 'name': 'Germany'},
    {'code': 'FR', 'name': 'France'},
    {'code': 'BR', 'name': 'Brazil'},
  ];

  final List<Map<String, String>> _docTypes = [
    {'code': 'NATIONAL_ID', 'name': 'National ID Card / Aadhaar / SSN'},
    {'code': 'PASSPORT', 'name': 'Passport'},
    {'code': 'DRIVERS_LICENSE', 'name': "Driver's License"},
    {'code': 'VET_LICENSE', 'name': 'Veterinary License'},
    {'code': 'BUSINESS_REGISTRATION', 'name': 'Rescue / Organization Registration'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _docNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user?.fullName != null && _nameController.text.isEmpty) {
      _nameController.text = authProvider.user!.fullName!;
    }

    final res = await _apiService.fetchVerificationStatus();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['has_application'] == true && res['application'] != null) {
          _application = Map<String, dynamic>.from(res['application']);
        }
      });
    }
  }

  Future<void> _pickDocumentImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked != null) {
        setState(() {
          _selectedFile = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select document: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final res = await _apiService.submitIndividualVerification(
      legalName: _nameController.text.trim(),
      country: _selectedCountry,
      documentType: _selectedDocType,
      documentNumber: _docNumberController.text.trim(),
      filePath: _selectedFile?.path,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification application submitted successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _loadStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to submit application'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    final isUserVerified = user?.isVerified == true || _application?['status'] == 'APPROVED';
    final isPending = _application?['status'] == 'SUBMITTED' || _application?['status'] == 'UNDER_REVIEW';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Blue Tick Verification',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUserVerified
                            ? [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]
                            : isPending
                                ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                                : [Colors.white, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isUserVerified
                            ? const Color(0xFFBFDBFE)
                            : isPending
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isUserVerified
                                ? const Color(0xFF2563EB)
                                : isPending
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isUserVerified
                                ? Icons.verified
                                : isPending
                                    ? Icons.hourglass_top_rounded
                                    : Icons.verified_user_outlined,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUserVerified
                                    ? 'Account Verified'
                                    : isPending
                                        ? 'Application Under Review'
                                        : 'Request Verified Badge',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isUserVerified
                                      ? const Color(0xFF1E3A8A)
                                      : isPending
                                          ? const Color(0xFF78350F)
                                          : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isUserVerified
                                    ? 'Your Peto account has been verified. The blue tick badge is displayed across your posts, reels, and profile.'
                                    : isPending
                                        ? 'Our safety and compliance team is reviewing your identity submission. Status will update once reviewed.'
                                        : 'Verified badges confirm authentic pet personalities, verified breeders, licensed clinics, and authentic creators.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isUserVerified
                                      ? const Color(0xFF1E40AF)
                                      : isPending
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (isUserVerified) ...[
                    // Already Verified details
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification Benefits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBenefitRow(
                            Icons.check_circle_outline,
                            'Authentic Blue Tick displayed next to your handle.',
                          ),
                          const SizedBox(height: 10),
                          _buildBenefitRow(
                            Icons.star_outline,
                            'Priority discovery in search and community feed.',
                          ),
                          const SizedBox(height: 10),
                          _buildBenefitRow(
                            Icons.shield_outlined,
                            'Enhanced trust for pet adoption, breeding, and advice.',
                          ),
                        ],
                      ),
                    ),
                  ] else if (isPending) ...[
                    // Application in progress info
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submission Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow('Legal Name', _application?['legal_name'] ?? '—'),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Document Type', _application?['document_type'] ?? '—'),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Country', _application?['country'] ?? '—'),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          _buildDetailRow('Status', 'UNDER REVIEW', isStatus: true),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Verification Form
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Identity Verification Form',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please submit your official legal name and valid government ID.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 20),

                            // Legal Name
                            const Text(
                              'Full Legal Name',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                hintText: 'Enter your legal first and last name',
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
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Please enter your legal name' : null,
                            ),

                            const SizedBox(height: 16),

                            // Country
                            const Text(
                              'Issuing Country',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCountry,
                              decoration: InputDecoration(
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
                              items: _countries.map((c) {
                                return DropdownMenuItem(
                                  value: c['code'],
                                  child: Text(c['name']!),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCountry = val);
                              },
                            ),

                            const SizedBox(height: 16),

                            // Document Type
                            const Text(
                              'ID Document Type',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedDocType,
                              decoration: InputDecoration(
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
                              items: _docTypes.map((d) {
                                return DropdownMenuItem(
                                  value: d['code'],
                                  child: Text(
                                    d['name']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDocType = val);
                              },
                            ),

                            const SizedBox(height: 16),

                            // Document Number
                            const Text(
                              'Document / License Number',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _docNumberController,
                              decoration: InputDecoration(
                                hintText: 'Enter ID or license number',
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
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Document number is required' : null,
                            ),

                            const SizedBox(height: 16),

                            // Document Photo Upload
                            const Text(
                              'Proof Document Image',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickDocumentImage,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedFile != null
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFE2E8F0),
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _selectedFile != null
                                            ? const Color(0xFFEFF6FF)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _selectedFile != null ? Icons.check_circle : Icons.upload_file,
                                        color: _selectedFile != null
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF64748B),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedFile != null
                                                ? _selectedFile!.path.split(Platform.pathSeparator).last
                                                : 'Upload Photo / Scan of ID',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _selectedFile != null
                                                  ? const Color(0xFF1E3A8A)
                                                  : const Color(0xFF334155),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _selectedFile != null
                                                ? 'Tap to change photo'
                                                : 'JPEG, PNG up to 10MB',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            CustomButton(
                              text: 'Submit Verification Request',
                              isLoading: _isSubmitting,
                              onPressed: _submitVerification,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF92400E),
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
      ],
    );
  }
}
