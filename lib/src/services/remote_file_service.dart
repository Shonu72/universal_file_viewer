import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downloads remote files and stores them in a local temp cache.
class RemoteFileService {
  RemoteFileService._();

  static final Map<String, Future<File>> _fileCache = <String, Future<File>>{};

  /// Resolves an HTTP/HTTPS URL into a local [File] in the temp directory.
  static Future<File> resolveToLocalFile(String url) {
    return _fileCache.putIfAbsent(url, () => _download(url));
  }

  static Future<File> _download(String url) async {
    if (kIsWeb) {
      throw UnsupportedError('Remote file downloading is not supported on web');
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError('Invalid remote URL: $url');
    }

    final http.Response response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
          'Failed to download remote file (${response.statusCode})');
    }

    final Directory tempDir = await getTemporaryDirectory();
    String ext = p.extension(uri.path);
    
    // Fallback: Try to get extension from headers if URL lacks one
    if (ext.isEmpty || !ext.contains('.')) {
      final String? contentDisposition = response.headers['content-disposition'];
      if (contentDisposition != null) {
        final RegExp filenameRegex = RegExp(r'filename[^;=\n]*=(([\x22]).*?\2|[^;\n]*)');
        final Match? match = filenameRegex.firstMatch(contentDisposition);
        if (match != null) {
          final String filename = match.group(1)?.replaceAll('"', '') ?? '';
          ext = p.extension(filename);
        }
      }
      
      if (ext.isEmpty || !ext.contains('.')) {
        final String? contentType = response.headers['content-type'];
        final String? mimeExt = _extensionFromMime(contentType);
        if (mimeExt != null) {
          ext = mimeExt;
        }
      }
    }

    final String fileName = 'ufv_${url.hashCode}${ext.isEmpty ? '' : ext}';
    final File localFile = File(p.join(tempDir.path, fileName));

    await localFile.writeAsBytes(response.bodyBytes, flush: true);
    return localFile;
  }

  static String? _extensionFromMime(String? mimeType) {
    if (mimeType == null) return null;
    final String mime = mimeType.split(';').first.trim().toLowerCase();
    switch (mime) {
      case 'image/jpeg':
      case 'image/jpg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/bmp':
        return '.bmp';
      case 'image/tiff':
        return '.tiff';
      case 'video/mp4':
        return '.mp4';
      case 'video/avi':
      case 'video/x-msvideo':
        return '.avi';
      case 'video/quicktime':
        return '.mov';
      case 'video/x-matroska':
        return '.mkv';
      case 'application/pdf':
        return '.pdf';
      case 'application/msword':
        return '.doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return '.docx';
      case 'application/vnd.ms-excel':
        return '.xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return '.xlsx';
      case 'text/csv':
        return '.csv';
      case 'application/vnd.ms-powerpoint':
        return '.ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return '.pptx';
      case 'text/plain':
        return '.txt';
      case 'text/markdown':
        return '.md';
      default:
        return null;
    }
  }
}
