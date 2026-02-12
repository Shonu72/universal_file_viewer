import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:webview_flutter/webview_flutter.dart';

/// A widget that displays the contents of a MD file specified by the file path.
class MdPreviewScreen extends StatefulWidget {
  /// The MD file to display.
  final File file;

  /// The padding inside the scroll for the document
  final EdgeInsets? padding;

  /// Creates a [MdPreviewScreen] widget.
  const MdPreviewScreen(
      {super.key,
      required this.file,
      this.padding = const EdgeInsets.only(bottom: 68)});

  @override
  MdPreviewScreenState createState() => MdPreviewScreenState();
}

// ignore: public_member_api_docs
class MdPreviewScreenState extends State<MdPreviewScreen> {
  /// The data read from the MD file.
  String mdData = '';

  /// The data in html format from the md file.
  String rawHtml = '';
  late final WebViewController _controller = WebViewController();

  @override
  void didUpdateWidget(covariant MdPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      readMdFile(widget.file);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    readMdFile(widget.file);
  }

  /// Reads the MD file at [file] and updates [mdData] and [rawHtml] with the data.
  ///
  /// If the file is successfully read, [mdData] is set to the contents of the file
  /// and [rawHtml] is set to the equivalent HTML. The [WebView] is then loaded with
  /// this HTML. If there is an error reading the file, a debug message is printed.
  Future<void> readMdFile(File file) async {
    try {
      String mdContent = await file.readAsString();
      setState(() {
        mdData = mdContent;
        rawHtml = markdown.markdownToHtml(mdData);
        _controller.loadRequest(Uri.dataFromString(rawHtml,
            mimeType: 'text/html', encoding: Encoding.getByName('utf-8')));
      });
    } catch (e) {
      debugPrint("Error reading MD file: $e");
    }
  }

  @override

  /// Builds a widget that displays the MD file at [widget.file].
  ///
  /// The widget displays the MD file in a table. The table is horizontally
  /// scrollable, and the cells are vertically scrollable. The table is also
  /// horizontally scrollable, so that the user can scroll through the entire
  /// file even if it is wider than the screen.
  ///
  /// If the MD file fails to load, a [Markdown] widget with the error message is
  /// displayed instead.

  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: widget.padding ?? const EdgeInsets.only(bottom: 68),
      child: Center(
          child: rawHtml.isNotEmpty
              ? WebViewWidget(controller: _controller)
              : const Text("No MD Data Loaded")),
    ));
  }
}
