import 'dart:convert' show base64Decode;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:pdf/widgets.dart' as pw;

/// Renders Bangla text through Flutter's own text engine (which shapes
/// Bengali pre-base vowel signs — ি/ে/ৈ — correctly) and hands the result
/// to `package:pdf` as an image, instead of `pw.Text`.
///
/// `package:pdf`'s built-in text layout doesn't reorder those vowel signs,
/// so words like "রিপোর্ট" or "সেপ্টেম্বর" come out visibly corrupted. Since
/// this app already ships the NotoSansBengali font and registers it with
/// the Flutter engine at startup (see pubspec.yaml `fonts:`), rasterizing
/// through `dart:ui`'s Paragraph API — the same engine every on-screen
/// Bangla `Text` widget already renders correctly with — sidesteps the bug
/// entirely. Pure-Arabic-numeral/Bangla-digit strings (amounts, dates)
/// don't need this: those glyphs never reorder, so they stay as crisp,
/// selectable `pw.Text` in the PDF.
class BanglaPdfText {
  /// Pixel-to-PDF-point scale used when rasterizing — a higher value keeps
  /// the embedded image crisp when printed, at the cost of PDF file size.
  static const double _pixelRatio = 3;

  static final Map<String, _Rendered> _cache = {};

  static final Uint8List _transparentPixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  /// Renders [text] and returns a `pw.Widget` of the given text's natural
  /// size (in PDF points). Results are cached by their full style+text key
  /// since the same labels (headers, "সর্বমোট", …) repeat often.
  static Future<pw.Widget> widget(
    String text, {
    required double fontSize,
    bool bold = false,
    ui.Color color = const ui.Color(0xFF000000),
  }) async {
    final key = '$text|$fontSize|$bold|${color.toARGB32()}';
    final rendered = _cache[key] ?? await _render(text, fontSize: fontSize, bold: bold, color: color);
    _cache[key] = rendered;
    return pw.Image(rendered.image, width: rendered.widthPt, height: rendered.heightPt);
  }

  static Future<_Rendered> _render(
    String text, {
    required double fontSize,
    required bool bold,
    required ui.Color color,
  }) async {
    if (text.isEmpty) {
      return _Rendered(pw.MemoryImage(_transparentPixel), 0.1, 0.1);
    }

    final style = ui.ParagraphStyle(
      fontFamily: 'NotoSansBengali',
      fontSize: fontSize * _pixelRatio,
      fontWeight: bold ? ui.FontWeight.bold : ui.FontWeight.normal,
    );
    final builder = ui.ParagraphBuilder(style)
      ..pushStyle(ui.TextStyle(color: color))
      ..addText(text);
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 4000));

    final width = paragraph.longestLine.clamp(1, 4000).ceilToDouble();
    final height = paragraph.height.clamp(1, 4000).ceilToDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
    canvas.drawParagraph(paragraph, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();

    return _Rendered(
      pw.MemoryImage(byteData!.buffer.asUint8List()),
      width / _pixelRatio,
      height / _pixelRatio,
    );
  }

  static void clearCache() => _cache.clear();
}

class _Rendered {
  final pw.MemoryImage image;
  final double widthPt;
  final double heightPt;
  _Rendered(this.image, this.widthPt, this.heightPt);
}
