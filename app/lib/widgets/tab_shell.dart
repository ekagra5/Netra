import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Bottom tab bar shared by Home / History / Queue / Settings - mirrors
/// `.ns-tabbar` / `.ns-tab` / `.ns-badge` in the design prototype.
class NsTabBar extends StatelessWidget {
  const NsTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    final items = [
      (AppScreen.home, Icons.home_outlined, Icons.home, t['home'], 0),
      (AppScreen.history, Icons.history, Icons.history, t['history'], 0),
      (AppScreen.queue, Icons.sync_outlined, Icons.sync, t['queue'], state.queue.length),
      (AppScreen.settings, Icons.settings_outlined, Icons.settings, t['settings'], 0),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: NetraColors.bg,
        border: Border(top: BorderSide(color: NetraColors.divider, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: InkWell(
                  onTap: () => _navigate(state, item.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              state.screen == item.$1 ? item.$3 : item.$2,
                              size: 22,
                              color: state.screen == item.$1 ? NetraColors.red700 : NetraColors.inkFaint,
                            ),
                            if (item.$5 > 0)
                              Positioned(
                                right: -8,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: const BoxDecoration(
                                    color: NetraColors.red600,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                  child: Text(
                                    '${item.$5}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$4,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: state.screen == item.$1 ? FontWeight.w700 : FontWeight.w500,
                            color: state.screen == item.$1 ? NetraColors.red700 : NetraColors.inkFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigate(AppState state, AppScreen screen) {
    switch (screen) {
      case AppScreen.home:
        state.goHome();
      case AppScreen.history:
        state.goHistory();
      case AppScreen.queue:
        state.goQueue();
      case AppScreen.settings:
        state.goSettings();
      default:
        break;
    }
  }
}
