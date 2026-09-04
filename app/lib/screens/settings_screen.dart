import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tab_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(leading: const NsBrandMark(letter: 'N'), title: t['settingsTitle']),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NsSectionLabel(t['language']),
                  NsSegControl(
                    labels: const ['EN', 'HI'],
                    selectedIndex: state.language == AppLanguage.hi ? 1 : 0,
                    onChanged: (i) => state.setLanguage(i == 1 ? AppLanguage.hi : AppLanguage.en),
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  NsListRow(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['offlineMode'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(t['offlineModeBody'], style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted)),
                            ],
                          ),
                        ),
                        Switch(
                          value: state.offlineFirstMode,
                          activeThumbColor: NetraColors.red600,
                          onChanged: (_) => state.toggleOfflineMode(),
                        ),
                      ],
                    ),
                  ),
                  NsListRow(
                    child: Row(
                      children: [
                        Expanded(child: Text(t['modelInfo'], style: const TextStyle(fontSize: 14))),
                        Icon(
                          state.modelReady ? Icons.check_circle_outline : Icons.error_outline,
                          size: 16,
                          color: state.modelReady ? const Color(0xFF1E8A5F) : NetraColors.red700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          state.modelReady ? t['modelReady'] : t['modelMissing'],
                          style: const TextStyle(fontSize: 12, color: NetraColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  NsListRow(
                    child: Row(
                      children: [
                        Expanded(child: Text(t['cameraCal'], style: const TextStyle(fontSize: 14))),
                        const Icon(Icons.chevron_right, size: 18, color: NetraColors.inkFaint),
                      ],
                    ),
                  ),
                  NsListRow(
                    child: Row(
                      children: [
                        Expanded(child: Text(t['dataStorage'], style: const TextStyle(fontSize: 14))),
                        const Icon(Icons.chevron_right, size: 18, color: NetraColors.inkFaint),
                      ],
                    ),
                  ),
                  NsListRow(
                    child: Row(
                      children: [
                        Expanded(child: Text(t['help'], style: const TextStyle(fontSize: 14))),
                        const Icon(Icons.chevron_right, size: 18, color: NetraColors.inkFaint),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const NsTabBar(),
          ],
        ),
      ),
    );
  }
}
