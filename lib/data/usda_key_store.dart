/// Speicher für einen optionalen, persönlichen USDA-Schlüssel (api.data.gov).
///
/// - In der App ist kein Schlüssel eingebaut. Nur wer selbst einen kostenlosen
///   Schlüssel einträgt, nutzt USDA FoodData Central.
/// - Ablage im sicheren Speicher des Betriebssystems: Schlüsselbund (iPhone,
///   nur dieses Gerät, nicht im Backup) bzw. Android-Keystore-verschlüsselt.
/// - Nicht in shared_preferences, nicht im Verlauf, nicht in Exporten.
/// - Fehler beim Lesen (z. B. nach Wiederherstellung eines Backups) gelten als
///   „kein Schlüssel“ – die App funktioniert dann wie ohne USDA.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UsdaKeyStore {
  UsdaKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock_this_device),
              aOptions: AndroidOptions(resetOnError: true),
            );

  final FlutterSecureStorage _storage;
  static const _name = 'usda_fdc_api_key';

  /// Prüft die Eingabe grob (api.data.gov-Schlüssel: Buchstaben/Ziffern).
  /// Liefert den bereinigten Schlüssel oder `null`, wenn er ungültig aussieht.
  static String? normalize(String input) {
    final key = input.trim();
    return RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(key) ? key : null;
  }

  Future<String?> read() async {
    try {
      final v = await _storage.read(key: _name);
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  /// Gibt `false` zurück, wenn der Speicher den Schlüssel nicht annimmt.
  Future<bool> write(String key) async {
    try {
      await _storage.write(key: _name, value: key);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> delete() async {
    try {
      await _storage.delete(key: _name);
    } catch (_) {
      // Nichts gespeichert oder Speicher nicht verfügbar – nichts zu tun.
    }
  }
}
