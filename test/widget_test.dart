import 'package:finn_code/app.dart';
import 'package:finn_code/data/repositories/agent_repository.dart';
import 'package:finn_code/data/storage/app_settings_store.dart';
import 'package:finn_code/domain/models/provider_config.dart';
import 'package:finn_code/viewmodels/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

void main() {
  testWidgets('renders tasks and sends a demo prompt', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(secrets: _MemorySecretStore()),
    );
    await viewModel.initialize();

    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finn Code'), findsOneWidget);
    expect(find.text('Welcome to Finn Code'), findsWidgets);
    expect(find.byKey(const Key('agent-prompt-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('agent-prompt-field')),
      'Test a free Android model',
    );
    await tester.tap(find.byKey(const Key('send-prompt-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Test a free Android model'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    expect(find.textContaining('Finn Demo'), findsWidgets);
  });

  testWidgets('keeps the task entry flow usable on a compact phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(secrets: _MemorySecretStore()),
    );
    await viewModel.initialize();

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppViewModel>.value(
        value: viewModel,
        child: const FinnCodeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('new-task-button')), findsOneWidget);
    expect(find.byKey(const Key('new-task-wide-button')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-task-button')));
    await tester.pumpAndSettle();
    expect(find.text('Start a coding task'), findsOneWidget);

    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();
    expect(find.text('Start with a clear request'), findsOneWidget);
    expect(find.byKey(const Key('agent-prompt-field')), findsOneWidget);
  });

  testWidgets('saves a custom provider and restores it after relaunch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = null);
    final preferences = SharedPreferencesAsync();
    final viewModel = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(
        preferences: preferences,
        secrets: _MemorySecretStore(),
      ),
    );
    await viewModel.initialize();
    addTearDown(viewModel.dispose);

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
    await tester.enterText(fields.at(0), 'Smoke provider');
    await tester.enterText(fields.at(1), 'https://example.com/v1');
    await tester.enterText(fields.at(2), 'smoke-model');
    await tester.enterText(fields.at(3), 'Packaged provider smoke test');
    await tester.ensureVisible(find.text('Save provider'));
    await tester.tap(find.text('Save provider'));
    await tester.pumpAndSettle();

    expect(
      viewModel.state.providers.any(
        (provider) =>
            provider.name == 'Smoke provider' &&
            provider.protocol == ProviderProtocol.openAICompatible,
      ),
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.text('Smoke provider'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Smoke provider'), findsOneWidget);

    final restored = AppViewModel(
      repository: AgentRepository(),
      settingsStore: AppSettingsStore(
        preferences: preferences,
        secrets: _MemorySecretStore(),
      ),
    );
    await restored.initialize();
    expect(
      restored.state.providers.any(
        (provider) =>
            provider.name == 'Smoke provider' &&
            provider.model == 'smoke-model',
      ),
      isTrue,
    );
    restored.dispose();
  });
}
