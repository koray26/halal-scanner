import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../domain/models.dart';
import '../../state/app_state.dart';
import '../result/result_screen.dart';

/// Zutatenliste fotografieren -> Text auf dem Gerät erkennen (ML Kit,
/// offline) -> anzeigen/korrigieren -> prüfen.
/// Das Foto wird nach der Texterkennung sofort gelöscht.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key, this.barcode, this.product});
  final String? barcode;
  final ProductRecord? product;

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

enum _Phase { intro, processing, review }

class _OcrScreenState extends State<OcrScreen> {
  _Phase _phase = _Phase.intro;
  final _text = TextEditingController();
  String _recognized = '';
  List<String> _uncertain = [];
  bool _completeConfirmed = false;
  bool _tooLittle = false;
  bool _unsupportedScript = false;
  String? _error;

  static final _header = RegExp(
      r'(zutaten|ingredients?|ingrédients?|içindekiler|ingredientes|ingredienti)',
      caseSensitive: false);

  Future<void> _pick(ImageSource source) async {
    final s = AppScope.read(context).strings;
    setState(() {
      _error = null;
    });
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
          source: source, imageQuality: 92, maxWidth: 2400, maxHeight: 2400);
    } catch (_) {
      setState(() => _error = s.t('ocr.error.camera'));
      return;
    }
    if (file == null) return;
    setState(() => _phase = _Phase.processing);

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
      final lines = <String>[];
      final uncertain = <String>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
          final c = line.confidence;
          if (c != null && c < 0.6) uncertain.add(line.text);
        }
      }
      _recognized = OcrText.join(lines);
      _unsupportedScript = OcrText.looksLikeUnsupportedScript(_recognized);
      _text.text = _recognized;
      _uncertain = uncertain;
      _tooLittle = _recognized.length < 15;
      _completeConfirmed = false;
      setState(() => _phase = _Phase.review);
    } catch (_) {
      setState(() {
        _phase = _Phase.intro;
        _error = s.t('ocr.error.read');
      });
    } finally {
      await recognizer.close();
      // Datensparsamkeit: Foto nicht aufbewahren.
      try {
        await File(file.path).delete();
      } catch (_) {}
    }
  }

  Future<void> _analyze() async {
    final state = AppScope.read(context);
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final edited = text != _recognized;
    final input = IngredientText(
      text: text,
      source: SourceRef(
        kind: edited ? SourceKind.userEdited : SourceKind.ocrPhoto,
        retrievedAt: state.now(),
      ),
      possiblyTruncated: !_completeConfirmed || !_header.hasMatch(text),
      uncertainFragments: edited ? const [] : _uncertain,
      unsupportedScript: _unsupportedScript,
    );
    final entry = await state.analyzeTexts([input],
        barcode: widget.barcode, product: widget.product);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(entry: entry)));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).strings;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('ocr.title'))),
      body: switch (_phase) {
        _Phase.processing => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: Gap.m),
              Text(s.t('ocr.processing')),
            ]),
          ),
        _Phase.intro => ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              AspectRatio(
                aspectRatio: 1.6,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.card),
                    border: Border.all(color: AppColors.gold, width: 3),
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  padding: const EdgeInsets.all(Gap.l),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.document_scanner_outlined, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: Gap.s),
                    Text(s.t('ocr.frame'), textAlign: TextAlign.center),
                  ]),
                ),
              ),
              const SizedBox(height: Gap.m),
              SectionCard(
                title: s.t('ocr.tips.title'),
                icon: Icons.tips_and_updates_outlined,
                child: Text(s.t('ocr.tips.body')),
              ),
              if (_error != null) ...[
                const SizedBox(height: Gap.m),
                Text(_error!, style: const TextStyle(color: AppColors.haram, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: Gap.l),
              FilledButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: Text(s.t('ocr.takePhoto')),
                onPressed: () => _pick(ImageSource.camera),
              ),
              const SizedBox(height: Gap.s),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(s.t('ocr.fromGallery')),
                onPressed: () => _pick(ImageSource.gallery),
              ),
              const SizedBox(height: Gap.m),
              Text(s.t('ocr.privacy'), style: theme.textTheme.bodySmall),
            ],
          ),
        _Phase.review => ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              if (_tooLittle)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.m),
                  child: MaterialBanner(
                    leading: const Icon(Icons.warning_amber, color: AppColors.unclear),
                    content: Text(s.t('ocr.tooLittle')),
                    actions: [
                      TextButton(
                          onPressed: () => setState(() => _phase = _Phase.intro),
                          child: Text(s.t('ocr.retake'))),
                    ],
                  ),
                ),
              if (_unsupportedScript)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.m),
                  child: MaterialBanner(
                    leading: const Icon(Icons.translate, color: AppColors.unclear),
                    content: Text(s.t('ocr.unsupportedScript')),
                    actions: [
                      TextButton(
                          onPressed: () => setState(() => _phase = _Phase.intro),
                          child: Text(s.t('ocr.retake'))),
                    ],
                  ),
                ),
              Text(s.t('ocr.review.title'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: Gap.xs),
              Text(s.t('ocr.review.body')),
              const SizedBox(height: Gap.m),
              TextField(
                controller: _text,
                minLines: 6,
                maxLines: 14,
                decoration: InputDecoration(labelText: s.t('ocr.recognized')),
              ),
              if (_uncertain.isNotEmpty) ...[
                const SizedBox(height: Gap.s),
                Text(s.t('ocr.uncertain', {'items': _uncertain.join(' | ')}),
                    style: const TextStyle(color: AppColors.unclear, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: Gap.m),
              CheckboxListTile(
                value: _completeConfirmed,
                onChanged: (v) => setState(() => _completeConfirmed = v ?? false),
                title: Text(s.t('ocr.confirmComplete')),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: Gap.m),
              FilledButton.icon(
                icon: const Icon(Icons.fact_check),
                label: Text(s.t('ocr.analyze')),
                onPressed: _analyze,
              ),
              const SizedBox(height: Gap.s),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(s.t('ocr.retake')),
                onPressed: () => setState(() => _phase = _Phase.intro),
              ),
              const SizedBox(height: Gap.m),
              Text(s.t('ocr.notice'), style: theme.textTheme.bodySmall),
            ],
          ),
      },
    );
  }
}

