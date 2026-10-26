# Download badge

The README's **total downloads** badge combines downloads of assets named exactly `SurvivorsDragonUi.zip` and `avrt.dll` across all published releases, including pre-releases. It excludes checksums, updater manifests, other filenames and drafts. It counts file downloads, not unique people or installations.

Shields' built-in GitHub download badge can count one asset name or every asset. The combined badge instead reads Shields endpoint JSON from `downloads.json` on the dedicated `download-badge` branch.

`.github/workflows/download-badge.yml` follows every page of GitHub's releases API, selects the two filenames and sums their `download_count` values. It refreshes hourly, after a successful **Package and release** workflow, on manual release publication/edit/deletion, and when the badge workflow changes on `main`. The workflow can also be run manually from Actions on `main`.

The first run after merge creates the badge branch automatically. That branch contains only the generated JSON. Later runs add a commit only when the total changes; they never commit to `main`, publish a release or change addon files. GitHub scheduling delays and Shields caching can delay visible updates. Failed API requests leave the last published badge intact.

The workflow uses GitHub's built-in token with `contents: write` to publish the JSON. It checks out and executes no repository code and consumes no release artifacts.
