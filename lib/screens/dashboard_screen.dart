import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'business_screen.dart';
import 'followups_screen.dart';
import 'help_screen.dart';
import 'lead_detail_screen.dart';
import 'order_builder_screen.dart';
import 'product_form_screen.dart';
import 'reply_studio_screen.dart';
import 'usage_screen.dart';

/// Which period the Overview cards show: 'today' | 'week' | 'month'.
final dashPeriodProvider = StateProvider<String>((ref) => 'today');

class DashboardScreen extends ConsumerWidget {
  final void Function(int tab) goToTab;
  const DashboardScreen({super.key, required this.goToTab});

  void _open(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> _addCustomer(BuildContext context, WidgetRef ref) async {
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
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final l = await ref.read(apiProvider).createLead(name.text.trim(), phone.text.trim());
      refreshAll(ref);
      if (context.mounted) _open(context, LeadDetailScreen(leadId: l.id));
    } catch (e) {
      if (context.mounted) snack(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final period = ref.watch(dashPeriodProvider);
    final me = ref.watch(meProvider);
    final products = ref.watch(productsProvider);
    return Scaffold(
      body: AsyncBody<Dashboard>(
        value: dash,
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (d) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(meProvider);
            ref.invalidate(productsProvider);
            await safeRefresh(ref.refresh(dashboardProvider.future));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _Header(shop: me.valueOrNull?.business.name ?? '', onHelp: () => _open(context, const HelpScreen())),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ---- main action
                  FadeSlideIn(
                    child: AppCard(
                      gradient: kBrandGradient,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Customer messaged you?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Paste their message and get a reply in seconds.',
                            style: TextStyle(color: Colors.white, height: 1.35)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kDeep),
                          onPressed: () => _open(context, const ReplyStudioScreen()),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Reply to customer'),
                        ),
                      ]),
                    ),
                  ),
                  // ---- getting started
                  _GettingStarted(
                    shopDone: me.valueOrNull != null && me.valueOrNull!.business.phone.isNotEmpty && me.valueOrNull!.business.deliveryPolicy.isNotEmpty,
                    productsDone: products.valueOrNull != null && products.valueOrNull!.isNotEmpty,
                    replyDone: d.usage.used > 0,
                    onShop: () => _open(context, const BusinessScreen()),
                    onProduct: () => _open(context, const ProductFormScreen()),
                    onReply: () => _open(context, const ReplyStudioScreen()),
                  ),
                  // ---- quick actions
                  const SectionTitle('Quick actions'),
                  Row(children: [
                    _Quick(0, Icons.person_add_alt_1, 'Add\ncustomer', () => _addCustomer(context, ref)),
                    _Quick(1, Icons.add_box_outlined, 'Add\nproduct', () => _open(context, const ProductFormScreen())),
                    _Quick(2, Icons.shopping_bag_outlined, 'New\norder', () => _open(context, const OrderBuilderScreen())),
                    _Quick(3, Icons.help_outline, 'How to\nuse', () => _open(context, const HelpScreen())),
                  ]),
                  // ---- overview (today / this week / this month)
                  const SectionTitle('Overview'),
                  Wrap(spacing: 8, children: [
                    for (final p in const [['today', 'Today'], ['week', 'This week'], ['month', 'This month']])
                      ChoiceChip(
                        label: Text(p[1]),
                        selected: period == p[0],
                        selectedColor: kOrange.withOpacity(0.2),
                        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: period == p[0] ? kDeep : kInk),
                        onSelected: (_) => ref.read(dashPeriodProvider.notifier).state = p[0],
                      ),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Follow-ups, pending orders and low stock always show the current status.',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (final (i, s) in <_Stat>[
                        _Stat('New customers', 'Messaged you',
                            '${period == 'week' ? d.newLeadsWeek : period == 'month' ? d.newLeadsMonth : d.newLeadsToday}',
                            Icons.person_add_alt, kOrange, () => goToTab(1)),
                        _Stat('Need follow-up', 'Message them again', '${d.followupsDue}', Icons.notifications_active,
                            d.followupsDue > 0 ? kDeep : Colors.grey, () => _open(context, const FollowupsScreen())),
                        _Stat('Orders', 'New orders',
                            '${period == 'week' ? d.ordersWeek : period == 'month' ? d.ordersMonth : d.ordersToday}',
                            Icons.shopping_bag_outlined, kOrange, () => goToTab(3)),
                        _Stat('Sales', 'Total amount',
                            taka(period == 'week' ? d.revenueWeek : period == 'month' ? d.revenueMonth : d.revenueToday),
                            Icons.payments_outlined, kDeep, () => goToTab(3)),
                        _Stat('To confirm', 'Pending orders', '${d.pendingOrders}', Icons.pending_actions, kOrange, () => goToTab(3)),
                        _Stat('Low stock', 'Running out', '${d.lowStockCount}', Icons.warning_amber,
                            d.lowStockCount > 0 ? Colors.red.shade700 : Colors.grey, () => goToTab(2)),
                      ].indexed)
                        FadeSlideIn(delayMs: 120 + i * 70, child: s),
                    ],
                  ),
                  // ---- customers by status
                  SectionTitle('Your customers'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in leadStatuses)
                      ActionChip(
                        backgroundColor: statusColor(s).withOpacity(0.10),
                        side: BorderSide.none,
                        label: Text('${label(s)}: ${d.leadsByStatus[s] ?? 0}', style: TextStyle(color: statusColor(s), fontWeight: FontWeight.w600)),
                        onPressed: () => goToTab(1),
                      ),
                  ]),
                  // ---- AI usage
                  const SectionTitle('AI replies this month'),
                  AppCard(
                    onTap: () => _open(context, const UsageScreen()),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('${d.usage.remaining} left', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${d.usage.used} of ${d.usage.limit} used', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: d.usage.limit == 0 ? 0 : (d.usage.used / d.usage.limit).clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => LinearProgressIndicator(
                            minHeight: 10,
                            value: v,
                            backgroundColor: kCream,
                            color: d.usage.remaining * 5 < d.usage.limit ? Colors.red.shade600 : kOrange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${planName(d.usage.plan)} - each reply, refine, follow-up and order-fill counts as 1',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ]),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String shop;
  final VoidCallback onHelp;
  const _Header({required this.shop, required this.onHelp});
  @override
  Widget build(BuildContext context) => WaveBackground(
    waveSpace: 30,
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 8, 20),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Assalamu Alaikum', style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 2),
            Text(shop.isEmpty ? 'Your shop' : shop,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
        IconButton(onPressed: onHelp, icon: const Icon(Icons.help_outline, color: Colors.white), tooltip: 'How to use'),
      ]),
    ),
  );
}

