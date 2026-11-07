// ignore_for_file: always_specify_types, public_member_api_docs, prefer_initializing_formals

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:universal_file_viewer/src/core/file_type_detector.dart';
import 'package:universal_file_viewer/src/services/remote_file_service.dart';
import 'package:universal_file_viewer/src/viewers/excel_csv_file_preview.dart';
import 'package:universal_file_viewer/src/viewers/md_file_preview.dart';
import 'package:universal_file_viewer/src/viewers/txt_file_preview.dart';
import 'package:universal_file_viewer/src/viewers/video_player_preview.dart';
import 'package:universal_file_viewer/src/viewers/word_file_preview.dart';

class UniversalFileViewer extends StatefulWidget {
  /// The file that gets opened in the [UniversalFileViewer].
  /// Should be an instance of the [File] class.
  final File? file;

  /// The url of the remote file to be opened in the [UniversalFileViewer].
  final String? fileUrl;

  /// Add inner padding added within the widget boundary.
  final EdgeInsets? innerPadding;

  /// The background color of the widget.
  final Color backgroundColor;

  /// The background color of the unsupported file window.
  final Color unsupportedBackgroundColor;

  /// The foreground Color of the error text.
  final Color errorTextforegroundColor;

  /// The styling options for the "Open in external app button".
  final ButtonStyle? openExternalAppButtonStyle;

  const UniversalFileViewer({
    super.key,
    required this.file,
    this.innerPadding,
    this.backgroundColor = Colors.white,
    this.unsupportedBackgroundColor = Colors.white,
    this.errorTextforegroundColor = Colors.black,
    this.openExternalAppButtonStyle,
  }) : fileUrl = null;

  const UniversalFileViewer.remote({
    super.key,
    required this.fileUrl,
    this.innerPadding,
    this.backgroundColor = Colors.white,
    this.unsupportedBackgroundColor = Colors.white,
    this.errorTextforegroundColor = Colors.black,
    this.openExternalAppButtonStyle,
  }) : file = null;

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
    if (widget.file != null && widget.fileUrl != null) {
      throw FlutterError(
        "Either `file` or `filePath` should be provided, not both.",
      );
    }
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
      padding: widget.innerPadding,
      color: widget.unsupportedBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (onOpenExternal != null) ...<Widget>[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: widget.openExternalAppButtonStyle,
                onPressed: _isOpeningExternal ? null : onOpenExternal,
                icon: _isOpeningExternal
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _isOpeningExternal ? 'Opening...' : 'Open in external app',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildForType(File file, FileType type) {
    switch (type) {
      case FileType.image:
        return Container(
          padding: widget.innerPadding,
          color: widget.backgroundColor,
          child: Center(child: Image.file(file)),
        );
      case FileType.video:
        return Container(
          padding: widget.innerPadding,
          color: widget.backgroundColor,
          child: VideoPlayerWidget(file: file),
        );
      case FileType.pdf:
        return PdfViewer.file(
          file.path,
          params: const PdfViewerParams(margin: 32),
        );
      case FileType.word:
        // DOC binary files are not handled by the DOCX parser.
        if (p.extension(file.path).toLowerCase() == '.doc') {
          return _unsupportedView(
            'Legacy .doc preview is not supported yet.',
            onOpenExternal: () => _openInExternalApp(file: file),
          );
        }
        return DocxToFlutter(
          file: file,
          padding: widget.innerPadding,
          backgroundColor: widget.backgroundColor,
          errorTextforegroundColor: widget.errorTextforegroundColor,
        );
      case FileType.excel:
      case FileType.csv:
        return ExcelCSVPreviewScreen(
          file: file,
          padding: widget.innerPadding,
          backgroundColor: widget.backgroundColor,
        );
      case FileType.text:
        return TxtPreviewScreen(file: file, padding: widget.innerPadding);
      case FileType.md:
        return MdPreviewScreen(file: file, padding: widget.innerPadding);
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

    FileType? type = detectFileType(sourcePath);

    if (type == null && widget.file != null) {
      return _unsupportedView(
        'File type not supported.',
        onOpenExternal: () => _openInExternalApp(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: constraints,
          child: Container(
            color: widget.backgroundColor,
            child: FutureBuilder<File>(
              future: _resolvedFile,
              builder: (BuildContext context, AsyncSnapshot<File> snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                if (snapshot.hasError) {
                  return _unsupportedView(
                    'Unable to load file:\n${snapshot.error}',
                  );
                }
                if (!snapshot.hasData) {
                  return _unsupportedView('Unable to load file.');
                }

                final File file = snapshot.requireData;
                type ??= detectFileType(file.path);

                if (type == null) {
                  return _unsupportedView(
                    'File type not supported.',
                    onOpenExternal: () => _openInExternalApp(file: file),
                  );
                }

                return _buildForType(file, type!);
              },
            ),
          ),
        );
      },
    );
  }
}
