# Optional Windows addon updater

Download `avrt.dll` from the [SurvivorsDragonUi release](https://github.com/migwynkriid13/SurvivorsDragonUi/releases/latest), separately from the addon ZIP. Put it beside `AzerothSurvivors.exe` and start the EXE normally. It targets Windows 10 or newer, x64. There is no launcher, script to run, administrator requirement or additional runtime download.

The DLL installs or updates only this folder:

```text
benilla-config/AddOns/SurvivorsDragonUi/
└── SurvivorsDragonUi.toc
```

The game discovers this folder and loads the TOC on world entry when the addon is enabled. The updater does not execute Lua or change the game's addon enable choices. See the [supplied addon API](../docs/AzerothSurvivors-Addon-API.md#installing-an-addon).

It contains no spider replacements, crab models, creature hooks, gameplay changes or performance flags. Spiderless and other mods using `avrt.dll` occupy the same installation slot; DLL chaining is unsupported. Keep a copy of an existing DLL before choosing which one to install. This change does not replace the DLL in the owner's installed game.

## What happens at startup

The DLL holds the game's original entrypoint while it checks for and downloads an addon update. The release check and ZIP share one ten-second deadline. If the download finishes in time, verification and installation finish before the game starts, so that launch can load the updated addon.

1. Acquire the exclusive startup session lock. Migrate old updater folders out of `AddOns`, restore an interrupted swap and verify/apply any complete pending update, without network access. If another game instance is already running, skip updating to protect its addon files.
2. Download the latest public release's `updater-manifest.json` over HTTPS within the startup deadline. It identifies an immutable `build-<commit>` release, the TOC version, ZIP hash and complete file hashes.
3. Compare the installed files with that manifest. Matching files skip the ZIP download. A complete pending download is reused. A missing folder, missing TOC or damaged file triggers installation or repair, even if the version label matches. A newer installed version is never replaced by an older published or pending version.
4. Download `SurvivorsDragonUi.zip` from that exact release, using the time left from the same deadline. A response finishing at or after the deadline is discarded before extraction. Verify a timely archive's SHA-256 and every file's path, size, CRC and SHA-256, then stage a complete pending copy outside `AddOns`.
5. Move the verified addon into the exact `AddOns/SurvivorsDragonUi` folder, retaining the previous installation as a rollback copy. Retain a shared session lock until process exit, then resume the game's original entrypoint. First installs, updates and repairs all complete in this startup path.

An offline connection, timeout, missing release, malformed manifest, corrupt archive or unwritable install skips the update and resumes the game with its installed copy. A first install that cannot download leaves the addon absent. There is no background downloader or retry loop; the next launch tries again. Shorter per-operation timeouts can skip a failed connection sooner than ten seconds. Slow HTTPS requests use asynchronous cancellation, and no late request can install files during gameplay.

The ten seconds bound checking and downloading. Local verification, filesystem operations and safe rollback must finish before the entrypoint resumes and can add startup time, particularly on a slow disk. The updater does not interrupt a local folder swap halfway through to meet the network deadline. Two simultaneous startups coordinate through the local session lock; a second launch waits for an in-progress startup to release its exclusive lock, then skips updating while that game is running.

A previously completed download can activate even when the next launch is offline. The updater does not force a native rescan, `/reload` or enable choice; enable the addon in the game's AddOns options as usual. A corrupt old pending copy does not block a fresh online download.

The updater compares addon release files, never EXE versions, hashes, timestamps or internal gameplay signatures. It resolves the game's current PE entrypoint from standard headers on each launch. It does not patch the EXE on disk, change environment variables, update itself or modify sibling addons, characters, preferences or SavedVariables. Its file identity and bootstrap API remain versioned independently from the addon TOC.

## Local files and recovery

`SurvivorsDragonUi-updater.log` beside the EXE reports the startup check, installed release, activation or reason for skipping, followed by resuming the game. `SurvivorsDragonUi-updater.lock` coordinates exclusive startup work and shared game sessions and contains no settings. The installed addon has a `.sdui-release.json` receipt; actual file hashes, rather than that receipt alone, decide whether it is current.

Only the canonical `SurvivorsDragonUi` installation is created under `AddOns`. Updater storage lives beside `AddOns`, with the same canonical addon basename in every stage:

```text
benilla-config/
  AddOns/SurvivorsDragonUi/
  SurvivorsDragonUi-updater/
    download/SurvivorsDragonUi/
    pending/SurvivorsDragonUi/
    backup/SurvivorsDragonUi/
```

Only after all extracted files are verified and flushed is a receipt written and the completed tree moved from `download` to `pending`. The previous complete addon is retained under `backup` when an existing installation is replaced. An interrupted partial extraction cannot activate. A completed extraction interrupted before its staging rename can recover locally on the next launch.

Startup migrates version 1.0.0's `.SurvivorsDragonUi-download`, `.SurvivorsDragonUi-update` and `.SurvivorsDragonUi-backup` folders from `AddOns` into their new storage locations. Migration never overwrites an existing destination; conflicting copies are retained. Renamed user copies such as `SurvivorsDragonUiX` and other addons are untouched.

A failed activation attempts immediate rollback and retains the pending copy for retry. If interruption or a filesystem error leaves only the backup, the next launch restores it before any network work. An activation whose rollback also fails can temporarily leave the addon unavailable; the log and backup remain for recovery.

For manual rollback, close all game instances, remove the optional DLL, move the current addon aside and move `benilla-config/SurvivorsDragonUi-updater/backup/SurvivorsDragonUi` into `benilla-config/AddOns/`. Removing only `avrt.dll` stops future automatic updates and leaves the installed addon available for manual updates.

Reparse points, directory links, unsafe Windows names, case collisions, unexpected ZIP members, encrypted entries, split archives and ZIP64 are refused. Limits are 1 MiB for metadata, 64 MiB for the archive, 32 MiB per expanded file, 256 MiB expanded in total and 4,096 files. Only HTTPS on GitHub's release hosts is accepted; certificate validation stays enabled and credentials/cookies are disabled. Hashes protect integrity against corruption and mismatched artifacts; the release repository and HTTPS transport remain the trust source.

The native startup handoff must restore the entrypoint and forward the real system AVRT functions before the game runs. A failure in that handoff can stop startup; removing the optional DLL restores normal loading. Game changes that remove the AVRT import or alter DLL loading policy can require an updater revision. There is no game-version lock or recurring offset update.

## Build and release

All updater code, dependencies, build instructions and tests live under `updater/`. CI uses Windows x64 MSVC with static runtime libraries. `VERSION` is the updater's independent version. The DLL has no external JSON or ZIP library requirement at runtime.

A new updater version is built and tested once, then published under the fixed, non-Latest release `updater-v<version>`. Every subsequent addon release downloads that same `avrt.dll` and `updater-binary.json`, verifies its SHA-256 and native source fingerprint, and attaches the same bytes to the new addon release. No compile/link step runs on the normal reuse path. The updater binary never follows game or addon version changes.

Native source changes require an explicit `updater/VERSION` bump to create a different updater binary. A changed source fingerprint, corrupt download, unfinished updater draft or service failure stops release packaging. A version tag whose release is missing also fails and requires restoring the original artifact. PR CI still compiles the source for review; those test binaries do not replace the published artifact.

The canonical-folder installation and ten-second startup download flow use updater 1.0.1. Users of 1.0.0 must replace their optional DLL once to get this behavior; the DLL does not update itself. Future addon releases reuse the frozen 1.0.1 binary until another explicit updater revision.

Each addon release publishes five separate assets: `SurvivorsDragonUi.zip`, `avrt.dll`, `updater-manifest.json`, `updater-binary.json` and `SHA256SUMS.txt`. The existing runtime manifest still determines the ZIP; it contains neither the DLL nor updater sources. Release metadata is generated from that exact ZIP and source manifest. Assets upload to a draft before publication; successful releases are immutable on reruns. Older builds do not displace a newer Latest release. Updater-only changes require no addon TOC bump.

CI fixtures exercise the production startup flow for complete first installs and existing-addon updates under the exact canonical name. A simulated monotonic clock covers the combined metadata/ZIP deadline, completion just inside the limit, refusal at and after the limit, skipping the ZIP after metadata times out, and no activation of a late response. Other cases cover updater storage outside `AddOns`, offline failure, legacy staging/backup migration, pending reuse/corruption, interrupted staging, downgrade refusal, exclusive startup/shared session locks, same-version repair, rollback, invalid archives/paths, size bounds and linked addon directories. They also check that sibling addons, renamed user copies, settings, the EXE and DLL remain unchanged. A separate tiny Windows test EXE checks the entrypoint handoff and system AVRT forwarding without starting the game or downloading an addon.

Python CI checks the actual ZIP, metadata, checksums, updater-only release gating and frozen-binary reuse, including failure without rebuilding when bytes or native sources differ. Updater PRs and the first binary publication also pass the complete release ZIP through the native installer in a temporary directory without loading Lua. Later addon releases reuse the frozen DLL and check the package/identity contract without recompiling the native test program.

No local tests, standalone validation, Windows compilation, addon execution or game launch were performed for this PR. Formatting and source review are the local verification. CI results and actual Windows/Wine game startup remain separate acceptance steps; Wine loading/HTTPS behavior and appearance are unverified.

## Source and licenses

The AVRT proxy and PE entrypoint handoff are adapted from the owner's [SpiderlessAzerothSurvivors source at fe9b278](https://github.com/migwynkriid13/SpiderlessAzerothSurvivors/tree/fe9b278304880c0375674182289426e92897cdbd). Its model resources, patch engine, native signatures and scaling policy are excluded. Network and filesystem work starts after DLL initialization and exception dispatch, outside the loader lock, following [Microsoft's DLL guidance](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices).

Static dependencies are pinned to immutable upstream commits:

| Library       | Version | Commit                                     | License                                     |
| ------------- | ------- | ------------------------------------------ | ------------------------------------------- |
| nlohmann/json | 3.12.0  | `55f93686c01528224f448c19128836e7df245f72` | [MIT notice](third_party/json-LICENSE.txt)  |
| zlib          | 1.3.2   | `da607da739fa6047df13e66a2af6b8bec7c2a498` | [zlib notice](third_party/zlib-LICENSE.txt) |

Both original license texts are embedded in the standalone DLL as resources 101 and 102.
