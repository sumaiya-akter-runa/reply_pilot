import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api.dart';
import 'core/api_client.dart';
import 'core/token_store.dart';
import 'models/models.dart';

/// Lets us close every open screen when the user logs out or the session expires.
final navigatorKey = GlobalKey<NavigatorState>();

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiProvider = Provider<Api>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final client = ApiClient(store, () => ref.read(authProvider.notifier).sessionExpired());
  return Api(client, store);
});

enum AuthStatus { loading, loggedOut, loggedIn }

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    Future.microtask(_init);
    return AuthStatus.loading;
  }

  Future<void> _init() async {
    final t = await ref.read(tokenStoreProvider).access;
    state = t == null ? AuthStatus.loggedOut : AuthStatus.loggedIn;
  }

  Future<void> login(String email, String password) async {
    await ref.read(apiProvider).login(email, password);
    state = AuthStatus.loggedIn;
  }

  Future<void> register(String email, String password, String firstName, String businessName) async {
    await ref.read(apiProvider).register(email, password, firstName, businessName);
    await login(email, password);
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    _closeScreens();
    state = AuthStatus.loggedOut;
  }

  void sessionExpired() {
    if (state == AuthStatus.loggedOut) return;
    ref.read(tokenStoreProvider).clear();
    _closeScreens();
    state = AuthStatus.loggedOut;
  }

  void _closeScreens() => navigatorKey.currentState?.popUntil((r) => r.isFirst);
}

final authProvider = NotifierProvider<AuthController, AuthStatus>(AuthController.new);

// ---- data providers. They watch authProvider so a new login never shows the old user's data. ----
final meProvider = FutureProvider.autoDispose<Me>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).me();
});

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).dashboard();
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).products();
});

final leadsProvider = FutureProvider.autoDispose.family<List<Lead>, String?>((ref, status) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).leads(status: status);
});

final followupsProvider = FutureProvider.autoDispose<List<Lead>>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).followups();
});

final leadProvider = FutureProvider.autoDispose.family<Lead, int>((ref, id) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).lead(id);
});

final faqsProvider = FutureProvider.autoDispose<List<Faq>>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).faqs();
});

final ordersProvider = FutureProvider.autoDispose.family<List<Order>, String?>((ref, status) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).orders(status: status);
});

final orderProvider = FutureProvider.autoDispose.family<Order, int>((ref, id) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).order(id);
});

final usageProvider = FutureProvider.autoDispose<UsageStats>((ref) {
  ref.watch(authProvider);
  return ref.watch(apiProvider).usage();
});

/// Call after anything that changes lead/order/product data so every list refreshes.
void refreshAll(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(productsProvider);
  ref.invalidate(leadsProvider);
  ref.invalidate(leadProvider);
  ref.invalidate(followupsProvider);
  ref.invalidate(ordersProvider);
  ref.invalidate(orderProvider);
  ref.invalidate(usageProvider);
}

String errText(Object e) => e is ApiException ? e.message : 'Something went wrong. Check your connection.';
