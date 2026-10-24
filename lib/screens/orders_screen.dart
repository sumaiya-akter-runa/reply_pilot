import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

/// Any order can be deleted. The server gives the stock back if the order was still open.
bool canDeleteOrder(Order o) => true;

/// Asks first, then deletes.
Future<bool> deleteOrderFlow(BuildContext context, WidgetRef ref, Order o) async {
  final open = o.status != 'delivered' && o.status != 'cancelled';
  final ok = await confirmDialog(
    context,
    'Delete order #${o.id}?',
    open
        ? 'This order is still open. It will be removed and its stock returned. This cannot be undone.\n'
            'এই order মুছে যাবে এবং stock ফেরত আসবে।'
        : 'It will be removed from your order list and sales totals. This cannot be undone.\n'
            'এই order আপনার তালিকা ও বিক্রির হিসাব থেকে মুছে যাবে।',
    ok: 'Delete',
  );
  if (!ok) return false;
  try {
    await ref.read(apiProvider).deleteOrder(o.id);
    refreshAll(ref);
    if (context.mounted) snack(context, 'Order deleted');
    return true;
  } catch (e) {
    if (context.mounted) snack(context, errText(e), error: true);
    return false;
  }
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            Padding(padding: const EdgeInsets.all(6), child: ChoiceChip(label: const Text('All'), selected: _status == null, onSelected: (_) => setState(() => _status = null))),
            for (final s in orderStatuses)
              Padding(padding: const EdgeInsets.all(6), child: ChoiceChip(label: Text(label(s)), selected: _status == s, onSelected: (_) => setState(() => _status = s))),
          ]),
        ),
        Expanded(
          child: AsyncBody<List<Order>>(
            value: orders,
            onRetry: () => ref.invalidate(ordersProvider),
            data: (list) => list.isEmpty
                ? const EmptyState('No orders yet.\nOpen a customer and tap Order, or use "Create order from this message" in Reply.\nকোনো order নেই।', icon: Icons.receipt_long_outlined)
                : RefreshIndicator(
                    onRefresh: () => safeRefresh(ref.refresh(ordersProvider(_status).future)),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: list.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return const InfoBanner(
                            'Tip: press and hold a delivered or cancelled order to delete it.\nDelivered order চেপে ধরে রাখলে delete করতে পারবেন।',
                            icon: Icons.touch_app_outlined,
                          );
                        }
                        final o = list[i - 1];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o.id))),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPress: () => deleteOrderFlow(context, ref, o),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('#${o.id}  ${o.customerName}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text('${fmtDate(o.createdAt)} - ${o.items.length} item(s)', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(taka(o.total), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  StatusChip(o.status),
                                ]),
                              ]),
                            ),
                          ),
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

class OrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _next = {'pending': 'confirmed', 'confirmed': 'shipped', 'shipped': 'delivered'};
  static const _nextLabel = {'confirmed': 'Confirm order', 'shipped': 'Mark as shipped', 'delivered': 'Mark as delivered'};

  Future<void> _setStatus(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(apiProvider).setOrderStatus(orderId, status);
      refreshAll(ref);
    } catch (e) {
      if (context.mounted) snack(context, errText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId'),
        actions: [
          if (order.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete order',
              onPressed: () async {
                if (await deleteOrderFlow(context, ref, order.valueOrNull!) && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: AsyncBody<Order>(
        value: order,
        onRetry: () => ref.invalidate(orderProvider(orderId)),
        data: (o) {
          final next = _next[o.status];
          final canCancel = o.status == 'pending' || o.status == 'confirmed' || o.status == 'shipped';
          return ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [StatusChip(o.status), const Spacer(), Text(fmtDate(o.createdAt), style: const TextStyle(color: Colors.black54))]),
                const SizedBox(height: 10),
                Text(o.customerName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(o.phone),
                Text(o.address),
                if (o.note.isNotEmpty) Text('Note: ${o.note}'),
              ]),
            ),
            const SizedBox(height: 10),
            AppCard(
              child: Column(children: [
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${i.productName}${i.variantLabel.isEmpty ? '' : ' (${i.variantLabel})'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${i.quantity} x ${taka(i.unitPrice)}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ]),
                      ),
                      Text(taka(i.lineTotal)),
                    ]),
                  ),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text(taka(o.subtotal))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Delivery'), Text(taka(o.deliveryCharge))]),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(taka(o.total), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy summary for customer'),
              onPressed: () async {
                try {
                  final text = await ref.read(apiProvider).orderSummary(orderId);
                  if (context.mounted) await copyText(context, text, msg: 'Summary copied. Paste it in Messenger.');
                } catch (e) {
                  if (context.mounted) snack(context, errText(e), error: true);
                }
              },
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: () => _setStatus(context, ref, next), child: Text(_nextLabel[next]!)),
            ],
            if (canCancel) ...[
              const SizedBox(height: 4),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  if (await confirmDialog(context, 'Cancel order', 'Cancel this order? Stock will be returned.', ok: 'Cancel order')) {
                    if (context.mounted) await _setStatus(context, ref, 'cancelled');
                  }
                },
                child: const Text('Cancel order'),
              ),
            ],
            if (canDeleteOrder(o)) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete this order'),
                onPressed: () async {
                  if (await deleteOrderFlow(context, ref, o) && context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ]);
        },
      ),
    );
  }
}
