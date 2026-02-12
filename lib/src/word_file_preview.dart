import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:docx_file_viewer/docx_file_viewer.dart';
import 'package:xml/xml.dart';

/// A widget that displays the contents of a Docx file as HTML.
class DocxToFlutter extends StatefulWidget {
  /// The DOCX file to display.
  final File file;

  /// The padding inside the scroll for the document
  final EdgeInsets? padding;

  /// Creates a [DocxToFlutter] widget.
  const DocxToFlutter(
      {super.key,
      required this.file,
      this.padding = const EdgeInsets.only(bottom: 68)});

  @override
  DocxToFlutterState createState() => DocxToFlutterState();
}

/// State for DocxToFlutter
class DocxToFlutterState extends State<DocxToFlutter> {
  late final Future<List<Widget>> _loadDocument;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadDocument = DocxExtractor().renderLayout(widget.file);
  }

  late TransformationController _transformationController;
  bool _isZooming = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FutureBuilder<List<Widget>>(
        future: _loadDocument,
        builder: (BuildContext context, AsyncSnapshot<List<Widget>> snapshot) {
          if (snapshot.hasData) {
            return GestureDetector(
              onScaleStart: (_) => setState(
                  () => _isZooming = true), // Detect zoom gesture start
              onScaleEnd: (_) => setState(() => _isZooming = false),
              onScaleUpdate: (ScaleUpdateDetails details) {
                if (details.scale != 1.0) {
                  setState(() {
                    _isZooming = true; // Keep zooming enabled
                  });
                  _transformationController.value = Matrix4.identity()
                    // ignore: deprecated_member_use
                    ..scale(details.scale);
                }
              }, // Detect zoom gesture end
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: false,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    return _isZooming; // Block scroll only when zooming
                  },
                  child: Scrollbar(
                    child: ListView.builder(
                      padding: widget.padding,
                      itemCount: snapshot.requireData.length,
                      physics: _isZooming
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      itemBuilder: (_, int index) =>
                          snapshot.requireData[index],
                    ),
                  ),
                ),
              ),
            );
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

/// DocxExtractor contains the logic for extract the Docx annotations to parse it into Flutter widgets
class DocxExtractor {
  final Map<String, Map<int, String>> _numberingDefinitions =
      <String, Map<int, String>>{};
  final Map<String, Map<String, TextStyle?>> _documentStyles =
      <String, Map<String, TextStyle?>>{};
  final Map<String, Border> _documentBorder = <String, Border>{};
  final Map<String, TextAlign> _documentTextAlignment = <String, TextAlign>{};
  final Map<String, Uint8List> _imageMap = <String, Uint8List>{};
  final Map<String, TableBorder> _tablesBorders = <String, TableBorder>{};
  final Map<String, EdgeInsetsGeometry> _tablesCellPadding =
      <String, EdgeInsetsGeometry>{};

