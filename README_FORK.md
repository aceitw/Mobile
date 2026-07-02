# TermixD — Fork Development Guide

This is the **forked** mobile app for [Termix](https://github.com/Termix-SSH/Termix), customized for independent distribution as **TermixD** with bundle ID `com.formprovisions.termix`.

## What changed from upstream

| Upstream | This fork |
|---|---|
| App name: **Termix** | **TermixD** |
| Bundle ID: `com.karmaa.termix` | `com.formprovisions.termix` |
| Expo owner: `termix` | `aceitw` |
| EAS project: `termix` | `termixd` |
| Mouse reporting feature | ✅ Included |

## Branches

| Branch | Purpose |
|---|---|
| **`main`** | **Work here.** Has upstream + mouse reporting + all fork-specific deployment config. |
| **`feature/mouse-reporting-clean`** | Clean feature branch for upstream PR. **No fork-specific config.** |

## Development (local)

### Prerequisites

- Node 20
- `npm i -g eas-cli`
- macOS with Xcode (for iOS)
- Android Studio (for Android)

### Run on a connected device (fastest for testing)

```bash
cd /Users/sal/CODE/Termix/Mobile
npm install
npx expo run:ios --device
# or
npx expo run:android --device
```

This builds a **development client** locally and installs it directly on your phone. It bypasses Expo Go and handles all native plugins (SSH, WebView, etc.).

### Run in simulator

```bash
npx expo run:ios
npx expo run:android
```

> ⚠️ **Expo Go does NOT work** for this app. It uses custom native plugins (`expo-dev-client`, network security plugins, etc.) that are incompatible with the Expo Go sandbox.

### Metro bundler (for debugging)

```bash
npx expo start
```

Then press `i` or `a` in the terminal to open iOS/Android. This uses the development client you already built.

## Building for TestFlight

### One-shot command

```bash
cd /Users/sal/CODE/Termix/Mobile
export EXPO_TOKEN="your-expo-token"
npm run build:ios:prod
```

This is equivalent to:

```bash
EAS_SKIP_AUTO_FINGERPRINT=1 eas build --platform ios --profile production --auto-submit --non-interactive
```

### What happens

1. EAS builds the iOS app in the cloud
2. EAS submits the `.ipa` to App Store Connect automatically
3. Apple processes the build (5–10 min)
4. It appears in the **TestFlight** app on your iPhone

### After build succeeds

1. Open **TestFlight** on your iPhone
2. Sign in with the Apple ID added as an internal tester
3. Tap **Install** on **TermixD**

## Managing iOS credentials

Credentials are stored **locally only** (not in git):

```text
certs/FP_Distribution.p12          ← private key + certificate
certs/FP_Distribution.key           ← private key
certs/TermixD.mobileprovision       ← provisioning profile
credentials.json                    ← p12 password (gitignored)
```

### Regenerating credentials

If your certificate expires or you need a new one:

```bash
cd /Users/sal/CODE/Termix/Mobile
./recreate-ios-creds.sh
```

Follow the prompts to upload the CSR to Apple Developer Portal, create the `.p12`, and download the provisioning profile.

### Verifying credentials

```bash
./verify-ios-creds.sh
```

Checks:
- Certificate fingerprint in `.p12` matches provisioning profile
- Profile type is correct for App Store distribution
- Bundle ID is `com.formprovisions.termix`

## Branch workflow for upstream PRs

If you need to fix or extend the **mouse reporting** feature and later PR it upstream:

### 1. Fix on `main` (where you test and build)

```bash
git checkout main
# ...edit code...
git add .
git commit -m "fix: [description]"
git push origin main
```

### 2. Cherry-pick to the clean feature branch

```bash
git checkout feature/mouse-reporting-clean
git cherry-pick <commit-hash-from-main>
git push origin feature/mouse-reporting-clean
```

### 3. Open PR from `feature/mouse-reporting-clean` to `Termix-SSH/Mobile:main`

This branch has **only** mouse reporting commits — no fork-specific config.

## Security checklist

- [ ] `credentials.json` is in `.gitignore` and never committed
- [ ] `certs/*.p12`, `certs/*.key` are in `.gitignore` and never committed
- [ ] `~/.zsh_history` does not contain `EXPO_TOKEN` or p12 password
- [ ] `certs/` directory permissions are `700`
- [ ] Old credential files (`*_old.*`) are deleted when no longer needed

## Related repos

- **Server**: `/Users/sal/CODE/Termix/Termix` — SSH session manager
- **Mobile**: `/Users/sal/CODE/Termix/Mobile` — this app
