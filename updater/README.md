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

The game never waits for an internet check or download. Startup activates any complete update already downloaded on an earlier launch, then starts one detached background worker and resumes the EXE. There is no thread join or network request in the startup path. Existing-addon replacement happens only during local startup activation.

1. Acquire the local session lock. If no other game instance uses this addon folder, migrate old updater folders out of `AddOns`, restore an interrupted swap and verify/apply any complete pending update, without network access. If the addon directory is still absent, grant this launch's worker permission to install the first copy. Other launches receive no first-install permission.
2. Retain a shared session lock until process exit. A separate lock coordinates background downloads, so an existing game session does not block staging. Only one worker writes staging at a time.
3. In the background, download the latest public release's `updater-manifest.json` over HTTPS. It identifies an immutable `build-<commit>` release, the TOC version, ZIP hash and complete file hashes.
4. Compare the installed files with that manifest. Matching files skip the ZIP download. A complete pending download is reused. A missing folder, missing TOC or damaged file triggers installation or repair, even if the version label matches. A newer installed version is never replaced by an older published or pending version.
5. Download `SurvivorsDragonUi.zip` from that exact release. Verify the archive SHA-256 and every file's path, size, CRC and SHA-256, then stage a complete pending copy outside `AddOns`. If this worker has first-install permission and the canonical addon directory remains absent, atomically install the verified tree as `AddOns/SurvivorsDragonUi` immediately. An existing destination is never removed or overwritten by the worker. Updates and repairs of existing addons remain pending until the next full game launch.

An offline connection, timeout, missing release, malformed manifest, corrupt archive or unwritable install skips the background update. Existing addon files and any complete pending update remain available. There is no background retry loop or idle polling; the next launch tries again. Downloads share a twelve-second network budget with shorter per-operation timeouts and asynchronous cancellation of slow requests. This budget runs on the background worker and does not delay game startup.

A first download creates the correctly named addon folder as soon as the complete download is ready. The updater does not force a native rescan, `/reload` or enable choice. If the game has already scanned addons, its UI may still need the next launch to discover the new installation. A game session that started with the addon installed keeps that version's files until it exits, even if someone renames or deletes its folder during downloading. A destination created during the download also stays intact.

Replacing an existing addon during gameplay could mix Lua and artwork from different releases, so those updates activate at the next full launch. A previously completed download can activate even when that launch is offline. Two simultaneous startups may briefly coordinate local verification/activation, but neither waits for downloading.

The updater compares addon release files, never EXE versions, hashes, timestamps or internal gameplay signatures. It resolves the game's current PE entrypoint from standard headers on each launch. It does not patch the EXE on disk, change environment variables, update itself or modify sibling addons, characters, preferences or SavedVariables. Its file identity and bootstrap API remain versioned independently from the addon TOC.

## Local files and recovery

`SurvivorsDragonUi-updater.log` beside the EXE reports local activation and then the background result. `SurvivorsDragonUi-updater.lock` coordinates game instances and download workers on separate byte ranges and contains no settings. The installed addon has a `.sdui-release.json` receipt; actual file hashes, rather than that receipt alone, decide whether it is current.

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

The canonical-folder first-install change uses updater 1.0.1. Users of 1.0.0 must replace their optional DLL once to get this behavior; the DLL does not update itself. Future addon releases reuse the frozen 1.0.1 binary until another explicit updater revision.

Each addon release publishes five separate assets: `SurvivorsDragonUi.zip`, `avrt.dll`, `updater-manifest.json`, `updater-binary.json` and `SHA256SUMS.txt`. The existing runtime manifest still determines the ZIP; it contains neither the DLL nor updater sources. Release metadata is generated from that exact ZIP and source manifest. Assets upload to a draft before publication; successful releases are immutable on reruns. Older builds do not displace a newer Latest release. Updater-only changes require no addon TOC bump.

CI fixtures cover an immediate complete first install under the exact canonical name, updater storage outside `AddOns`, destination races, offline first-install failure, legacy staging/backup migration, background updates without live-file changes, local next-launch activation, pending reuse/corruption, interrupted staging, downgrade refusal, independent session/worker locks, same-version repair, rollback, invalid archives/paths, size bounds and linked addon directories. They also check that sibling addons, settings, the EXE and DLL remain unchanged. A separate tiny Windows test EXE checks the entrypoint handoff and system AVRT forwarding without starting the game or downloading an addon.

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
