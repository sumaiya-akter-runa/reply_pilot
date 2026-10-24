import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, Faq? f) async {
    final q = TextEditingController(text: f?.question ?? '');
    final a = TextEditingController(text: f?.answer ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(f == null ? 'New FAQ' : 'Edit FAQ'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: q, decoration: const InputDecoration(labelText: 'Question')),
            const SizedBox(height: 8),
            TextField(controller: a, maxLines: 4, decoration: const InputDecoration(labelText: 'Answer')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || q.text.trim().isEmpty || a.text.trim().isEmpty) return;
    try {
      final api = ref.read(apiProvider);
      if (f == null) {
        await api.createFaq(q.text.trim(), a.text.trim());
      } else {
        await api.updateFaq(f.id, q.text.trim(), a.text.trim());
      }
      ref.invalidate(faqsProvider);
    } catch (e) {
      if (context.mounted) snack(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = ref.watch(faqsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      floatingActionButton: GradientFab(onPressed: () => _edit(context, ref, null), icon: Icons.add),      body: AsyncBody<List<Faq>>(
        value: faqs,
        onRetry: () => ref.invalidate(faqsProvider),
        data: (list) => list.isEmpty
            ? const EmptyState('Add common questions (cash on delivery? return? delivery time?). The AI uses them to answer.', icon: Icons.quiz_outlined)
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final f = list[i];
                  return ListTile(
                    title: Text(f.question),
                    subtitle: Text(f.answer, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => _edit(context, ref, f),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDialog(context, 'Delete FAQ', 'Delete this question?', ok: 'Delete')) {
                          try {
                            await ref.read(apiProvider).deleteFaq(f.id);
                            ref.invalidate(faqsProvider);
                          } catch (e) {
                            if (context.mounted) snack(context, errText(e), error: true);
                          }
                        }
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
