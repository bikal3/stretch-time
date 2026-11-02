import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout.dart';

class Settings {
  final bool sound, vibration, voice, keepAwake;
  final int readySecs;
  const Settings({
    this.sound = true,
    this.vibration = true,
    this.voice = true,
    this.keepAwake = true,
    this.readySecs = 5,
  });

  Settings copyWith({
    bool? sound,
    bool? vibration,
    bool? voice,
    bool? keepAwake,
    int? readySecs,
  }) => Settings(
    sound: sound ?? this.sound,
    vibration: vibration ?? this.vibration,
    voice: voice ?? this.voice,
    keepAwake: keepAwake ?? this.keepAwake,
    readySecs: readySecs ?? this.readySecs,
  );

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'voice': voice,
    'keepAwake': keepAwake,
    'readySecs': readySecs,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    sound: j['sound'] ?? true,
    vibration: j['vibration'] ?? true,
    voice: j['voice'] ?? true,
    keepAwake: j['keepAwake'] ?? true,
    readySecs: j['readySecs'] ?? 5,
  );
}

/// Single app-wide state, persisted to SharedPreferences on every change.
class AppState extends ChangeNotifier {
  final SharedPreferences _prefs;
  late Workout current;
  late List<Workout> saved, recent;
  late Settings settings;

  AppState(this._prefs) {
    // Corrupt or old-format data shouldn't brick the app: fall back to defaults.
    current = _read('current', (j) => Workout.fromJson(j), presets.last);
    saved = _read(
      'saved',
      (j) => [for (final w in j) Workout.fromJson(w)],
      <Workout>[],
    );
    recent = _read(
      'recent',
      (j) => [for (final w in j) Workout.fromJson(w)],
      <Workout>[],
    );
    settings = _read('settings', (j) => Settings.fromJson(j), const Settings());
  }

  T _read<T>(String key, T Function(dynamic) parse, T fallback) {
    try {
      final raw = _prefs.getString(key);
      return raw == null ? fallback : parse(jsonDecode(raw));
    } catch (_) {
      return fallback;
    }
  }

  void _write(String key, Object value) {
    _prefs.setString(key, jsonEncode(value));
    notifyListeners();
  }

  /// Editing a loaded preset turns it into an unnamed custom workout.
  void edit(Workout w) {
    current = w.copyWith(name: w.sameAs(current) ? current.name : '');
    _write('current', current);
  }

  void load(Workout w) {
    current = w;
    _write('current', current);
  }

  void saveAs(String name) {
    current = current.copyWith(name: name);
    saved = [current, ...saved.where((w) => w.name != name)];
    _write('current', current);
    _write('saved', saved);
  }

  void deleteSaved(Workout w) {
    saved = saved.where((s) => s != w).toList();
    _write('saved', saved);
  }

  void recordRun() {
    recent = [
      current,
      ...recent.where((w) => !w.sameAs(current)),
    ].take(15).toList();
    _write('recent', recent);
  }

  void updateSettings(Settings s) {
    settings = s;
    _write('settings', settings);
  }
}
