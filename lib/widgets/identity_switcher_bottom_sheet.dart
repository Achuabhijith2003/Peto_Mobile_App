import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'verification_badge.dart';

class IdentitySwitcherBottomSheet extends StatelessWidget {
  const IdentitySwitcherBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IdentitySwitcherBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final active = authProvider.activeIdentity;
    final businesses = authProvider.managedBusinesses;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch Identity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Choose who you are posting, liking, and commenting as',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Personal Identity
          if (user != null) ...[
            _buildIdentityTile(
              context: context,
              isSelected: active.type == 'PERSON',
              title: user.displayName,
              subtitle: 'Personal Profile (@${user.username})',
              avatarUrl: user.avatarUrl,
              fallbackIcon: Icons.person,
              isBusiness: false,
              isVerified: user.isVerified,
              badgeType: user.verificationBadgeType,
              onTap: () async {
                await authProvider.switchIdentity('PERSON');
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Switched identity to ${user.displayName}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],

          if (businesses.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Managed Businesses',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            ...businesses.map((biz) {
              final isSelected = active.type == 'BUSINESS' && active.id == biz.id;
              final roleStr = biz.role != null && biz.role!.isNotEmpty ? biz.role!.toUpperCase() : 'MEMBER';
              return _buildIdentityTile(
                context: context,
                isSelected: isSelected,
                title: biz.name,
                subtitle: '$roleStr • ${biz.category.isNotEmpty ? biz.category : "Business"}',
                avatarUrl: biz.avatarUrl,
                fallbackIcon: Icons.storefront,
                isBusiness: true,
                isVerified: biz.isVerified,
                badgeType: 'BUSINESS',
                onTap: () async {
                  await authProvider.switchIdentity('BUSINESS', businessId: biz.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Switched identity to ${biz.name}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              );
            }),
          ],

          if (businesses.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You do not manage any business profiles yet. Register a business on web or contact support.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentityTile({
    required BuildContext context,
    required bool isSelected,
    required String title,
    required String subtitle,
    required String? avatarUrl,
    required IconData fallbackIcon,
    required bool isBusiness,
    required bool isVerified,
    required String? badgeType,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? (isBusiness ? Colors.amber.shade50 : AppColors.primaryContainer.withValues(alpha: 0.2))
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? (isBusiness ? Colors.amber.shade400 : AppColors.primary)
              : AppColors.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: isBusiness ? Colors.amber.shade100 : AppColors.primaryFixed,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? CachedNetworkImageProvider(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Icon(
                  fallbackIcon,
                  color: isBusiness ? Colors.amber.shade900 : AppColors.primary,
                  size: 22,
                )
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            if (isVerified || isBusiness) ...[
              const SizedBox(width: 4),
              VerificationBadge(
                badgeType: badgeType,
                size: 16,
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isSelected && isBusiness ? Colors.amber.shade900 : AppColors.onSurfaceVariant,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: isBusiness ? Colors.amber.shade700 : AppColors.primary,
                size: 22,
              )
            : const Icon(Icons.radio_button_unchecked, color: AppColors.outline, size: 20),
      ),
    );
  }
}
