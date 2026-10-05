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
    const IconData iconData = Icons.verified;
    String tooltip;

    final type = (badgeType ?? 'PERSON').toUpperCase();

    if (type.contains('BUSINESS')) {
      badgeColor = const Color(0xFFEAB308); // Yellow / Amber for Business
      tooltip = 'Business verified';
    } else {
      badgeColor = const Color(0xFF2563EB); // Blue for Person
      tooltip = 'Person verified';
    }

    return Semantics(
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Icon(
          iconData,
          size: size,
          color: badgeColor,
        ),
      ),
    );
  }
}
