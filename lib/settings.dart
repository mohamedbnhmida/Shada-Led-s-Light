import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const shadaYellow = Color(0xFFF8D91F); // sampled from the Shada logo
const shadaSlate = Color(0xFF303E47);

/// Theme mode + language, persisted.
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale; // null = follow the phone

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[p.getInt('theme') ?? 0];
    final l = p.getString('lang');
    locale = l == null ? null : Locale(l);
  }

  Future<void> set({ThemeMode? theme, Locale? lang, bool systemLang = false}) async {
    themeMode = theme ?? themeMode;
    locale = systemLang ? null : lang ?? locale;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('theme', themeMode.index);
    locale == null ? await p.remove('lang') : await p.setString('lang', locale!.languageCode);
  }
}

final settings = AppSettings();

/// Brand colours that differ between light and dark.
class Palette extends ThemeExtension<Palette> {
  final Color bg, card, muted, nav, off, track;
  const Palette(
      {required this.bg, required this.card, required this.muted, required this.nav, required this.off, required this.track});

  static const dark = Palette(
      bg: shadaSlate,
      card: Color(0xFF3B4A54),
      muted: Color(0xFFA3AFB8),
      nav: Color(0xFF26323A),
      off: Color(0xFF26323A),
      track: Color(0x33000000));
  static const light = Palette(
      bg: Color(0xFFF2F4F6),
      card: Colors.white,
      muted: Color(0xFF6B7782),
      nav: Colors.white,
      off: Color(0xFFD5DBE0),
      track: Color(0x14303E47));

  @override
  Palette copyWith() => this;
  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : other ?? this;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: shadaYellow,
    brightness: b,
    primary: b == Brightness.dark ? shadaYellow : shadaSlate,
    onPrimary: b == Brightness.dark ? shadaSlate : Colors.white,
    surface: p.bg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    fontFamily: 'Almarai',
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
  );
}

