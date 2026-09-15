import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    _trackImpression();
  }

  void _trackImpression() {
    if (_hasTrackedImpression) return;
    _hasTrackedImpression = true;

    final campaignId = widget.ad['id']?.toString();
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
    final creativeId = creative?['id']?.toString();

    if (campaignId != null && campaignId.isNotEmpty) {
      ApiService().trackAdImpression(campaignId, creativeId: creativeId);
    }
  }

  void _handleCtaTap(BuildContext context) {
    final campaignId = widget.ad['id']?.toString();
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;
    final creativeId = creative?['id']?.toString();
    final destinationUrl = creative?['destination_url']?.toString() ?? '';

    if (campaignId != null && campaignId.isNotEmpty) {
      ApiService().trackAdClick(campaignId, creativeId: creativeId);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          destinationUrl.isNotEmpty
              ? 'Opening partner website: $destinationUrl'
              : 'Opening sponsored partner page...',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final advertiser = widget.ad['advertiser'] is Map ? widget.ad['advertiser'] as Map : null;
    final creative = widget.ad['creative'] is Map ? widget.ad['creative'] as Map : null;

    final companyName = advertiser?['company_name']?.toString() ?? 'Peto Commercial Partner';
    final websiteUrl = advertiser?['website_url']?.toString();
    final industry = advertiser?['industry']?.toString() ?? 'PET_CARE';

    final headline = creative?['headline']?.toString() ?? 'Exclusive Pet Community Offer';
    final bodyText = creative?['body_text']?.toString() ?? '';
    final callToAction = (creative?['call_to_action']?.toString() ?? 'LEARN_MORE')
        .replaceAll('_', ' ');

    String? mediaUrl;
    if (creative?['media_urls'] is List && (creative!['media_urls'] as List).isNotEmpty) {
      final firstMedia = (creative['media_urls'] as List).first;
      if (firstMedia is Map) {
        mediaUrl = firstMedia['url']?.toString();
      }
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
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, size: 10, color: Colors.amber),
                                SizedBox(width: 3),
                                Text(
                                  'Sponsored',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