  ///process the Docx into Flutter widgets
  Future<List<Widget>> renderLayout(File file) async {
    try {
      final Archive archive =
          ZipDecoder().decodeBytes(await file.readAsBytes());

      // Extract document.xml and document.xml.rels
      final ArchiveFile? documentXmlFile = archive.files
          .where((ArchiveFile file) => file.name == 'word/document.xml')
          .firstOrNull;
      final ArchiveFile? numberingXmlFile = archive.files
          .where((ArchiveFile file) => file.name == 'word/numbering.xml')
          .firstOrNull;

      final ArchiveFile? relsXmlFile = archive.files
          .where(
              (ArchiveFile file) => file.name == 'word/_rels/document.xml.rels')
          .firstOrNull;
      // final themeXmlFIle = archive.files
      //     .where((file) => file.name == 'word/theme/theme1.xml')
      // .firstOrNull;
      final ArchiveFile? stylesXmlFile = archive.files
          .where((ArchiveFile file) => file.name == 'word/styles.xml')
          .firstOrNull;
      if (stylesXmlFile != null) {
        final XmlDocument styleXml =
            XmlDocument.parse(utf8.decode(stylesXmlFile.content));

        _parseStyles(styleXml);
      }
      if (documentXmlFile == null) {
        return <Widget>[];
      }
      // if (themeXmlFIle != null) {
      //   final themerel =
      //       XmlDocument.parse(utf8.decode(themeXmlFIle.content));
      //   // log(themerel.toXmlString());
      // }
      // Parse XML
      final XmlDocument documentXml =
          XmlDocument.parse(utf8.decode(documentXmlFile.content));

      if (relsXmlFile != null) {
        final XmlDocument relsXml =
            XmlDocument.parse(utf8.decode(relsXmlFile.content));
        _extractImageRelationships(relsXml, archive);
      }

      if (numberingXmlFile != null) {
        final String numberingXmlContent =
            utf8.decode(numberingXmlFile.content as List<int>);
        _parseNumberingDefinitions(numberingXmlContent);
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

      return <Widget>[
        const Text('Error opening the document')
      ]; // Fallback widget in case of error
    }
  }

  void _parseStyles(XmlDocument stylesXml) {
    final Map<String, Map<String, TextStyle?>> stylesMap =
        <String, Map<String, TextStyle?>>{};
    final Map<String, Border> newBorderMap = <String, Border>{};
    final Map<String, TextAlign> newTextAlignMap = <String, TextAlign>{};
    final Map<String, TableBorder> newTableBorder = <String, TableBorder>{};
    final Map<String, EdgeInsetsGeometry> newCellPadding =
        <String, EdgeInsetsGeometry>{};
    // log(stylesXml.toXmlString());
    for (final XmlElement styleElement
        in stylesXml.findAllElements('w:style')) {
      final String? styleId = styleElement.getAttribute('w:styleId');
      final String? type = styleElement.getAttribute('w:type');

      if (styleId != null && type != null) {
        final XmlElement? rPrElement = styleElement.getElement('w:rPr');
        final XmlElement? tableBorderElement =
            styleElement.getElement('w:tblPr');

        TextStyle? paragraphId;
        Border? border;
        TextAlign? textAlign;
        // log("StyleId:$styleId ${rPrElement.toXmlString()}");
        final TextStyle parsedStyles = _parseRunStyle(rPrElement);

        final XmlElement? pPRStyle = styleElement.getElement('w:pPr');
        if (pPRStyle != null) {
          final TextStyle pPRStyleId = _parseRunStyle(pPRStyle);

          Border newBorder =
              _createBorder(pPRStyle.findElements('w:pBdr').firstOrNull);

          paragraphId = pPRStyleId;
          border = newBorder;
          textAlign = _getTextAlign(pPRStyle.getElement('w:jc'));
        }
        if (tableBorderElement != null) {
          final TableBorder? tableborder =
              _parseTableStyle(tableBorderElement.getElement('w:tblBorders'));
          if (tableborder != null) {
            newTableBorder[styleId] = tableborder;
          }
        }
        if (tableBorderElement != null) {
          final EdgeInsetsGeometry tablePadding =
              _parseCellMargin(tableBorderElement.getElement('w:tblCellMar'));

          newCellPadding[styleId] = tablePadding;
        }

        stylesMap[styleId] = <String, TextStyle?>{
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
    _tablesBorders.addAll(newTableBorder);
    _tablesCellPadding.addAll(newCellPadding);
    _documentBorder.addAll(newBorderMap);
    _documentStyles.addAll(stylesMap);
    _documentTextAlignment.addAll(newTextAlignMap);
  }

  TableBorder? _parseTableStyle(XmlElement? element) {
    if (element == null) {
      return null;
    }

    final XmlElement? topBorder = element.findElements('w:top').firstOrNull;
    final XmlElement? bottomBorder =
        element.findElements('w:bottom').firstOrNull;
    final XmlElement? leftBorder = element.findElements('w:left').firstOrNull;
    final XmlElement? rightBorder = element.findElements('w:right').firstOrNull;

    return TableBorder(
        top: _parseTableBorderSide(topBorder),
        left: _parseTableBorderSide(leftBorder),
        right: _parseTableBorderSide(rightBorder),
        bottom: _parseTableBorderSide(bottomBorder));
  }

  BorderSide _parseTableBorderSide(XmlElement? element) {
    if (element == null) return const BorderSide();
    final Color color = element.getAttribute('w:color') != null
        ? _hexToColor(element.getAttribute('w:color')!)
        : Colors.transparent;
    final double? width = double.tryParse(element.getAttribute('w:sz') ?? "0");

    return BorderSide(color: color, width: (width ?? 8) / 8);
  }

  EdgeInsetsGeometry _parseCellMargin(XmlElement? element) {
    if (element == null) return EdgeInsets.zero;
    final XmlElement? topPadding = element.findElements('w:top').firstOrNull;
    final XmlElement? bottomPadding =
        element.findElements('w:bottom').firstOrNull;
    final XmlElement? leftPadding = element.findElements('w:left').firstOrNull;
    final XmlElement? rightPadding =
        element.findElements('w:right').firstOrNull;

    return EdgeInsets.only(
        bottom: _parseCellMarginValue(bottomPadding),
        left: _parseCellMarginValue(leftPadding),
        right: _parseCellMarginValue(rightPadding),
        top: _parseCellMarginValue(topPadding));
  }

  double _parseCellMarginValue(XmlElement? element) {
    final double value =
        double.tryParse(element?.getAttribute('w:w') ?? "0") ?? 0;

    return value / 15;
  }

  void _parseNumberingDefinitions(String numberingXml) {
    final XmlDocument document = XmlDocument.parse(numberingXml);
    final Map<String, Map<int, String>> numberingMap =
        <String, Map<int, String>>{};

    // Iterate through all abstractNum elements
    for (final XmlElement abstractNum
        in document.findAllElements('w:abstractNum')) {
      final String abstractNumId =
          abstractNum.getAttribute('w:abstractNumId') ?? '';
      final Map<int, String> levels = <int, String>{};

      for (final XmlElement level in abstractNum.findAllElements('w:lvl')) {
        final int ilvl = int.tryParse(level.getAttribute('w:ilvl') ?? '0') ?? 0;
        final String format =
            level.getElement('w:numFmt')?.getAttribute('w:val') ?? '';

        levels[ilvl] = format;
      }

      numberingMap[abstractNumId] = levels;
    }
    _numberingDefinitions.addAll(numberingMap);

    // Map of abstractNumId to level definitions
  }

  void _extractImageRelationships(XmlDocument relsXml, Archive archive) {
    final Map<String, Uint8List> appimageMap = <String, Uint8List>{};

    relsXml.findAllElements('Relationship').forEach((XmlElement rel) {
      final String type = rel.getAttribute('Type') ?? '';
      final String target = rel.getAttribute('Target') ?? '';
      final String id = rel.getAttribute('Id') ?? '';

      if (type.contains('image')) {
        final String filePath = 'word/$target';
        final ArchiveFile file = archive.files.firstWhere(
          (ArchiveFile file) => file.name == filePath,
        );
        appimageMap[id] = Uint8List.fromList(file.content);
      }
    });

    _imageMap.addAll(appimageMap);
  }

  Widget _parseParagraph({
    required XmlElement paragraph,
    required Map<String, int> counter,
  }) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final String? pprStyleId = paragraph
        .getElement('w:pPr')
        ?.getElement('w:pStyle')
        ?.getAttribute('w:val');
    final XmlElement? borderElement =
        paragraph.getElement('w:pPr')?.findElements('w:pBdr').firstOrNull;
    final XmlElement? backgroundColorElement =
        paragraph.getElement('w:pPr')?.findElements('w:shd').firstOrNull;
    String? bgHex;
    if (backgroundColorElement != null &&
        backgroundColorElement.getAttribute('w:val') != "clear") {
      bgHex = backgroundColorElement.getAttribute('w:val');
    } else if (backgroundColorElement != null) {
      bgHex = backgroundColorElement.getAttribute('w:fill');
    }
    final Color backgroundColor = bgHex != null && bgHex != 'auto'
        ? _hexToColor(bgHex)
        : Colors.transparent;
    // Handle unordered or ordered list items
    final bool isListItem =
        paragraph.getElement('w:pPr')?.getElement('w:numPr') != null;

    TextStyle? mergedStye;
    TextAlign? textAlignment;
    Border? border;
    if (pprStyleId != null) {
      mergedStye = _documentStyles[pprStyleId]?["paragraph" "pPr"];
      mergedStye =
          mergedStye?.merge(_documentStyles[pprStyleId]?["paragraph" "rPr"]);
      border = _documentBorder[pprStyleId];
      textAlignment = _documentTextAlignment[pprStyleId];
    }
    mergedStye ??= const TextStyle(color: Colors.black);

    if (isListItem) {
      final XmlElement? numPr =
          paragraph.getElement('w:pPr')?.getElement('w:numPr');
      final String? numId = numPr?.getElement('w:numId')?.getAttribute('w:val');
      final int ilvl = int.tryParse(
            numPr?.getElement('w:ilvl')?.getAttribute('w:val') ?? '0',
          ) ??
          0;

      if (numId != null && _numberingDefinitions.containsKey(numId)) {
        final String? listLevelStyle = _numberingDefinitions[numId]?[ilvl];
        int newLevel = _level ?? ilvl;

        if (listLevelStyle != null) {
          if (listLevelStyle.toLowerCase() == 'bullet') {
            _level = null;
          }
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(left: ilvl != 0 ? 30 : 20.0, right: 4),
              child: listLevelStyle.toLowerCase() == 'bullet'
                  ? _getBulletForLevel(ilvl)
                  : Transform.translate(
                      offset: const Offset(0, -1),
                      child: Text(
                        _getFormattedListNumber(
                            _numberingDefinitions, counter, numId, newLevel),
                        style:
                            const TextStyle(color: Colors.black, fontSize: 16),
                      )),
            ),
          ));
        }
      }
    } else {
      _level = null;
    }

    // Iterate through runs (text + style) in the paragraph
    paragraph.findAllElements('w:r').forEach((XmlElement run) {
      final Iterable<XmlElement> text = run.findElements('w:t');
      final Iterable<XmlElement> tabs = run.findElements('w:tab');
      for (final XmlElement textElement in text) {
        TextStyle style = _parseRunStyle(run.getElement('w:rPr'));
        final XmlElement? borderElement =
            run.getElement('w:rPr')?.getElement('w:bdr');
        Border newCharacterBorder = _characterBorder(borderElement);

        final String? characterId = run
            .getElement('w:rPr')
            ?.getElement('w:rStyle')
            ?.getAttribute('w:val');

        if (characterId != null) {
          style = _documentStyles[characterId]?["character" "rPr"] ?? style;
        }
        if (borderElement == null) {
          spans.add(TextSpan(
            text: textElement.innerText,
            style: style,
          ));
        } else {
          spans.add(WidgetSpan(
            child: Container(
              decoration: BoxDecoration(border: newCharacterBorder),
              child: Text(
                textElement.innerText,
                style: style,
              ),
            ),
          ));
        }
      }
      for (XmlElement tab in tabs) {
        final int pos = int.tryParse(tab.getAttribute('pos') ?? '0') ?? 0;
        final String leader = tab.getAttribute('leader') ?? 'none';
        final String val = tab.getAttribute('val') ?? 'start';

        spans.add(WidgetSpan(
          child: _buildTabWidget(pos: pos, leader: leader, val: val),
        ));
      }

      final XmlElement? hasPageBreak = run.getElement('w:pict');

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
      run.findAllElements('a:blip').forEach((XmlElement imageElement) {
        final String embedId = imageElement.getAttribute('r:embed') ?? '';
        if (_imageMap.containsKey(embedId)) {
          spans.add(WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.memory(_imageMap[embedId]!),
            ),
          ));
        }
      });
    });

    // Handle headings
    final TextStyle? headingStyle = _parseHeadingStyle(paragraph);
    // Handle paragraph spacing
    final EdgeInsets paragraphSpacing = _parseParagraphSpacing(paragraph);
    final TextAlign newTextAlignment =
        _getTextAlign(paragraph.getElement('w:pPr')?.getElement('w:jc'));

    if (headingStyle != null) {
      return Padding(
        padding: paragraphSpacing,
        child: Container(
          decoration: BoxDecoration(
              color: backgroundColor,
              border: border ?? _createBorder(borderElement)),
          child: Text.rich(
            TextSpan(
                children: spans.map(
              (InlineSpan span) {
                if (span is TextSpan) {
                  return TextSpan(
                    text: span.toPlainText(),
                    style: span.style != null
                        ? span.style?.merge(headingStyle)
                        : headingStyle,
                  );
                } else {
                  return span;
                }
              },
            ).toList()),
            textAlign: textAlignment ?? newTextAlignment,
            style: headingStyle,
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
            border: border ?? _createBorder(borderElement)),
        child: Text.rich(
          textAlign: textAlignment ?? newTextAlignment,
          TextSpan(
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
          children: <Widget>[
            Text(
              leaderCharacter * (tabWidth ~/ 10),
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        );
      case 'end':
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
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

  Border _createBorder(XmlElement? borderElement) {
    final XmlElement? top = borderElement?.findElements('w:top').firstOrNull;
    final XmlElement? bottom =
        borderElement?.findElements('w:bottom').firstOrNull;
    final XmlElement? left = borderElement?.findElements('w:left').firstOrNull;
    final XmlElement? right =
        borderElement?.findElements('w:right').firstOrNull;

    return Border(
      top: top != null ? _parseBorderSide(top) : BorderSide.none,
      bottom: bottom != null ? _parseBorderSide(bottom) : BorderSide.none,
      left: left != null ? _parseBorderSide(left) : BorderSide.none,
      right: right != null ? _parseBorderSide(right) : BorderSide.none,
    );
  }

  Border _characterBorder(XmlElement? borderElement) {
    if (borderElement == null) return const Border();
    final String? thickness = borderElement.getAttribute('w:sz');
    final double width = double.tryParse(thickness ?? "8") ?? 8;
    final Color color = borderElement.getAttribute('w:color') != null
        ? _hexToColor(borderElement.getAttribute('w:color')!)
        : Colors.transparent;

    return Border.all(color: color, width: width / 8);
  }

  BorderSide _parseBorderSide(XmlElement? element) {
    if (element == null) {
      return BorderSide.none;
    }
    final String style = element.getAttribute('w:val') ?? 'single';
    final Color color = element.getAttribute('w:color') != null
        ? _hexToColor(element.getAttribute('w:color')!)
        : Colors.transparent;

    final double width =
        (double.tryParse(element.getAttribute('w:sz') ?? '0') ?? 0) / 8.0;

    return _getBorderSide(style, color, width);
  }

  BorderSide _getBorderSide(String style, Color color, double width) {
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
        return BorderSide(color: color.withValues(alpha: 0.8), width: width);
      default:
        return BorderSide.none;
    }
  }

  TextAlign _getTextAlign(XmlElement? alignment) {
    final String? alignmentValue = alignment?.getAttribute("w:val");

    if (alignmentValue == null) {
      return TextAlign.start;
    }
    switch (alignmentValue) {
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
    final XmlElement? pPr = paragraph.getElement('w:pPr');
    final int before = int.tryParse(
            pPr?.getElement('w:spacing')?.getAttribute('w:before') ?? "0") ??
        0;
    final int after = int.tryParse(
            pPr?.getElement('w:spacing')?.getAttribute('w:after') ?? "0") ??
        0;

    // Convert Word spacing units to Flutter padding (assume 20 units = 1 point)
    return EdgeInsets.only(top: before / 20, bottom: after / 20);
  }

  TextStyle? _parseHeadingStyle(XmlElement paragraph) {
    final String? pStyle = paragraph
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
  Widget _getBulletForLevel(int level) {
    List<String> bulletStyles = <String>[
      '•',
      '◦',
      '∙',
      '▪',
      '▫',
      '»',
      '›',
      '⁃',
      '–'
    ];
    List<double> bulletOffset = <double>[-3.5, -1, 1, 0, 0, 0, 0, 0, 0];
    int bulletIndex = level % bulletStyles.length;
    String bullet = bulletStyles[bulletIndex];
    double yOffset = bulletOffset[bulletIndex];
    return Transform.translate(
        offset: Offset(0, yOffset),
        child: Text(
          bullet,
          style: const TextStyle(
            fontSize: 20, // Adjust size based on level
            color: Colors.black,
          ),
        ));
  }

  int? _level;

  /// Retrieves the formatted list number for an ordered list item
  String _getFormattedListNumber(
      Map<String, Map<int, String>> numberingDefinitions,
      Map<String, int> counters,
      String numId,
      int ilvl) {
    // Retrieve the format for the current level
    final String format = numberingDefinitions[numId]?[ilvl] ?? 'decimal';

    // Increment the counter for the given numId and ilvl
    final String key = '$numId-$ilvl';
    counters[key] = (counters[key] ?? 0) + 1;
    final int number = counters[key]!;

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
    final List<String> romanNumerals = <String>[
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
    final List<int> romanValues = <int>[
      1000,
      900,
      500,
      400,
      100,
      90,
      50,
      40,
      10,
      9,
      5,
      4,
      1
    ];
    String result = '';
    int i = 0;

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
    final List<Widget> widgets = <Widget>[];
    final Map<String, int> counters = <String, int>{};
    for (final XmlElement body in documentXml.findAllElements('w:body')) {
      for (final XmlElement element in body.children.whereType<XmlElement>()) {
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
    final List<TableRow> rows = <TableRow>[];
    TableBorder? tableBorder;
    final String? tableBorderStyleid =
        table.getElement("w:tblStyle")?.getAttribute('w:val');
    if (tableBorderStyleid != null) {
      tableBorder = _tablesBorders[tableBorderStyleid];
    }
    // Parse table border properties
    final TableBorderStyle borderStyle = _parseTableBorderStyle(table);

    // Store the number of cells in the first row to ensure all rows match this count
    int maxCells = 0;

    table.findAllElements('w:tr').forEach((XmlElement row) {
      final List<Widget> cells = <Widget>[];

      // Parse cells in each row
      row.findAllElements('w:tc').forEach((XmlElement cell) {
        final List<Widget> cellContent = <Widget>[];

        // Check for background fill color (shading)
        final Color backgroundColor = _parseCellBackgroundColor(cell);

        cell.findAllElements('w:p').forEach((XmlElement paragraph) {
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
    for (TableRow row in rows) {
      final int childrenCount = row.children.length;
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
    final String borderColor = table
            .getElement('w:tblBorders')
            ?.getElement('w:top')
            ?.getAttribute('w:color') ??
        '000000';
    final String borderWidth = table
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
    final XmlElement? shading = cell.getElement('w:shd');
    final String? fillColor = shading?.getAttribute('w:fill');

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
    final Iterable<XmlElement> content = sdtElement
        .findAllElements('w:sdtContent')
        .expand((XmlElement contentElement) => contentElement.children)
        .whereType<XmlElement>();

    final List<Widget> contentWidgets = content.map((XmlElement childElement) {
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
    final bool isBold = styleElement.findElements('w:b').isNotEmpty;
    final bool isItalic = styleElement.findElements('w:i').isNotEmpty;
    final bool isUnderline = styleElement.findElements('w:u').isNotEmpty;
    final bool isStrikeThrough =
        styleElement.findElements('w:strike').isNotEmpty;
    if (isUnderline) {
      textDecoration = TextDecoration.underline;
    } else if (isStrikeThrough) {
      textDecoration = TextDecoration.lineThrough;
    }
    // Parse font size (half-points to points)
    final double fontSize = double.tryParse(
          styleElement.getElement('w:sz')?.getAttribute('w:val') ?? '20',
        ) ??
        16.0;

    // Parse text color (if available)
    final String? colorHex =
        styleElement.findElements('w:color').firstOrNull?.getAttribute('w:val');
    final Color textColor =
        colorHex != null ? _hexToColor(colorHex) : Colors.black;

    // Ensure transparent colors are assigned black
    final Color effectiveTextColor =
        textColor == Colors.transparent ? Colors.black : textColor;

    // Parse background color (shading) for text background

    String? bgHex;
    final XmlElement? highlightElement = styleElement.getElement('w:highlight');
    final XmlElement? shadingElement = styleElement.getElement('w:shd');

    if (highlightElement != null) {
      bgHex = highlightElement.getAttribute('w:val');
    } else if (shadingElement != null) {
      bgHex = shadingElement.getAttribute('w:fill');
    }
    final Color backgroundColor = bgHex != null && bgHex != 'auto'
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
      fontSize: fontSize == 16 ? fontSize : fontSize / 2,
      // Word font size is in half-points
      color: effectiveTextColor,
      // Set the effective text color
      backgroundColor: backgroundColor, // Set the background color
    );
  }

  Color _hexToColor(String hex) {
    try {
      // Clean up the hex string by removing any '#' and converting it to uppercase
      final String hexColor = hex.replaceAll('#', '').toUpperCase();

      // If the hex code is 6 characters long (RGB), make it 8 by adding full opacity (FF)
      if (hexColor.length == 6) {
        return Color(int.parse('0xFF$hexColor'));
      }

      // If the hex code is 8 characters long (RGBA), use it directly
      if (hexColor.length == 8) {
        // Extract the alpha value (first 2 characters)
        final int alpha = int.parse(hexColor.substring(0, 2), radix: 16);

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
      return _getColorFromString(hex);
    }
  }

  Color _getColorFromString(String colorName) {
    // Define a map of supported colors
    Map<String, Color> colorMap = <String, Color>{
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

    // Return the color if found, else default to black
    return colorMap[colorName.toLowerCase()] ?? Colors.black;
  }
}

/// Wrapper for the Table border style
class TableBorderStyle {
  /// The color for the table border.
  final Color color;

  /// The width for the table border.
  final double width;

  ///Constructor
  TableBorderStyle({required this.color, required this.width});
}
