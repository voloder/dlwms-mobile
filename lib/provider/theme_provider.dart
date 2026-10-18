import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A named accent colour offered in the colour scheme editor.
class AccentPreset {
  const AccentPreset(this.name, this.color);

  final String name;
  final Color color;
}

/// Appearance settings: light/dark mode and the accent colour (a preset, a
/// custom colour or the device's wallpaper colours).
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs);

  final SharedPreferences _prefs;

  static const _modeKey = 'theme_mode';
  static const _seedKey = 'theme_seed';
  static const _deviceKey = 'theme_device_colors';
  // Used by an earlier version; cleared on reset.
  static const _legacyKeys = ['theme_variant', 'theme_contrast'];

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

  /// The seed actually used: wallpaper colour when enabled and available.
  Color get effectiveSeed =>
      useDeviceColors && _deviceSeed != null ? _deviceSeed! : seedColor;

  /// Material 3 scheme from the accent colour. Only the primary/secondary
  /// families and neutral surfaces are used in the UI; the tertiary family is
  /// a hue-shifted colour (blue → green) and is avoided on purpose.
  ColorScheme schemeFor(Brightness brightness, {Color? seed}) {
    return ColorScheme.fromSeed(
      seedColor: seed ?? effectiveSeed,
      brightness: brightness,
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

  Future<void> reset() async {
    for (final key in [_modeKey, _seedKey, _deviceKey, ..._legacyKeys]) {
      await _prefs.remove(key);
    }
    notifyListeners();
  }
}
