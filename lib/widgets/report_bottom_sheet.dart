import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'auth_prompt_bottom_sheet.dart';

class ReportBottomSheet extends StatefulWidget {
  final String targetType; // 'post', 'reel', 'comment', 'user'
  final String targetId;
  final String? targetTitle;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    String? targetTitle,
  }) async {
    final storageService = StorageService();
    final token = await storageService.getToken();

    if (!context.mounted) return;

    if (token == null || token.isEmpty) {
      AuthPromptBottomSheet.show(context, actionTitle: 'report content');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ReportBottomSheet(
        targetType: targetType,
        targetId: targetId,
        targetTitle: targetTitle,
      ),
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _descController = TextEditingController();

  String? _selectedReason;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isSuccess = false;

  final List<Map<String, dynamic>> _reasons = [
    {
      'id': 'ANIMAL_ABUSE',
      'label': 'Animal Abuse or Neglect',
      'description': 'Cruelty, endangerment, harm or severe neglect',
      'icon': Icons.pets_outlined,
      'isHighPriority': true,
    },
    {
      'id': 'VIOLENCE',
      'label': 'Violence or Physical Harm',
      'description': 'Threats, dangerous acts, or violent content',
      'icon': Icons.warning_amber_rounded,
      'isHighPriority': true,
    },
    {
      'id': 'SPAM',
      'label': 'Spam or Deceptive Ads',
      'description': 'Repetitive posts, unsolicited promotions, scams',
      'icon': Icons.mark_email_unread_outlined,
      'isHighPriority': false,
    },
    {
      'id': 'HARASSMENT',
      'label': 'Harassment or Bullying',
      'description': 'Targeted attacks, insults, doxxing, or intimidation',
      'icon': Icons.person_off_outlined,
      'isHighPriority': false,
    },
    {
      'id': 'HATE_SPEECH',
      'label': 'Hate Speech',
      'description': 'Attacking individuals based on identity or beliefs',
      'icon': Icons.shield_outlined,
      'isHighPriority': false,
    },
    {
      'id': 'SEXUAL_CONTENT',
      'label': 'Inappropriate or Nudity',
      'description': 'Sexually explicit material or imagery',
      'icon': Icons.visibility_off_outlined,
      'isHighPriority': false,
    },
    {
      'id': 'MISINFORMATION',
      'label': 'False Information or Medical Risk',
      'description': 'Dangerous pet medical claims or hoaxes',
      'icon': Icons.info_outline,
      'isHighPriority': false,
    },
    {
      'id': 'COPYRIGHT',
      'label': 'Intellectual Property Violation',
      'description': 'Content used without permission or stolen media',
      'icon': Icons.copyright_outlined,
      'isHighPriority': false,
    },
    {
      'id': 'OTHER',
      'label': 'Other Safety Concern',
      'description': 'Any other violation not listed above',
      'icon': Icons.more_horiz,
      'isHighPriority': false,
    },
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedReason == null) {
      setState(() {
        _errorMessage = 'Please select a reason for reporting.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final res = await _apiService.createReport(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: _selectedReason!,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1600));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Report submitted. Our moderation team will review it.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.tertiary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage = res['message'] ?? 'Failed to submit report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: _isSuccess
          ? _buildSuccessView()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report ${widget.targetType.toUpperCase()}',
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            'Help keep Peto safe and friendly',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Reasons List
                const Text(
                  'Reason for reporting *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _reasons.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = _reasons[index];
                      final isSelected = _selectedReason == item['id'];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedReason = item['id'];
                            _errorMessage = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer.withValues(alpha: 0.12)
                                : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.outlineVariant.withValues(alpha: 0.4),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item['icon'] as IconData,
                                size: 20,
                                color: isSelected
                                    ? AppColors.primary
                                    : (item['isHighPriority'] == true
                                        ? AppColors.error
                                        : AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item['label'] as String,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.onSurface,
                                          ),
                                        ),
                                        if (item['isHighPriority'] == true) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.errorContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Priority',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      item['description'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.outlineVariant,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Additional details input
                TextField(
                  controller: _descController,
                  maxLines: 2,
                  maxLength: 300,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit Report',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.tertiary,
              size: 52,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Report Submitted',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for helping keep the Peto community safe. Our moderation team will investigate promptly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
