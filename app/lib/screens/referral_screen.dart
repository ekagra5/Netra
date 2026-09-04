import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  String urgency = 'urgent';
  final notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.t;

    return Scaffold(
      backgroundColor: NetraColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            NsHeader(
              leading: NsBackButton(onPressed: state.backToResults),
              title: t['referralTitle'],
            ),
            NsBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NsCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(t['referYes'], style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        NsTag(t['present'], style: NsTagStyle.accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  NsSectionLabel(t['urgency']),
                  _RadioRow(
                    label: t['urgent'],
                    selected: urgency == 'urgent',
                    onTap: () => setState(() => urgency = 'urgent'),
                  ),
                  const SizedBox(height: NetraSpace.s2),
                  _RadioRow(
                    label: t['routine'],
                    selected: urgency == 'routine',
                    onTap: () => setState(() => urgency = 'routine'),
                  ),
                  const SizedBox(height: NetraSpace.s4),
                  NsSectionLabel(t['notes']),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: t['notesPlaceholder'],
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(color: NetraColors.dividerStrong, width: 2),
                        borderRadius: BorderRadius.circular(NetraRadius.card),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(NetraSpace.s4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: NetraColors.divider, width: 2)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await state.saveReferral(urgency: urgency, notes: notesController.text);
                    state.backToHome();
                  },
                  child: Text(t['confirmSave']),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: selected ? NetraColors.red600 : NetraColors.inkFaint,
          ),
          const SizedBox(width: NetraSpace.s3),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
