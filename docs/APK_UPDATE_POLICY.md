# APK Update Compatibility Policy

This policy is mandatory for every future Cineseat Android build.

## Signing migration record

- Alpha26 (`versionCode 46`) was signed by an ephemeral GitHub runner debug key whose private key was not retained.
- Its certificate SHA-256 was `85CD76BB3988145C2066CC712181DBBFD3A3C3068858E202C2830DB92CE7C0D3`.
- Because the corresponding private key is unrecoverable, alpha26 cannot be updated by later APKs. Installing alpha27 requires one uninstall of alpha26.
- Alpha27 begins the permanent signing chain. Every build after alpha27 must overwrite-install over alpha27 and later versions without deleting user data.

## Required identity from alpha27 onward

- Keep the application ID/package name fixed: `com.fx564286.cinema_seat_alert`.
- Use the encrypted permanent Cineseat release keystore stored through the existing RSA/AES protected build process.
- Required signer certificate SHA-256: `F8954BA293629909345CA7A0AE42198BFB0A6B568E1CF5384ECB9C7A3E18EDD4`.
- Certificate subject: `CN=Cineseat Release, O=fx564286, C=KR`.
- Never replace it with a debug key, temporary runner key, newly generated key, or another CI key.
- Never commit or upload the unencrypted private keystore.

## Required versioning

- Alpha27 is `versionCode 47`, `versionName 0.2.1-alpha.27`.
- Increase `versionCode` for every APK delivered after alpha27.
- Increase `versionName` consistently with the release label.
- Never reuse or lower a previously delivered `versionCode`.

## Required verification before delivery

The build must fail instead of being delivered when any check below fails:

1. Package name equals `com.fx564286.cinema_seat_alert`.
2. `versionCode` is greater than the previously delivered APK.
3. APK signer certificate equals `F8954BA293629909345CA7A0AE42198BFB0A6B568E1CF5384ECB9C7A3E18EDD4`.
4. APK Signature Scheme v2 or later is present.
5. The APK passes ZIP integrity, zipalign, and Android package inspection.
6. For alpha28 and later, the resulting APK must install over alpha27 or the latest delivered fixed-signed build without uninstalling or deleting user data.

## Delivery rule

- Alpha27 is the one-time signing migration build and requires alpha26 to be uninstalled first.
- Every APK after alpha27 must be provided as an **overwrite/update-installable APK** using the permanent alpha27 signing identity.
- A later clean-install-only APK is not acceptable unless the user explicitly requests a package or signing identity change.
