import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

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
    readMdFile(widget.file);
  }

  /// Reads the MD file at [file] and updates [mdData] with the data.
  ///
  /// If the file is successfully read, [mdData] is set to the contents of the file.
  /// If there is an error reading the file, a debug message is printed.
  Future<void> readMdFile(File file) async {
    try {
      String mdContent = await file.readAsString();
      setState(() {
        mdData = mdContent;
      });
    } catch (e) {
      debugPrint("Error reading MD file: $e");
    }
  }

  @override

  /// Builds a widget that displays the MD file at [widget.file].
  Widget build(BuildContext context) {
    final EdgeInsets padding = widget.padding ?? const EdgeInsets.only(bottom: 68);
    return Scaffold(
      body: mdData.isNotEmpty
          ? Markdown(
              data: mdData,
              selectable: true,
              padding: padding,
            )
          : const Center(
              child: Text("No MD Data Loaded"),
            ),
    );
  }
}

