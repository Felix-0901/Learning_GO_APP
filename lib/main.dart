import 'package:flutter/material.dart';
import 'app.dart';
import 'shared/services/app_state.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.load();
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: const LearningGOApp(),
    ),
  );
}
