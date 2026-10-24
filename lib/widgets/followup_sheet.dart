import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import 'common.dart';

/// Generates a follow-up draft for [lead] and shows it in a bottom sheet.
Future<void> showFollowupSheet(BuildContext context, WidgetRef ref, Lead lead) async {
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  Reply r;
  try {
    r = await ref.read(apiProvider).followupDraft(lead.id);
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // close spinner
      snack(context, errText(e), error: true);
    }
    return;
  }
  if (!context.mounted) return;
  Navigator.pop(context); // close spinner
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FollowupSheet(lead: lead, reply: r),
  );
}

class _FollowupSheet extends ConsumerStatefulWidget {
  final Lead lead;
  final Reply reply;
  const _FollowupSheet({required this.lead, required this.reply});
  @override
  ConsumerState<_FollowupSheet> createState() => _FollowupSheetState();
}

class _FollowupSheetState extends ConsumerState<_FollowupSheet> {
  late final _text = TextEditingController(text: widget.reply.reply);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final api = ref.read(apiProvider);
    await Clipboard.setData(ClipboardData(text: text));
    try {
      await api.draftFeedback(widget.reply.draftId, text);
      await api.addMessage(widget.lead.id, 'seller', text);
      // snooze: remind again in 2 days
      await api.updateLead(widget.lead.id, followupAt: DateTime.now().add(const Duration(days: 2)));
      refreshAll(ref);
    } catch (_) {
      // copying already worked; history/feedback is best-effort
    }
    if (mounted) {
      Navigator.pop(context);
      snack(context, 'Copied. Paste it in Messenger. Next reminder in 2 days.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Follow-up for ${widget.lead.title}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (widget.reply.needsSellerCheck || widget.reply.warnings.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.orange.shade50,
            child: Text(widget.reply.warnings.isEmpty ? 'Check this message before sending.' : widget.reply.warnings.join('\n')),
          ),
        TextField(controller: _text, maxLines: 5, minLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Text('Copy and save')),
      ]),
    );
  }
}
