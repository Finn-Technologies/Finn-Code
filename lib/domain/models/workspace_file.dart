class WorkspaceFile {
  const WorkspaceFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  factory WorkspaceFile.fromMap(Map<String, Object?> map) {
    return WorkspaceFile(
      name: map['name']?.toString() ?? 'untitled',
      path: map['path']?.toString() ?? '',
      isDirectory: map['isDirectory'] == true,
      size: (map['size'] as num?)?.toInt() ?? 0,
      modified: DateTime.fromMillisecondsSinceEpoch(
        (map['modified'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
