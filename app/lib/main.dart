import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NetraRoot());
}

/// Owns the single app-wide AppState for the app's lifetime and boots it
/// (loads the on-device model, reads patients/queue from SQLite) once.
class NetraRoot extends StatefulWidget {
  const NetraRoot({super.key});

  @override
  State<NetraRoot> createState() => _NetraRootState();
}

class _NetraRootState extends State<NetraRoot> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
    _appState.bootstrap();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _appState,
      child: const NetraApp(),
    );
  }
}
