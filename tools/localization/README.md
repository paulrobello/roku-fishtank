# Offline localization sources

Run `python3 tools/localization/build_catalogs.py` to regenerate `locale/*/translations.xml`.
The generator uses only checked-in UTF-8 data and Python's standard library.

- `translations.tsv`: English source, Canadian French, Spanish, German, Italian,
  Brazilian Portuguese. UI and development-history translations are maintained
  here. Preserve `%1`, `%2` placeholders exactly.
- `countries.json`: the same five target-language columns for all 228 source
  country/territory labels. Most names were generated with `Intl.DisplayNames`
  in Bun 1.4.4, ICU 78.1 / Unicode 17.0, then frozen so rebuilding is deterministic.
  This is Unicode CLDR-derived naming data, not a geopolitical classification.
  Chatham Islands, Kermadec Islands, Northern Cyprus and Somaliland have explicit
  translations because they do not have matching ISO region identifiers here.
  Source aliases were matched without changing their dataset IDs or city coverage.
- Canadian English (`en_CA`) uses native English-source fallback because Roku's
  package analyzer rejects an `en_CA` catalog despite listing the device locale.
  Other English regional catalogs use the existing English wording. Spanish ES and MX
  share broadly understandable Spanish; localized UI does not promise country-
  specific postal, date, or number parsing conventions.
- The source dataset typo `Necw Zealand` is displayed as `New Zealand` in English
  and translated normally elsewhere. It retains its separate original dataset ID.
- City names remain the source dataset's names. Countries are localized; this does
  not translate or transliterate every city's name.

These are application translations, not a certified professional translation
review. Real-device text fitting and screen-reader checks remain necessary.
The existing coordinate parser requires decimal points and comma separation;
localized error text explains this explicitly. ZIP strings retain leading zeros.
No runtime network requests, downloaded fonts, or translation services are used.

CLDR provenance: https://cldr.unicode.org/
Unicode data license: https://www.unicode.org/license.txt

The complete official Unicode License V3 is distributed in `locale/NOTICE.txt`.
