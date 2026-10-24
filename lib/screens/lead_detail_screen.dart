import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import '../widgets/followup_sheet.dart';
import 'order_builder_screen.dart';
import 'reply_studio_screen.dart';

class LeadDetailScreen extends ConsumerWidget {
  final int leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  Future<void> _update(BuildContext context, WidgetRef ref, {String? status, DateTime? at, bool clear = false}) async {
    try {
      await ref.read(apiProvider).updateLead(leadId, status: status, followupAt: at, clearFollowup: clear);
      refreshAll(ref);
    } catch (e) {
      if (context.mounted) snack(context, errText(e), error: true);
    }
  }

  Future<void> _editInfo(BuildContext context, WidgetRef ref, Lead l) async {
    final name = TextEditingController(text: l.customerName);
    final phone = TextEditingController(text: l.phone);
    final notes = TextEditingController(text: l.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Customer info'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).updateLead(leadId, name: name.text.trim(), phone: phone.text.trim(), notes: notes.text.trim());
      refreshAll(ref);
    } catch (e) {
      if (context.mounted) snack(context, errText(e), error: true);
    }
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return;
    _update(context, ref, at: DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadProvider(leadId));
    return Scaffold(
      appBar: AppBar(
        title: Text(lead.valueOrNull?.title ?? 'Customer'),
        actions: [
          if (lead.valueOrNull != null) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editInfo(context, ref, lead.valueOrNull!)),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDialog(context, 'Delete customer', 'Delete this customer and the saved messages?', ok: 'Delete')) {
                try {
                  await ref.read(apiProvider).deleteLead(leadId);
                  refreshAll(ref);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) snack(context, errText(e), error: true);
                }
              }
            },
          ),
        ],
      ),
      body: AsyncBody<Lead>(
        value: lead,
        onRetry: () => ref.invalidate(leadProvider(leadId)),
        data: (l) => Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
              if (l.phone.isNotEmpty) Text('Phone: ${l.phone}'),
              if (l.notes.isNotEmpty) Text('Notes: ${l.notes}'),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (final s in leadStatuses)
                  ChoiceChip(label: Text(label(s)), selected: l.status == s, onSelected: (_) => _update(context, ref, status: s)),
              ]),
              const SizedBox(height: 8),
              Text(l.nextFollowupAt == null ? 'No reminder set. Pick a day to remind yourself to message them again.' : 'Remind me: ${fmtDate(l.nextFollowupAt)}', style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 6, children: [
                ActionChip(
                  label: const Text('Tomorrow 10 AM'),
                  onPressed: () {
                    final n = DateTime.now();
                    _update(context, ref, at: DateTime(n.year, n.month, n.day + 1, 10));
                  },
                ),
                ActionChip(
                  label: const Text('In 3 days'),
                  onPressed: () {
                    final n = DateTime.now();
                    _update(context, ref, at: DateTime(n.year, n.month, n.day + 3, 10));
                  },
                ),
                ActionChip(label: const Text('Pick date'), onPressed: () => _pickDate(context, ref)),
                if (l.nextFollowupAt != null) ActionChip(label: const Text('Clear'), onPressed: () => _update(context, ref, clear: true)),
              ]),
              const Divider(height: 24),
              if (l.messages.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: EmptyState('No messages yet. Open Reply Studio and paste the customer\'s message.', icon: Icons.chat_bubble_outline)),
              for (final m in l.messages) _Bubble(m),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReplyStudioScreen(lead: l))),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Reply'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(onPressed: () => showFollowupSheet(context, ref, l), icon: const Icon(Icons.notifications_active_outlined), label: const Text('Follow-up')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderBuilderScreen(lead: l))),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Order'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message m;
  const _Bubble(this.m);
  @override
  Widget build(BuildContext context) {
    final mine = !m.fromCustomer;
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: mine ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.text),
          const SizedBox(height: 2),
          Text('${mine ? 'You' : 'Customer'} - ${fmtDate(m.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    );
  }
}