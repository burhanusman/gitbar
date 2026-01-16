# GitHub Actions Release Setup

This guide explains how to configure GitHub Actions for automated GitBar releases.

## Overview

The automated release workflow (`.github/workflows/release.yml`) is triggered when you push a git tag in the format `v*` (e.g., `v1.0.0`, `v1.0.0-beta1`).

The workflow will:
1. ✅ Build the app with the tagged version
2. ✅ Sign the app with Developer ID
3. ✅ Notarize the app with Apple
4. ✅ Create a professional DMG installer
5. ✅ Sign and notarize the DMG
6. ✅ Generate appcast.xml with Sparkle signatures
7. ✅ Upload artifacts to GitHub Releases
8. ✅ Update appcast.xml in the repository

## Required GitHub Secrets

Configure these secrets in your GitHub repository:

**Settings → Secrets and variables → Actions → New repository secret**

### 1. CERTIFICATE_BASE64

Your Apple Developer ID Application certificate in base64 format.

**How to create:**

```bash
# Export your Developer ID certificate from Keychain
# 1. Open Keychain Access
# 2. Find "Developer ID Application: Your Name (TEAM_ID)"
# 3. Right-click → Export "Developer ID Application..."
# 4. Save as certificate.p12 with a password

# Convert to base64
base64 -i certificate.p12 | pbcopy

# The base64 string is now in your clipboard
# Paste it into GitHub Secrets as CERTIFICATE_BASE64
```

**Alternative command-line export:**

```bash
# Export certificate and private key
security find-identity -v -p codesigning
# Note the identity hash from the output

security export -t identities -f pkcs12 \
  -o certificate.p12 \
  -P "your-password-here"

# Convert to base64
base64 -i certificate.p12 | pbcopy
```

### 2. CERTIFICATE_PASSWORD

The password you used when exporting the .p12 certificate file.

### 3. TEAM_ID

Your Apple Developer Team ID.

**How to find:**

- Go to https://developer.apple.com/account
- Sign in
- Your Team ID is shown in the top right (10 characters, e.g., `ABCDE12345`)

Or from command line:

```bash
# List your signing identities
security find-identity -v -p codesigning

# Look for line like:
# "Developer ID Application: Your Name (ABCDE12345)"
# The value in parentheses is your Team ID
```

### 4. APPLE_ID

Your Apple ID email address (e.g., `developer@example.com`)

### 5. APPLE_APP_SPECIFIC_PASSWORD

An app-specific password for notarization.

**How to create:**

1. Go to https://appleid.apple.com/account/manage
2. Sign in with your Apple ID
3. In the "Sign-In and Security" section, select "App-Specific Passwords"
4. Click "Generate an app-specific password"
5. Enter a label like "GitBar Notarization"
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)
7. Save it to GitHub Secrets as `APPLE_APP_SPECIFIC_PASSWORD`

**Note:** You cannot view this password again, so save it immediately.

### 6. SPARKLE_PRIVATE_KEY

Your Sparkle EdDSA private key for signing updates.

**How to generate:**

```bash
# Download Sparkle tools
curl -L -o Sparkle.tar.xz \
  https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
tar -xf Sparkle.tar.xz

# Generate key pair
./bin/generate_keys

# Output will show:
# A key has been generated and saved in your keychain.
# Add the `SUPublicEDKey` key to your Info.plist:
# [PUBLIC_KEY_HERE - copy this to GitBar/Info.plist]
#
# Private key (save this securely!):
# [PRIVATE_KEY_HERE - copy this to GitHub Secrets]
```

**Important:**
- Copy the **public key** to `GitBar/Info.plist` under `SUPublicEDKey`
- Copy the **private key** to GitHub Secrets as `SPARKLE_PRIVATE_KEY`
- Keep the private key secure - never commit it to git!

## Summary of Required Secrets

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `CERTIFICATE_BASE64` | Base64-encoded Developer ID cert | `MIIP8wIBAzCCD7cG...` |
| `CERTIFICATE_PASSWORD` | Password for the certificate | `MySecurePassword123` |
| `TEAM_ID` | Apple Developer Team ID | `ABCDE12345` |
| `APPLE_ID` | Your Apple ID email | `dev@example.com` |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | `xxxx-xxxx-xxxx-xxxx` |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key | `MC4CAQAwBQYDK2VwB...` |

## Verification Checklist

Before pushing your first release tag, verify:

- [ ] All 6 secrets are configured in GitHub
- [ ] Certificate is valid and not expired
- [ ] Team ID matches your Developer ID certificate
- [ ] App-specific password is valid (test with `xcrun notarytool history`)
- [ ] Sparkle public key is in `GitBar/Info.plist`
- [ ] `SUFeedURL` in `Info.plist` points to correct repository

## Testing the Workflow

Test with a beta release first:

```bash
# Create a beta tag
git tag -a v1.0.0-beta1 -m "Beta release for testing"
git push origin v1.0.0-beta1

# Monitor the workflow
# GitHub → Actions → "Release GitBar" workflow

# If successful, test the release:
# 1. Download the DMG from GitHub Releases
# 2. Install the app
# 3. Verify it launches and is notarized
# 4. Check that appcast.xml was updated
```

## Troubleshooting

### Certificate Import Fails

**Error:** `security: SecKeychainItemImport: The user name or passphrase you entered is not correct.`

**Solution:** Verify `CERTIFICATE_PASSWORD` matches the password you used when exporting the certificate.

### Code Signing Fails

**Error:** `errSecInternalComponent` or `The specified item could not be found in the keychain.`

**Solution:**
- Verify `TEAM_ID` is correct
- Ensure certificate hasn't expired
- Check certificate is "Developer ID Application" (not "Development" or "Distribution")

### Notarization Fails

**Error:** `Error: Invalid credentials. Username or password is incorrect.`

**Solution:**
- Verify `APPLE_ID` is correct
- Regenerate `APPLE_APP_SPECIFIC_PASSWORD` if needed
- Ensure 2FA is enabled on your Apple ID

**Error:** `The software asset has exceeded the previous compilation of provided invalid responses.`

**Solution:** The app bundle has issues. Check:
- App is properly signed with hardened runtime
- All frameworks and binaries are signed
- Entitlements are correct

### Appcast Generation Fails

**Error:** `Invalid private key`

**Solution:**
- Verify `SPARKLE_PRIVATE_KEY` is the complete private key
- Check for line breaks or formatting issues
- Regenerate keys if needed

### Workflow Permission Issues

**Error:** `Resource not accessible by integration` when pushing appcast

**Solution:**
1. Go to Settings → Actions → General
2. Under "Workflow permissions"
3. Select "Read and write permissions"
4. Check "Allow GitHub Actions to create and approve pull requests"
5. Click Save

## Security Best Practices

1. **Never commit secrets to git**
   - All sensitive data should be in GitHub Secrets
   - Use `.gitignore` to exclude certificate files

2. **Rotate app-specific passwords regularly**
   - Generate new passwords every 6-12 months
   - Update GitHub Secret when rotated

3. **Monitor certificate expiration**
   - Developer ID certificates expire after 5 years
   - Set calendar reminders before expiration

4. **Audit workflow runs**
   - Review Actions logs periodically
   - Check for failed notarizations

5. **Limit secret access**
   - Only repository admins should have access to secrets
   - Use environment protection rules for production releases

## Manual Backup Process

If GitHub Actions is unavailable, you can release manually:

See [MANUAL_RELEASE.md](MANUAL_RELEASE.md) for step-by-step instructions.

## Resources

- [Apple Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Developer ID Certificates](https://developer.apple.com/support/developer-id/)
