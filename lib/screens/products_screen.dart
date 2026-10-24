import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _q = '';
  bool _lowOnly = false;

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      floatingActionButton: GradientFab(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: Icons.add,
        label: 'Add product',
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search products', border: kBorder, filled: true, fillColor: Colors.white, isDense: true),
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(label: const Text('Low stock only'), selected: _lowOnly, onSelected: (v) => setState(() => _lowOnly = v)),
          ),
        ),
        Expanded(
          child: AsyncBody<List<Product>>(
            value: products,
            onRetry: () => ref.invalidate(productsProvider),
            data: (all) {
              final list = all
                  .where((p) => p.name.toLowerCase().contains(_q) && (!_lowOnly || p.hasLowStock))
                  .toList();
              if (list.isEmpty) {
                return EmptyState(all.isEmpty ? 'No products yet. Add your first product so the AI can answer price and stock questions.' : 'No product matches.', icon: Icons.inventory_2_outlined);
              }
              return RefreshIndicator(
                onRefresh: () => safeRefresh(ref.refresh(productsProvider.future)),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.variants.map((v) => '${v.label}: ${v.stockQty}').join('  |  ')),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(taka(p.price), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (p.hasLowStock) const Text('Low stock', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ]),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
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
