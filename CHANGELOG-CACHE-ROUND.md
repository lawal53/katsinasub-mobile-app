# Changes — Nov 27 review round
- ADDED lib/widgets/one_time_promo_dialog.dart (main.dart imported it but it was missing from the project files).
- Logout now clears the cache AND the "unlocked this session" flag (before, a second account on the same run could skip the PIN lock).
- Cached pages now respect their 15s / 25s limits, so server/admin changes show within 15-30 seconds.
- Transfer, Bonus Transfer and Program pages open instantly from cache. Terms/Privacy show a thin progress bar instead of a blocking spinner.
- Good News banner uses the app's theme colour.
- Receipt card is now compact (about 330 px wide, smaller header, text and spacing), like a standard bank receipt. Size only; content unchanged.

## Cache + live refresh round
- Whole app refreshes in the background every 60 seconds while it is open (balance, history, notices, prices, rewards); pausing the app stops it, resuming refreshes at once if more than 30 s passed.
- Pull-to-refresh (Home, Profile, Rewards, Support, History, Program) now refreshes EVERYTHING in the app immediately, and screens redraw by themselves.
- Live screens (Home, Notifications, Rewards, Support, Referral, Profile, History page 1) update on their own when new data arrives.
- Cache hardening: a request that finishes after logout can no longer write into the next customer's cache; the same page is never fetched twice at once; requests time out (20 s) instead of hanging; transfer/bulk SMS/airtime-to-cash caches are cleared after money moves; profile refresh no longer wipes the whole cache.
- Prices/plans are never shown older than ~25 s without asking the server; other pages open instantly and refresh in the background.
