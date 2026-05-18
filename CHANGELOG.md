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
