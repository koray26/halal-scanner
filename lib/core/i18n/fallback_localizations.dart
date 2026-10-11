/// Ersatz für Flutter-Standardtexte (Bedienelemente wie „Zurück“, „Einfügen“)
/// in Sprachen, für die Flutter selbst keine Übersetzung mitbringt
/// (z. B. Hausa). Dann werden die englischen Standardtexte verwendet.
///
/// Betrifft nur Flutter-interne Texte. Alle Texte der App kommen aus
/// assets/i18n; die Schreibrichtung setzt die App selbst (siehe app.dart).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _fallback = Locale('en');

class FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      !kMaterialSupportedLanguages.contains(locale.languageCode);

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(FallbackMaterialLocalizationsDelegate old) => false;
}

class FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      !kCupertinoSupportedLanguages.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(FallbackCupertinoLocalizationsDelegate old) => false;
}

class FallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      !kWidgetsSupportedLanguages.contains(locale.languageCode);

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(FallbackWidgetsLocalizationsDelegate old) => false;
}
