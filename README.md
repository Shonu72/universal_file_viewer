UniversalFileViewer is a Flutter package to preview common file types from local files and remote URLs.

## Features
- Inline image preview: `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`
- Inline video playback: `.mp4`, `.avi`, `.mov`, `.mkv`
- Inline PDF preview: `.pdf`
- Inline Word preview: `.docx`
- Inline spreadsheet preview: `.xls`, `.xlsx`, `.csv`
- Inline text preview: `.txt`, `.md`
- PowerPoint detection: `.ppt`, `.pptx` (opens externally)
- Remote URL support: `http://` / `https://` files are downloaded to temp storage
- External app fallback for unsupported types

## Installation
Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  universal_file_viewer: latest_version
```

## Usage

Local file:
```dart
UniversalFileViewer(
  file: File('/path/to/sample.pdf'),
)
```

Remote file:
```dart
UniversalFileViewer.remote(
  fileUrl: 'https://example.com/sample.pdf',
)
```

## Notes
- `.doc` (legacy binary Word format) is detected but opened via external app fallback.
- `.ppt/.pptx` currently use external app fallback (inline preview not yet implemented).

## License
This project is licensed under the MIT License. See `LICENSE` for details.
