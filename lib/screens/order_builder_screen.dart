import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'orders_screen.dart';

class _Row {
  int? productId;
  int? variantId;
  int qty;
  _Row({this.productId, this.variantId, this.qty = 1});
}

/// The seller reviews and edits everything. The server recalculates prices and totals.
class OrderBuilderScreen extends ConsumerStatefulWidget {
  final Lead? lead;
  final Extract? extract; // optional: suggestion from the AI
  const OrderBuilderScreen({super.key, this.lead, this.extract});
  @override
  ConsumerState<OrderBuilderScreen> createState() => _OrderBuilderScreenState();
}

class _OrderBuilderScreenState extends ConsumerState<OrderBuilderScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.lead?.customerName ?? '');
  late final _phone = TextEditingController(text: widget.lead?.phone ?? '');
  final _address = TextEditingController();
  final _charge = TextEditingController();
  final _note = TextEditingController();
  final _paste = TextEditingController();
  List<Product> _products = [];
  final List<_Row> _rows = [];
  bool _loading = true;
  bool _busy = false;
  String _defaultCharge = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _products = await ref.read(productsProvider.future);
      final me = await ref.read(meProvider.future);
      _defaultCharge = me.business.defaultDeliveryCharge == 0 ? '' : me.business.defaultDeliveryCharge.toStringAsFixed(0);
      _charge.text = _defaultCharge;
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    }
    final ex = widget.extract;
    if (ex != null) _apply(ex);
    if (_rows.isEmpty) _rows.add(_Row());
    if (mounted) setState(() => _loading = false);
  }

  void _apply(Extract ex) {
    if (ex.customerName.isNotEmpty) _name.text = ex.customerName;
    if (ex.phone.isNotEmpty) _phone.text = ex.phone;
    if (ex.address.isNotEmpty) _address.text = ex.address;
    _rows.clear();
    for (final it in ex.items) {
      _rows.add(_Row(productId: it.productId, variantId: it.variantId, qty: it.quantity < 1 ? 1 : it.quantity));
    }
    if (_rows.isEmpty) _rows.add(_Row());
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _charge, _note, _paste]) {
      c.dispose();
    }
    super.dispose();
  }

  Product? _product(int? id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Variant? _variant(_Row r) {
    final p = _product(r.productId);
    if (p == null) return null;
    for (final v in p.variants) {
      if (v.id == r.variantId) return v;
    }
    return null;
  }

  double get _subtotal {
    var t = 0.0;
    for (final r in _rows) {
      final p = _product(r.productId);
      if (p != null && r.variantId != null) t += p.price * r.qty;
    }
    return t;
  }

  Future<void> _fillFromMessage() async {
    final msg = _paste.text.trim();
    if (msg.isEmpty) return;
    setState(() => _busy = true);
    try {
      final ex = await ref.read(apiProvider).extractOrder(msg, leadId: widget.lead?.id);
      ref.invalidate(dashboardProvider);
      setState(() => _apply(ex));
      if (mounted && ex.missingFields.isNotEmpty) snack(context, 'Please fill: ${ex.missingFields.join(', ')}');
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final items = <Map<String, dynamic>>[];
    for (final r in _rows) {
      if (r.variantId == null) {
        snack(context, 'Choose a product and option for every item', error: true);
        return;
      }
      items.add({'variant_id': r.variantId, 'quantity': r.qty});
    }
    setState(() => _busy = true);
    try {
      final charge = double.tryParse(_charge.text.trim());
      final order = await ref.read(apiProvider).createOrder({
        if (widget.lead != null) 'lead_id': widget.lead!.id,
        'customer_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        if (charge != null) 'delivery_charge': charge,
        'note': _note.text.trim(),
        'items': items,
      });
      refreshAll(ref);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
      }
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _itemRow(int i) {
    final r = _rows[i];
    final p = _product(r.productId);
    final v = _variant(r);
    final tooMany = v != null && r.qty > v.stockQty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                hint: const Text('Product'),
                value: p?.id,
                items: [for (final x in _products) DropdownMenuItem(value: x.id, child: Text('${x.name} - ${taka(x.price)}', overflow: TextOverflow.ellipsis))],
                onChanged: (id) => setState(() {
                  r.productId = id;
                  final np = _product(id);
                  r.variantId = (np != null && np.variants.length == 1) ? np.variants.first.id : null;
                }),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _rows.length <= 1 ? null : () => setState(() => _rows.removeAt(i)),
            ),
          ]),
          if (p != null)
            DropdownButton<int>(
              isExpanded: true,
              hint: const Text('Size / option'),
              value: v?.id,
              items: [for (final x in p.variants) DropdownMenuItem(value: x.id, child: Text('${x.label} (${x.stockQty} in stock)'))],
              onChanged: (id) => setState(() => r.variantId = id),
            ),
          Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: r.qty > 1 ? () => setState(() => r.qty--) : null),
            Text('${r.qty}', style: Theme.of(context).textTheme.titleMedium),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => r.qty++)),
            if (tooMany) Expanded(child: Text('Only ${v!.stockQty} in stock', style: const TextStyle(color: Colors.red))),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final charge = double.tryParse(_charge.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Create order')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (widget.extract != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.blue.shade50,
                    child: Text('Filled by AI. Check every field.${widget.extract!.missingFields.isEmpty ? '' : '\nMissing: ${widget.extract!.missingFields.join(', ')}'}'),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Fill from customer message (optional)'),
                  children: [
                    TextField(controller: _paste, minLines: 2, maxLines: 5, decoration: const InputDecoration(border: kBorder, filled: true, fillColor: Colors.white, hintText: 'Paste the message with name, phone, address, product')),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _busy ? null : _fillFromMessage, child: const Text('Fill with AI'))),
                  ],
                ),
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Customer name', border: kBorder, filled: true, fillColor: Colors.white), validator: requiredField),
                const SizedBox(height: 12),
                TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', border: kBorder, filled: true, fillColor: Colors.white), validator: phoneField),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Delivery address', border: kBorder, filled: true, fillColor: Colors.white),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Enter the address' : null,
                ),
                const SizedBox(height: 16),
                Text('Items', style: Theme.of(context).textTheme.titleMedium),
                if (_products.isEmpty) const Text('You have no products yet. Add products first.', style: TextStyle(color: Colors.red)),
                for (var i = 0; i < _rows.length; i++) _itemRow(i),
                TextButton.icon(onPressed: () => setState(() => _rows.add(_Row())), icon: const Icon(Icons.add), label: const Text('Add another item')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _charge,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Delivery charge (Tk)', border: kBorder, filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', border: kBorder, filled: true, fillColor: Colors.white)),
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text(taka(_subtotal))]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Delivery'), Text(taka(charge))]),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Estimated total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(taka(_subtotal + charge), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                      const Text('The server calculates the final total.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_busy ? 'Saving...' : 'Create order')),
                ),
              ]),
            ),
    );
  }
}
