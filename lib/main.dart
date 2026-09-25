import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/repositories/agent_repository.dart';
import 'data/storage/app_settings_store.dart';
import 'viewmodels/app_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final viewModel = AppViewModel(
    repository: AgentRepository(),
    settingsStore: AppSettingsStore(),
    probeAndroidRuntime: defaultTargetPlatform == TargetPlatform.android,
  );
  AppLifecycleListener(
    onPause: () => unawaited(viewModel.flushSessionPersistence()),
    onDetach: () => unawaited(viewModel.flushSessionPersistence()),
  );
  runApp(
    ChangeNotifierProvider<AppViewModel>.value(
      value: viewModel,
      child: const FinnCodeApp(),
    ),
  );
  unawaited(viewModel.initialize());
}
