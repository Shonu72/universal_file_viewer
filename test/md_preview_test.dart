import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_file_viewer/src/viewers/md_file_preview.dart';

void main() {
  group('MdPreviewScreen', () {
    late File tempFile;

    setUp(() async {
      tempFile = File(
          '${Directory.systemTemp.path}/test_preview_${DateTime.now().millisecondsSinceEpoch}.md');
      await tempFile.writeAsString('''
# Test Heading

This is **bold** text and *italic* text.

- Item 1
- Item 2

```dart
void main() {}
```

| Header 1 | Header 2 |
| --- | --- |
| Cell 1 | Cell 2 |

[Example Link](https://example.com)
''');
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    });

    testWidgets('renders markdown elements successfully',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MdPreviewScreen(file: tempFile),
          ),
        );
        // Wait for file read async operation to complete
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(find.byType(Markdown), findsOneWidget);
      expect(find.text('Test Heading', findRichText: true), findsOneWidget);
      expect(find.text('Item 1', findRichText: true), findsOneWidget);
      expect(find.text('Cell 1', findRichText: true), findsOneWidget);
    });
  });
}
