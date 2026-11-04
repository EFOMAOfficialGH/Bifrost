/// Returns the containing folder for a Windows file path.
///
/// Accepts both Windows separators and forward slashes so persisted paths from
/// older app versions are handled consistently.
String windowsContainingFolder(String filePath) {
  final normalized = filePath.replaceAll('/', '\\');
  final separator = normalized.lastIndexOf('\\');
  if (separator < 0) return '.';
  if (separator == 0) return '\\';
  if (separator == 2 && normalized.length >= 3 && normalized[1] == ':') {
    return normalized.substring(0, 3);
  }
  return normalized.substring(0, separator);
}
