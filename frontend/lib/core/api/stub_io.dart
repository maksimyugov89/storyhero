/// Stub для dart:io на Web платформе.
/// Эти классы не используются на Web, но нужны для компиляции.

class File {
  final String path;
  File(this.path);
  
  bool existsSync() => false;
  int lengthSync() => 0;
}

