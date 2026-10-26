import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'widgets/common.dart';

void main() {
  if (kReleaseMode) {
    // a build error would otherwise show a blank grey screen
    ErrorWidget.builder = (details) => const Material(
      color: kBg,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Something went wrong on this screen.\nPlease go back and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
  runApp(const ProviderScope(child: ReplyPilotApp()));
}

class ReplyPilotApp extends StatelessWidget {
  const ReplyPilotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ReplyPilot',
    navigatorKey: navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const RootGate(),
  );
}

class RootGate extends ConsumerWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider);
    final Widget page;
    if (s == AuthStatus.loading) {
      page = const _Splash();
    } else {
      page = s == AuthStatus.loggedIn ? const HomeShell() : const AuthScreen();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(s), child: page),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: WaveBackground(
      waveSpace: 40,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: kInk.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/img.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: kOrange,
                    child: const Icon(Icons.auto_awesome, size: 48, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ReplyPilot AI', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 28),
          const WaveLoader(color: Colors.white),
        ]),
      ),
    ),
  );
}