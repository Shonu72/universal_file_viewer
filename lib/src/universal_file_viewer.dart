// ignore_for_file: always_specify_types, public_member_api_docs, prefer_initializing_formals

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:universal_file_viewer/src/excel_csv_file_preview.dart';
import 'package:universal_file_viewer/src/file_type_detector.dart';
import 'package:universal_file_viewer/src/md_file_preview.dart';
import 'package:universal_file_viewer/src/remote_file_service.dart';
import 'package:universal_file_viewer/src/txt_file_preview.dart';
import 'package:universal_file_viewer/src/video_player_preview.dart';
import 'package:universal_file_viewer/src/word_file_preview.dart';

class UniversalFileViewer extends StatefulWidget {
  final File? file;
  final String? fileUrl;
  final EdgeInsets? padding;
  final Color backgroundColor;

  const UniversalFileViewer(
      {super.key,
      required File file,
      this.padding,
      this.backgroundColor = Colors.white})
      : file = file,
        fileUrl = null;

  const UniversalFileViewer.remote(
      {super.key,
      required String fileUrl,
      this.padding,
      this.backgroundColor = Colors.white})
      : file = null,
        fileUrl = fileUrl;

  @override
  State<UniversalFileViewer> createState() => _UniversalFileViewerState();
}

class _UniversalFileViewerState extends State<UniversalFileViewer> {
  late Future<File> _resolvedFile;
  bool _isOpeningExternal = false;

  String? get _sourcePath => widget.file?.path ?? widget.fileUrl;

  @override
  void initState() {
    super.initState();
    _resolvedFile = _resolveFile();
  }

  @override
  void didUpdateWidget(covariant UniversalFileViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final String? oldSource = oldWidget.file?.path ?? oldWidget.fileUrl;
    final String? newSource = _sourcePath;
    if (oldSource != newSource) {
      _resolvedFile = _resolveFile();
    }
  }

  Future<File> _resolveFile() async {
    if (widget.file != null) {
      return widget.file!;
    }

    final String? url = widget.fileUrl;
    if (url == null || url.isEmpty) {
      throw ArgumentError('No file or URL was provided.');
    }

    return RemoteFileService.resolveToLocalFile(url);
  }

  Future<void> _openInExternalApp({File? file}) async {
    setState(() => _isOpeningExternal = true);
    try {
      final File target = file ?? await _resolvedFile;
      final OpenResult result = await OpenFile.open(target.path);

      if (!mounted) return;
      if (result.type != ResultType.done) {
        final String message = result.message.isNotEmpty
            ? result.message
            : 'Unable to open file in external app.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to open file: $e')));
    } finally {
      if (mounted) {
        setState(() => _isOpeningExternal = false);
      }
    }
  }

  Widget _unsupportedView(String message, {VoidCallback? onOpenExternal}) {
    return Container(
      padding: widget.padding,
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (onOpenExternal != null) ...<Widget>[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isOpeningExternal ? null : onOpenExternal,
                icon: _isOpeningExternal
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.open_in_new),
                label: Text(
                    _isOpeningExternal ? 'Opening...' : 'Open in external app'),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildForType(File file, FileType type) {
    switch (type) {
      case FileType.image:
        return Container(
            padding: widget.padding,
            color: widget.backgroundColor,
            child: Center(child: Image.file(file)));
      case FileType.video:
        return Container(
            padding: widget.padding,
            color: widget.backgroundColor,
            child: VideoPlayerWidget(file: file));
      case FileType.pdf:
        return PdfViewer.file(file.path,
            params: const PdfViewerParams(margin: 32));
      case FileType.word:
        // DOC binary files are not handled by the DOCX parser.
        if (p.extension(file.path).toLowerCase() == '.doc') {
          return _unsupportedView(
            'Legacy .doc preview is not supported yet.',
            onOpenExternal: () => _openInExternalApp(file: file),
          );
        }
        return DocxToFlutter(file: file, padding: widget.padding);
      case FileType.excel:
      case FileType.csv:
        return ExcelCSVPreviewScreen(file: file, padding: widget.padding);
      case FileType.text:
        return TxtPreviewScreen(file: file, padding: widget.padding);
      case FileType.md:
        return MdPreviewScreen(file: file, padding: widget.padding);
      case FileType.ppt:
        return _unsupportedView(
          'PowerPoint inline preview is not supported yet.',
          onOpenExternal: () => _openInExternalApp(file: file),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? sourcePath = _sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      return _unsupportedView('No file selected.');
    }

    final FileType? type = detectFileType(sourcePath);
    if (type == null) {
      return _unsupportedView(
        'File type not supported.',
        onOpenExternal: () => _openInExternalApp(),
      );
    }

    return FutureBuilder<File>(
      future: _resolvedFile,
      builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _unsupportedView('Unable to load file.');
        }

        return _buildForType(snapshot.requireData, type);
      },
    );
  }
}
