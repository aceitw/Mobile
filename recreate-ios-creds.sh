#!/bin/bash
# recreate-ios-creds.sh
# Run from /Users/sal/CODE/Termix/Mobile

set -e

cd "$(dirname "$0")"
CERTS_DIR="certs"
mkdir -p "$CERTS_DIR"

echo "=== Step 1: Generate new private key and CSR ==="
openssl genrsa -out "$CERTS_DIR/FP_Distribution.key" 2048
openssl req -new -key "$CERTS_DIR/FP_Distribution.key" -out "$CERTS_DIR/FP_Distribution.csr" \
  -subj "/emailAddress=you@example.com/CN=Form Provisions Distribution"

echo ""
echo "✓ Created:"
echo "  $CERTS_DIR/FP_Distribution.key"
echo "  $CERTS_DIR/FP_Distribution.csr"
echo ""
echo "=== MANUAL STEP: Upload CSR to Apple Developer Portal ==="
echo ""
echo "1. Go to: https://developer.apple.com/account/resources/certificates/list"
echo "2. Click '+' → select 'iOS Distribution (App Store and Ad Hoc)'"
echo "3. Upload: $PWD/$CERTS_DIR/FP_Distribution.csr"
echo "4. Download the .cer file to your Downloads folder"
echo ""
echo "Press ENTER after you have downloaded the .cer file:"
read -r

echo ""
echo "=== Step 2: Create macOS-compatible .p12 ==="

# Check common locations for the downloaded .cer file
CER_FILE=""
for dir in "$CERTS_DIR" "$HOME/Downloads"; do
  if [ -f "$dir/ios_distribution.cer" ]; then
    CER_FILE="$dir/ios_distribution.cer"
    break
  fi
  # Try to find any .cer in this dir
  found=$(find "$dir" -maxdepth 1 -name "*.cer" -type f -print -quit 2>/dev/null)
  if [ -n "$found" ]; then
    CER_FILE="$found"
    break
  fi
done

if [ -z "$CER_FILE" ] || [ ! -f "$CER_FILE" ]; then
  echo "ERROR: Could not find .cer file"
  echo "Checked: $CERTS_DIR/ and ~/Downloads/"
  echo "Please move the .cer file to one of those folders and run again."
  exit 1
fi

echo "Found certificate: $CER_FILE"
echo ""
echo "Enter a password for the new .p12 file:"
read -s P12_PASS
echo ""

# CRITICAL: Use 3DES encryption so macOS Keychain can import it
openssl pkcs12 -export \
  -inkey "$CERTS_DIR/FP_Distribution.key" \
  -in "$CER_FILE" \
  -out "$CERTS_DIR/FP_Distribution.p12" \
  -descert \
  -keypbe PBE-SHA1-3DES \
  -certpbe PBE-SHA1-3DES \
  -macalg SHA1 \
  -password pass:"$P12_PASS"

echo "✓ Created: $CERTS_DIR/FP_Distribution.p12"

echo ""
echo "=== Step 3: Update credentials.json ==="
cat > credentials.json <<EOF
{
  "ios": {
    "provisioningProfilePath": "./certs/TermixD.mobileprovision",
    "distributionCertificate": {
      "path": "./certs/FP_Distribution.p12",
      "password": "$P12_PASS"
    }
  }
}
EOF
echo "✓ Updated: credentials.json"

echo ""
echo "=== MANUAL STEP: Create provisioning profile ==="
echo ""
echo "1. Go to: https://developer.apple.com/account/resources/profiles/list"
echo "2. Delete any old 'TermixD' profiles"
echo "3. Click '+' → select 'App Store Connect' under Distribution"
echo "4. App ID: com.formprovisions.termix"
echo "5. Certificate: select the NEW one you just created"
echo "6. Name: TermixD"
echo "7. Download the .mobileprovision file"
echo ""
echo "Press ENTER after you have downloaded the .mobileprovision file:"
read -r

# Check common locations for the downloaded .mobileprovision file
PROFILE_FILE=""
for dir in "$HOME/Downloads" "$CERTS_DIR"; do
  if [ -f "$dir/TermixD.mobileprovision" ]; then
    PROFILE_FILE="$dir/TermixD.mobileprovision"
    break
  fi
  found=$(find "$dir" -maxdepth 1 -name "*.mobileprovision" -type f -print -quit 2>/dev/null)
  if [ -n "$found" ]; then
    PROFILE_FILE="$found"
    break
  fi
done

if [ -z "$PROFILE_FILE" ] || [ ! -f "$PROFILE_FILE" ]; then
  echo "ERROR: Could not find .mobileprovision file"
  echo "Checked: ~/Downloads/ and $CERTS_DIR/"
  exit 1
fi

cp "$PROFILE_FILE" "$CERTS_DIR/TermixD.mobileprovision"
echo "✓ Copied profile to: $CERTS_DIR/TermixD.mobileprovision"

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "1. Commit: git add credentials.json && git commit -m 'fix: recreate iOS creds with 3DES .p12'"
echo "2. Build: export EXPO_TOKEN=... && export EAS_SKIP_AUTO_FINGERPRINT=1"
echo "   npx eas build --platform ios --profile production --auto-submit --non-interactive"
