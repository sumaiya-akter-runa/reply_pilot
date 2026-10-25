import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'lead_detail_screen.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});
  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  String? _status;
  String _q = '';

  Future<void> _add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add customer'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Customer name (Facebook name is fine)')),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final l = await ref.read(apiProvider).createLead(name.text.trim(), phone.text.trim());
      refreshAll(ref);
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id)));
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leads = ref.watch(leadsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Customers'), actions: [
        IconButton(icon: const Icon(Icons.info_outline), tooltip: 'What do the statuses mean?', onPressed: () => showStatusHelp(context)),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.person_add), label: const Text('Add customer')),
      body: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: InfoBanner('People who messaged you. Track who ordered and who needs a reply. Tap (i) to see what each status means.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or phone', border: kBorder, filled: true, fillColor: Colors.white, isDense: true),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null))),
            for (final s in leadStatuses)
              Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: Text(label(s)), selected: _status == s, onSelected: (_) => setState(() => _status = s))),
          ]),
        ),
        Expanded(
          child: AsyncBody<List<Lead>>(
            value: leads,
            onRetry: () => ref.invalidate(leadsProvider),
            data: (all) {
              final list = all.where((l) => l.customerName.toLowerCase().contains(_q) || l.phone.contains(_q)).toList();
              if (list.isEmpty) {
                return const EmptyState('No customers here yet. Tap "Add customer" when someone messages you.', icon: Icons.people_outline);
              }
              return RefreshIndicator(
                onRefresh: () => safeRefresh(ref.refresh(leadsProvider(_status).future)),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = list[i];
                    final overdue = l.nextFollowupAt != null && l.nextFollowupAt!.isBefore(DateTime.now());
                    return ListTile(
                      title: Text(l.title),
                      subtitle: Text([
                        if (l.phone.isNotEmpty) l.phone,
                        if (l.nextFollowupAt != null) 'Follow-up ${fmtDate(l.nextFollowupAt)}',
                      ].join(' - ')),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        StatusChip(l.status),
                        if (overdue && l.status != 'ordered' && l.status != 'lost') const Text('Due', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeadDetailScreen(leadId: l.id))),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
