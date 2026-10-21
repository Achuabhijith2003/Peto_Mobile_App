import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/post_upload_provider.dart';

class HomeUploadQueue extends StatelessWidget {
  const HomeUploadQueue({super.key});
  @override
  Widget build(BuildContext context) {
    final owner = context.watch<AuthProvider>().user?.id;
    final queue = context.watch<PostUploadProvider>();
    final jobs = queue.jobs.where((job) => job.ownerId == owner).toList();
    return Column(
      children: jobs
          .map(
            (job) => Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          job.state == 'complete'
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            job.label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!job.terminal)
                          Text('${(job.progress * 100).floor()}% transferred'),
                        if (job.terminal)
                          IconButton(
                            tooltip: 'Dismiss',
                            icon: const Icon(Icons.close),
                            onPressed: () => queue.dismiss(job.id),
                          ),
                      ],
                    ),
                    if (!job.terminal) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: job.processing || job.state == 'retrying'
                            ? null
                            : job.progress.clamp(0.0, 1.0),
                        semanticsLabel: job.label,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.statusHint,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    if (job.error != null && job.terminal)
                      Text(
                        job.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (job.terminal && job.state != 'complete')
                      TextButton.icon(
                        onPressed: () => queue.retry(job.id),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry upload'),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
