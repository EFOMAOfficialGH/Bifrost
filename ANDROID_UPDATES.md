# Android updates for Bifrost

Android only allows an APK to update an installed app when both APKs are signed with the same signing key. Earlier Bifrost GitHub builds used a temporary debug key, which changed between GitHub runners. That is why Android currently asks for an uninstall.

Starting with **Bifrost v0.7.0+9**, the workflow supports a stable release keystore through GitHub Actions secrets.

## One-time setup

Run this on a computer with Java installed:

```bash
keytool -genkeypair -v -keystore bifrost-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bifrost -storepass CHANGE_THIS_PASSWORD -keypass CHANGE_THIS_PASSWORD -dname "CN=Bifrost, OU=Bifrost, O=Bifrost, C=US"
```

Replace `CHANGE_THIS_PASSWORD` with a private password and keep the `.jks` file and password safe. Do not commit the keystore to GitHub.

Convert the keystore to one line of Base64:

```bash
base64 -w 0 bifrost-upload.jks > bifrost-upload.base64.txt
```

In the GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret** and create these four secrets:

| Secret name | Value |
|---|---|
| `BIFROST_KEYSTORE_BASE64` | The complete contents of `bifrost-upload.base64.txt` |
| `BIFROST_KEYSTORE_PASSWORD` | The keystore password chosen above |
| `BIFROST_KEY_PASSWORD` | The key password chosen above |
| `BIFROST_KEY_ALIAS` | `bifrost` |

After these secrets exist, GitHub Android builds use the same stable key for every release.

## Important migration note

The first APK built with the new stable key cannot update an older APK signed with the temporary debug key. Uninstall Bifrost one final time, install the first stable-key APK, and then all later versioned APKs can update in place as long as the signing secrets are not changed.

The app version must also increase each time. For example:

```text
Bifrost v0.7.0+9 → Bifrost v0.7.0+10
```
