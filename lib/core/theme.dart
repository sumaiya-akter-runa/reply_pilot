import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---- brand palette (deeper, softer tones so it is easy on the eyes)
const kDeep = Color(0xFF8F4A03);
const kDeepDark = Color(0xFF6E3802);
const kOrange = Color(0xFFC85F1E);
const kPeach = Color(0xFFE0956A);
const kCream = Color(0xFFF3D9A8);

const kPrimary = kDeep;
const kInk = Color(0xFF34190A);
const kBg = Color(0xFFF7EEE2);
const kCard = Color(0xFFFFFCF7);
const kBorderColor = Color(0xFFE8D3AE);

const kBrandGradient = LinearGradient(
  colors: [kDeepDark, kOrange],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kWarmGradient = LinearGradient(
  colors: [kOrange, kPeach],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kSoftGradient = LinearGradient(
  colors: [kCream, kBg],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

/// Floating button with the deep brand gradient.
/// Use [label] for the wide version ("Add customer"), leave it out for a round icon button.
class GradientFab extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  const GradientFab({super.key, required this.icon, required this.onPressed, this.label});

  @override
  Widget build(BuildContext context) {
    final wide = label != null;
    return Container(
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(wide ? 18 : 28),
        boxShadow: [BoxShadow(color: kDeepDark.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(wide ? 18 : 28),
          splashColor: Colors.white24,
          onTap: onPressed,
          child: Padding(
            padding: wide ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14) : const EdgeInsets.all(16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white),
              if (wide) ...[
                const SizedBox(width: 10),
                Text(label!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Only stable theme parts are set here, so this keeps working across Flutter versions.
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kOrange, brightness: Brightness.light).copyWith(
    primary: kDeep,
    onPrimary: Colors.white,
    primaryContainer: kCream,
    onPrimaryContainer: kInk,
    secondary: kOrange,
    secondaryContainer: kCream,
    onSecondaryContainer: kInk,
  );
  final radius = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: kDeep,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kDeep,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: radius,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kDeep,
        side: const BorderSide(color: kPeach),
        minimumSize: const Size(64, 46),
        shape: radius,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kDeep)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kDeep,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kOrange, linearTrackColor: kCream),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kInk,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: Colors.white,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}