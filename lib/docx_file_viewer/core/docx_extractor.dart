import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:xml/xml.dart';

import '../docx_file_viewer.dart';

class DocxExtractor {
  final Map<String, Map<int, String>> numberingDefinitions = {};
  final Map<String, Map<String, TextStyle?>> documentStyles = {};
  final Map<String, Border> documentBorder = {};
  final Map<String, TextAlign> documentTextAlignment = {};
  final Map<String, Uint8List> imageMap = {};
  final Map<String, TableBorder> tablesBorders = {};
  final Map<String, EdgeInsetsGeometry> tablesCellPadding = {};
  Future<List<Widget>> renderLayout(File file) async {
    try {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());

      // Extract document.xml and document.xml.rels
      final documentXmlFile = archive.files
          .where((file) => file.name == 'word/document.xml')
          .firstOrNull;
      final numberingXmlFile = archive.files
          .where((file) => file.name == 'word/numbering.xml')
          .firstOrNull;

      final relsXmlFile = archive.files
          .where((file) => file.name == 'word/_rels/document.xml.rels')
          .firstOrNull;
      // final themeXmlFIle = archive.files
      //     .where((file) => file.name == 'word/theme/theme1.xml')
      // .firstOrNull;
      final stylesXmlFile = archive.files
          .where((file) => file.name == 'word/styles.xml')
          .firstOrNull;
      if (stylesXmlFile != null) {
        final styleXml =
            XmlDocument.parse(String.fromCharCodes(stylesXmlFile.content));

        _parseStyles(styleXml);
      }
      if (documentXmlFile == null) {
        return [];
      }
      // if (themeXmlFIle != null) {
      //   final themerel =
      //       XmlDocument.parse(String.fromCharCodes(themeXmlFIle.content));
      //   // log(themerel.toXmlString());
      // }
      // Parse XML
      final documentXml =
          XmlDocument.parse(String.fromCharCodes(documentXmlFile.content));

      if (relsXmlFile != null) {
        final relsXml =
            XmlDocument.parse(String.fromCharCodes(relsXmlFile.content));
        _extractImageRelationships(relsXml, archive);
      }

      if (numberingXmlFile != null) {
        final numberingXmlContent =
            utf8.decode(numberingXmlFile.content as List<int>);
        parseNumberingDefinitions(numberingXmlContent);
      }
      // log(documentXml.toXmlString());
      // await _loadFontsFromFontTable(archive);
      // await _loadStyles(stylesXml);
      // Parse the content
      return _parseContent(
        documentXml: documentXml,
      );
    } catch (e) {
      log(e.toString());
      // Handle error, log it or provide a fallback widget

      return [
        const Text('Error parsing the document')
      ]; // Fallback widget in case of error
    }
  }

  void _parseStyles(XmlDocument stylesXml) {
    final stylesMap = <String, Map<String, TextStyle?>>{};
    final newBorderMap = <String, Border>{};
    final newTextAlignMap = <String, TextAlign>{};
    final newTableBorder = <String, TableBorder>{};
    final newCellPadding = <String, EdgeInsetsGeometry>{};
    // log(stylesXml.toXmlString());
    for (final styleElement in stylesXml.findAllElements('w:style')) {
      final styleId = styleElement.getAttribute('w:styleId');
      final type = styleElement.getAttribute('w:type');

      if (styleId != null && type != null) {
        final rPrElement = styleElement.getElement('w:rPr');
        final tableBorderElement = styleElement.getElement('w:tblPr');

        TextStyle? paragraphId;
        Border? border;
        TextAlign? textAlign;
        // log("StyleId:$styleId ${rPrElement.toXmlString()}");
        final parsedStyles = _parseRunStyle(rPrElement);

        final pPRStyle = styleElement.getElement('w:pPr');
        if (pPRStyle != null) {
          final pPRStyleId = _parseRunStyle(pPRStyle);

          Border newBorder =
              createBorder(pPRStyle.findElements('w:pBdr').firstOrNull);

          paragraphId = pPRStyleId;
          border = newBorder;
          textAlign = getTextAlign(pPRStyle.getElement('w:jc'));
        }
        if (tableBorderElement != null) {
          final tableborder =
              _parseTableStyle(tableBorderElement.getElement('w:tblBorders'));
          if (tableborder != null) {
            newTableBorder[styleId] = tableborder;
          }
        }
        if (tableBorderElement != null) {
          final tablePadding =
              _parseCellMargin(tableBorderElement.getElement('w:tblCellMar'));

          newCellPadding[styleId] = tablePadding;
        }

        stylesMap[styleId] = {
          "${type}pPr": paragraphId,
          "${type}rPr": parsedStyles
        };
        if (border != null) {
          newBorderMap[styleId] = border;
        }
        if (textAlign != null) {
          newTextAlignMap[styleId] = textAlign;
        }
      }

      // Parse attributes for the text style
    }
    tablesBorders.addAll(newTableBorder);
    tablesCellPadding.addAll(newCellPadding);
    documentBorder.addAll(newBorderMap);
    documentStyles.addAll(stylesMap);
    documentTextAlignment.addAll(newTextAlignMap);
  }

  TableBorder? _parseTableStyle(XmlElement? element) {
    if (element == null) {
      return null;
    }

    final topBorder = element.findElements('w:top').firstOrNull;
    final bottomBorder = element.findElements('w:bottom').firstOrNull;
    final leftBorder = element.findElements('w:left').firstOrNull;
    final rightBorder = element.findElements('w:right').firstOrNull;

    return TableBorder(
        top: _parseBorderSide(topBorder),
        left: _parseBorderSide(leftBorder),
        right: _parseBorderSide(rightBorder),
        bottom: _parseBorderSide(bottomBorder));
  }

  BorderSide _parseBorderSide(XmlElement? element) {
    if (element == null) return const BorderSide();
    final color = element.getAttribute('w:color') != null
        ? _hexToColor(element.getAttribute('w:color')!)
        : Colors.transparent;
    final width = double.tryParse(element.getAttribute('w:sz') ?? "0");

    return BorderSide(color: color, width: (width ?? 8) / 8);
  }

  EdgeInsetsGeometry _parseCellMargin(XmlElement? element) {
    if (element == null) return EdgeInsets.zero;
    final topPadding = element.findElements('w:top').firstOrNull;
    final bottomPadding = element.findElements('w:bottom').firstOrNull;
    final leftPadding = element.findElements('w:left').firstOrNull;
    final rightPadding = element.findElements('w:right').firstOrNull;

    return EdgeInsets.only(
        bottom: _parseCellMarginValue(bottomPadding),
        left: _parseCellMarginValue(leftPadding),
        right: _parseCellMarginValue(rightPadding),
        top: _parseCellMarginValue(topPadding));
  }

  double _parseCellMarginValue(XmlElement? element) {
    final value = double.tryParse(element?.getAttribute('w:w') ?? "0") ?? 0;

    return value / 15;
  }

  void parseNumberingDefinitions(String numberingXml) {
    final document = XmlDocument.parse(numberingXml);
    final numberingMap = <String, Map<int, String>>{};

    // Iterate through all abstractNum elements
    for (final abstractNum in document.findAllElements('w:abstractNum')) {
      final abstractNumId = abstractNum.getAttribute('w:abstractNumId') ?? '';
      final levels = <int, String>{};

      for (final level in abstractNum.findAllElements('w:lvl')) {
        final ilvl = int.tryParse(level.getAttribute('w:ilvl') ?? '0') ?? 0;
        final format =
            level.getElement('w:numFmt')?.getAttribute('w:val') ?? '';

        levels[ilvl] = format;
      }

      numberingMap[abstractNumId] = levels;
    }
    numberingDefinitions.addAll(numberingMap);

    // Map of abstractNumId to level definitions
  }

  void _extractImageRelationships(XmlDocument relsXml, Archive archive) {
    final appimageMap = <String, Uint8List>{};

    relsXml.findAllElements('Relationship').forEach((rel) {
      final type = rel.getAttribute('Type') ?? '';
      final target = rel.getAttribute('Target') ?? '';
      final id = rel.getAttribute('Id') ?? '';

      if (type.contains('image')) {
        final filePath = 'word/$target';
        final file = archive.files.firstWhere(
          (file) => file.name == filePath,
        );
        appimageMap[id] = Uint8List.fromList(file.content);
      }
    });

    imageMap.addAll(appimageMap);
  }

  Widget _parseParagraph({
    required XmlElement paragraph,
    required Map<String, int> counter,
  }) {
    final spans = <InlineSpan>[];
    final pprStyleId = paragraph
        .getElement('w:pPr')
        ?.getElement('w:pStyle')
        ?.getAttribute('w:val');
    final borderElement =
        paragraph.getElement('w:pPr')?.findElements('w:pBdr').firstOrNull;
    final backgroundColorElement =
        paragraph.getElement('w:pPr')?.findElements('w:shd').firstOrNull;
    String? bgHex;
    if (backgroundColorElement != null &&
        backgroundColorElement.getAttribute('w:val') != "clear") {
      bgHex = backgroundColorElement.getAttribute('w:val');
    } else if (backgroundColorElement != null) {
      bgHex = backgroundColorElement.getAttribute('w:fill');
    }
    final backgroundColor = bgHex != null && bgHex != 'auto'
        ? _hexToColor(bgHex)
        : Colors.transparent;
    // Handle unordered or ordered list items
    final isListItem =
        paragraph.getElement('w:pPr')?.getElement('w:numPr') != null;

    TextStyle? mergedStye;
    TextAlign? textAlignment;
    Border? border;
    if (pprStyleId != null) {
      mergedStye = documentStyles[pprStyleId]?["paragraph" "pPr"];
      mergedStye =
          mergedStye?.merge(documentStyles[pprStyleId]?["paragraph" "rPr"]);
      border = documentBorder[pprStyleId];
      textAlignment = documentTextAlignment[pprStyleId];
    }
    mergedStye ??= const TextStyle(color: Colors.black);

    if (isListItem) {
      final numPr = paragraph.getElement('w:pPr')?.getElement('w:numPr');
      final numId = numPr?.getElement('w:numId')?.getAttribute('w:val');
      final ilvl = int.tryParse(
            numPr?.getElement('w:ilvl')?.getAttribute('w:val') ?? '0',
          ) ??
          0;

      if (numId != null && numberingDefinitions.containsKey(numId)) {
        final listLevelStyle = numberingDefinitions[numId]?[ilvl];
        int newLevel = level ?? ilvl;

        if (listLevelStyle != null) {
          if (listLevelStyle.toLowerCase() == 'bullet') {
            level = null;
          }
          spans.add(WidgetSpan(
            child: Padding(
              padding: EdgeInsets.only(left: ilvl != 0 ? 30 : 20.0),
              child: listLevelStyle.toLowerCase() == 'bullet'
                  ? Text(
                      _getBulletForLevel(ilvl),
                      style: const TextStyle(
                        fontSize: 20, // Adjust size based on level
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      _getFormattedListNumber(
                          numberingDefinitions, counter, numId, newLevel),
                      style: const TextStyle(color: Colors.black, fontSize: 16),
                    ),
            ),
          ));
        }
      }
    } else {
      level = null;
      enabled = false;
    }

    // Iterate through runs (text + style) in the paragraph
    paragraph.findAllElements('w:r').forEach((run) {
      final text = run.findElements('w:t');
      final tabs = run.findElements('w:tab');
      for (final textelement in text) {
        TextStyle style = _parseRunStyle(run.getElement('w:rPr'));
        final borderElement = run.getElement('w:rPr')?.getElement('w:bdr');
        Border newCharacterBorder = characterBorder(borderElement);

        final characterId = run
            .getElement('w:rPr')
            ?.getElement('w:rStyle')
            ?.getAttribute('w:val');

        if (characterId != null) {
          style = documentStyles[characterId]?["character" "rPr"] ?? style;
        }
        if (borderElement == null) {
          spans.add(TextSpan(
            text: textelement.innerText,
            style: style,
          ));
        } else {
          spans.add(WidgetSpan(
            child: Container(
              decoration: BoxDecoration(border: newCharacterBorder),
              child: Text(
                textelement.innerText,
                style: style,
              ),
            ),
          ));
        }
      }
      for (var tab in tabs) {
        final pos = int.tryParse(tab.getAttribute('pos') ?? '0') ?? 0;
        final leader = tab.getAttribute('leader') ?? 'none';
        final val = tab.getAttribute('val') ?? 'start';

        spans.add(WidgetSpan(
          child: _buildTabWidget(pos: pos, leader: leader, val: val),
        ));
      }

      final hasPageBreak = run.getElement('w:pict');

      if (hasPageBreak != null) {
        spans.add(const WidgetSpan(
            child: SizedBox(
          width: double.infinity,
          child: Divider(
            color: Colors.grey,
            thickness: 1,
          ),
        )));
      }

      // Check for embedded images
      run.findAllElements('a:blip').forEach((imageElement) {
        final embedId = imageElement.getAttribute('r:embed') ?? '';
        if (imageMap.containsKey(embedId)) {
          spans.add(WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.memory(imageMap[embedId]!),
            ),
          ));
        }
      });
    });

    // Handle headings
    final headingStyle = _parseHeadingStyle(paragraph);
    // Handle paragraph spacing
    final paragraphSpacing = _parseParagraphSpacing(paragraph);
    final newtextAlignment =
        getTextAlign(paragraph.getElement('w:pPr')?.getElement('w:jc'));

    if (headingStyle != null) {
      return Padding(
        padding: paragraphSpacing,
        child: Container(
          decoration: BoxDecoration(
              color: backgroundColor,
              border: border ?? createBorder(borderElement)),
          child: RichText(
            textAlign: textAlignment ?? newtextAlignment,
            text: TextSpan(
              children: spans,
              style: headingStyle.merge(mergedStye),
            ),
          ),
        ),
      );
    }

    // Handle paragraph spacing

    return Padding(
      padding: paragraphSpacing,
      child: Container(
        decoration: BoxDecoration(
            color: backgroundColor,
            border: border ?? createBorder(borderElement)),
        child: RichText(
          textAlign: textAlignment ?? newtextAlignment,
          text: TextSpan(
            children: spans,
            style: mergedStye,
          ),
        ),
      ),
    );
  }

  Widget _buildTabWidget({
    required int pos,
    required String leader,
    required String val,
  }) {
    double tabWidth = pos / 20.0; // Convert twips to points
    String leaderCharacter;

    // Determine the leader character
    switch (leader) {
      case 'dot':
        leaderCharacter = '.';
        break;
      case 'heavy':
        leaderCharacter = '━';
        break;
      case 'hyphen':
        leaderCharacter = '-';
        break;
      case 'middleDot':
        leaderCharacter = '·';
        break;
      case 'underscore':
        leaderCharacter = '_';
        break;
      default:
        leaderCharacter = ''; // No leader character
    }

    // Handle different tab styles (val attribute)
    switch (val) {
      case 'center':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              leaderCharacter * (tabWidth ~/ 10),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      case 'end':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              leaderCharacter * (tabWidth ~/ 10),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      case 'decimal':
        // Decimal-aligned tab
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: tabWidth,
            child: Text(
              leaderCharacter * (tabWidth ~/ 10),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        );
      case 'bar':
        return Container(
          width: tabWidth,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
        );
      default:
        // Default start-aligned tab
        return SizedBox(
          width: tabWidth,
          child: Text(
            leaderCharacter * (tabWidth ~/ 10),
            style: const TextStyle(color: Colors.grey),
          ),
        );
    }
  }

  Border createBorder(XmlElement? borderElement) {
    final top = borderElement?.findElements('w:top').firstOrNull;
    final bottom = borderElement?.findElements('w:bottom').firstOrNull;
    final left = borderElement?.findElements('w:left').firstOrNull;
    final right = borderElement?.findElements('w:right').firstOrNull;

    return Border(
      top: top != null ? parseBorderSide(top) : BorderSide.none,
      bottom: bottom != null ? parseBorderSide(bottom) : BorderSide.none,
      left: left != null ? parseBorderSide(left) : BorderSide.none,
      right: right != null ? parseBorderSide(right) : BorderSide.none,
    );
  }

  Border characterBorder(XmlElement? borderElement) {
    if (borderElement == null) return const Border();
    final thichness = borderElement.getAttribute('w:sz');
    final width = double.tryParse(thichness ?? "8") ?? 8;
    final color = borderElement.getAttribute('w:color') != null
        ? _hexToColor(borderElement.getAttribute('w:color')!)
        : Colors.transparent;

    return Border.all(color: color, width: width / 8);
  }

  BorderSide parseBorderSide(XmlElement? element) {
    if (element == null) {
      return BorderSide.none;
    }
    final style = element.getAttribute('w:val') ?? 'single';
    final color = element.getAttribute('w:color') != null
        ? _hexToColor(element.getAttribute('w:color')!)
        : Colors.transparent;

    final width =
        (double.tryParse(element.getAttribute('w:sz') ?? '0') ?? 0) / 8.0;

    return getBorderSide(style, color, width);
  }

  BorderSide getBorderSide(String style, Color color, double width) {
    switch (style) {
      case 'single':
      case 'thick':
        return BorderSide(color: color, width: width);
      case 'double':
        return BorderSide(color: color, width: width, style: BorderStyle.solid);
      case 'dashed':
      case 'dotted':
        return BorderSide(color: color, width: width, style: BorderStyle.solid);
      case 'wave':
      case 'doubleWave':
        return BorderSide(color: color, width: width, style: BorderStyle.solid);
      case 'triple':
      case 'inset':
      case 'outset':
        return BorderSide(color: color, width: width, style: BorderStyle.solid);
      case 'thickThinLargeGap':
      case 'thinThickSmallGap':
      case 'thinThickThinMediumGap':
        return BorderSide(color: color, width: width, style: BorderStyle.solid);
      case 'threeDEmboss':
      case 'threeDEngrave':
        return BorderSide(color: color.withOpacity(0.8), width: width);
      default:
        return BorderSide.none;
    }
  }

  TextAlign getTextAlign(XmlElement? alignment) {
    final String? alignementValue = alignment?.getAttribute("w:val");

    if (alignementValue == null) {
      return TextAlign.start;
    }
    switch (alignementValue) {
      case "left":
        return TextAlign.left;
      case "center":
        return TextAlign.center;
      case "start":
        return TextAlign.start;
      case "end":
        return TextAlign.end;
      case "right":
        return TextAlign.right;
      case "both":
        return TextAlign.justify;
      default:
        return TextAlign.start;
    }
  }

  EdgeInsets _parseParagraphSpacing(XmlElement paragraph) {
    final pPr = paragraph.getElement('w:pPr');
    final before = int.tryParse(
            pPr?.getElement('w:spacing')?.getAttribute('w:before') ?? "0") ??
        0;
    final after = int.tryParse(
            pPr?.getElement('w:spacing')?.getAttribute('w:after') ?? "0") ??
        0;

    // Convert Word spacing units to Flutter padding (assume 20 units = 1 point)
    return EdgeInsets.only(
      top: before / 20,
      bottom: after / 20,
    );
  }

  TextStyle? _parseHeadingStyle(XmlElement paragraph) {
    final pStyle = paragraph
        .getElement('w:pPr')
        ?.getElement('w:pStyle')
        ?.getAttribute('w:val');
    TextStyle style = _parseRunStyle(paragraph.getElement('w:rPr'));

    if (pStyle != null) {
      switch (pStyle) {
        case 'Heading1':
          style = style.copyWith(fontSize: 32, fontWeight: FontWeight.bold);
        case 'Heading2':
          style = style.copyWith(fontSize: 28, fontWeight: FontWeight.bold);
        case 'Heading3':
          style = style.copyWith(fontSize: 24, fontWeight: FontWeight.bold);
        case 'Heading4':
          style = style.copyWith(fontSize: 20, fontWeight: FontWeight.bold);
        case 'Heading5':
          style = style.copyWith(fontSize: 18, fontWeight: FontWeight.bold);
        case 'Heading6':
          style = style.copyWith(fontSize: 16, fontWeight: FontWeight.bold);
        default:
          break;
      }
    }

    return style; // Not a heading
  }

