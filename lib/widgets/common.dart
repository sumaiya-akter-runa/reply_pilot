import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../providers.dart';

const leadStatuses = ['new', 'interested', 'follow_up', 'ordered', 'lost'];
const orderStatuses = ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];
const languages = ['bangla', 'banglish', 'english'];
const tones = ['friendly', 'professional', 'fun', 'premium'];

String label(String s) {
  const special = {'follow_up': 'Follow-up'};
  if (special.containsKey(s)) return special[s]!;
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

Color statusColor(String s) {
  switch (s) {
    case 'new':
    case 'pending':
      return Colors.blue;
    case 'interested':
    case 'confirmed':
      return Colors.teal;
    case 'follow_up':
    case 'shipped':
      return Colors.orange;
    case 'ordered':
    case 'delivered':
      return Colors.green;
    default:
      return Colors.red;
  }
}

String fmtDate(DateTime? d) {
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

void snack(BuildContext c, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(c);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red.shade700 : null));
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'Yes'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

Future<void> copyText(BuildContext c, String text, {String msg = 'Copied'}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (c.mounted) snack(c, msg);
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(label(status), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Shows loading / error+retry / data for an AsyncValue.
/// If a refresh fails but older data exists (for example the phone went offline),
/// the old data stays visible with a small "offline" bar instead of a blank page.
class AsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  const AsyncBody({super.key, required this.value, required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (value.hasError && value.hasValue) {
      return Column(children: [
        Container(
          width: double.infinity,
          color: kCream,
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(children: [
            const Icon(Icons.cloud_off, size: 18, color: kDeep),
            const SizedBox(width: 8),
            const Expanded(child: Text('Offline. Showing saved data.', style: TextStyle(fontSize: 12))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        ),
        Expanded(child: data(value.requireValue)),
      ]);
    }
    return value.when(
      data: data,
      loading: () => const Center(child: WaveLoader()),
      error: (e, _) => _ErrorView(error: e, onRetry: onRetry),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).offline;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(gradient: kSoftGradient, shape: BoxShape.circle),
            child: Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 40, color: kDeep),
          ),
          const SizedBox(height: 18),
          Text(
            offline ? 'No connection' : 'Something went wrong',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk),
          ),
          const SizedBox(height: 8),
          Text(
            offline ? "Can't reach the server.\nCheck your Wi-Fi and try again." : errText(error),
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.4, color: kInk.withOpacity(0.7)),
          ),
          if (offline) ...[
            const SizedBox(height: 4),
            Text(
              'সংযোগ নেই। Wi-Fi চেক করে আবার চেষ্টা করুন।',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: kInk.withOpacity(0.55)),
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: 180,
            child: GradientButton(text: 'Try again', icon: Icons.refresh, onPressed: onRetry),
          ),
        ]),
      ),
    );
  }
}

/// Pull-to-refresh must never throw when the phone is offline.
Future<void> safeRefresh(Future<dynamic> f) async {
  try {
    await f;
  } catch (_) {
    // the screen shows the error itself
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: Colors.grey),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
      ]),
    ),
  );
}

String? requiredField(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
final phoneRegex = RegExp(r'^\+?[0-9 \-]{7,18}$');
String? phoneField(String? v) => (v == null || !phoneRegex.hasMatch(v.trim())) ? 'Enter a valid phone number' : null;

// ---------------------------------------------------------------- look & feel
const kBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFFE8CFA3)),
);

/// "free" is shown as "Free trial" because there is no payment yet.
String planName(String plan) => plan == 'starter' ? 'Starter' : 'Free trial';

/// Rounded card used everywhere. Pass [gradient] for a coloured hero card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color, this.gradient});
  @override
  Widget build(BuildContext context) {
    final hero = gradient != null;
    final inner = onTap == null
        ? Padding(padding: padding, child: child)
        : Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: kPeach.withOpacity(0.35),
        highlightColor: kCream.withOpacity(0.4),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: hero ? null : (color ?? kCard),
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: hero ? null : Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: kDeep.withOpacity(hero ? 0.28 : 0.07),
            blurRadius: hero ? 20 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: inner,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? hint;
  const SectionTitle(this.title, {super.key, this.hint});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      if (hint != null) Text(hint!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
    ]),
  );
}