extension Ctx on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;

  /// Translated string; `{n}` / `{x}` placeholders are filled from [args].
  String t(String key, [Map<String, Object> args = const {}]) {
    final lang = Localizations.localeOf(this).languageCode;
    var s = (_strings[lang] ?? _strings['en']!)[key] ?? _strings['en']![key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}

const supportedLocales = [Locale('en'), Locale('fr'), Locale('ar')];
const languageNames = {'en': 'English', 'fr': 'Français', 'ar': 'العربية'};

const _strings = <String, Map<String, String>>{
  'en': {
    'steps_one': '1 step',
    'bt_remind': 'Turn it on so your lamp schedules and scenes can run.',
    'duration': 'Duration',
    'then_off': 'Then the lamp turns off',
    'bg_text': 'Running in background',
    'on_action': 'Turn on',
    'scene_action': 'Scene',
    'hue': 'Hue',
    'try_lamp': 'Try on lamp',
    'repeat': 'Repeat',
    'off_hint': 'The lamp will switch off at this time.',
    'new_schedule': 'New schedule',
    'edit_schedule': 'Edit schedule',
    'retrying': 'Lamp not reachable yet. Still trying, make sure it is switched on and nearby.',
    'preset_sunrise': 'Sunrise',
    'preset_sunset': 'Sunset',
    'preset_relax': 'Relax',
    'preset_reading': 'Reading',
    'preset_night': 'Night light',
    'preset_candle': 'Candle',
    'preset_ocean': 'Ocean',
    'preset_rainbow': 'Rainbow',
    'preset_party': 'Party',
    'step': 'Step {n}',
    'bt_off_title': 'Bluetooth is off',
    'bt_off_hint': 'Turn on Bluetooth to control your lamp.',
    'turn_on': 'Turn on Bluetooth',
    'lamp': 'Lamp',
    'address': 'Address',
    'status': 'Status',
    'smart_bulb': 'smart bulb',
    'looking': 'Looking for bulbs…',
    'found': '{n} found',
    'scan': 'Scan',
    'no_bulb': 'No bulb found.\nScrew it in, switch it on and stay close.',
    'bulb_default': "LED's light bulb",
    'light': 'Light',
    'scenes': 'Scenes',
    'schedules': 'Schedules',
    'switch_bulb': 'Switch bulb',
    'connected': 'Connected',
    'connecting': 'Connecting…',
    'connecting_title': 'Connecting to your lamp',
    'connecting_hint': 'Make sure the lamp is switched on and close to your phone.',
    'retry': 'Retry',
    'settings': 'Settings',
    'theme': 'Theme',
    'system': 'System',
    'light_theme': 'Light',
    'dark': 'Dark',
    'language': 'Language',
    'color': 'Color',
    'white': 'White',
    'brightness': 'Brightness',
    'quick_colors': 'Quick colors',
    'warm_white': 'Warm white 2700K',
    'steps': '{n} steps',
    'edit_scene': 'Edit scene',
    'add_current': 'Add current light',
    'name': 'Name',
    'loop': 'Loop',
    'loop_sub': 'Repeat until stopped',
    'tip': 'Tip: set a colour on the Light tab, then add it here.',
    'fade': 'Fade',
    'hold': 'Hold',
    'use_current': 'Use current light',
    'my_scene': 'My scene',
    'no_sched': 'No schedules yet',
    'turn_off': 'Turn off',
    'deleted_scene': 'Deleted scene',
    'action': 'Action',
    'play': 'Play "{x}"',
    'delete': 'Delete',
    'save': 'Save',
    'days': 'M,T,W,T,F,S,S',
  },
  'fr': {
    'steps_one': '1 étape',
    'bt_remind': 'Activez-le pour que les programmes et scènes de votre lampe fonctionnent.',
    'duration': 'Durée',
    'then_off': "Ensuite la lampe s'éteint",
    'bg_text': 'Fonctionne en arrière-plan',
    'on_action': 'Allumer',
    'scene_action': 'Scène',
    'hue': 'Teinte',
    'try_lamp': 'Essayer sur la lampe',
    'repeat': 'Répéter',
    'off_hint': "La lampe s'éteindra à cette heure.",
    'new_schedule': 'Nouveau programme',
    'edit_schedule': 'Modifier le programme',
    'retrying': "La lampe n'est pas encore joignable. Nouvelle tentative, vérifiez qu'elle est allumée et proche.",
    'preset_sunrise': 'Lever du soleil',
    'preset_sunset': 'Coucher du soleil',
    'preset_relax': 'Détente',
    'preset_reading': 'Lecture',
    'preset_night': 'Veilleuse',
    'preset_candle': 'Bougie',
    'preset_ocean': 'Océan',
    'preset_rainbow': 'Arc-en-ciel',
    'preset_party': 'Fête',
    'step': 'Étape {n}',
    'bt_off_title': 'Bluetooth désactivé',
    'bt_off_hint': 'Activez le Bluetooth pour contrôler votre lampe.',
    'turn_on': 'Activer le Bluetooth',
    'lamp': 'Lampe',
    'address': 'Adresse',
    'status': 'État',
    'smart_bulb': 'ampoule connectée',
    'looking': 'Recherche d\'ampoules…',
    'found': '{n} trouvée(s)',
    'scan': 'Rechercher',
    'no_bulb': 'Aucune ampoule trouvée.\nVissez-la, allumez-la et restez à proximité.',
    'bulb_default': "Ampoule LED's light",
    'light': 'Lumière',
    'scenes': 'Scènes',
    'schedules': 'Programmes',
    'switch_bulb': 'Changer d\'ampoule',
    'connected': 'Connectée',
    'connecting': 'Connexion…',
    'connecting_title': 'Connexion à votre lampe',
    'connecting_hint': 'Vérifiez que la lampe est allumée et proche de votre téléphone.',
    'retry': 'Réessayer',
    'settings': 'Paramètres',
    'theme': 'Thème',
    'system': 'Système',
    'light_theme': 'Clair',
    'dark': 'Sombre',
    'language': 'Langue',
    'color': 'Couleur',
    'white': 'Blanc',
    'brightness': 'Luminosité',
    'quick_colors': 'Couleurs rapides',
    'warm_white': 'Blanc chaud 2700K',
    'steps': '{n} étapes',
    'edit_scene': 'Modifier la scène',
    'add_current': 'Ajouter la lumière actuelle',
    'name': 'Nom',
    'loop': 'Boucle',
    'loop_sub': 'Répéter jusqu\'à l\'arrêt',
    'tip': 'Astuce : réglez une couleur dans l\'onglet Lumière, puis ajoutez-la ici.',
    'fade': 'Fondu',
    'hold': 'Fixe',
    'use_current': 'Utiliser la lumière actuelle',
    'my_scene': 'Ma scène',
    'no_sched': 'Aucun programme',
    'turn_off': 'Éteindre',
    'deleted_scene': 'Scène supprimée',
    'action': 'Action',
    'play': 'Lancer « {x} »',
    'delete': 'Supprimer',
    'save': 'Enregistrer',
    'days': 'L,M,M,J,V,S,D',
  },
  'ar': {
    'steps_one': 'خطوة واحدة',
    'bt_remind': 'شغّله لكي تعمل جداول ومشاهد المصباح.',
    'duration': 'المدة',
    'then_off': 'ثم ينطفئ المصباح',
    'bg_text': 'يعمل في الخلفية',
    'on_action': 'تشغيل',
    'scene_action': 'مشهد',
    'hue': 'اللون',
    'try_lamp': 'جرّب على المصباح',
    'repeat': 'التكرار',
    'off_hint': 'سيتم إطفاء المصباح في هذا الوقت.',
    'new_schedule': 'جدول جديد',
    'edit_schedule': 'تعديل الجدول',
    'retrying': 'لا يمكن الوصول إلى المصباح بعد. جارٍ إعادة المحاولة، تأكد من أنه مشغّل وقريب.',
    'preset_sunrise': 'شروق الشمس',
    'preset_sunset': 'غروب الشمس',
    'preset_relax': 'استرخاء',
    'preset_reading': 'قراءة',
    'preset_night': 'ضوء ليلي',
    'preset_candle': 'شمعة',
    'preset_ocean': 'محيط',
    'preset_rainbow': 'قوس قزح',
    'preset_party': 'حفلة',
    'step': 'الخطوة {n}',
    'bt_off_title': 'البلوتوث مغلق',
    'bt_off_hint': 'شغّل البلوتوث للتحكم في المصباح.',
    'turn_on': 'تشغيل البلوتوث',
    'lamp': 'المصباح',
    'address': 'العنوان',
    'status': 'الحالة',
    'smart_bulb': 'مصباح ذكي',
    'looking': 'جارٍ البحث عن المصابيح…',
    'found': 'تم العثور على {n}',
    'scan': 'بحث',
    'no_bulb': 'لم يتم العثور على أي مصباح.\nركّب المصباح وشغّله وابقَ قريبًا منه.',
    'bulb_default': "مصباح LED's light",
    'light': 'الإضاءة',
    'scenes': 'المشاهد',
    'schedules': 'الجداول',
    'switch_bulb': 'تغيير المصباح',
    'connected': 'متصل',
    'connecting': 'جارٍ الاتصال…',
    'connecting_title': 'جارٍ الاتصال بالمصباح',
    'connecting_hint': 'تأكد من أن المصباح مشغّل وقريب من هاتفك.',
    'retry': 'إعادة المحاولة',
    'settings': 'الإعدادات',
    'theme': 'المظهر',
    'system': 'النظام',
    'light_theme': 'فاتح',
    'dark': 'داكن',
    'language': 'اللغة',
    'color': 'ألوان',
    'white': 'أبيض',
    'brightness': 'السطوع',
    'quick_colors': 'ألوان سريعة',
    'warm_white': 'أبيض دافئ 2700K',
    'steps': '{n} خطوات',
    'edit_scene': 'تعديل المشهد',
    'add_current': 'إضافة الإضاءة الحالية',
    'name': 'الاسم',
    'loop': 'تكرار',
    'loop_sub': 'التكرار حتى الإيقاف',
    'tip': 'نصيحة: اختر لونًا من تبويب الإضاءة ثم أضفه هنا.',
    'fade': 'تلاشٍ',
    'hold': 'ثابت',
    'use_current': 'استخدام الإضاءة الحالية',
    'my_scene': 'مشهدي',
    'no_sched': 'لا توجد جداول بعد',
    'turn_off': 'إطفاء',
    'deleted_scene': 'مشهد محذوف',
    'action': 'الإجراء',
    'play': 'تشغيل «{x}»',
    'delete': 'حذف',
    'save': 'حفظ',
    'days': 'ن,ث,ر,خ,ج,س,ح',
  },
};
