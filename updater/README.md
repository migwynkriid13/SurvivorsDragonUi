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

1. Acquire an installation lock. Another game instance using this updater prevents changes until it exits. A second launch waits for an update already in progress, then uses the completed installation.
2. Restore the previous addon if a prior interruption left its live folder missing. This happens even without internet.
3. Download the latest public release's `updater-manifest.json` over HTTPS. It identifies one immutable `build-<commit>` release, the TOC version, ZIP hash and complete file hashes.
4. Compare the installed files with that manifest. If every managed file matches, skip the ZIP download. A missing folder, missing TOC or damaged file triggers installation or repair, even if its version label matches.
5. Download `SurvivorsDragonUi.zip` from that exact release. Verify the archive SHA-256 and every file's path, size, CRC and SHA-256. Stage the complete addon beside the live folder, then swap directories before the EXE entrypoint resumes.

An offline connection, timeout, missing release, malformed manifest, corrupt archive or unwritable install skips the update. Existing complete addon files remain available. A first install without internet has no addon to load and retries on the next launch. There is no background polling or mid-run update. Downloads share a twelve-second network budget, with shorter per-operation timeouts and cancellation of slow requests. Local hashing, disk work and waiting for another startup are outside that network budget.

The updater compares addon release files, never EXE versions, hashes, timestamps or internal gameplay signatures. It resolves the game's current PE entrypoint from standard headers on each launch. It does not patch the EXE on disk, change environment variables, update itself or modify sibling addons, characters, preferences or SavedVariables. Its file identity and bootstrap API remain versioned independently from the addon TOC.

## Local files and recovery

`SurvivorsDragonUi-updater.log` beside the EXE reports the last startup result. `SurvivorsDragonUi-updater.lock` coordinates game instances and contains no settings. The installed addon has a `.sdui-release.json` receipt; actual file hashes, rather than that receipt alone, decide whether it is current.

Staging uses `benilla-config/AddOns/.SurvivorsDragonUi-update/`. The last replaced addon is retained in `benilla-config/AddOns/.SurvivorsDragonUi-backup/`. Only these two updater-owned folders and the exact `SurvivorsDragonUi` folder are managed. A failed activation attempts immediate rollback. If interruption or a filesystem error leaves only the backup, the next launch restores it before checking the network. An activation whose rollback also fails can temporarily leave the addon unavailable; the log and backup remain for recovery.

For manual rollback, close all game instances, remove the optional DLL, move the current addon aside and rename `.SurvivorsDragonUi-backup` to `SurvivorsDragonUi`. Removing only `avrt.dll` stops future automatic updates and leaves the installed addon available for manual updates.

Reparse points, directory links, unsafe Windows names, case collisions, unexpected ZIP members, encrypted entries, split archives and ZIP64 are refused. Limits are 1 MiB for metadata, 64 MiB for the archive, 32 MiB per expanded file, 256 MiB expanded in total and 4,096 files. Only HTTPS on GitHub's release hosts is accepted; certificate validation stays enabled and credentials/cookies are disabled. Hashes protect integrity against corruption and mismatched artifacts; the release repository and HTTPS transport remain the trust source.

The native startup handoff must restore the entrypoint and forward the real system AVRT functions before the game runs. A failure in that handoff can stop startup; removing the optional DLL restores normal loading. Game changes that remove the AVRT import or alter DLL loading policy can require an updater revision. There is no game-version lock or recurring offset update.

## Build and release

All updater code, dependencies, build instructions and tests live under `updater/`. CI uses Windows x64 MSVC with static runtime libraries. `build/action.yml` shares the build and test steps between PR checks and the main release workflow. The DLL has no external JSON or ZIP library requirement at runtime.

The main release builds and tests the DLL whenever the addon payload or updater changes. Each release publishes four separate assets: `SurvivorsDragonUi.zip`, `avrt.dll`, `updater-manifest.json` and `SHA256SUMS.txt`. The existing runtime manifest still determines the ZIP; it contains neither the DLL nor updater sources. Release metadata is generated from that exact ZIP and source manifest. Assets are uploaded to a draft before publication; successful releases are immutable on reruns. Older builds do not displace a newer Latest release. Updater-only changes require no addon TOC bump.

CI fixtures cover first install, latest detection, upgrades, same-version repair, missing files, offline first/existing installs, interrupted downloads and swaps, activation rollback and retry, invalid downloads, path escapes, case collisions, expanded-size limits and linked addon directories. They also check that sibling addons, settings, the EXE and DLL remain unchanged. A separate tiny Windows test EXE imports the DLL and checks the entrypoint handoff and system AVRT forwarding without starting the game or downloading an addon. Python CI checks the real release ZIP, metadata, checksums and updater-only release gating, then passes that exact ZIP through the native install-and-current check in a temporary directory without loading Lua.

No local tests, standalone validation, Windows compilation, addon execution or game launch were performed for this PR. Formatting and source review are the local verification. CI results and actual Windows/Wine game startup remain separate acceptance steps; Wine loading/HTTPS behavior and appearance are unverified.

## Source and licenses

The AVRT proxy and PE entrypoint handoff are adapted from the owner's [SpiderlessAzerothSurvivors source at fe9b278](https://github.com/migwynkriid13/SpiderlessAzerothSurvivors/tree/fe9b278304880c0375674182289426e92897cdbd). Its model resources, patch engine, native signatures and scaling policy are excluded. Network and filesystem work starts after DLL initialization and exception dispatch, outside the loader lock, following [Microsoft's DLL guidance](https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-best-practices).

Static dependencies are pinned to immutable upstream commits:

| Library       | Version | Commit                                     | License                                     |
| ------------- | ------- | ------------------------------------------ | ------------------------------------------- |
| nlohmann/json | 3.12.0  | `55f93686c01528224f448c19128836e7df245f72` | [MIT notice](third_party/json-LICENSE.txt)  |
| zlib          | 1.3.2   | `da607da739fa6047df13e66a2af6b8bec7c2a498` | [zlib notice](third_party/zlib-LICENSE.txt) |

Both original license texts are embedded in the standalone DLL as resources 101 and 102.
