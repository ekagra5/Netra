// Design tokens for Netra.
//
// The visual language (thick 2px dividers, uppercase tracked micro-labels,
// bold oversized numerals for the grade readout, flat 1990s-Swiss-poster
// "modernist" cards) is ported from the Claude Design canvas prototype for
// this app. That prototype's actual color/type tokens weren't available
// when this was built, so the palette below is a deliberate substitute:
// red + white + near-black, per direction from the project owner.
//
// One departure from a pure red/white palette, on purpose: the DR severity
// scale (grade 0-4) keeps its own green -> amber -> red progression instead
// of rendering every grade in brand red. A health worker glancing at the
// result screen needs "grade 0, no referral needed" to read as calm and
// "grade 4, urgent" to read as alarming - collapsing both into the same
// brand-red accent would erase that signal. Everything else (buttons, tabs,
// links, badges) uses the red/white/black system.
library;

import 'package:flutter/material.dart';

class NetraColors {
  NetraColors._();

  // Brand red scale (Tailwind's red, chosen for a well-tested contrast
  // ratio rather than picking a hex by eye).
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red200 = Color(0xFFFECACA);
  static const Color red600 = Color(0xFFDC2626); // accent
  static const Color red700 = Color(0xFFB91C1C); // accent-700 (text/icons)
  static const Color red900 = Color(0xFF7F1D1D);

  static const Color bg = Color(0xFFFFFFFF);
  static const Color bgMuted = Color(0xFFF5F3F2); // page background wash
  static const Color divider = Color(0xFFE3DFDD);
  static const Color dividerStrong = Color(0xFFCFC9C6);

  static const Color ink = Color(0xFF17130F); // near-black, warm-tinted
  // Pre-blended against white rather than using ink.withValues(alpha: ...):
  // a runtime-computed Color isn't a compile-time constant, and these are
  // used throughout as `const TextStyle(color: NetraColors.inkMuted)`, etc.
  static const Color inkMuted = Color(0xFF6F6D6A); // ink @ ~62% over white
  static const Color inkFaint = Color(0xFFA7A5A4); // ink @ ~38% over white

  // Severity scale for DR grade 0-4 only - see the file doc comment above.
  static const List<Color> severity = [
    Color(0xFF1E8A5F), // 0 - No DR
    Color(0xFF7C9B35), // 1 - Mild
    Color(0xFFC77D00), // 2 - Moderate
    Color(0xFFD06724), // 3 - Severe
    Color(0xFFB91C1C), // 4 - Proliferative
  ];
}

class NetraSpace {
  NetraSpace._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
}

class NetraRadius {
  NetraRadius._();
  static const double card = 4; // modernist: near-square, not rounded
  static const double pill = 999;
}

ThemeData buildNetraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NetraColors.red600,
    brightness: Brightness.light,
    primary: NetraColors.red600,
    onPrimary: Colors.white,
    surface: NetraColors.bg,
    onSurface: NetraColors.ink,
    error: NetraColors.red700,
  );

  const dividerSide = BorderSide(color: NetraColors.divider, width: 2);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NetraColors.bgMuted,
    fontFamily: 'Roboto', // bundled with Flutter; no network font fetch,
    // which matters for an app built for low-connectivity rural clinics.
    dividerTheme: const DividerThemeData(
      color: NetraColors.divider,
      thickness: 2,
      space: 0,
    ),
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 34,
        height: 1.05,
        color: NetraColors.ink,
        letterSpacing: 0.2,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        color: NetraColors.ink,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: NetraColors.ink,
      ),
      bodyMedium: TextStyle(fontSize: 15, color: NetraColors.ink, height: 1.4),
      bodySmall: TextStyle(fontSize: 13, color: NetraColors.ink, height: 1.4),
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: NetraColors.inkMuted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NetraColors.bg,
      foregroundColor: NetraColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: dividerSide),
    ),
    cardTheme: CardThemeData(
      color: NetraColors.bg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NetraRadius.card),
        side: dividerSide,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NetraColors.red600,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetraRadius.card),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NetraColors.ink,
        side: const BorderSide(color: NetraColors.dividerStrong, width: 2),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NetraRadius.card),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NetraColors.red700,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dividerColor: NetraColors.divider,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: NetraColors.bg,
      indicatorColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? NetraColors.red700 : NetraColors.inkFaint,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? NetraColors.red700 : NetraColors.inkFaint,
        );
      }),
    ),
  );
}
