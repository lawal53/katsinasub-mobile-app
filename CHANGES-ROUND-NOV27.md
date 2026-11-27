# Changes — Nov 27 review round
- ADDED lib/widgets/one_time_promo_dialog.dart (main.dart imported it but it was missing from the project files).
- Logout now clears the cache AND the "unlocked this session" flag (before, a second account on the same run could skip the PIN lock).
- Cached pages now respect their 15s / 25s limits, so server/admin changes show within 15-30 seconds.
- Transfer, Bonus Transfer and Program pages open instantly from cache. Terms/Privacy show a thin progress bar instead of a blocking spinner.
- Good News banner uses the app's theme colour.
