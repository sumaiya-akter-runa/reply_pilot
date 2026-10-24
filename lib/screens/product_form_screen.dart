import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class _VRow {
  final int? id; // null = new variant
  final TextEditingController label;
  final TextEditingController stock;
  final TextEditingController threshold;
  _VRow({this.id, String l = '', String s = '0', String t = '3'})
      : label = TextEditingController(text: l),
        stock = TextEditingController(text: s),
        threshold = TextEditingController(text: t);
  void dispose() {
    label.dispose();
    stock.dispose();
    threshold.dispose();
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _desc = TextEditingController(text: widget.product?.description ?? '');
  late final _price = TextEditingController(
      text: widget.product == null ? '' : widget.product!.price.toString().replaceAll(RegExp(r'\.0$'), ''));
  late final List<_VRow> _rows = widget.product == null
      ? [_VRow(l: 'Default', s: '0')]
      : widget.product!.variants
          .map((v) => _VRow(id: v.id, l: v.label, s: '${v.stockQty}', t: '${v.lowStockThreshold}'))
          .toList();
  final List<int> _removed = [];
  bool _busy = false;

  bool get _editing => widget.product != null;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _variantBody(_VRow r) => {
        'label': r.label.text.trim(),
        'stock_qty': int.parse(r.stock.text.trim()),
        'low_stock_threshold': int.parse(r.threshold.text.trim()),
      };

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final api = ref.read(apiProvider);
      final price = double.parse(_price.text.trim());
      if (_editing) {
        final id = widget.product!.id;
        await api.updateProduct(id, {'name': _name.text.trim(), 'description': _desc.text.trim(), 'price': price});
        for (final r in _rows) {
          if (r.id != null) {
            await api.updateVariant(r.id!, _variantBody(r));
          } else {
            await api.addVariant(id, _variantBody(r)); // add before delete: a product needs >= 1 variant
          }
        }
        for (final vid in _removed) {
          await api.deleteVariant(vid);
        }
      } else {
        await api.createProduct({
          'name': _name.text.trim(),
          'description': _desc.text.trim(),
          'price': price,
          'variants': _rows.map(_variantBody).toList(),
        });
      }
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Delete product', 'Hide "${widget.product!.name}"? Old orders keep their history.', ok: 'Delete')) return;
    try {
      await ref.read(apiProvider).deleteProduct(widget.product!.id);
      ref.invalidate(productsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    }
  }

  String? _intField(String? v, {int min = 0}) {
    final n = int.tryParse((v ?? '').trim());
    return (n == null || n < min) ? 'Number >= $min' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit product' : 'New product'),
        actions: [if (_editing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Product name', border: kBorder, filled: true, fillColor: Colors.white), validator: requiredField),
          const SizedBox(height: 12),
          TextFormField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price (Tk)', border: kBorder, filled: true, fillColor: Colors.white),
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              return (n == null || n <= 0) ? 'Enter a price above 0' : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)', border: kBorder, filled: true, fillColor: Colors.white, alignLabelWithHint: true)),
          const SizedBox(height: 20),
          Text('Sizes / colours and stock', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Example: M, L, XL or Red / Black. Use one row named "Default" if there are no options.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++)
            Padding(
              key: ObjectKey(_rows[i]),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: TextFormField(controller: _rows[i].label, decoration: const InputDecoration(labelText: 'Label', border: kBorder, filled: true, fillColor: Colors.white, isDense: true), validator: requiredField)),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(controller: _rows[i].stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock', border: kBorder, filled: true, fillColor: Colors.white, isDense: true), validator: (v) => _intField(v))),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: TextFormField(controller: _rows[i].threshold, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Alert at', border: kBorder, filled: true, fillColor: Colors.white, isDense: true), validator: (v) => _intField(v))),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _rows.length <= 1
                      ? null
                      : () => setState(() {
                            final r = _rows.removeAt(i);
                            if (r.id != null) _removed.add(r.id!);
                            r.dispose();
                          }),
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => setState(() => _rows.add(_VRow())), icon: const Icon(Icons.add), label: const Text('Add option')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_busy ? 'Saving...' : 'Save')),
          ),
        ]),
      ),
    );
  }
}
