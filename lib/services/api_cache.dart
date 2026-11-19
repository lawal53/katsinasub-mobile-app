import 'dart:async';
import 'dart:convert';
import 'dart:io';

class _Entry {
  final dynamic value;
  final DateTime at;
  _Entry(this.value, this.at);
}

/// A small cache for the answers the app asks the server for. Pages that need no provider
/// (history, notifications, plans, rewards, support and so on) open at once from here, and the
/// app refreshes them quietly in the background. It lives in memory and in a private file in
/// the app's own cache folder, so it is ready even right after the app is opened. It is wiped
/// when the customer logs out or logs in.
class ApiCache {
  static final Map<String, _Entry> _mem = {};
  static File? _file;
  static bool _loaded = false;
  static Timer? _saveTimer;

  static Future<void> init() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _file = File('${Directory.systemTemp.path}/katsinasub_cache_v1.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString());
        if (j is Map) {
          j.forEach((k, v) {
            if (v is Map && v['at'] != null) {
              _mem['$k'] = _Entry(v['v'], DateTime.tryParse('${v['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0));
            }
          });
        }
      }
    } catch (_) {}
  }

  static dynamic peek(String key) => _mem[key]?.value;

  static Duration? age(String key) {
    final e = _mem[key];
    return e == null ? null : DateTime.now().difference(e.at);
  }

  static void put(String key, dynamic value) {
    _mem[key] = _Entry(value, DateTime.now());
    _scheduleSave();
  }

  /// Forget every entry whose key starts with one of the prefixes (after money moves, etc.).
  static void invalidate(Iterable<String> prefixes) {
    _mem.removeWhere((k, _) => prefixes.any((p) => k.startsWith(p)));
    _scheduleSave();
  }

  /// Forget everything (login / logout): one customer's data must never show for another.
  static void clear() {
    _mem.clear();
    _saveTimer?.cancel();
    try { _file?.delete(); } catch (_) {}
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        _file ??= File('${Directory.systemTemp.path}/katsinasub_cache_v1.json');
        final out = <String, dynamic>{};
        _mem.forEach((k, e) {
          if (!k.startsWith('receipt:')) out[k] = {'at': e.at.toIso8601String(), 'v': e.value};
        });
        await _file!.writeAsString(jsonEncode(out));
      } catch (_) {}
    });
  }
}
