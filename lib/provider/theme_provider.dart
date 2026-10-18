import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named accent colour offered in the colour scheme editor.
class AccentPreset {
  const AccentPreset(this.name, this.color);

  final String name;
  final Color color;
}

/// A palette style ([DynamicSchemeVariant]) with a Bosnian label.
class PaletteStyle {
  const PaletteStyle(this.variant, this.name, this.description);

  final DynamicSchemeVariant variant;
  final String name;
  final String description;
}

/// Appearance settings: light/dark mode and the colour scheme (accent colour,
/// palette style, contrast, or the device's wallpaper colours).
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs);

  final SharedPreferences _prefs;

  static const _modeKey = 'theme_mode';
  static const _seedKey = 'theme_seed';
  static const _deviceKey = 'theme_device_colors';
  static const _variantKey = 'theme_variant';
  static const _contrastKey = 'theme_contrast';

  static const Color defaultSeed = Color(0xFF1E5AA8);

  static const List<AccentPreset> presets = [
    AccentPreset('FIT plava', Color(0xFF1E5AA8)),
    AccentPreset('Nebo', Color(0xFF0288D1)),
    AccentPreset('Tirkiz', Color(0xFF00897B)),
    AccentPreset('Zelena', Color(0xFF2E7D32)),
    AccentPreset('Maslina', Color(0xFF6B7B2C)),
    AccentPreset('Jantar', Color(0xFFF9A825)),
    AccentPreset('Narandžasta', Color(0xFFEF6C00)),
    AccentPreset('Crvena', Color(0xFFC62828)),
    AccentPreset('Ruža', Color(0xFFD81B60)),
    AccentPreset('Ljubičasta', Color(0xFF7B1FA2)),
    AccentPreset('Indigo', Color(0xFF3949AB)),
    AccentPreset('Grafit', Color(0xFF546E7A)),
  ];

  static const List<PaletteStyle> styles = [
    PaletteStyle(DynamicSchemeVariant.tonalSpot, 'Uravnotežen',
        'Mirni tonovi izvedeni iz boje'),
    PaletteStyle(DynamicSchemeVariant.vibrant, 'Živ', 'Zasićenije boje'),
    PaletteStyle(DynamicSchemeVariant.expressive, 'Ekspresivan',
        'Razigrane, kontrastne nijanse'),
    PaletteStyle(DynamicSchemeVariant.fidelity, 'Vjeran boji',
        'Što bliže odabranoj boji'),
    PaletteStyle(
        DynamicSchemeVariant.neutral, 'Neutralan', 'Gotovo sive površine'),
    PaletteStyle(
        DynamicSchemeVariant.monochrome, 'Monohromatski', 'Samo nijanse sive'),
  ];


  /// Primary colour of the device's dynamic (wallpaper) palette, if the
  /// platform provides one (Android 12+). Set by the app root.
  Color? _deviceSeed;
  Color? get deviceSeed => _deviceSeed;
  bool get deviceColorsAvailable => _deviceSeed != null;

  void updateDeviceSeed(Color? color) {
    if (color?.toARGB32() == _deviceSeed?.toARGB32()) return;
    _deviceSeed = color;
    // Called while building the app root; notify after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  ThemeMode get themeMode => switch (_prefs.getString(_modeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Color get seedColor {
    final value = _prefs.getInt(_seedKey);
    return value == null ? defaultSeed : Color(value);
  }

  bool get useDeviceColors => _prefs.getBool(_deviceKey) ?? false;

  DynamicSchemeVariant get variant {
    final name = _prefs.getString(_variantKey);
    return DynamicSchemeVariant.values.firstWhere(
      (v) => v.name == name,
      orElse: () => DynamicSchemeVariant.tonalSpot,
    );
  }

  double get contrast => _prefs.getDouble(_contrastKey) ?? 0.0;

  /// The seed actually used: wallpaper colour when enabled and available.
  Color get effectiveSeed =>
      useDeviceColors && _deviceSeed != null ? _deviceSeed! : seedColor;

  ColorScheme schemeFor(Brightness brightness, {Color? seed,
      DynamicSchemeVariant? variant}) {
    return ColorScheme.fromSeed(
      seedColor: seed ?? effectiveSeed,
      brightness: brightness,
      dynamicSchemeVariant: variant ?? this.variant,
      contrastLevel: contrast,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_modeKey, mode.name);
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    await _prefs.setInt(_seedKey, color.toARGB32());
    await _prefs.setBool(_deviceKey, false);
    notifyListeners();
  }

  Future<void> setUseDeviceColors(bool value) async {
    await _prefs.setBool(_deviceKey, value);
    notifyListeners();
  }

  Future<void> setVariant(DynamicSchemeVariant variant) async {
    await _prefs.setString(_variantKey, variant.name);
    notifyListeners();
  }

  Future<void> setContrast(double value) async {
    await _prefs.setDouble(_contrastKey, value);
    notifyListeners();
  }

  Future<void> reset() async {
    for (final key in [_modeKey, _seedKey, _deviceKey, _variantKey, _contrastKey]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }
}
