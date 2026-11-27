import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

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

  /// Goes up by one whenever fresh data arrives that differs from what a screen may be showing
  /// (a background refresh found a change, or a full refresh finished). Screens that listen to
  /// it re-read the cache and redraw by themselves.
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);
  static void notifyChanged() => refreshTick.value++;

  /// Goes up on login/logout. A request that started under an older number must not write its
  /// answer into the cache, or one customer's data could appear for the next customer.
  static int epoch = 0;

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

  /// Stores a fresh answer. Returns true when it differs from what was stored before.
  static bool put(String key, dynamic value) {
    String? before, after;
    try { before = _mem[key] == null ? null : jsonEncode(_mem[key]!.value); after = jsonEncode(value); } catch (_) {}
    _mem[key] = _Entry(value, DateTime.now());
    _scheduleSave();
    return before == null || before != after;
  }

  /// Marks everything as old (nothing is deleted), so the next read goes to the server.
  static void expireAll() {
    final old = DateTime.fromMillisecondsSinceEpoch(0);
    _mem.updateAll((k, e) => _Entry(e.value, old));
  }

  static void expire(Iterable<String> keys) {
    final old = DateTime.fromMillisecondsSinceEpoch(0);
    for (final k in keys) { final e = _mem[k]; if (e != null) _mem[k] = _Entry(e.value, old); }
  }

  static List<String> keys() => _mem.keys.toList();

  /// Forget every entry whose key starts with one of the prefixes (after money moves, etc.).
  static void invalidate(Iterable<String> prefixes) {
    _mem.removeWhere((k, _) => prefixes.any((p) => k.startsWith(p)));
    _scheduleSave();
  }

  /// Forget everything (login / logout): one customer's data must never show for another.
  static void clear() {
    epoch++;
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
