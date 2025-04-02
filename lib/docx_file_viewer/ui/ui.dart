import 'dart:io';

import '../docx_file_viewer.dart';

class DocxViewer extends StatefulWidget {
  final File file;

  const DocxViewer({super.key, required this.file});

  @override
  State<DocxViewer> createState() => _DocxViewerState();
}

class _DocxViewerState extends State<DocxViewer> {
  late final Future<List<Widget>> loadDocumet;
  @override
  void initState() {
    super.initState();
    loadDocumet = DocxExtractor().renderLayout(widget.file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: loadDocumet,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return InteractiveViewer(
                child: ListView(children: snapshot.requireData));
          } else if (snapshot.hasError) {
            return const Center(
              child: Text("Error rendering layout"),
            );
          } else {
            return const CircularProgressIndicator.adaptive();
          }
        },
      ),
    );
  }
}
