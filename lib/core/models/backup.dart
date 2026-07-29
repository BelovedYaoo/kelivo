enum RestoreMode { overwrite, merge }

final class LocalBackupOptions {
  const LocalBackupOptions({
    this.includeChats = true,
    this.includeFiles = true,
  });

  final bool includeChats;
  final bool includeFiles;

  LocalBackupOptions copyWith({bool? includeChats, bool? includeFiles}) {
    return LocalBackupOptions(
      includeChats: includeChats ?? this.includeChats,
      includeFiles: includeFiles ?? this.includeFiles,
    );
  }
}
