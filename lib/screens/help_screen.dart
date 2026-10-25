import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/common.dart';

/// Plain-language guide for first-time users.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String title, String en) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 14, backgroundColor: kPrimary, child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(en, style: const TextStyle(height: 1.4)),
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('How to use ReplyPilot')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const InfoBanner(
          'ReplyPilot helps you answer customers faster. It does NOT send messages by itself. You copy the reply and send it on Messenger.',
          icon: Icons.lightbulb_outline,
          color: Colors.green,
        ),
        step(1, 'Set up your shop', 'More > Shop profile. Write your phone, delivery and return rules. The AI answers only from this.'),
        step(2, 'Add your products', 'Products > Add product. Give price, sizes and stock. Without this the AI cannot tell prices.'),
        step(3, 'Reply to a customer', 'Home > Reply to customer. Paste the customer\'s message, tap Generate reply, edit if needed, tap Copy reply, then paste it in Messenger.'),
        step(4, 'Customers', 'A customer is anyone who messaged you. Keep them here and set a status: New, Interested, Follow-up, Ordered, Lost. Tap the (i) icon on the Customers screen to see what each means.'),
        step(5, 'Follow-up reminders', 'If a customer asked the price and went quiet, set a reminder (tomorrow or in 3 days). On that day it shows on Home under "Need follow-up". Tap Draft and the AI writes a polite message.'),
        step(6, 'Orders', 'When a customer wants to buy, create an order. Stock goes down automatically. Move it: Confirm > Shipped > Delivered. After delivery you can delete the order if you want (long-press the order). Cancelling gives the stock back.'),
        step(7, 'Good to know', 'The AI can make mistakes. If you see the orange "Check before sending" box, read the reply carefully first. Always check the price and size before you send.'),
      ]),
    );
  }
}
