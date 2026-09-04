import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/community_model.dart';
import '../theme/app_theme.dart';

class CommunityCard extends StatelessWidget {
  final Community community;
  final VoidCallback onJoinToggle;
  final VoidCallback? onTap;

  const CommunityCard({
    super.key,
    required this.community,
    required this.onJoinToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUri = community.coverImageUrl ?? community.iconUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Community Thumbnail Image
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: imageUri != null && imageUri.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUri,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(color: AppColors.surfaceContainerLow),
                          errorWidget: (_, _, _) => _buildFallbackThumbnail(),
                        )
                      : _buildFallbackThumbnail(),
                ),
              ),
              const SizedBox(width: 14),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            community.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (community.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.lock_rounded, size: 14, color: AppColors.outline),
                          ),
                      ],
                    ),
                    if (community.slug.isNotEmpty) ...[
                      Text(
                        '@${community.slug}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (community.description.isNotEmpty) ...[
                      Text(
                        community.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            community.category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${community.memberCount} members',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.outline,
                          ),
                        ),
                        if (community.postCount > 0) ...[
                          const SizedBox(width: 4),
                          const Text('•', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                          const SizedBox(width: 4),
                          Text(
                            '${community.postCount} posts',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Join / Joined Button
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: community.isJoined ? Colors.transparent : AppColors.primaryContainer,
                  foregroundColor: community.isJoined ? AppColors.onSurface : AppColors.onPrimaryContainer,
                  side: BorderSide(
                    color: community.isJoined ? AppColors.surfaceContainerHigh : AppColors.primaryContainer,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(64, 34),
                ),
                onPressed: onJoinToggle,
                child: Text(
                  community.isJoined ? 'Joined' : 'Join',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: AppColors.primaryFixed,
      child: Center(
        child: Text(
          community.name.isNotEmpty ? community.name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
