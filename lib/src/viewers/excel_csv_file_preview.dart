import 'dart:io';

import 'package:excel_community/excel_community.dart' as exc;
import 'package:flutter/foundation.dart'; // Import compute()
import 'package:flutter/material.dart';
import 'package:universal_file_viewer/src/core/file_type_detector.dart';
import 'package:universal_file_viewer/src/widgets/shimmer_widget.dart';

/// A widget that displays the contents of an Excel file specified by the file path.
///
/// The widget reads the Excel / CSV file and displays its contents in a table.
class ExcelCSVPreviewScreen extends StatefulWidget {
  /// The Excel file to display.
  final File file;

  /// The padding inside the scroll for the table
  final EdgeInsets? padding;

  /// Creates a [ExcelCSVPreviewScreen] widget.
  const ExcelCSVPreviewScreen(
      {super.key,
      required this.file,
      this.padding = const EdgeInsets.only(bottom: 68)});

  @override
  ExcelCSVPreviewScreenState createState() => ExcelCSVPreviewScreenState();
}

// ignore: public_member_api_docs
class ExcelCSVPreviewScreenState extends State<ExcelCSVPreviewScreen> {
  final ScrollController _verticalController = ScrollController();

  /// The data read from the Excel file.
  late final Future<List<List<String>>> _excelData;

  @override
  void initState() {
    super.initState();
    _excelData = readExcelFile(widget.file);
  }

  @override
  void dispose() {
    super.dispose();
    _verticalController.dispose();
  }

  @override
  void didUpdateWidget(covariant ExcelCSVPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file != widget.file) {
      _excelData = readExcelFile(widget.file);
    }
  }

  /// Reads the Excel file and processes it in the background using `compute()`.
  Future<List<List<String>>> readExcelFile(File file) async {
    try {
      if (kIsWeb) {
        Uint8List fileBytes =
            await file.readAsBytes(); //Read file bytes in the main thread
        return _parseExcelData(fileBytes); //Runs synchronously on Web
      } else {
        final FileType fileType = detectFileType(file.path)!;
        if (fileType == FileType.excel) {
          Uint8List fileBytes =
              await file.readAsBytes(); //Read file bytes in the main thread

          return await compute(_parseExcelData, fileBytes);
        } else {
          String csvString = await file
              .readAsString(); //Read file as String in the main thread

          return await compute(_parseCSVString, csvString);
        }
      }
    } catch (e) {
      debugPrint("Error reading Excel / CSV file: $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          padding: widget.padding,
          child: FutureBuilder<List<List<String>>>(
            future: _excelData,
            builder: (BuildContext context,
                AsyncSnapshot<List<List<String>>> snapshot) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: snapshot.hasData
                    ? Theme(
                        data: Theme.of(context).copyWith(
                            cardTheme: const CardThemeData(elevation: 0)),
                        child: PaginatedDataTable(
                          columns: <DataColumn>[
                            const DataColumn(label: Text("  ")),
                            ...snapshot.requireData.first.map(
                              (String header) => DataColumn(
                                label: Text(header == 'null' ? '' : header,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                          source:
                              _ExcelDataSource(snapshot.requireData.sublist(1)),
                          rowsPerPage: 100,
                          showFirstLastButtons: true,
                          showEmptyRows: true,
                          dataRowMinHeight: 0,
                          dataRowMaxHeight: 40,
                          headingRowHeight: 40,
                          columnSpacing: 16,
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        itemCount: 100,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 2,
                        ),
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (_, __) {
                          return ShimmerWidget.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration:
                                  const BoxDecoration(color: Colors.white),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExcelDataSource extends DataTableSource {
  final List<List<String>> data;

  _ExcelDataSource(this.data);

  @override
  DataRow getRow(int index) {
    if (index >= data.length) return const DataRow(cells: <DataCell>[]);

    return DataRow(
      cells: <DataCell>[
        _buildDataCell((index + 1).toString(), isHeader: true),
        ...data[index].map((String cell) => _buildDataCell(cell)),
      ],
    );
  }

  DataCell _buildDataCell(String text, {bool isHeader = false}) =>
      DataCell(Text(text == 'null' ? '' : text,
          style: TextStyle(
              fontWeight: isHeader ? FontWeight.w300 : FontWeight.normal)));

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}

/// ✅ Background isolate function to parse Excel data
List<List<String>> _parseExcelData(Uint8List fileBytes) {
  final exc.Excel excel = exc.Excel.decodeBytes(fileBytes);
  final List<List<String>> extractedData = <List<String>>[];

  for (String table in excel.tables.keys) {
    for (List<exc.Data?> row in excel.tables[table]!.rows) {
      extractedData.add(
        row
            .map((exc.Data? cell) => cell?.value?.toString() ?? "")
            .toList(), // ✅ Extract only Strings
      );
    }
  }

  return extractedData;
}

/// ✅ Background isolate function to parse CSV data
List<List<String>> _parseCSVString(String content) {
  List<List<String>> csvData = <List<String>>[];

  // Detect line and column delimiters
  String lineDelimiter = _detectLineDelimiter(content);
  String columnDelimiter = _detectDelimiter(content);

  List<String> rows = content.split(lineDelimiter);

  for (String row in rows) {
    if (row.trim().isEmpty) continue; // Skip empty lines
    csvData.add(_splitRow(row, columnDelimiter));
  }

  return csvData;
}

String _detectLineDelimiter(String content) {
  if (content.contains('\r\n')) return '\r\n'; // Windows
  if (content.contains('\r')) return '\r'; // MacOS Classic
  return '\n'; // Default Unix/Linux
}

String _detectDelimiter(String content) {
  List<String> commonDelimiters = <String>[',', ';', '\t', '|'];
  Map<String, int> delimiterCount = <String, int>{};

  List<String> lines = content.split(_detectLineDelimiter(content));
  if (lines.isEmpty) return ','; // Default fallback

  String sampleLine = lines.first;

  for (String delim in commonDelimiters) {
    delimiterCount[delim] = sampleLine.split(delim).length - 1;
  }

  return delimiterCount.entries
      .reduce((MapEntry<String, int> a, MapEntry<String, int> b) =>
          a.value > b.value ? a : b)
      .key;
}

List<String> _splitRow(String row, String delimiter) {
  List<String> fields = <String>[];
  StringBuffer currentField = StringBuffer();
  bool inQuotes = false;

  for (int i = 0; i < row.length; i++) {
    String char = row[i];

    if (char == '"') {
      if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
        currentField.write('"'); // Handle escaped double quotes ""
        i++; // Skip next quote
      } else {
        inQuotes = !inQuotes; // Toggle quote mode
      }
    } else if (char == delimiter && !inQuotes) {
      fields.add(currentField.toString().trim());
      currentField.clear();
    } else {
      currentField.write(char);
    }
  }

  fields.add(currentField.toString().trim());

  return fields;
}
