import 'package:flutter_test/flutter_test.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';

void main() {
  group('detectFileType', () {
    test('detects ppt/pptx types', () {
      expect(detectFileType('slides.ppt'), FileType.ppt);
      expect(detectFileType('slides.pptx'), FileType.ppt);
    });

    test('detects file type from URL path with query params', () {
      expect(detectFileType('https://example.com/a/doc.pdf?token=abc'),
          FileType.pdf);
      expect(detectFileType('https://example.com/video.MP4?download=true'),
          FileType.video);
    });

    test('returns null for unsupported extensions', () {
      expect(detectFileType('archive.zip'), isNull);
      expect(supportedFile('archive.zip'), isFalse);
    });
  });
}
