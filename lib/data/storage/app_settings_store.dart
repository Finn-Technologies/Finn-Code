import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/agent_session.dart';
import '../../domain/models/provider_config.dart';
import 'session_codec.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  SecureSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AppSettingsStore {
  AppSettingsStore({SharedPreferencesAsync? preferences, SecretStore? secrets})
    : _preferences = preferences ?? SharedPreferencesAsync(),
      _secrets = secrets ?? SecureSecretStore();

  final SharedPreferencesAsync _preferences;
  final SecretStore _secrets;

  static const _sessionsKey = 'sessions';
  static const _selectedSessionKey = 'selectedSessionId';

  Future<String?> selectedProviderId() =>
      _preferences.getString('selectedProviderId');

  Future<void> setSelectedProviderId(String value) =>
      _preferences.setString('selectedProviderId', value);

  Future<String> themeMode() async =>
      await _preferences.getString('themeMode') ?? 'system';

  Future<void> setThemeMode(String value) =>
      _preferences.setString('themeMode', value);

  Future<List<AgentSession>> sessions() async {
    final value = await _preferences.getString(_sessionsKey);
    if (value == null || value.isEmpty) return const <AgentSession>[];
    return SessionCodec.decode(value);
  }

  Future<void> setSessions(List<AgentSession> sessions) {
    return _preferences.setString(_sessionsKey, SessionCodec.encode(sessions));
  }

  Future<String?> selectedSessionId() =>
      _preferences.getString(_selectedSessionKey);

  Future<void> setSelectedSessionId(String value) =>
      _preferences.setString(_selectedSessionKey, value);

  Future<List<ProviderConfig>> customProviders() async {
    final value = await _preferences.getString('customProviders');
    if (value == null || value.isEmpty) return const <ProviderConfig>[];
    try {
      final decoded = jsonDecode(value) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ProviderConfig.fromPersistedMap)
          .toList(growable: false);
    } on FormatException {
      return const <ProviderConfig>[];
    }
  }

  Future<void> setCustomProviders(List<ProviderConfig> providers) {
    return _preferences.setString(
      'customProviders',
      jsonEncode(
        providers.map((provider) => provider.toPersistedMap()).toList(),
      ),
    );
  }

  Future<Map<String, Map<String, dynamic>>> providerOverrides() async {
    final value = await _preferences.getString('providerOverrides');
    if (value == null || value.isEmpty) {
      return const <String, Map<String, dynamic>>{};
    }
    try {
      final decoded = jsonDecode(value) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          (value as Map).map((itemKey, item) => MapEntry('$itemKey', item)),
        ),
      );
    } on FormatException {
      return const <String, Map<String, dynamic>>{};
    }
  }

  Future<void> setProviderOverrides(Map<String, ProviderConfig> providers) {
    return _preferences.setString(
      'providerOverrides',
      jsonEncode(
        providers.map(
          (key, provider) => MapEntry(key, provider.toPersistedMap()),
        ),
      ),
    );
  }

  Future<String?> apiKey(String providerId) =>
      _secrets.read('finn-code:$providerId:api-key');

  Future<void> setApiKey(String providerId, String value) {
    if (value.isEmpty) return _secrets.delete('finn-code:$providerId:api-key');
    return _secrets.write('finn-code:$providerId:api-key', value);
  }
}
