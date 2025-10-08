# Publishing Setup Instructions

This file contains step-by-step instructions for setting up automated publishing to pub.dev.

## Prerequisites

1. **pub.dev Account**: Make sure you have a pub.dev account and can publish packages
2. **Publisher (Optional but Recommended)**: Create a publisher on pub.dev for better package management

## Setup Steps

### 1. Get Your pub.dev Publishing Token

Choose one of these methods:

#### Method A: Using Dart CLI (Recommended)
```bash
# Run this command in your local terminal
dart pub token add https://pub.dev

# This will open a browser for authentication
# After completing authentication, copy the displayed token
```

#### Method B: Through pub.dev Website
1. Go to https://pub.dev/publishers
2. Create a publisher if you don't have one
3. Navigate to your publisher settings
4. Generate an access token

### 2. Add the Token to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Name: `PUB_DEV_PUBLISH_ACCESS_TOKEN`
5. Value: Paste the token you copied from step 1
6. Click **Add secret**

### 3. Verify Your Package Configuration

Before publishing, ensure your `pubspec.yaml` has all required fields:

```yaml
name: soia  # Package name on pub.dev
description: A Dart client library for Soia serialization  # Clear description
version: 0.1.0  # Version (will be updated for each release)
homepage: https://github.com/gepheum/soia-dart-client  # Project homepage
repository: https://github.com/gepheum/soia-dart-client  # Source code

environment:
  sdk: '>=3.0.0 <4.0.0'  # Supported Dart versions

# ... rest of your dependencies
```

### 4. Test Before Publishing

Always test your package before creating a release:

```bash
# Check if package is ready for publishing
dart pub publish --dry-run

# Run all tests
dart test

# Check formatting
dart format --set-exit-if-changed .

# Analyze code
dart analyze --fatal-infos
```

### 5. Create a Release to Publish

1. Go to your GitHub repository
2. Click **Releases** > **Create a new release**
3. Choose a tag version (e.g., `v0.1.0`) - should match your pubspec.yaml version
4. Fill in release notes
5. Click **Publish release**

The GitHub Action will automatically:
- Run all tests and checks
- Publish to pub.dev
- Add a comment to the release with the pub.dev link

## Troubleshooting

### Common Issues

1. **Token Invalid**: Regenerate the token and update the GitHub secret
2. **Version Conflicts**: Make sure the version in pubspec.yaml matches your release tag
3. **Package Validation Errors**: Run `dart pub publish --dry-run` locally to see detailed errors
4. **Permission Denied**: Ensure you have publishing rights to the package name

### Manual Publishing (Fallback)

If the automated workflow fails, you can publish manually:

```bash
# Set up credentials (one time only)
dart pub token add https://pub.dev

# Publish
dart pub publish
```

## Notes

- The workflow only triggers on release creation, not on every push
- Each version can only be published once to pub.dev
- Make sure to increment the version number in pubspec.yaml before each release
- Consider using semantic versioning (major.minor.patch)
