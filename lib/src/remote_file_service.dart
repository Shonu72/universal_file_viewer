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
    final String ext = p.extension(uri.path);
    final String fileName = 'ufv_${url.hashCode}${ext.isEmpty ? '' : ext}';
    final File localFile = File(p.join(tempDir.path, fileName));

    await localFile.writeAsBytes(response.bodyBytes, flush: true);
    return localFile;
  }
}
