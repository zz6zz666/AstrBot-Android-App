import 'dart:math';
import 'dart:ui';

num _linearizeColorComponent(double component) {
  if (component <= 0.03928) {
    return component / 12.92;
  } else {
    return pow((component + 0.055) / 1.055, 2.4);
  }
}

double _relativeLuminance(Color color) {
  final r = _linearizeColorComponent(color.red / 255.0);
  final g = _linearizeColorComponent(color.green / 255.0);
  final b = _linearizeColorComponent(color.blue / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color color1, Color color2) {
  final luminance1 = _relativeLuminance(color1);
  final luminance2 = _relativeLuminance(color2);
  final brightest = max(luminance1, luminance2);
  final darkest = min(luminance1, luminance2);
  return (brightest + 0.05) / (darkest + 0.05);
}

void main() {
  final color1 = Color(0xff141414);
  final color2 = Color(0xff050505);
  final contrast = contrastRatio(color1, color2);
  print('Contrast ratio: $contrast');
}
