# Offline localization

Reef Tank follows the Roku device's language/locale automatically. The app does
not change the device language or send strings/location data to a translation
service. Missing translations fall back to the source English through Roku's
native `tr()` function.

Supported locale catalogs: `en_US`, `en_GB`, `en_AU`, `fr_CA`, `es_ES`,
`es_MX`, `de_DE`, `it_IT`, and `pt_BR`.

## Scope

- Settings labels and values, navigation hints, location chooser, keyboard
  instructions, validation errors, digit picker, and build history.
- Country/territory display names are translated; source country identifiers,
  city-file associations, city names, coordinates and ZIP lookup coverage are
  unchanged. Country order retains the stable source ordering.
- City names retain the existing dataset spelling. Translating thousands of
  proper names/exonyms is a separate dataset project, not a UI requirement.
- The background clock retains device-local time and the device's 12/24-hour
  preference. The separate AM/PM indicator is localized without altering clock
  arithmetic or stored settings.
- The product name "Reef Tank" remains a brand name.

Native Roku keyboard/system chrome is controlled by Roku. App-owned labels on
native controls are explicitly translated. Streaming Store listing text and
screenshots are separate from these bundled UI catalogs and are not changed.

## Maintenance

Keep persisted preference keys and enum values language-independent. Translate
complete templates before substituting `%1`, `%2`, etc.; do not concatenate
English grammar around translated fragments. Catalog tests enforce source
coverage and placeholder parity. Test long translations at both UI resolutions,
including dismissal/re-entry, invalid location input and unchanged persistence.

Reference: https://developer.roku.com/dev/docs/localization
Locale list: https://developer.roku.com/dev/docs/ifdeviceinfo

## Verification scope

The integrity gate verifies 290 source strings in each of nine catalogs, matching
placeholders, valid XLIFF, bundled notices and unchanged location-data hashes.
The browser preview uses the emulator's native device locale, not a replacement
translation function. Its localized visual cases cover all ten locales, six
non-English settings/location/country/history paths, German/French/Spanish
invalid-input cancellation, and Spanish clock periods. Scaled 720-pixel browser
screenshots are not a substitute for a true 720p Roku device check.

Translations received internal language/visual review, not professional
translation certification. Audible screen-reader behavior in every language,
all country-name lengths and all device/font combinations are not exhaustively
certified. The user's earlier successful screen-reader settings test predates
this localization work.

Validated on 2026-11-17: `make checkall-ci` passed, including 228 BrightScript
unit tests and four localization-integrity tests. The final focused functional
visual run passed all 23 locale/settings/history cases without updating
snapshots; the unchanged tank baseline also passed. Renderer readback confirmed
ANGLE Metal on Apple M4 Max. Localized screenshots were reviewed for fitting,
including shorter translated history headings. These were correctness checks
under a busy host, not timing/performance measurements or certification.

## Canadian English validator compatibility

Roku documents `en_CA` as a device locale, but its 2026-11-17 package analyzer
rejects a bundled `en_CA` catalog. Canadian English therefore uses native `tr()`
English-source fallback instead. All ten device locales remain covered, with
nine accepted translation catalogs. This removes the catalog flagged by the analyzer
without changing the Canadian English UI wording. The country-name source typo
is normalized before lookup so fallback also displays "New Zealand" correctly.

The compatibility correction passed the existing US-English and Canadian-English
settings snapshots plus French dialog/country/history and invalid-location flows
without changing any screenshot baseline (four focused cases).
