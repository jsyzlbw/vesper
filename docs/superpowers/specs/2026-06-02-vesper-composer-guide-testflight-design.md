# Vesper Composer, In-App Guide, and TestFlight Design

## Goal

Prepare Vesper for a first external TestFlight round while improving the chat
composer:

- Make the software keyboard easy to dismiss.
- Replace the default bordered text field with the selected warm card design.
- Add the existing Chinese user guide to Settings as an in-app reading page.
- Add a repeatable TestFlight archive workflow and an external-testing checklist.

## Chat Composer

The composer remains a multiline SwiftUI `TextField`, but owns explicit focus
state. The keyboard can be dismissed in four predictable ways:

1. Tap the keyboard toolbar's dismiss button.
2. Drag the conversation scroll view.
3. Tap the conversation background.
4. Send a message.

The visual style is the selected warm card option: white rounded surface, subtle
border and shadow, a small natural-language label, and a circular send button.
The composer expands up to five lines and remains readable above the tab bar.

## In-App User Guide

Settings gains a Support section with a User Guide row. Tapping it opens a
native SwiftUI reading page. The page contains the same current Chinese guide
material as `docs/vesper-user-guide-zh-Hans.md`, expressed as app-local SwiftUI
sections so it works offline and is readable in TestFlight builds.

The guide page is localized at navigation level. The first TestFlight guide
content remains Simplified Chinese because that is the current tester audience.

## TestFlight External Testing

The repository gains a release script that:

1. Verifies the Release archive build.
2. Archives Vesper with automatic signing.
3. Exports an App Store Connect upload package.
4. Optionally uploads when App Store Connect API key environment variables are
   provided.

The script must fail with an actionable explanation when the Apple Developer
Program membership, distribution certificate, provisioning profile, App Store
Connect app record, or API key is missing.

The repository also gains a Chinese release checklist for first-time external
TestFlight distribution. It explains that Apple Developer Program enrollment,
payment, identity verification, tax/legal agreements, and Beta App Review
submission require the account owner to complete Apple's web flow.

## Versioning

Set explicit user-facing app version and build number values in Xcode:

- Marketing version: `0.1.0`
- Current project version: `1`

The release script accepts overrides so later builds can increment without
editing the project manually.

## Verification

- Build the app for the iPhone 17 Pro simulator.
- Launch it in Simulator and manually verify composer focus and all keyboard
  dismissal paths.
- Open Settings and verify the User Guide page renders.
- Run the release script in preflight mode and verify its diagnostics.
- Run `swift test --package-path DiaryCompanionCore`.
- Run `git diff --check`.
