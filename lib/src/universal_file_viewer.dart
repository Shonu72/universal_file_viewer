// ignore_for_file: always_specify_types, public_member_api_docs

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:universal_file_viewer/src/excel_csv_file_preview.dart';
import 'package:universal_file_viewer/src/txt_file_preview.dart';
import 'package:universal_file_viewer/src/word_file_preview.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';

import 'md_file_preview.dart';

class UniversalFileViewer extends StatelessWidget {
  final File file;
  final EdgeInsets? padding;
  final Color backgroundColor;

  const UniversalFileViewer(
      {super.key,
        required this.file,
        this.padding,
        this.backgroundColor = Colors.white});

  /// Builds a widget that displays the file at [file].
  ///
  /// The widget depends on the type of the file. If the file is an image, video,
  /// or PDF, a widget is returned that displays the file directly. Otherwise, a
  /// button is returned that opens the file in an external application when
  /// pressed.
  @override
  Widget build(BuildContext context) {
    if (supportedFile(file.path)) {
      final fileType = detectFileType(file.path)!;
      switch (fileType) {
        case FileType.image:
          return Container(
              padding: padding,
              color: backgroundColor,
              child: Center(child: Image.file(file)));
        case FileType.video:
          return Container(
              padding: padding,
              color: backgroundColor,
              child: VideoPlayerWidget(file: file));
        case FileType.pdf:
          return PdfViewer.file(file.path,
              params: const PdfViewerParams(margin: 0));
        case FileType.word:
          return DocxToFlutter(file: file, padding: padding);
        case FileType.excel:
        case FileType.csv:
          return ExcelCSVPreviewScreen(file: file, padding: padding);
        case FileType.text:
          return TxtPreviewScreen(file: file, padding: padding);
        case FileType.md:
          return MdPreviewScreen(file: file, padding: padding);
      }
    } else {
      return const Center(
        child: Text('File type not supported'),
      );
    }
  }
}