import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'order_builder_screen.dart';

/// The core screen: paste a customer message -> get a reply draft -> edit -> copy to Messenger.
class ReplyStudioScreen extends ConsumerStatefulWidget {
  final Lead? lead;
  const ReplyStudioScreen({super.key, this.lead});
  @override
  ConsumerState<ReplyStudioScreen> createState() => _ReplyStudioScreenState();
}

class _ReplyStudioScreenState extends ConsumerState<ReplyStudioScreen> {
  final _message = TextEditingController();
  final _draft = TextEditingController();
  String _language = 'banglish';
  String _tone = 'friendly';
  Reply? _reply;
  bool _busy = false;
  String _savedMessage = ''; // customer message already stored in the lead history

  static const _quick = {
    'Shorter': 'Make it shorter',
    'More friendly': 'Make it more friendly and warm',
    'Banglish': 'Rewrite in Banglish (Bengali in English letters)',
    'বাংলা': 'Rewrite in Bangla script',
    'English': 'Rewrite in English',
    'Ask for details': 'Politely ask the customer for size, quantity and address',
  };

  @override
  void initState() {
    super.initState();
    ref.read(meProvider.future).then((me) {
      if (!mounted) return;
      setState(() {
        _language = me.business.defaultLanguage;
        _tone = me.business.tone;
      });
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _message.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData('text/plain');
    if (d?.text != null) setState(() => _message.text = d!.text!);
  }

  void _setReply(Reply r) {
    setState(() {
      _reply = r;
      _draft.text = r.reply;
    });
  }

  Future<void> _generate() async {
    final msg = _message.text.trim();
    if (msg.isEmpty) {
      snack(context, 'Paste the customer\'s message first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final lead = widget.lead;
      final r = await ref.read(apiProvider).reply(
            msg,
            leadId: lead?.id,
            language: _language,
            tone: _tone,
            saveMessage: lead != null && msg != _savedMessage,
          );
      if (lead != null) {
        _savedMessage = msg;
        ref.invalidate(leadProvider);
      }
      _setReply(r);
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refine(String instruction) async {
    final cur = _reply;
    if (cur == null) return;
    setState(() => _busy = true);
    try {
      _setReply(await ref.read(apiProvider).refine(cur.draftId, instruction));
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final r = _reply;
    final text = _draft.text.trim();
    if (r == null || text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    final api = ref.read(apiProvider);
    try {
      await api.draftFeedback(r.draftId, text); // quality metric: was it edited?
      final lead = widget.lead;
      if (lead != null) {
        await api.addMessage(lead.id, 'seller', text);
        refreshAll(ref);
      }
    } catch (_) {
      // the copy itself worked; saving history is best-effort
    }
    if (mounted) snack(context, 'Copied. Paste it in Messenger.');
  }

  Future<void> _extract() async {
    final msg = _message.text.trim();
    if (msg.isEmpty) {
      snack(context, 'Paste the customer\'s message first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final ex = await ref.read(apiProvider).extractOrder(msg, leadId: widget.lead?.id);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OrderBuilderScreen(lead: widget.lead, extract: ex)));
      }
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _reply;
    return Scaffold(
      appBar: AppBar(title: Text(widget.lead == null ? 'Reply to customer' : 'Reply to ${widget.lead!.title}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_reply == null)
          const InfoBanner('Paste what the customer wrote on Messenger, tap Generate reply, then Copy the reply and send it.\nMessenger থেকে কাস্টমারের লেখা copy করে এখানে paste করুন, তারপর Generate reply চাপুন।',
              icon: Icons.lightbulb_outline, color: Colors.green),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Customer message',
            hintText: 'Paste what the customer wrote',
            border: kBorder, filled: true, fillColor: Colors.white,
            alignLabelWithHint: true,
            suffixIcon: IconButton(icon: const Icon(Icons.content_paste), tooltip: 'Paste', onPressed: _paste),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Reply language', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final l in languages) ChoiceChip(label: Text(label(l)), selected: _language == l, onSelected: (_) => setState(() => _language = l)),
        ]),
        const SizedBox(height: 8),
        const Text('Tone', style: TextStyle(fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final t in tones) ChoiceChip(label: Text(label(t)), selected: _tone == t, onSelected: (_) => setState(() => _tone = t)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
          label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(r == null ? 'Generate reply' : 'Generate again')),
        ),
        if (r != null) ...[
          const SizedBox(height: 16),
          if (r.needsSellerCheck || r.warnings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Check before sending', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('The AI could not confirm every detail from your shop data.'),
                for (final w in r.warnings) Text('- $w'),
                if (r.missingInfo.isNotEmpty) Text('Missing: ${r.missingInfo.join(', ')}'),
              ]),
            ),
          Row(children: [
            Chip(label: Text(r.intent.replaceAll('_', ' '))),
            const Spacer(),
            Text('AI uses left: ${r.usage.remaining}', style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _draft, minLines: 4, maxLines: 10, decoration: const InputDecoration(labelText: 'Draft (edit freely)', border: kBorder, filled: true, fillColor: Colors.white, alignLabelWithHint: true)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final e in _quick.entries) ActionChip(label: Text(e.key), onPressed: _busy ? null : () => _refine(e.value)),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _copy, icon: const Icon(Icons.copy), label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Copy reply'))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _busy ? null : _extract, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('Create order from this message')),
        ],
      ]),
    );
  }
}
