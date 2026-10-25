import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers.dart';
import '../widgets/common.dart';
import 'business_screen.dart';
import 'faq_screen.dart';
import 'followups_screen.dart';
import 'help_screen.dart';
import 'usage_screen.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // valueOrNull: never throws when the phone is offline
    final me = ref.watch(meProvider).valueOrNull;
    void open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    Widget item(IconData icon, String title, VoidCallback onTap, {String? sub}) => ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kCream, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: kDeep, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: sub == null ? null : Text(sub),
      trailing: Icon(Icons.chevron_right, color: kInk.withOpacity(0.4)),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me != null) ...[
            FadeSlideIn(
              child: AppCard(
                gradient: kBrandGradient,
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.storefront, color: kDeep),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(me.business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${me.email} - ${planName(me.plan)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FadeSlideIn(
            delayMs: 80,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: Column(children: [
                  item(Icons.help_outline, 'How to use ReplyPilot', () => open(const HelpScreen())),
                  item(Icons.storefront, 'Shop profile and policies', () => open(const BusinessScreen())),
                  item(Icons.quiz_outlined, 'FAQs (AI uses these)', () => open(const FaqScreen())),
                  item(Icons.notifications_active_outlined, 'Follow-up reminders', () => open(const FollowupsScreen())),
                  item(Icons.bolt, 'AI usage', () => open(const UsageScreen())),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delayMs: 160,
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Material(
                color: Colors.transparent,
                child: item(Icons.logout, 'Logout', () async {
                  if (await confirmDialog(context, 'Logout', 'Do you want to log out?', ok: 'Logout')) {
                    await ref.read(authProvider.notifier).logout();
                  }
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}