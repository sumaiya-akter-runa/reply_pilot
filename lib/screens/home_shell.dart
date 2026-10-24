import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'leads_screen.dart';
import 'more_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _i = 0;
  DateTime? _lastBack;
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _i) return;
    setState(() => _i = i);
    _fade.forward(from: 0);
  }

  /// Android back button:
  ///  - on Customers/Products/Orders/More -> go back to Home tab (do NOT close the app)
  ///  - on Home -> press twice to exit
  void _onBack() {
    if (_i != 0) {
      _go(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    snack(context, 'Press back again to exit');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(_curve),
            child: IndexedStack(index: _i, children: [
              DashboardScreen(goToTab: _go),
              const LeadsScreen(),
              const ProductsScreen(),
              const OrdersScreen(),
              const MoreScreen(),
            ]),
          ),
        ),
        bottomNavigationBar: _NavBar(selected: _i, onTap: _go),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _NavBar({required this.selected, required this.onTap});

  static const _items = [
    [Icons.home_outlined, Icons.home_rounded, 'Home'],
    [Icons.people_outline, Icons.people_rounded, 'Customers'],
    [Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Products'],
    [Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'],
    [Icons.menu_rounded, Icons.menu_rounded, 'More'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: kDeep.withOpacity(0.14), blurRadius: 22, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(children: [
            for (int i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: _items[i][2] as String,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: i == selected ? kBrandGradient : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: i == selected ? [BoxShadow(color: kOrange.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))] : null,
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        AnimatedScale(
                          scale: i == selected ? 1.18 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            (i == selected ? _items[i][1] : _items[i][0]) as IconData,
                            size: 24,
                            color: i == selected ? Colors.white : kInk.withOpacity(0.55),
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == selected ? FontWeight.w700 : FontWeight.w500,
                            color: i == selected ? Colors.white : kInk.withOpacity(0.6),
                          ),
                          child: Text(_items[i][2] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
