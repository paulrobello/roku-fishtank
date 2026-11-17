# Offline location data

Generated November 17, 2026. No lookup service, location permission, network request,
or geolocation is used. Only the selected coordinates are saved on the Roku.

## Sources and reuse

* US Census Bureau 2026 Gazetteer ZCTA file (US government public-domain data):
  https://www.census.gov/geographies/reference-files/time-series/geo/gazetteer-files.2026.html
  Download: https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2026_Gazetteer/2026_Gaz_zcta_national.zip
  SHA-256: `f1e9046b91f6e60686a99343cb2752834c02b0764939403b331c78c017e2c54c`
* Natural Earth 1:10m populated places, simple, version 5.1.2:
  https://www.naturalearthdata.com/downloads/10m-cultural-vectors/10m-populated-places/
  Download: https://naciscdn.org/naturalearth/10m/cultural/ne_10m_populated_places_simple.zip
  Public-domain terms: https://www.naturalearthdata.com/about/terms-of-use/
  SHA-256: `2963ee08f7743f13f37d5243acd77a2f7a510e26a36c7e04b920f1b381f2b251`

## Coverage and limitations

33,791 US ZIP Code Tabulation Areas are representative geographic areas, not a
complete or current USPS delivery-code list. PO-box, unique and new ZIP codes may
be absent. Five-digit strings preserve leading zeros. An unmatched code leaves the
previous location unchanged; custom coordinates remain available.

7,342 places, including US cities, across 228 countries/territories are a selective map dataset,
not every city or village. Choose a nearby listed city or custom coordinates.
Names and territorial groupings reflect the source, not a political assertion.
Coordinates are rounded to 0.01 degrees, suitable for approximate solar timing,
not navigation. Keep the Roku time zone correct.

## Reproduce

Download the two archives, verify their SHA-256 values, then run:

    python3 tools/location/build_data.py /path/zcta.zip /path/cities.zip

Only generated `config/location/` files ship. ZIP records use the lossless `ZP01`
binary format: 4-byte magic, big-endian u32 record count, big-endian u16 block
size (128), then one 7-byte index entry per block (u24 first ZIP and u32 byte
offset relative to payload). The 33,791 records require 264 blocks. Each block
resets previous ZIP/latitude/longitude to zero, then stores unsigned base-128
varints: positive ZIP delta, zigzag latitude delta, zigzag longitude delta.
Coordinates retain latitude+90 and longitude+180 in integer hundredths. The
index permits binary search followed by decoding at most 128 records. Leading
zeros are restored when presenting ZIP strings; omitted codes stay unmatched.

City shards retain all names, order, and countries, but store signed integer
hundredths instead of JSON decimal degrees. Runtime divides by 100. Neither
conversion reduces the existing 0.01-degree precision or changes coordinates.
Cities still load one country at a time.

`tools/location/data_hashes.json` pins the original canonical 15-byte ZIP records,
encoded binary, and canonical integer city records. Run
`python3 tools/location/test_data.py` to verify exhaustive roundtrip, all 100,000
possible five-digit ZIP lookups, and dataset hashes/coverage. Codec implementation
and format documentation are in `tools/location/codec.py`.

ZIP payload shrank from 506,865 to 115,575 uncompressed bytes. Full-resolution
splash JPEGs use quality 53/chroma subsampling; lossless masters remain preserved
and tank artwork is unchanged.
