# APK Update Compatibility Policy

This policy is mandatory for every future Cineseat Android build.

## Required identity

- Keep the application ID/package name fixed: `com.fx564286.cinema_seat_alert`.
- Sign every APK with the same fixed signing key used for the accepted alpha26 build.
- Never replace the signing key with a debug key, temporary key, newly generated key, or another CI key.
- Keep the existing signing-key cache and signing workflow intact unless a verified migration is explicitly requested.

## Required versioning

- Increase `versionCode` for every APK delivered after alpha26 (`versionCode 46`).
- Increase `versionName` consistently with the release label.
- Never reuse or lower a previously delivered `versionCode`.

## Required verification before delivery

The build must fail instead of being delivered when any check below fails:

1. Package name equals `com.fx564286.cinema_seat_alert`.
2. `versionCode` is greater than the previously delivered APK.
3. APK signer certificate matches the previously accepted Cineseat signing certificate.
4. APK Signature Scheme v2 or later is present.
5. The APK passes ZIP integrity and Android package inspection.
6. The resulting APK can be installed as an update without uninstalling the existing app or deleting user data.

## Delivery rule

Every future APK must be described and provided as an **overwrite/update-installable APK**. A clean-install-only APK is not an acceptable deliverable unless the user explicitly requests a package or signing identity change.
