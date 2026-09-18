import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class SponsoredPostCard extends StatefulWidget {
  final Map<String, dynamic> ad;

  const SponsoredPostCard({
    super.key,
    required this.ad,
  });

  @override
  State<SponsoredPostCard> createState() => _SponsoredPostCardState();
}

class _SponsoredPostCardState extends State<SponsoredPostCard> {
  bool _hasTrackedImpression = false;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _trackImpression();
  }

  void _trackImpression() {
    if (_hasTrackedImpression) return;
    _hasTrackedImpression = true;

    final isExternal = widget.ad['source'] == 'EXTERNAL' || widget.ad['ad_source'] == 'EXTERNAL';
    if (isExternal) {
      ApiService().trackExternalAdEvent(
        eventType: 'AD_IMPRESSION',
        provider: widget.ad['provider']?.toString() ?? 'ADMOB',
        placement: widget.ad['placement']?.toString() ?? 'FEED',
        adUnitId: widget.ad['adUnitId']?.toString(),
      );
      return;
    }

    final campaignId = widget.ad['id']?.toString();
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
    final creativeId = creative?['id']?.toString();

    if (campaignId != null && campaignId.isNotEmpty) {
      ApiService().trackAdImpression(campaignId, creativeId: creativeId);
    }
  }

  void _handleHideAd() {
    final isExternal = widget.ad['source'] == 'EXTERNAL' || widget.ad['ad_source'] == 'EXTERNAL';
    if (isExternal) {
      ApiService().trackExternalAdEvent(
        eventType: 'AD_HIDE',
        provider: widget.ad['provider']?.toString() ?? 'ADMOB',
        placement: widget.ad['placement']?.toString() ?? 'FEED',
      );
      setState(() => _isHidden = true);
      return;
    }

    final campaignId = widget.ad['id']?.toString();
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
    final creativeId = creative?['id']?.toString();

    if (campaignId != null && campaignId.isNotEmpty) {
      ApiService().trackAdFeedback(
        campaignId,
        action: 'HIDE',
        reason: 'NOT_INTERESTED',
        creativeId: creativeId,
      );
    }

    setState(() {
      _isHidden = true;
    });
  }

  void _showWhySeeingThisDialog(BuildContext context, String companyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('About This Ad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are seeing this sponsored ad from $companyName based on:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            const Text('• Pet care interests and community activity on Peto.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            const Text('• Your approximate regional country to show relevant offers.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            const Text('• Peto strictly protects personal data and does not sell your private info.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String selectedReason = 'MISLEADING';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.red, size: 22),
              SizedBox(width: 8),
              Text('Report Advertisement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this ad?', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              ...[
                ('MISLEADING', 'Misleading or scam'),
                ('INAPPROPRIATE', 'Inappropriate content'),
                ('ANIMAL_WELFARE', 'Animal welfare concern'),
              ].map((item) {
                final isSelected = selectedReason == item.$1;
                return InkWell(
                  onTap: () => setDialogState(() => selectedReason = item.$1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.red.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected ? Colors.red : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.red : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                final campaignId = widget.ad['id']?.toString();
                final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
                final creativeId = creative?['id']?.toString();

                if (campaignId != null && campaignId.isNotEmpty) {
                  ApiService().trackAdFeedback(
                    campaignId,
                    action: 'REPORT',
                    reason: selectedReason,
                    creativeId: creativeId,
                  );
                }

                setState(() => _isHidden = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you. Ad reported and hidden from your feed.'),
                    backgroundColor: Colors.black87,
                  ),
                );
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBrowserUrl(String rawUrl) async {
    if (rawUrl.trim().isEmpty) return;
    String formattedUrl = rawUrl.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.tryParse(formattedUrl);
    if (uri != null) {
      try {
        final canLaunch = await canLaunchUrl(uri);
        if (canLaunch) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      } catch (e) {
        debugPrint('Could not open ad URL $formattedUrl: $e');
      }
    }
  }

  void _handleCtaTap(BuildContext context) {
    final isExternal = widget.ad['source'] == 'EXTERNAL' || widget.ad['ad_source'] == 'EXTERNAL';
    if (isExternal) {
      ApiService().trackExternalAdEvent(
        eventType: 'AD_CLICK',
        provider: widget.ad['provider']?.toString() ?? 'ADMOB',
        placement: widget.ad['placement']?.toString() ?? 'FEED',
        adUnitId: widget.ad['adUnitId']?.toString(),
      );
      final destinationUrl = widget.ad['destinationUrl']?.toString() ?? 'https://google.com';
      _openBrowserUrl(destinationUrl);
      return;
    }

    final campaignId = widget.ad['id']?.toString();
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
    final creativeId = creative?['id']?.toString();
    final destinationUrl = creative?['destination_url']?.toString() ??
        widget.ad['advertiser']?['website_url']?.toString() ??
        '';

    if (campaignId != null && campaignId.isNotEmpty) {
      ApiService().trackAdClick(campaignId, creativeId: creativeId);
    }

    if (destinationUrl.isNotEmpty) {
      _openBrowserUrl(destinationUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No partner destination URL available.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExternal = widget.ad['source'] == 'EXTERNAL' || widget.ad['ad_source'] == 'EXTERNAL';
    final provider = widget.ad['provider']?.toString() ?? 'ADMOB';
    final isTest = widget.ad['isTest'] == true;

    final advertiser = widget.ad['advertiser'] is Map ? widget.ad['advertiser'] as Map : null;
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;

    final companyName = isExternal
        ? (provider == 'ADMOB' ? 'Google AdMob Network' : 'Sponsored Partner')
        : (advertiser?['company_name']?.toString() ?? 'Peto Commercial Partner');
    final websiteUrl = isExternal
        ? (widget.ad['destinationUrl']?.toString() ?? 'google.com/ads')
        : advertiser?['website_url']?.toString();
    final industry = advertiser?['industry']?.toString() ?? 'PET_CARE';

    final headline = isExternal
        ? (widget.ad['headline']?.toString() ?? 'Premium Pet Nutrition & Care')
        : (creative?['headline']?.toString() ?? 'Exclusive Pet Community Offer');
    final bodyText = isExternal
        ? (widget.ad['body']?.toString() ?? 'Discover veterinary approved care and top quality supplies for your pets.')
        : (creative?['body_text']?.toString() ?? '');
    final callToAction = (isExternal
        ? (widget.ad['callToAction']?.toString() ?? 'LEARN MORE')
        : (creative?['call_to_action']?.toString() ?? 'LEARN MORE'))
        .replaceAll('_', ' ');

    String? mediaUrl;
    if (isExternal) {
      mediaUrl = widget.ad['mediaUrl']?.toString() ?? 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?w=800&auto=format&fit=crop&q=80';
    } else if (creative?['media_urls'] is List && (creative!['media_urls'] as List).isNotEmpty) {
      final firstMedia = (creative['media_urls'] as List).first;
      if (firstMedia is Map) {
        mediaUrl = firstMedia['url']?.toString();
      }
    }

    if (_isHidden) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Ad hidden based on your preferences.',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isHidden = false),
              child: const Text(
                'Undo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.business_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              companyName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isExternal
                                  ? Colors.indigo.withValues(alpha: 0.12)
                                  : Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isExternal
                                    ? Colors.indigo.withValues(alpha: 0.4)
                                    : Colors.amber.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExternal ? Icons.public : Icons.auto_awesome,
                                  size: 10,
                                  color: isExternal ? Colors.indigo : Colors.amber,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isExternal ? (provider == 'ADMOB' ? 'AdMob' : 'Ad') : 'Sponsored',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isExternal ? Colors.indigo : Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isTest) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                'TEST',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.purple),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (websiteUrl != null && websiteUrl.isNotEmpty)
                        Text(
                          websiteUrl.replaceAll(RegExp(r'^https?:\/\/'), ''),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.onSurfaceVariant),
                  onPressed: () => _handleCtaTap(context),
                  tooltip: 'Visit Sponsor',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (value) {
                    if (value == 'why') {
                      _showWhySeeingThisDialog(context, companyName);
                    } else if (value == 'hide') {
                      _handleHideAd();
                    } else if (value == 'report') {
                      _showReportDialog(context);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'why',
                      child: Row(
                        children: [
                          Icon(Icons.help_outline, size: 16, color: AppColors.onSurfaceVariant),
                          SizedBox(width: 8),
                          Text('Why this ad?', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, size: 16, color: AppColors.onSurfaceVariant),
                          SizedBox(width: 8),
                          Text('Hide this ad', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Report ad', style: TextStyle(fontSize: 13, color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Media Thumbnail / Image
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Center(
                      child: Icon(Icons.pets, color: AppColors.outline),
                    ),
                  ),
                ),
              ),
            ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                if (bodyText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    bodyText,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // CTA Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      industry.replaceAll('_', ' '),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outline,
                        letterSpacing: 0.5,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handleCtaTap(context),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      label: Text(
                        callToAction,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
