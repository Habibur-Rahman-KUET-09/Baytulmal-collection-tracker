import 'dart:io';
import 'package:image/image.dart' as img;

// Dark greenish-black background for the adaptive icon, chosen to sit
// noticeably darker than the shield artwork's own teal fill.
const int _bgR = 0x08, _bgG = 0x1A, _bgB = 0x15;

void main() {
  final src = img.decodePng(File('assets/icon/app_icon_source.png').readAsBytesSync())!;
  final w = src.width, h = src.height;

  // Find the tight bounding box of non-transparent pixels.
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (src.getPixel(x, y).a > 10) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final contentW = maxX - minX + 1;
  final contentH = maxY - minY + 1;
  print('content bbox: $minX,$minY -> $maxX,$maxY ($contentW x $contentH of $w x $h)');

  const canvasSize = 1024;
  const marginFraction = 0.06; // small, even margin -> the badge fills most of the frame
  final targetContent = (canvasSize * (1 - 2 * marginFraction)).round();
  final scale = targetContent / (contentW > contentH ? contentW : contentH);

  final cropped = img.copyCrop(src, x: minX, y: minY, width: contentW, height: contentH);
  final resized = img.copyResize(
    cropped,
    width: (contentW * scale).round(),
    height: (contentH * scale).round(),
    interpolation: img.Interpolation.cubic,
  );

  // Transparent foreground (for the adaptive icon foreground layer).
  final fg = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  final offsetX = (canvasSize - resized.width) ~/ 2;
  final offsetY = (canvasSize - resized.height) ~/ 2;
  img.compositeImage(fg, resized, dstX: offsetX, dstY: offsetY);
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // Flattened, opaque composite (for the legacy/iOS icon).
  final flat = img.Image(width: canvasSize, height: canvasSize);
  img.fill(flat, color: img.ColorRgb8(_bgR, _bgG, _bgB));
  img.compositeImage(flat, resized, dstX: offsetX, dstY: offsetY);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(flat));

  print('done');
}
