import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers.dart';
import '../widgets/common.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _shop = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _shop.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authProvider.notifier);
      if (_register) {
        await auth.register(_email.text.trim(), _password.text, _name.text.trim(), _shop.text.trim());
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) snack(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WaveBackground(
            waveSpace: 40,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 36, 24, 8),
              child: Column(children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: kInk.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.auto_awesome, size: 38, color: kOrange),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('ReplyPilot AI', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                  'Customer replies, orders and follow-ups in one place',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
                ),
              ]),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeSlideIn(
                delayMs: 150,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(_register ? 'Create your account' : 'Welcome back',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
                      const SizedBox(height: 16),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _register
                            ? Column(children: [
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(labelText: 'Your name', border: kBorder, filled: true, fillColor: Colors.white),
                                  validator: requiredField,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _shop,
                                  decoration: const InputDecoration(labelText: 'Shop name', border: kBorder, filled: true, fillColor: Colors.white),
                                  validator: requiredField,
                                ),
                                const SizedBox(height: 12),
                              ])
                            : const SizedBox(width: double.infinity),
                      ),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Email', border: kBorder, filled: true, fillColor: Colors.white),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: kBorder, filled: true, fillColor: Colors.white,
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                      ),
                      const SizedBox(height: 22),
                      GradientButton(
                        text: _register ? 'Create account' : 'Login',
                        busy: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() => _register = !_register),
                        child: Text(_register ? 'I already have an account' : 'New here? Create an account'),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
