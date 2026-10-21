import 'package:flutter/material.dart';

/// Transfer percentage is separate from server processing, which has no byte total.
class MediaUploadProgress extends StatelessWidget {
  final String label;
  final double? progress;
  final bool processing;

  const MediaUploadProgress({
    super.key,
    required this.label,
    this.progress,
    this.processing = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = progress?.clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                if (value != null)
                  Text(
                    '${(value * 100).floor()}%${processing ? ' transferred' : ''}',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: processing ? null : value,
              semanticsLabel: processing ? 'Processing uploaded media' : label,
            ),
            if (processing) ...[
              const SizedBox(height: 8),
              const Text(
                'Upload received. Video processing may take a few minutes. Keep this screen open.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
