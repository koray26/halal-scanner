import 'package:flutter_test/flutter_test.dart';
import 'package:halal_scanner/features/ocr/ocr_screen.dart';

void main() {
  test('Worttrennung am Zeilenende wird zusammengefügt', () {
    expect(OcrText.join(['Zutaten: Zucker, Emul-', 'gator (E471),', 'Mono- und', 'Diglyceride']),
        'Zutaten: Zucker, Emulgator (E471), Mono- und Diglyceride');
  });

  test('E-Nummern, Mengen und Klammern bleiben erhalten', () {
    expect(OcrText.join(['Kakao 7,4 %, Farbstoff:', 'E120 (Karmin)']),
        'Kakao 7,4 %, Farbstoff: E120 (Karmin)');
  });

  test('Nicht lateinische Schrift wird erkannt', () {
    expect(OcrText.looksLikeUnsupportedScript('سكر، جيلاتين، ملح، ماء'), isTrue);
    expect(OcrText.looksLikeUnsupportedScript('Zucker, Gelatine, Salz'), isFalse);
    expect(OcrText.looksLikeUnsupportedScript('#*~ ^^ ¤¤ §§ ** ##'), isTrue);
  });
}
