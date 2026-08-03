# Legacy repository migration

The native apps previously lived in standalone GitHub repositories. Their
default-branch histories were imported without squashing and are ancestors of
this repository's `main` branch.

Historical release tags were namespaced to avoid collisions with one another
and with the monorepo's future release tags:

| App | Historical tags | Future tags |
| --- | --- | --- |
| Barr | `legacy-barr-v*` | `barr-v*` |
| Windo | `legacy-windo-v*` | `windo-v*` |
| Loadout | `legacy-loadout-v*` | `loadout-v*` |

All 23 historical GitHub Releases and all 40 attached assets were copied to
this repository. Asset filenames, byte sizes, and SHA-256 digests match the
standalone repositories.

Four Barr branches contained commits that were not merged into its default
branch. Their tips are preserved by these tags:

- `legacy-barr-branch-agent-coalesce-shelf-layout`
- `legacy-barr-branch-agent-integration-bug-sweep`
- `legacy-barr-branch-agent-stabilize-menu-bar-environment`
- `legacy-barr-branch-agent-stabilize-synthetic-menu-moves`

GitHub does not support retaining original release publication timestamps or
download counters when releases are recreated in another repository.
