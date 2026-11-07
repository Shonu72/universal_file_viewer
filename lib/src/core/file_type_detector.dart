// ignore_for_file: public_member_api_docs
import 'dart:io';

import 'package:path/path.dart' as p;

enum FileType { image, video, pdf, word, excel, csv, text, md, ppt }

/// Detect the file type of the given file path.
///
/// The function supports the following file types:
/// - image: .jpg, .jpeg, .png, .gif, .bmp, .tiff
/// - video: .mp4, .avi, .mov, .mkv
/// - pdf: .pdf
/// - word: .doc, .docx
/// - excel: .xls, .xlsx
/// - csv: .csv
/// - ppt: .ppt, .pptx
/// - text: .txt, .md
FileType? detectFileType(String path) {
  // For remote URLs like https://host/file.pdf?token=..., inspect uri.path.
  final Uri? uri = Uri.tryParse(path);
  final String normalizedPath =
      (uri != null && uri.hasScheme && uri.path.isNotEmpty) ? uri.path : path;
  final String extension = p.extension(normalizedPath).toLowerCase();

  if (<String>[
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp',
    '.wbmp',
    '.ico',
    '.tif',
    '.tiff',
    '.heic',
    '.heif',
    '.avif',
  ].contains(extension)) {
    return FileType.image;
  } else if (<String>['.mp4', '.avi', '.mov', '.mkv'].contains(extension)) {
    return FileType.video;
  } else if (extension == '.pdf') {
    return FileType.pdf;
  } else if (<String>['.doc', '.docx'].contains(extension)) {
    return FileType.word;
  } else if (<String>['.xls', '.xlsx'].contains(extension)) {
    return FileType.excel;
  } else if (extension == '.csv') {
    return FileType.csv;
  } else if (<String>['.ppt', '.pptx'].contains(extension)) {
    return FileType.ppt;
  } else if (isTextFile(normalizedPath)) {
    return FileType.text;
  } else if (<String>['.md'].contains(extension)) {
    return FileType.md;
  } else {
    return null;
  }
}

bool supportedFile(String path) => detectFileType(path) != null;

bool isTextFile(String path, {int sampleSize = 8192}) {
  final raf = File(path).openSync();
  try {
    final bytes = raf.readSync(sampleSize);
    if (bytes.isEmpty) return true;

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return true;
    }
    if (bytes.length >= 2 &&
        ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
            (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
      return true;
    }

    int suspicious = 0;
    for (final b in bytes) {
      if (b == 0) return false;
      if (b < 32 &&
          b != 9 &&
          b != 10 &&
          b != 11 &&
          b != 12 &&
          b != 13 &&
          b != 27) {
        suspicious++;
      }
    }

    return suspicious / bytes.length < 0.10;
  } finally {
    raf.close();
  }
}
