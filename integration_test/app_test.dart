import 'dart:async';

import 'package:finn_code/app.dart';
import 'package:finn_code/data/repositories/agent_repository.dart';
import 'package:finn_code/data/storage/app_settings_store.dart';
import 'package:finn_code/domain/models/agent_session.dart';
import 'package:finn_code/domain/models/agent_stream_update.dart';
import 'package:finn_code/domain/models/model_info.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/domain/services/agent_gateway.dart';
import 'package:finn_code/viewmodels/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BlockingGateway implements AgentGateway {
  final List<StreamController<AgentStreamUpdate>> controllers =
      <StreamController<AgentStreamUpdate>>[];
  int interruptCount = 0;

  @override
  Stream<AgentStreamUpdate> streamReply({
    required AgentSession session,
    required String prompt,
    required ProviderConfig provider,
  }) {
    final controller = StreamController<AgentStreamUpdate>();
    controllers.add(controller);
    return controller.stream;
  }

  @override
  Future<List<ModelInfo>> listModels(ProviderConfig provider) async =>
      const <ModelInfo>[];

  @override
  Future<void> testConnection(ProviderConfig provider) async {}

  @override
  Future<void> respondToApproval({
    required ProviderConfig provider,
    required ApprovalRequest request,
    required bool approve,
    required bool allowForSession,
  }) async {}

  @override
  Future<void> interrupt({
    required AgentSession session,
    required ProviderConfig provider,
  }) async {
    interruptCount++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates a task and completes a demo turn', (tester) async {
    await SharedPreferencesAsync().clear();
    await const FlutterSecureStorage().deleteAll();
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(),
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finn Code'), findsWidgets);
    await tester.tap(find.byKey(const Key('new-task-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    final prompt = find.byKey(const Key('agent-prompt-field'));
    expect(prompt, findsOneWidget);
    await tester.enterText(prompt, 'Test the free Android runtime');
    await tester.tap(find.byKey(const Key('send-prompt-button')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Test the free Android runtime'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));

    expect(find.textContaining('Finn Demo'), findsWidgets);
    viewModel.dispose();
  });

  testWidgets('keeps Workspace files and command modes reachable on Android', (
    tester,
  ) async {
    await SharedPreferencesAsync().clear();
    await const FlutterSecureStorage().deleteAll();
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(),
      probeAndroidRuntime: true,
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workspace'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-mode-switch')), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Command'), findsOneWidget);

    await tester.tap(find.text('Command'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-command-panel')), findsOneWidget);
    expect(find.byKey(const Key('workspace-command-field')), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-mode-switch')), findsOneWidget);
    expect(find.byKey(const Key('workspace-command-panel')), findsNothing);
    await tester.tap(find.text('New file'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-save-file-button')), findsOneWidget);
    viewModel.dispose();
  });

  testWidgets('keeps streams scoped while switching tasks and cancelling', (
    tester,
  ) async {
    await SharedPreferencesAsync().clear();
    await const FlutterSecureStorage().deleteAll();
    final gateway = _BlockingGateway();
    final viewModel = AppViewModel(
      repository: AgentRepository(
        gatewayFactories: <ProviderProtocol, AgentGatewayFactory>{
          ProviderProtocol.demo: () => gateway,
        },
      ),
      settingsStore: AppSettingsStore(),
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-task-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    final firstId = viewModel.state.selectedSessionId!;
    await tester.enterText(
      find.byKey(const Key('agent-prompt-field')),
      'First task stays attached',
    );
    await tester.tap(find.byKey(const Key('send-prompt-button')));
    await tester.pump();

    await tester.tap(find.byTooltip('Back to tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-task-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    final secondId = viewModel.state.selectedSessionId!;
    expect(find.byKey(const Key('send-prompt-button')), findsOneWidget);

    gateway.controllers.first.add(const AgentTextDelta('first task update'));
    await tester.pump();
    expect(find.text('first task update'), findsNothing);

    await tester.tap(find.byTooltip('Back to tasks'));
    await tester.pumpAndSettle();
    final firstTile = find.byKey(ValueKey<String>('session-tile-$firstId'));
    expect(firstTile, findsOneWidget);
    await tester.tap(firstTile);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('first task update'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-run-button')));
    await tester.pumpAndSettle();
    expect(gateway.interruptCount, 1);
    expect(find.byKey(const Key('send-prompt-button')), findsOneWidget);
    expect(viewModel.state.sendingSessionIds, isEmpty);
    expect(
      viewModel.state.sessions.any((session) => session.id == secondId),
      isTrue,
    );
    viewModel.dispose();
  });

  testWidgets('uses the anonymous Space Bunny route on Android', (
    tester,
  ) async {
    await SharedPreferencesAsync().clear();
    await const FlutterSecureStorage().deleteAll();
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(),
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try Space Bunny'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-task-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('agent-prompt-field')),
      'Reply exactly SPACE_BUNNY_ANDROID_OK',
    );
    await tester.tap(find.byKey(const Key('send-prompt-button')));
    for (var attempt = 0; attempt < 30; attempt++) {
      await tester.pump(const Duration(seconds: 1));
      if (find.text('SPACE_BUNNY_ANDROID_OK').evaluate().isNotEmpty) break;
    }

    expect(find.text('SPACE_BUNNY_ANDROID_OK'), findsOneWidget);
    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.textContaining('Input'), findsOneWidget);
    expect(viewModel.state.selectedSession?.providerId, 'space-bunny-free');
    expect(viewModel.state.sendingSessionIds, isEmpty);
    viewModel.dispose();
  });

  testWidgets('saves and removes a custom provider on Android', (tester) async {
    await SharedPreferencesAsync().clear();
    await const FlutterSecureStorage().deleteAll();
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(),
    );
    await viewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add provider'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Harness Mock');
    await tester.enterText(fields.at(1), 'http://10.0.2.2:18080/v1');
    await tester.enterText(fields.at(2), 'mock-model');
    await tester.enterText(fields.at(3), 'Device lifecycle smoke');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final saveButton = find.byKey(const Key('save-provider-button'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Save provider'), findsNothing);
    expect(
      viewModel.state.providers.any(
        (provider) => provider.name == 'Harness Mock',
      ),
      isTrue,
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final removeButton = find.byTooltip('Delete Harness Mock');
    await tester.scrollUntilVisible(
      removeButton,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('settings-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(find.text('Harness Mock'), findsNothing);
    expect(
      viewModel.state.providers.any(
        (provider) => provider.name == 'Harness Mock',
      ),
      isFalse,
    );
    viewModel.dispose();
  });
}
