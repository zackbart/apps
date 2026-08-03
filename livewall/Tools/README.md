# Tools

Standalone scripts for livewall maintenance. Run from the repo root.

## seed-catalog.swift

Fetches a few hundred videos from Pexels and writes them as a livewall
seed catalog.

```sh
PEXELS_API_KEY=your_key_here swift Tools/seed-catalog.swift
```

Get a free Pexels API key at <https://www.pexels.com/api/>. The free tier
allows 200 requests per hour; this script makes 8 requests per run (one per
curated query term).

Output goes to `livewall/Resources/catalog.generated.json`. The existing
`catalog.json` is **not** overwritten — review the generated file and rename
it manually if you want to replace the bundled seed catalog. This avoids
breaking any wallpaper IDs that users have already applied (those IDs are
persisted in UserDefaults).

The script:

- Hits `https://api.pexels.com/videos/search` for a curated query list
  (`nature`, `ocean`, `space`, `abstract`, `city skyline`, `forest`,
  `aurora`, `underwater`).
- Picks the highest-quality MP4 file under 4K for each video.
- Maps Pexels metadata to the livewall `Wallpaper` JSON schema:
  `id`, `title`, `thumbnailURL`, `videoURL`, `resolution`, `tags`,
  `source`, `duration`.
- Deduplicates by Pexels video ID across queries.
- Writes atomically (temp file + rename) so a partial run won't corrupt the
  output.

To change the query list or pull more results per query, edit the
`queries` and `resultsPerQuery` constants near the top of the script.
