# MS-2FA-Export

A jailbreak tweak that adds export functionality to Microsoft Authenticator for iOS, allowing you to extract your 2FA seeds/secrets in otpauth URI format.

## Description

Microsoft Authenticator doesn't provide a built-in way to export your 2FA seeds, making it difficult to migrate to alternative authenticator apps. This tweak adds an export button to the top right of the app, allowing you to export all of your 2FA seeds in a format compatible with most authenticator apps.

I made this so that I could migrate to Ente Auth. If the format is not compatible with your authenticator app of choice, feel free to open an issue and I'll try to make it work.

*Note: Microsoft accounts are handled differently from other accounts, and cannot be exported by this tool. All other services I have tried were able to be exported just fine.*

## Usage

1. Open Microsoft Authenticator
3. Tap the new export button (share icon) in the navigation bar
4. Review the alert showing which accounts were successfully processed
5. Tap "Copy otpauth URIs" to copy all the URIs to your clipboard
6. Import the URIs into your preferred authenticator app

The exported otpauth URIs follow this format:
```
otpauth://totp/AccountName:Username?secret=SECRET&issuer=AccountName
```

## Compilation

1. Install [Theos](https://theos.dev/docs/installation) if you haven't already
2. Clone this repository
3. Build and install:

```bash
make package
```
