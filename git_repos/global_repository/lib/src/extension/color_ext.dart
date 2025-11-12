import 'dart:ui';

const int _opacty02 = 51;
const int _opacty04 = 102;
const int _opacty06 = 153;
const int _opacty08 = 204;

extension ColorExtension on Color {
  Color get opacty02 {
    return withAlpha(_opacty02);
  }

  Color get opacty04 {
    return withAlpha(_opacty04);
  }

  Color get opacty06 {
    return withAlpha(_opacty06);
  }

  Color get opacty08 {
    return withAlpha(_opacty08);
  }
}
