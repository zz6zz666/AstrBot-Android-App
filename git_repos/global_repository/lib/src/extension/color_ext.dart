import 'dart:ui';

const int _opacity02 = 51;
const int _opacity04 = 102;
const int _opacity06 = 153;
const int _opacity08 = 204;

extension ColorExtension on Color {
  Color get opacity02 {
    return withAlpha(_opacity02);
  }

  Color get opacity04 {
    return withAlpha(_opacity04);
  }

  Color get opacity06 {
    return withAlpha(_opacity06);
  }

  Color get opacity08 {
    return withAlpha(_opacity08);
  }
}
