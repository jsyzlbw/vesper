# Vesper Branding and App Language Design

## Goal

Rename the iPhone companion app to `Vesper`, add a production-ready iOS app icon, and let users choose between system language, Simplified Chinese, and English inside the app.

## Brand

### Name

The user-facing product name is `Vesper`.

`Vesper` refers to evening light. It fits a quiet private assistant that remembers, reminds, and helps close small daily loops without demanding attention. The internal target and bundle identifier remain unchanged to avoid unnecessary migration work.

### App Icon

The icon uses:

- A deep twilight-blue square background suitable for the iOS rounded mask.
- A restrained luminous circular orbit that suggests time, daily rhythm, and continuity.
- One small warm light point on the upper-right portion of the orbit, suggesting quiet presence.
- No text, chat bubble, robot face, notebook, or detailed illustration.
- Enough padding and contrast to remain legible at small home-screen sizes.

The project stores a 1024 by 1024 PNG source and an Xcode `AppIcon.appiconset`. Xcode generates the required device variants from the single universal iOS icon asset.

## Language Selection

### Supported Choices

The Settings screen adds an `App Language` section with:

- `Follow System`
- `简体中文`
- `English`

The setting defaults to `Follow System` and is stored locally with `AppStorage`.

### Resolution Rules

When `Follow System` is selected:

- Use Simplified Chinese if the preferred system language starts with `zh-Hans`.
- Use English for all other preferred system languages.

The app intentionally supports only Simplified Chinese and English in this version. Traditional Chinese and other languages fall back to English.

### Runtime Behavior

Changing the language setting refreshes all visible app chrome immediately without requiring a restart. The selected locale also controls date formatting in reminder cards.

The first implementation localizes every user-facing string in the current iPhone app:

- Tab labels
- Empty states
- Chat title, composer, progress, alerts, and provider errors
- Reminder proposal cards
- Reminder proposal editor
- Provider settings and provider form
- Timeline and audit views
- Validation messages surfaced from `DiaryCompanionCore`

Provider names, model names, URLs, API keys, and AI-generated reminder titles or notes remain unchanged.

## Localization Architecture

Create an app-local localization module:

- `VesperLanguage`: persisted user choice and resolved supported language.
- `VesperSupportedLanguage`: Simplified Chinese or English.
- `VesperStrings`: typed accessors for localized app strings and interpolation helpers.
- `VesperLocalizationContext`: SwiftUI environment value containing the resolved language.

`DiaryCompanionApp` owns the `AppStorage` setting and injects the resolved language into the environment. Views read localized strings from the environment instead of branching on `Locale` independently.

`DiaryCompanionCore` validation errors receive bilingual descriptions through a compact localization helper based on the current preferred app language. This keeps errors shown by editor and repository flows consistent with the selected app language while avoiding a broad package resource migration.

## AI Reply Language

The system prompt defaults to the resolved app language:

- Simplified Chinese interface: answer in Simplified Chinese.
- English interface: answer in English.

If the newest user message contains Chinese Han characters, the system prompt instructs the model to answer that message in Simplified Chinese even when the interface language is English.

The rule affects assistant prose only. Reminder envelope JSON schema keys remain unchanged.

## Settings UI

The Settings screen presents:

1. AI Provider
2. App Language
3. Permissions

The language picker uses the localized label for each option. It updates immediately when changed.

## Testing

Add unit coverage for:

- Resolving each explicit language selection.
- Resolving `Follow System` for `zh-Hans`, English, Traditional Chinese, and unsupported languages.
- Detecting Chinese text in the latest user message.
- Producing Chinese and English AI reply instructions.
- Producing localized core validation errors.

Run:

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Install the app in the iPhone simulator and verify:

- The home screen displays the `Vesper` name and icon.
- Settings shows all three language choices.
- Switching between Simplified Chinese and English updates current screens immediately.
- English UI plus an English message prompts an English AI response.
- English UI plus a Chinese message prompts a Chinese AI response.