class _GettingStarted extends StatelessWidget {
  final bool shopDone, productsDone, replyDone;
  final VoidCallback onShop, onProduct, onReply;
  const _GettingStarted({
    required this.shopDone, required this.productsDone, required this.replyDone,
    required this.onShop, required this.onProduct, required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    if (shopDone && productsDone && replyDone) return const SizedBox.shrink();
    final done = [shopDone, productsDone, replyDone].where((x) => x).length;
    Widget step(bool ok, String t, String bn, VoidCallback f) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? kOrange : Colors.grey),
      title: Text(t, style: TextStyle(fontWeight: FontWeight.w600, decoration: ok ? TextDecoration.lineThrough : null)),
      subtitle: Text(bn),
      trailing: ok ? null : const Icon(Icons.chevron_right),
      onTap: ok ? null : f,
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Get started ($done of 3 done)'),
      AppCard(
        child: Column(children: [
          step(shopDone, '1. Add your shop details', 'Phone, delivery and return rules', onShop),
          step(productsDone, '2. Add your products', 'Price, sizes and stock', onProduct),
          step(replyDone, '3. Try your first AI reply', 'Paste a customer message and see', onReply),
        ]),
      ),
    ]);
  }
}

class _Quick extends StatelessWidget {
  final int index;
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _Quick(this.index, this.icon, this.text, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FadeSlideIn(
        delayMs: 100 + index * 70,
        child: AppCard(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          onTap: onTap,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(gradient: kSoftGradient, shape: BoxShape.circle),
              child: Icon(icon, color: kDeep),
            ),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2)),
          ]),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String title, sub, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Stat(this.title, this.sub, this.value, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color))),
      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54)),
    ]),
  );
}