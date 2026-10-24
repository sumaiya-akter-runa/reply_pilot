import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/followup_sheet.dart';
import 'lead_detail_screen.dart';

/// Customers whose reminder day has come: "message them again today".
class FollowupsScreen extends ConsumerWidget {
  const FollowupsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(followupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Follow-up reminders')),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: InfoBanner(
            'These customers need a message from you. Tap Draft and the AI writes a polite follow-up.\n'
            'আজ এই কাস্টমারদের আবার মেসেজ দিতে হবে। Draft চাপলে AI মেসেজ লিখে দেবে।',
            icon: Icons.notifications_active_outlined,
            color: Colors.orange,
          ),
        ),
        Expanded(
          child: AsyncBody<List<Lead>>(
            value: f,
            onRetry: () => ref.invalidate(followupsProvider),
            data: (list) => list.isEmpty
                ? const EmptyState('Nobody to follow up right now.\nTo add a reminder, open a customer and tap "Tomorrow 10 AM" or "In 3 days".\nএখন কাউকে মেসেজ দেওয়ার নেই।', icon: Icons.check_circle_outline)
                : RefreshIndicator(
                    onRefresh: () => safeRefresh(ref.refresh(followupsProvider.future)),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final l = list[i];
                        return ListTile(
                          title: Text(l.title),
                          subtitle: Text('${label(l.status)} - was due ${fmtDate(l.nextFollowupAt)}'),
                          trailing: FilledButton.tonal(onPressed: () => showFollowupSheet(context, ref, l), child: const Text('Draft')),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}
