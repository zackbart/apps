# Release versioning

Keep `MARKETING_VERSION` at `1.0`. All Deadbolt iOS updates increment only `CURRENT_PROJECT_VERSION` unless Zack explicitly changes this policy. Keep app and AutoFill extension version/build numbers identical.

Use the Cursor Kittens team (`F2J8ZU2NQJ`) and App Store Connect app `6835505284`. Other Apple teams are present; use `scripts/asc.sh` for the existing Cursor Kittens ASC profile.

Use runbp for builds and simulator validation. Run only one simulator at a time and close each session when finished. Source publication to `zackbart/apps` and private TestFlight distribution are authorized. Never commit vault data, signing keys, ASC credentials, raw test evidence, or build artifacts; scan staged changes before pushing.
