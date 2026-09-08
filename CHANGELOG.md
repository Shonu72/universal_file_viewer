## 0.1.6

- Fixed known bugs

## 0.1.5

- Dependency Modernization & Cleanup:
  - Removed dead `docx_file_viewer`, `webview_flutter_web`, `webview_flutter`, and `shimmer` dependencies.
  - Replaced `shimmer` dependency with an internal pure-Dart `ShimmerWidget`.
  - Upgraded `pdfrx` to `^2.6.1` and `archive` to `^4.0.9`.
  - Migrated from legacy `excel` package to maintained `excel_community: ^2.3.0`.
  - Migrated Markdown rendering from WebView/HTML to `flutter_markdown_plus: ^1.0.12` for cross-platform native Flutter rendering.
- Codebase Architecture Restructuring:
  - Restructured internal `lib/src/` directory into `core/`, `services/`, `viewers/`, and `widgets/` modules while preserving 100% public API compatibility.

## 0.1.4

- Fixed an issue where remote files without extensions in their URL failed to load. The package now correctly infers the file extension using the `Content-Type` header from the remote server.

## 0.1.3

- Added remote URL support via `UniversalFileViewer.remote(...)`
- Added PowerPoint (`.ppt`, `.pptx`) file-type detection
- Added external-app fallback button for unsupported/non-inline formats
- Improved URL-based file type detection for links with query parameters
- Added safer handling for legacy `.doc` files (external app fallback)

## 0.1.2

- Added padding and background color customisation
- Updated to latest dependency