/// Hilfsfunktionen für erkannten Text (testbar ohne Kamera).
class OcrText {
  OcrText._();

  /// Fügt Zeilen zusammen und repariert Worttrennungen am Zeilenende
  /// ("Emul-" + "gator" -> "Emulgator"). Bindestriche in Wörtern wie
  /// "Mono- und" bleiben erhalten, weil danach ein Leerzeichen folgt.
  static String join(List<String> lines) {
    final buf = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
      final hyphenated = RegExp(r'\p{Ll}-$', unicode: true).hasMatch(l) &&
          RegExp(r'^\p{Ll}', unicode: true).hasMatch(next);
      if (hyphenated) {
        buf.write(l.substring(0, l.length - 1));
      } else {
        buf.write(l);
        buf.write(' ');
      }
    }
    return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Viele Fragezeichen/Sonderzeichen oder kaum Buchstaben deuten auf eine
  /// nicht unterstützte Schrift (z. B. Arabisch) oder ein unlesbares Foto hin.
  static bool looksLikeUnsupportedScript(String text) {
    if (text.isEmpty) return false;
    final nonLatinLetters =
        RegExp(r'[\p{Script=Arabic}\p{Script=Cyrillic}\p{Script=Han}\p{Script=Hebrew}\p{Script=Devanagari}\p{Script=Bengali}]', unicode: true)
            .allMatches(text)
            .length;
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(text).length;
    final noise = RegExp(r'[^\p{L}\p{N}\s,.;:()%\-/&+]', unicode: true).allMatches(text).length;
    if (letters == 0) return true;
    return nonLatinLetters > letters * 0.2 || noise > text.length * 0.15;
  }
}
