import 'dart:async';

import 'package:flutter/services.dart';

class AndroidRuntimeInfo {
  const AndroidRuntimeInfo({
    required this.runtimeId,
    required this.platform,
    required this.workspaceName,
    required this.workspacePath,
    required this.storageBytes,
  });

  final String runtimeId;
  final String platform;
  final String workspaceName;
  final String workspacePath;
  final int storageBytes;

  factory AndroidRuntimeInfo.fromMap(Map<Object?, Object?> map) {
    return AndroidRuntimeInfo(
      runtimeId: map['runtimeId']?.toString() ?? 'android-local',
      platform: map['platform']?.toString() ?? 'Android',
      workspaceName: map['workspaceName']?.toString() ?? 'workspace',
      workspacePath: map['workspacePath']?.toString() ?? '',
      storageBytes: (map['storageBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class AndroidRuntimeBridge {
  AndroidRuntimeBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('tech.finn.finn_code/android_runtime');

  final MethodChannel _channel;

  Future<AndroidRuntimeInfo?> getInfo() async {
    try {
      final result = await _channel
          .invokeMethod<Object?>('runtimeInfo')
          .timeout(const Duration(milliseconds: 750));
      if (result is! Map) return null;
      return AndroidRuntimeInfo.fromMap(result);
    } on Object {
      return null;
    }
  }

  Future<List<Map<String, Object?>>> listFiles({String path = '.'}) async {
    final result = await _channel
        .invokeMethod<List<Object?>>('listFiles', <String, Object?>{
          'path': path,
        })
        .timeout(const Duration(seconds: 5));
    return _maps(result);
  }

  Future<String> readFile(String path) async {
    final result = await _channel
        .invokeMethod<String>('readFile', <String, Object?>{'path': path})
        .timeout(const Duration(seconds: 5));
    return result ?? '';
  }

  Future<void> writeFile(String path, String content) {
    return _channel
        .invokeMethod<void>('writeFile', <String, Object?>{
          'path': path,
          'content': content,
        })
        .timeout(const Duration(seconds: 5));
  }

  Future<void> deleteFile(String path) {
    return _channel
        .invokeMethod<void>('deleteFile', <String, Object?>{'path': path})
        .timeout(const Duration(seconds: 5));
  }

  Future<AndroidCommandResult> runCommand(String command) async {
    final result = await _channel
        .invokeMethod<Object?>('runCommand', <String, Object?>{
          'command': command,
        })
        .timeout(const Duration(seconds: 20));
    if (result is! Map) {
      return const AndroidCommandResult(exitCode: 0, output: '');
    }
    return AndroidCommandResult(
      exitCode: (result['exitCode'] as num?)?.toInt() ?? 0,
      output: result['output']?.toString() ?? '',
    );
  }

  List<Map<String, Object?>> _maps(List<Object?>? values) {
    return <Map<String, Object?>>[
      for (final value in values ?? const <Object?>[])
        if (value is Map)
          value.map((key, item) => MapEntry(key.toString(), item)),
    ];
  }
}

class AndroidCommandResult {
  const AndroidCommandResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;
}
