import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, NetraSpace.s4, NetraSpace.s4, 0),
                child: NsSegControl(
                  labels: const ['EN', 'HI'],
                  selectedIndex: state.language == AppLanguage.hi ? 1 : 0,
                  onChanged: (i) => state.setLanguage(i == 1 ? AppLanguage.hi : AppLanguage.en),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(NetraSpace.s6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NsBrandMark(letter: 'N', size: 64),
                    const SizedBox(height: NetraSpace.s5),
                    Text(t['appName'], style: Theme.of(context).textTheme.displaySmall),
                    const SizedBox(height: NetraSpace.s2),
                    Text(
                      t['tagline'],
                      style: const TextStyle(fontSize: 16, color: NetraColors.inkMuted),
                    ),
                    const SizedBox(height: NetraSpace.s5),
                    const Divider(),
                    const SizedBox(height: NetraSpace.s4),
                    _Bullet(t['onboardBullet1']),
                    const SizedBox(height: NetraSpace.s3),
                    _Bullet(t['onboardBullet2']),
                    const SizedBox(height: NetraSpace.s3),
                    _Bullet(t['onboardBullet3']),
                    if (!state.modelReady) ...[
                      const SizedBox(height: NetraSpace.s5),
                      NsCard(
                        accentBorder: NetraColors.red700,
                        child: Text(
                          t['modelMissing'],
                          style: const TextStyle(fontSize: 13, color: NetraColors.red900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(NetraSpace.s4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: state.goHome,
                  label: Text(t['getStarted']),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 18, color: NetraColors.red700),
        const SizedBox(width: NetraSpace.s3),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}
