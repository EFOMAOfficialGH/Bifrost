import 'package:bifrost/core/platform/windows_file_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('windowsContainingFolder', () {
    test('returns the actual containing folder for paths with spaces', () {
      expect(
        windowsContainingFolder(
          r'C:\Users\Test User\Documents\Bifrost Saves\Image.png',
        ),
        r'C:\Users\Test User\Documents\Bifrost Saves',
      );
    });

    test('accepts forward slashes in saved history paths', () {
      expect(
        windowsContainingFolder('D:/Bifrost/Received/Image.png'),
        r'D:\Bifrost\Received',
      );
    });

    test('preserves a drive root and UNC share path', () {
      expect(windowsContainingFolder(r'C:\Image.png'), r'C:\');
      expect(
        windowsContainingFolder(r'\\server\share\Image.png'),
        r'\\server\share',
      );
    });

    test('returns the current directory for a bare filename', () {
      expect(windowsContainingFolder('Image.png'), '.');
    });
  });
}
