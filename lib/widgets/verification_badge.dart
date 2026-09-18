import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final String? badgeType;
  final double size;

  const VerificationBadge({
    super.key,
    this.badgeType,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    IconData iconData = Icons.verified;
    String tooltip;

    final type = (badgeType ?? 'PERSON').toUpperCase();

    switch (type) {
      case 'BUSINESS':
        badgeColor = const Color(0xFF0284C7); // Sky / Blue for Business
        tooltip = 'Verified Business Partner';
        break;
      case 'ADVERTISER':
        badgeColor = const Color(0xFFF59E0B); // Amber / Gold for Advertiser
        tooltip = 'Verified Peto Advertiser';
        break;
      case 'PERSON':
      default:
        badgeColor = const Color(0xFF10B981); // Emerald Green for Verified Pet Parent
        tooltip = 'Verified Pet Parent';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(
        iconData,
        size: size,
        color: badgeColor,
      ),
    );
  }
}
