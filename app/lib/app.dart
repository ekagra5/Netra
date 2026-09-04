import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/analyzing_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/findings_screen.dart';
import 'screens/heatmap_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/queue_screen.dart';
import 'screens/record_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

class NetraApp extends StatelessWidget {
  const NetraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netra',
      debugShowCheckedModeBanner: false,
      theme: buildNetraTheme(),
      home: const _ScreenRouter(),
    );
  }
}

/// Renders whichever screen `AppState.screen` currently points to. There is
/// no Navigator stack here on purpose - see app_state.dart's doc comment.
class _ScreenRouter extends StatelessWidget {
  const _ScreenRouter();

  @override
  Widget build(BuildContext context) {
    final screen = context.watch<AppState>().screen;
    final Widget body = switch (screen) {
      AppScreen.onboarding => const OnboardingScreen(),
      AppScreen.home => const HomeScreen(),
      AppScreen.capture => const CaptureScreen(),
      AppScreen.analyzing => const AnalyzingScreen(),
      AppScreen.results => const ResultsScreen(),
      AppScreen.heatmap => const HeatmapScreen(),
      AppScreen.findings => const FindingsScreen(),
      AppScreen.referral => const ReferralScreen(),
      AppScreen.history => const HistoryScreen(),
      AppScreen.record => const RecordScreen(),
      AppScreen.queue => const QueueScreen(),
      AppScreen.settings => const SettingsScreen(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(key: ValueKey(screen), child: body),
    );
  }
}
