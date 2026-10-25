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

The game never waits for an internet check or download. Startup activates only a complete update already downloaded on an earlier launch, then starts one detached background worker and resumes the EXE. There is no thread join or network request in the startup path. Local verification and the directory swap happen before the game can read addon files.

1. Acquire the local session lock. If no other game instance uses this addon folder, restore an interrupted swap and verify/apply any complete pending update, without network access. Otherwise keep using the current addon.
2. Retain a shared session lock until process exit. A separate lock coordinates background downloads, so an existing game session does not block staging. Only one worker writes staging at a time.
3. In the background, download the latest public release's `updater-manifest.json` over HTTPS. It identifies an immutable `build-<commit>` release, the TOC version, ZIP hash and complete file hashes.
4. Compare the installed files with that manifest. Matching files skip the ZIP download. A complete pending download is reused. A missing folder, missing TOC or damaged file triggers installation or repair, even if the version label matches. A newer installed version is never replaced by an older published or pending version.
5. Download `SurvivorsDragonUi.zip` from that exact release. Verify the archive SHA-256 and every file's path, size, CRC and SHA-256, then stage a complete pending copy. The running game's files stay intact. The next full game launch activates the download; `/reload` is not required or invoked by the updater.

An offline connection, timeout, missing release, malformed manifest, corrupt archive or unwritable install skips the background update. Existing addon files and any complete pending update remain available. There is no background retry loop or idle polling; the next launch tries again. Downloads share a twelve-second network budget with shorter per-operation timeouts and asynchronous cancellation of slow requests. This budget runs on the background worker and does not delay game startup.

A first download also takes effect on the next launch. Replacing the live folder during gameplay could mix Lua and artwork from different releases, so background work never activates files in the current session. A previously completed download can activate even when the next launch is offline. Two simultaneous startups may briefly coordinate local verification/activation, but neither waits for downloading.

The updater compares addon release files, never EXE versions, hashes, timestamps or internal gameplay signatures. It resolves the game's current PE entrypoint from standard headers on each launch. It does not patch the EXE on disk, change environment variables, update itself or modify sibling addons, characters, preferences or SavedVariables. Its file identity and bootstrap API remain versioned independently from the addon TOC.

## Local files and recovery

`SurvivorsDragonUi-updater.log` beside the EXE reports local activation and then the background result. `SurvivorsDragonUi-updater.lock` coordinates game instances and download workers on separate byte ranges and contains no settings. The installed addon has a `.sdui-release.json` receipt; actual file hashes, rather than that receipt alone, decide whether it is current.

Extraction uses `benilla-config/AddOns/.SurvivorsDragonUi-download/`. Only after all files are verified and flushed is a receipt written and the completed tree renamed to `.SurvivorsDragonUi-update/`. The last replaced addon is retained in `.SurvivorsDragonUi-backup/`. Only these three updater-owned folders and the exact `SurvivorsDragonUi` folder are managed. An interrupted partial extraction cannot activate. A completed extraction interrupted before its staging rename can recover locally on the next launch.

A failed activation attempts immediate rollback and retains the pending copy for retry. If interruption or a filesystem error leaves only the backup, the next launch restores it before any network work. An activation whose rollback also fails can temporarily leave the addon unavailable; the log and backup remain for recovery.

For manual rollback, close all game instances, remove the optional DLL, move the current addon aside and rename `.SurvivorsDragonUi-backup` to `SurvivorsDragonUi`. Removing only `avrt.dll` stops future automatic updates and leaves the installed addon available for manual updates.

Reparse points, directory links, unsafe Windows names, case collisions, unexpected ZIP members, encrypted entries, split archives and ZIP64 are refused. Limits are 1 MiB for metadata, 64 MiB for the archive, 32 MiB per expanded file, 256 MiB expanded in total and 4,096 files. Only HTTPS on GitHub's release hosts is accepted; certificate validation stays enabled and credentials/cookies are disabled. Hashes protect integrity against corruption and mismatched artifacts; the release repository and HTTPS transport remain the trust source.

The native startup handoff must restore the entrypoint and forward the real system AVRT functions before the game runs. A failure in that handoff can stop startup; removing the optional DLL restores normal loading. Game changes that remove the AVRT import or alter DLL loading policy can require an updater revision. There is no game-version lock or recurring offset update.

## Build and release

All updater code, dependencies, build instructions and tests live under `updater/`. CI uses Windows x64 MSVC with static runtime libraries. `VERSION` is the updater's independent version. The DLL has no external JSON or ZIP library requirement at runtime.

The first main release builds and tests the updater once, then publishes its exact binary under the fixed, non-Latest release `updater-v1.0.0`. Every subsequent addon release downloads that same `avrt.dll` and `updater-binary.json`, verifies its SHA-256 and native source fingerprint, and attaches the same bytes to the new addon release. No compile/link step runs on the normal reuse path. The updater binary never follows game or addon version changes.

Native source changes require an explicit `updater/VERSION` bump to create a different updater binary. A changed source fingerprint, corrupt download, unfinished updater draft or service failure stops release packaging. A version tag whose release is missing also fails and requires restoring the original artifact. PR CI still compiles the source for review; those test binaries do not replace the published artifact.

Each addon release publishes five separate assets: `SurvivorsDragonUi.zip`, `avrt.dll`, `updater-manifest.json`, `updater-binary.json` and `SHA256SUMS.txt`. The existing runtime manifest still determines the ZIP; it contains neither the DLL nor updater sources. Release metadata is generated from that exact ZIP and source manifest. Assets upload to a draft before publication; successful releases are immutable on reruns. Older builds do not displace a newer Latest release. Updater-only changes require no addon TOC bump.

CI fixtures cover background staging without live-file changes, local next-launch activation, offline startup, pending reuse and corruption, completed staging recovery, downgrade refusal, independent session/worker locks, first install, updates, same-version repair, interrupted transfers/swaps, activation rollback, invalid archives/paths, size bounds and linked addon directories. They also check that sibling addons, settings, the EXE and DLL remain unchanged. A separate tiny Windows test EXE checks the entrypoint handoff and system AVRT forwarding without starting the game or downloading an addon.

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
