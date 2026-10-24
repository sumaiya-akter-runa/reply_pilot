import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';

class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Shop profile')),
      body: AsyncBody<Me>(
        value: me,
        onRetry: () => ref.invalidate(meProvider),
        data: (m) => _BusinessForm(m.business),
      ),
    );
  }
}

class _BusinessForm extends ConsumerStatefulWidget {
  final Business b;
  const _BusinessForm(this.b);
  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.b.name);
  late final _phone = TextEditingController(text: widget.b.phone);
  late final _address = TextEditingController(text: widget.b.address);
  late final _delivery = TextEditingController(text: widget.b.deliveryPolicy);
  late final _returns = TextEditingController(text: widget.b.returnPolicy);
  late final _payment = TextEditingController(text: widget.b.paymentMethods);
  late final _charge = TextEditingController(
      text: widget.b.defaultDeliveryCharge == 0 ? '' : widget.b.defaultDeliveryCharge.toStringAsFixed(0));
  late String _tone = widget.b.tone;
  late String _lang = widget.b.defaultLanguage;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _delivery, _returns, _payment, _charge]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).updateBusiness({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'delivery_policy': _delivery.text.trim(),
        'return_policy': _returns.text.trim(),
        'payment_methods': _payment.text.trim(),
        'tone': _tone,
        'default_language': _lang,
        'default_delivery_charge': double.tryParse(_charge.text.trim()) ?? 0,
      });
      ref.invalidate(meProvider);
      if (mounted) {
        snack(context, 'Saved');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String l, {int lines = 1, TextInputType? type, String? hint, String? Function(String?)? v}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          maxLines: lines,
          keyboardType: type,
          validator: v,
          decoration: InputDecoration(labelText: l, hintText: hint, border: kBorder, filled: true, fillColor: Colors.white, alignLabelWithHint: true),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _field(_name, 'Shop name', v: requiredField),
        _field(_phone, 'Phone', type: TextInputType.phone),
        _field(_address, 'Address'),
        _field(_delivery, 'Delivery policy', lines: 3, hint: 'e.g. Chattogram city 60 Tk, outside 120 Tk. 2-4 days.'),
        _field(_returns, 'Return / exchange policy', lines: 3),
        _field(_payment, 'Payment methods', hint: 'bKash, Nagad, Cash on delivery'),
        _field(_charge, 'Default delivery charge (Tk)', type: TextInputType.number),
        Text('Reply language', style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: [
          for (final l in languages) ChoiceChip(label: Text(label(l)), selected: _lang == l, onSelected: (_) => setState(() => _lang = l)),
        ]),
        const SizedBox(height: 12),
        Text('Reply tone', style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 8, children: [
          for (final t in tones) ChoiceChip(label: Text(label(t)), selected: _tone == t, onSelected: (_) => setState(() => _tone = t)),
        ]),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy ? null : _save, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_busy ? 'Saving...' : 'Save'))),
      ]),
    );
  }
}