// Helper to determine the list type

// Helper to get list bullet (number or bullet symbol)
  String _getBulletForLevel(int level) {
    const bulletStyles = ['•', '◦', '▪', '▫', '»', '›', '⁃', '–'];
    return bulletStyles[level % bulletStyles.length];
  }

  int? level;
  bool enabled = false;

  /// Retrieves the formatted list number for an ordered list item
  String _getFormattedListNumber(
      Map<String, Map<int, String>> numberingDefinitions,
      Map<String, int> counters,
      String numId,
      int ilvl) {
    // Retrieve the format for the current level
    final format = numberingDefinitions[numId]?[ilvl] ?? 'decimal';

    // Increment the counter for the given numId and ilvl
    final key = '$numId-$ilvl';
    counters[key] = (counters[key] ?? 0) + 1;
    final number = counters[key]!;

    // Generate list number based on format
    switch (format.toLowerCase()) {
      case 'decimal':
        return '$number.'; // Example: 1., 2., 3.
      case 'lowerroman':
        return '${_toRoman(number).toLowerCase()}.'; // Example: i., ii., iii.
      case 'upperroman':
        return '${_toRoman(number).toUpperCase()}.'; // Example: I., II., III.
      case 'lowerletter':
        return '${String.fromCharCode(97 + (number - 1))}.'; // Example: a., b., c.
      case 'upperletter':
        return '${String.fromCharCode(65 + (number - 1))}.'; // Example: A., B., C.
      default:
        return '$number.'; // Fallback to decimal
    }
  }

  String _toRoman(int number) {
    final romanNumerals = [
      'M',
      'CM',
      'D',
      'CD',
      'C',
      'XC',
      'L',
      'XL',
      'X',
      'IX',
      'V',
      'IV',
      'I'
    ];
    final romanValues = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1];
    var result = '';
    var i = 0;

    while (number > 0) {
      while (number >= romanValues[i]) {
        result += romanNumerals[i];
        number -= romanValues[i];
      }
      i++;
    }
    return result;
  }

  /// Retrieves the list type (ordered/unordered) based on paragraph properties

  List<Widget> _parseContent({
    required XmlDocument documentXml,
  }) {
    final widgets = <Widget>[];
    final counters = <String, int>{};
    for (final body in documentXml.findAllElements('w:body')) {
      for (final element in body.children.whereType<XmlElement>()) {
        switch (element.name.local) {
          case 'p':
            widgets.add(_parseParagraph(
              paragraph: element,
              counter: counters,
            ));
            break;
          case 'tbl':
            widgets.add(_parseTable(
              table: element,
              counter: counters,
            ));
            break;

          case 'sdt':
            widgets.add(_parseSdt(
              sdtElement: element,
              counter: counters,
            ));
            break;
          // case 'sectPr':
          //   widgets.add(_parseSectionProperties(element));
          // break;
        }
      }
    }

    return widgets;
  }

  Widget _parseTable({
    required XmlElement table,
    required Map<String, int> counter,
  }) {
    final rows = <TableRow>[];
    TableBorder? tableBorder;
    final tableBorderStyleid =
        table.getElement("w:tblStyle")?.getAttribute('w:val');
    if (tableBorderStyleid != null) {
      tableBorder = tablesBorders[tableBorderStyleid];
    }
    // Parse table border properties
    final borderStyle = _parseTableBorderStyle(table);

    // Store the number of cells in the first row to ensure all rows match this count
    int maxCells = 0;

    table.findAllElements('w:tr').forEach((row) {
      final cells = <Widget>[];

      // Parse cells in each row
      row.findAllElements('w:tc').forEach((cell) {
        final cellContent = <Widget>[];

        // Check for background fill color (shading)
        final backgroundColor = _parseCellBackgroundColor(cell);

        cell.findAllElements('w:p').forEach((paragraph) {
          cellContent.add(_parseParagraph(
            paragraph: paragraph,
            counter: counter,
          ));
        });

        cells.add(Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: backgroundColor, // Apply background color
            border:
                Border.all(color: borderStyle.color, width: borderStyle.width),
          ),
          child: Column(children: cellContent),
        ));
      });

      // Update the maxCells if this row has more cells
      maxCells = maxCells > cells.length ? maxCells : cells.length;

      // Add the row to the table
      rows.add(TableRow(children: cells));
    });

    // Add empty cells if a row has fewer cells than maxCells
    for (var row in rows) {
      final childrenCount = row.children.length;
      if (childrenCount < maxCells) {
        for (int i = 0; i < maxCells - childrenCount; i++) {
          row.children.add(Container(
            padding: const EdgeInsets.all(8.0),
            child: const SizedBox.shrink(), // Empty cell
          ));
        }
      }
    }

    return Table(
      border: tableBorder ??
          TableBorder.all(color: borderStyle.color, width: borderStyle.width),
      children: rows,
    );
  }

  // Parse table border style (color, width)
  TableBorderStyle _parseTableBorderStyle(XmlElement table) {
    final borderColor = table
            .getElement('w:tblBorders')
            ?.getElement('w:top')
            ?.getAttribute('w:color') ??
        '000000';
    final borderWidth = table
            .getElement('w:tblBorders')
            ?.getElement('w:top')
            ?.getAttribute('w:space') ??
        '1';

    return TableBorderStyle(
      color: _hexToColor(borderColor),
      width: double.parse(borderWidth),
    );
  }

  // Parse background color (shading) for a table cell
  Color _parseCellBackgroundColor(XmlElement cell) {
    final shading = cell.getElement('w:shd');
    final fillColor = shading?.getAttribute('w:fill');

    if (fillColor != null) {
      return _hexToColor(fillColor);
    } else {
      return Colors.transparent; // No background color
    }
  }

  Widget _parseSdt({
    required XmlElement sdtElement,
    required Map<String, int> counter,
  }) {
    final content = sdtElement
        .findAllElements('w:sdtContent')
        .expand((contentElement) => contentElement.children)
        .whereType<XmlElement>();

    final contentWidgets = content.map((childElement) {
      switch (childElement.name.local) {
        case 'p':
          return _parseParagraph(
            paragraph: childElement,
            counter: counter,
          );
        case 'tbl':
          return _parseTable(
            table: childElement,
            counter: counter,
          );
        default:
          return Text(childElement.innerText);
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  TextStyle _parseRunStyle(XmlElement? styleElement) {
    if (styleElement == null) return const TextStyle();
    TextDecoration textDecoration = TextDecoration.none;
    final isBold = styleElement.findElements('w:b').isNotEmpty;
    final isItalic = styleElement.findElements('w:i').isNotEmpty;
    final isUnderline = styleElement.findElements('w:u').isNotEmpty;
    final isStrikeThrough = styleElement.findElements('w:strike').isNotEmpty;
    if (isUnderline) {
      textDecoration = TextDecoration.underline;
    } else if (isStrikeThrough) {
      textDecoration = TextDecoration.lineThrough;
    }
    // Parse font size (half-points to points)
    final fontSize = double.tryParse(
          styleElement.getElement('w:sz')?.getAttribute('w:val') ?? '20',
        ) ??
        16.0;

    // Parse text color (if available)
    final colorHex =
        styleElement.findElements('w:color').firstOrNull?.getAttribute('w:val');
    final textColor = colorHex != null ? _hexToColor(colorHex) : Colors.black;

    // Ensure transparent colors are assigned black
    final effectiveTextColor =
        textColor == Colors.transparent ? Colors.black : textColor;

    // Parse background color (shading) for text background

    String? bgHex;
    final highlightElement = styleElement.getElement('w:highlight');
    final shadingElement = styleElement.getElement('w:shd');

    if (highlightElement != null) {
      bgHex = highlightElement.getAttribute('w:val');
    } else if (shadingElement != null) {
      bgHex = shadingElement.getAttribute('w:fill');
    }
    final backgroundColor = bgHex != null && bgHex != 'auto'
        ? _hexToColor(bgHex)
        : Colors.transparent;

    // If custom font is available, load it
    // final fontId = styleElement.getElement('w:rFonts')?.getAttribute('w:ascii');

    // final fontFamily = _fontNameMapping[fontId ?? ''] ?? 'Roboto';

    return TextStyle(
      // fontFamily: fontFamily,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: textDecoration,
      fontSize: fontSize == 16
          ? fontSize
          : fontSize / 2, // Word font size is in half-points
      color: effectiveTextColor, // Set the effective text color
      backgroundColor: backgroundColor, // Set the background color
    );
  }

  Color _hexToColor(String hex) {
    try {
      // Clean up the hex string by removing any '#' and converting it to uppercase
      final hexColor = hex.replaceAll('#', '').toUpperCase();

      // If the hex code is 6 characters long (RGB), make it 8 by adding full opacity (FF)
      if (hexColor.length == 6) {
        return Color(int.parse('0xFF$hexColor'));
      }

      // If the hex code is 8 characters long (RGBA), use it directly
      if (hexColor.length == 8) {
        // Extract the alpha value (first 2 characters)
        final alpha = int.parse(hexColor.substring(0, 2), radix: 16);

        // If the alpha value is 0 (fully transparent), return black color
        if (alpha == 0) {
          return Colors.black; // Fallback to black
        }

        return Color(int.parse('0x$hexColor'));
      }

      // Fallback for unexpected formats (return black in case of an invalid format)
      return Colors.black;
    } catch (e) {
      log(hex);
      return getColorFromString(hex);
    }
  }

  Color getColorFromString(String colorName) {
    // Define a map of supported colors
    Map<String, Color> colorMap = {
      'yellow': Colors.yellow,
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'black': Colors.black,
      'white': Colors.white,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'cyan': Colors.cyan,
      'grey': Colors.grey,
    };

    // Return the color if found, else default to transparent
    return colorMap[colorName.toLowerCase()] ?? Colors.transparent;
  }
}

class TableBorderStyle {
  final Color color;
  final double width;

  TableBorderStyle({required this.color, required this.width});
}
