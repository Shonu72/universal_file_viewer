import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:universal_file_viewer/universal_file_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'File Viewer Test', home: FileViewerScreen());
  }
}

class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({super.key});

  @override
  FileViewerScreenState createState() => FileViewerScreenState();
}

class FileViewerScreenState extends State<FileViewerScreen> {
  String? _filePath;
  final TextEditingController _urlController = TextEditingController(
    text:
        'https://raw.githubusercontent.com/flutter/website/main/src/content/assets/images/docs/catalog-widget-placeholder.png',
  );

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _filePath = result.files.single.path;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Universal File Viewer Example')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickFile,
            child: const Text('Pick a File'),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Remote file URL',
                hintText: 'https://example.com/sample.pdf',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => setState(() => _filePath = null),
            child: const Text('Load URL'),
          ),
          const SizedBox(height: 20),
          Expanded(
            key: ValueKey('${_filePath}_${_urlController.text}'),
            child:
                _filePath != null
                    ? UniversalFileViewer(file: File(_filePath!))
                    : UniversalFileViewer.remote(fileUrl: _urlController.text),
          ),
        ],
      ),
    );
  }
}
