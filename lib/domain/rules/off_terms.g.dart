// GENERIERT von tool/off_terms/extract_off_terms.mjs – nicht von Hand ändern.
// Quelle: Open Food Facts, taxonomies/food/ingredients.txt und taxonomies/additives.txt, Stand 8852423.
// Lizenz der Daten: Open Database License (ODbL), (c) Open Food Facts.
//
// Zutatenbezeichnungen in Sprachen ohne eigene Wortlisten. Jeder Begriff
// erbt die Regel, die die BESTEHENDEN englischen Wortlisten für den
// englischen Namen desselben Wörterbuch-Eintrags auslösen. Mehrdeutige
// Begriffe sind entfernt. Diese Begriffe erkennen HARAM/UNKLAR, ermöglichen
// aber nie ein grünes Ergebnis (Sprachen ohne Freigabe für Grün).
// ignore_for_file: lines_longer_than_80_chars
library;

/// Sprache -> Regel-ID -> Regex-Muster (Ganzwort, ohne Groß-/Kleinschreibung).
const Map<String, Map<String, List<String>>> offTermPatterns = {
  'ar': {
    'alcohol_declared': [r'إيثانول'],
    'alcoholic_beverage': [r'براندي', r'شامبانيا', r'ليكير', r'ميرين', r'نبيذ', r'نبيذ\s+أبيض', r'نبيذ\s+أحمر', r'نبيذ\s+فوار', r'نبيذ\s+مارسالا'],
    'animal_fat': [r'دهن\s+حيواني'],
    'cheese': [r'بارميجيانو\s+ريجيانو', r'جبن', r'جبن\s+الماعز', r'جبنة\s+تشيدر', r'جبنة\s+زرقاء', r'موتزاريلا'],
    'e_number_animal_possible': [r'أحادي\s+ستيرات\s+الغليسرول', r'إينوسينات\s+ثنائية\s+الصوديوم', r'استرات\s+الأحماض\s+الدهنية\s+الأحادية\s+وثنائية\s+الجليسريد', r'ستيرات\s+المغنسيوم', r'غوانيلات\s+ثنائية\s+الصوديوم', r'مونوهيدرات\s+هيدروكلوريد\s+l-سيستين'],
    'gelatine': [r'جيلاتين', r'كولاجين', r'كولاجين\s+متحلل'],
    'insect_derived': [r'شيلاك'],
    'meat': [r'باكون', r'دجاج\s+رومي', r'دهن\s+الدجاج', r'دواجن', r'سلامي', r'عظم', r'قشرة\s+لحم\s+الخنزير', r'لحم\s+الماعز', r'لحم\s+خيل'],
    'pork': [r'قشرة\s+لحم\s+الخنزير'],
    'rennet': [r'منفحة'],
    'seafood_non_fish': [r'أخطبوط\s+شائع', r'سبيدج', r'محار'],
    'whey': [r'بروتين\s+مصل\s+اللبن', r'مصل\s+اللبن'],
    'wine_vinegar': [r'خل\s+بلسميك'],
  },
  'id': {
    'alcoholic_beverage': [r'brendi', r'likeur', r'sampanye'],
    'cheese': [r'keju', r'keju\s+västerbotten'],
    'e_number_animal_possible': [r'dinatrium\s+guanilat'],
    'flavouring': [r'perisa\s+alami\s+lemon'],
    'gelatine': [r'kolagen'],
    'meat': [r'daging\s+domba', r'daging\s+kalkun', r'daging\s+kambing', r'daging\s+kelinci', r'daging\s+kuda', r'kalkun', r'tulang', r'unggas'],
    'seafood_non_fish': [r'cumi-cumi', r'kupang', r'tiram', r'udang'],
    'whey': [r'laktoserum', r'protein\s+susu'],
  },
  'ms': {
    'alcoholic_beverage': [r'brandi', r'syeri', r'wain'],
    'cheese': [r'keju', r'keju\s+kambing'],
    'flavouring': [r'ekstrak\s+vanila'],
    'gelatine': [r'kolagen'],
    'insect_derived': [r'syelek'],
    'meat': [r'daging\s+kambing', r'daging\s+kuda', r'tulang', r'unggas'],
    'rennet': [r'renet'],
    'seafood_non_fish': [r'sotong', r'tiram'],
  },
  'ur': {
    'alcohol_declared': [r'ایتھنول'],
    'alcoholic_beverage': [r'برینڈی', r'شراب', r'شیری', r'میرین'],
    'cheese': [r'موزاریلا', r'پنیر'],
    'meat': [r'بیکن', r'سالامی', r'ہڈی'],
    'rennet': [r'خامرہ'],
    'seafood_non_fish': [r'قیر\s+ماہی\s+مچھلی'],
  },
  'bn': {
    'alcohol_declared': [r'ইথানল'],
    'alcoholic_beverage': [r'মিরিন'],
    'cheese': [r'চিজ', r'ছাগল\s+পনির', r'মজারেলা\s+পনির'],
    'gelatine': [r'জেলাটিন'],
    'insect_derived': [r'লাক্ষা'],
    'meat': [r'টার্কি', r'পোল্ট্রি', r'শূকরচর্ম', r'হাড়'],
    'pork': [r'শূকরচর্ম'],
    'rennet': [r'উৎসেচক'],
    'seafood_non_fish': [r'চিংড়ি', r'ঝিনুক', r'স্কুইড'],
    'whey': [r'ঘোল'],
  },
  'hi': {
    'alcohol_declared': [r'इथेनॉल'],
    'alcoholic_beverage': [r'ब्रांडी', r'मीरीन', r'शराब', r'शराब्'],
    'cheese': [r'चीज़', r'मोत्ज़ारेला'],
    'gelatine': [r'कोलेजन', r'जिलेटिन'],
    'insect_derived': [r'चपड़ा'],
    'meat': [r'अस्थि', r'टर्की', r'पोर्क\s+का\s+छिलका', r'पोल्ट्री'],
    'pork': [r'पोर्क\s+का\s+छिलका'],
    'rennet': [r'प्रकिण्व'],
    'seafood_non_fish': [r'ऑक्टोपस', r'विद्रूप'],
    'whey': [r'मट्ठा\s+प्रोटीन'],
  },
  'fa': {
    'alcohol_declared': [r'اتانول'],
    'alcoholic_beverage': [r'برندی', r'جین', r'شامپاین', r'شراب', r'شراب\s+تقویت\s+شده', r'شراب\s+سرخ', r'شراب\s+سفید', r'شراب\s+مارسالا', r'شراب\s+گازدار', r'لیکور', r'میرین'],
    'cheese': [r'موزارلا', r'پنیر', r'پنیر\s+آبی', r'پنیر\s+شیر\s+گوسفند', r'پنیر\s+پارمیجانو', r'پنیر\s+چدار', r'پنیر\s+گودا'],
    'e_number_animal_possible': [r'دی‌سدیم\s+اینوزینات', r'دی‌سدیم\s+گوانیلات', r'منیزیم\s+استارات', r'گیسرول\s+مونوستارات'],
    'gelatine': [r'ژلاتین', r'کلاژن'],
    'insect_derived': [r'شلاک'],
    'meat': [r'استخوان', r'بوقلمون', r'بیکن', r'سالامی', r'ماکیان', r'گوشت\s+اسب', r'گوشت\s+بوقلمون'],
    'pork': [r'چربی\s+خوک'],
    'rennet': [r'آنزیم'],
    'seafood_non_fish': [r'صدف\s+خوراکی', r'صدف\s+سیاه', r'ماهی\s+مرکب', r'میگو', r'هشت‌پای\s+معمولی'],
    'whey': [r'آب‌پنیر', r'پروتیین\s+وی'],
    'wine_vinegar': [r'سرکه\s+بالزامیک'],
  },
  'ha': {
  },
};
