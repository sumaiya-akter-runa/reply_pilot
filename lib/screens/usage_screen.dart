import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class UsageScreen extends ConsumerWidget {
  const UsageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(usageProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI usage')),
      body: AsyncBody<UsageStats>(
        value: u,
        onRetry: () => ref.invalidate(usageProvider),
        data: (s) {
          final pct = s.draftsWithFeedback == 0 ? null : (100 * s.draftsSentUnedited / s.draftsWithFeedback).round();
          return RefreshIndicator(
            onRefresh: () => safeRefresh(ref.refresh(usageProvider.future)),
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
              Text(planName(s.plan), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: s.limit == 0 ? 0 : s.used / s.limit, minHeight: 10),
              const SizedBox(height: 6),
              Text('${s.used} of ${s.limit} AI uses this month - ${s.remaining} left'),
              const SizedBox(height: 4),
              const Text('Each reply, follow-up, refine and order-extract counts as 1 use.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Text('Reply quality', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Drafts created: ${s.draftsTotal}'),
              Text('Copied from the app: ${s.draftsWithFeedback}'),
              Text(pct == null
                  ? 'Sent without editing: not enough data yet'
                  : 'Sent without editing: ${s.draftsSentUnedited} ($pct%)'),
              const SizedBox(height: 8),
              const Text('A high "sent without editing" number means the AI replies are useful as they are.',
                  style: TextStyle(color: Colors.grey)),
            ]),
          );
        },
      ),
    );
  }
}