/// Tinted box with an icon and a short explanation (used to explain screens in simple words).
class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const InfoBanner(this.text, {super.key, this.icon = Icons.info_outline, this.color = kDeep});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
    ]),
  );
}

/// Explains the customer statuses in simple words (English + Bangla).
Future<void> showStatusHelp(BuildContext context) {
  const rows = [
    ['new', 'Just messaged you', 'নতুন - এইমাত্র মেসেজ করেছে'],
    ['interested', 'Asking or thinking about buying', 'আগ্রহী - দাম/সাইজ জানতে চেয়েছে'],
    ['follow_up', 'You need to message again later', 'আবার মেসেজ দিতে হবে'],
    ['ordered', 'Placed an order', 'অর্ডার করেছে'],
    ['lost', 'Not buying', 'কিনবে না'],
  ];
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('What do the statuses mean?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('A "customer" here is anyone who messaged you on Messenger.\nযারা আপনাকে মেসেজ করেছে তারাই customer।', style: TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 92, child: StatusChip(r[0])),
                const SizedBox(width: 8),
                Expanded(child: Text('${r[1]}\n${r[2]}', style: const TextStyle(fontSize: 13, height: 1.3))),
              ]),
            ),
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

// ------------------------------------------------------------ animation kit

bool _reduceMotion(BuildContext c) => MediaQuery.of(c).disableAnimations;

/// Fades and slides its child up a little. Use [delayMs] to stagger a list.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double dy;
  const FadeSlideIn({super.key, required this.child, this.delayMs = 0, this.dy = 0.08});
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, widget.dy), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Gradient background with soft moving waves along the bottom edge.
/// [bottomColor] is the colour of the page below, so the wave melts into it.
class WaveBackground extends StatefulWidget {
  final Widget child;
  final Gradient gradient;
  final Color bottomColor;
  final double waveSpace;
  const WaveBackground({
    super.key,
    required this.child,
    this.gradient = kBrandGradient,
    this.bottomColor = kBg,
    this.waveSpace = 34,
  });
  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: widget.gradient),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _WavePainter(_c.value, widget.bottomColor)),
          ),
        ),
      ),
      Padding(padding: EdgeInsets.only(bottom: widget.waveSpace), child: widget.child),
    ]);
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  final Color bottom;
  _WavePainter(this.t, this.bottom);

  Path _wave(Size s, double base, double amp, double freq, double phase) {
    final p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x += 4) {
      final y = base + amp * math.sin((x / s.width) * 2 * math.pi * freq + phase);
      p.lineTo(x, y);
    }
    p.lineTo(s.width, s.height);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t * 2 * math.pi;
    canvas.drawPath(_wave(size, size.height - 34, 9, 1.1, a), Paint()..color = kCream.withOpacity(0.20));
    canvas.drawPath(_wave(size, size.height - 24, 8, 1.6, -a + 1.3), Paint()..color = kPeach.withOpacity(0.28));
    canvas.drawPath(_wave(size, size.height - 12, 7, 1.3, a * 2 + 2.4), Paint()..color = bottom);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.bottom != bottom;
}

/// Five bars rising and falling in a wave (replaces the plain spinner).
class WaveLoader extends StatefulWidget {
  final double size;
  final Color color;
  const WaveLoader({super.key, this.size = 36, this.color = kOrange});
  @override
  State<WaveLoader> createState() => _WaveLoaderState();
}

class _WaveLoaderState extends State<WaveLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size / 7;
    return Semantics(
      label: 'Loading',
      child: SizedBox(
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            for (int i = 0; i < 5; i++)
              Container(
                width: w,
                height: widget.size * (0.3 + 0.7 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi - i * 0.8))),
                margin: EdgeInsets.symmetric(horizontal: w * 0.35),
                decoration: BoxDecoration(
                  color: Color.lerp(widget.color, kPeach, i / 4),
                  borderRadius: BorderRadius.circular(w),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Main call-to-action button with the brand gradient.
class GradientButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final Gradient gradient;
  const GradientButton({super.key, required this.text, required this.onPressed, this.icon, this.busy = false, this.gradient = kBrandGradient});
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled || busy ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: kDeep.withOpacity(0.28), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white24,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                else ...[
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}