import 'dart:io';

import 'package:flutter/material.dart';

/// A widget that displays the contents of a TXT file specified by the file path.
class TxtPreviewScreen extends StatefulWidget {
  /// The TXT file to display.
  final File file;

  /// The padding inside the scroll for the document
  final EdgeInsets? padding;

  /// Creates a [TxtPreviewScreen] widget.
  const TxtPreviewScreen(
      {super.key,
      required this.file,
      this.padding = const EdgeInsets.only(bottom: 68)});

  @override
  TxtPreviewScreenState createState() => TxtPreviewScreenState();
}

// ignore: public_member_api_docs
class TxtPreviewScreenState extends State<TxtPreviewScreen> {
  /// The data read from the TXT file.
  late Future<String> txtData;

  @override
  void initState() {
    super.initState();
    txtData = readTxtFile(widget.file);
  }

  @override

  /// Called when the [TxtPreviewScreen] widget is updated. If the [File] being
  /// displayed has changed, this method reads the new file and updates the
  /// [txtData] future with the new data.
  void didUpdateWidget(covariant TxtPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      setState(() {
        txtData = readTxtFile(widget.file);
      });
    }
  }

  /// Reads the TXT file at [file] and updates [txtData] with the data.
  Future<String> readTxtFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      debugPrint("Error reading TXT file: $e");
      rethrow;
    }
  }

  @override

  /// Builds a widget that displays the TXT file at [widget.file].
  ///
  /// The widget displays the TXT file in a table. The table is horizontally
  /// scrollable, and the cells are vertically scrollable. The table is also
  /// horizontally scrollable, so that the user can scroll through the entire
  /// file even if it is wider than the screen.
  ///
  /// If the TXT file fails to load, a [Text] widget with the error message is
  /// displayed instead.

  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: txtData,
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          return Scaffold(
              body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Padding(
                    padding:
                        widget.padding ?? const EdgeInsets.only(bottom: 68),
                    child: Text(snapshot.hasData
                        ? snapshot.requireData
                        : "No TXT Data Loaded"),
                  )));
        });
  }
}
