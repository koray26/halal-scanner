/// Lokaler Verlauf und Favoriten – nur auf dem Gerät gespeichert.
/// Es werden keine Fotos gespeichert, nur Texte und Ergebnisse.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';
import '../domain/rules/halal_engine.dart';

class ScanEntry {
  ScanEntry({
    required this.id,
    required this.createdAt,
    required this.verdict,
    this.barcode,
    this.product,
    this.analyzedTexts = const [],
    this.sourceChecks = const [],
    this.favorite = false,
  });

  final String id;
  final DateTime createdAt;
  final String? barcode;
  final ProductRecord? product;

  /// Texte, die tatsächlich ausgewertet wurden (z. B. OCR / korrigiert).
  final List<IngredientText> analyzedTexts;

  /// Welche Produktquellen bei diesem Scan abgefragt wurden und mit welchem Ergebnis.
  final List<SourceCheck> sourceChecks;
  final Verdict verdict;
  bool favorite;

  String get title =>
      product?.name ?? (barcode != null ? barcode! : 'photo');

  ScanEntry copyWith({Verdict? verdict, ProductRecord? product,
          List<IngredientText>? analyzedTexts, DateTime? createdAt}) =>
      ScanEntry(
        id: id,
        createdAt: createdAt ?? this.createdAt,
        verdict: verdict ?? this.verdict,
        barcode: barcode,
        product: product ?? this.product,
        analyzedTexts: analyzedTexts ?? this.analyzedTexts,
        sourceChecks: sourceChecks,
        favorite: favorite,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'barcode': barcode,
        'product': product?.toJson(),
        'analyzedTexts': analyzedTexts.map((t) => t.toJson()).toList(),
        'verdict': verdict.toJson(),
        'sourceChecks': sourceChecks.map((c) => c.toJson()).toList(),
        'favorite': favorite,
      };

  factory ScanEntry.fromJson(Map<String, dynamic> j) => ScanEntry(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        barcode: j['barcode'] as String?,
        product: j['product'] == null
            ? null
            : ProductRecord.fromJson(j['product'] as Map<String, dynamic>),
        analyzedTexts: ((j['analyzedTexts'] as List?) ?? const [])
            .map((e) => IngredientText.fromJson(e as Map<String, dynamic>))
            .toList(),
        verdict: Verdict.fromJson(j['verdict'] as Map<String, dynamic>),
        sourceChecks: ((j['sourceChecks'] as List?) ?? const [])
            .map((e) => SourceCheck.fromJson(e as Map<String, dynamic>))
            .toList(),
        favorite: j['favorite'] as bool? ?? false,
      );
}

class HistoryStore {
  static const _key = 'scan_history_v1';
  static const maxEntries = 200;

  Future<List<ScanEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final out = <ScanEntry>[];
      for (final e in list) {
        try {
          out.add(ScanEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // Beschädigten Eintrag überspringen statt alles zu verlieren.
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<ScanEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    // Favoriten werden nie automatisch gelöscht.
    final kept = <ScanEntry>[];
    var nonFav = 0;
    for (final e in entries) {
      if (e.favorite) {
        kept.add(e);
      } else if (nonFav < maxEntries) {
        kept.add(e);
        nonFav++;
      }
    }
    await prefs.setString(
        _key, jsonEncode(kept.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class SettingsStore {
  static const _lang = 'language';
  static const _theme = 'theme_mode';

  Future<String?> loadLanguage() async =>
      (await SharedPreferences.getInstance()).getString(_lang);
  Future<void> saveLanguage(String code) async =>
      (await SharedPreferences.getInstance()).setString(_lang, code);

  Future<String?> loadTheme() async =>
      (await SharedPreferences.getInstance()).getString(_theme);
  Future<void> saveTheme(String mode) async =>
      (await SharedPreferences.getInstance()).setString(_theme, mode);
}
