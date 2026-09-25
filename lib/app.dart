import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'ui/shell/app_shell.dart';
import 'viewmodels/app_view_model.dart';

class FinnCodeApp extends StatelessWidget {
  const FinnCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppViewModel>(
      builder: (context, viewModel, _) {
        return MaterialApp(
          title: 'Finn Code',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: viewModel.state.themeMode,
          themeAnimationDuration: Durations.medium2,
          themeAnimationCurve: Easing.standard,
          home: const AppShell(),
        );
      },
    );
  }
}
