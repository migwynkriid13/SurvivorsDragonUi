# Demon summon countdown

Butcher and Pact of the Annihilan have a passive demon socket at the right end of the equipped-jewelry row, above action button seven. The five equipment sockets keep their positions, native readers and tooltips. The extra socket reuses the existing circular icon clipping and gold rim, with the same shared number renderer as abilities and jewelry: centered DEFAULT text, a 14-unit maximum at the action-bar reference scale, outline, black shadow, white/yellow/red thresholds and the final positive sub-100ms zero. It has no item action or hover. It follows the jewelry attachment, including detached mode, and the existing Equipped jewelry and Cooldown numbers choices control its visibility and numeric label respectively. The detached editing region reserves the extra socket without changing the saved owner geometry.

The socket appears only after valid received native summon, run and stat data establish its timing. Missing support or unknown timing hides this socket alone. No placeholder demon, saved gameplay data, new preference, image or independent layout group is added.

## Recovered timing

This is an inferred next-summon countdown, rather than a player buff, trinket cooldown or summon-lifetime display. Its rule was recovered from Azeroth Survivors **0.113.2**, executable SHA-256 `58b484d4a5f145ba41b1241c184c38202e871fdd7aa4a6b90536d0503ecba6bb`.

The current native state serializer at `0x145900080..0x145904a68` supplies a separate `timers` list to the native HUD. Its raw-effect-34 projection uses the scheduler's last successful spawn and the current global cooldown multiplier. The relevant capstone records have interval 30 seconds and minimum interval 13 seconds:

```text
lastSpawn = newest matching AZS_PETS.ends - AZS_PETS.dur
period = max(30 * AZS_STATS.cd, 13)
remaining = max(lastSpawn + period - AZS_GetRunTime(), 0)
```

The scheduler at `0x14592ecb0` writes its spawn timestamp at `0x14592f598`, then invokes the creation wrapper at `0x145962280`. The summon append at `0x14592e560` records the same native run clock as birth. The summon iterator at `0x1459ad860` publishes expiry and duration, with duration calculated as expiry minus birth. The stat producer at `0x1458f4e30` reads the same `Game+0x488` multiplier as the scheduler. Native stat refresh already includes active cooldown auras, so no addon buff arithmetic is needed.

The calculation is isolated in `modules/ui/demon_cooldown.lua`. Only the exact native key/kind pairs `felguard`/`felguard` and `pit_lord`/`pitlord` qualify, and the received native icon supplies the artwork. With overlapping summons, use the newest birth. Retain that observed birth in session memory after ordinary expiry, so the longer interval remains visible while no demon is alive. An early removal, contradictory capstone roster, invalid metadata or backwards birth cannot establish a replacement timer. As with ability numbers, ready/expired time clears the label; the icon can remain while awaiting the next native summon publication.

## Snapshot lifecycle and limits

The jewelry controller forwards native packet notifications to the tracker and reads its icon on the existing five-Hz refresh after packet parsing completes. Numeric painting runs every 100ms, switching to every rendered frame while any displayed jewelry or demon cooldown has at most 200 positive milliseconds left. Phase is checked before retained state. Only received, finite native run and pet stamps qualify; world/zone retirement blocks old packet references and receipt counts. Pending same-batch snapshots can survive zone notification ordering. A regressing raw run time also retires the old inference; interpolated clock corrections do not create false run boundaries. Missing or invalid stat data hides the timer until valid data returns.

`AZS_GetRunTime()` supplies pause and level-up behavior. No wall-clock deadline or decrementing private timer is maintained. World leave/logout and inactive phases clear session timing; nothing is written for ReloadUI. A new VM must receive enough fresh data to observe a qualifying summon before it can display a countdown. This can leave the socket absent temporarily after reload, including the interval with no demon alive. The API has no run identifier or effect-origin field, so unobserved run/talent changes and arbitrary alternate summon creators remain inference limits.

The native summon packet rounds timing to tenths and the cooldown multiplier to three decimal places. Snapshot delay and rounding can briefly change the displayed integer at a boundary. The 0.11-second metadata allowance accommodates rounded birth/expiry boundaries; it does not extend a countdown or supply missing time.

Fresh REA/Ghidra observations recovered the current serializer, HUD reader, summon iterator, stat producer and summon append. Thirty bounded original-instruction cases checked the current timer formula with supplied effect, activity, timestamp, multiplier and clock inputs. That evidence does not execute the addon, full scheduler, game or renderer. This implementation has no local tests, syntax checks, formatting runs or game execution; GitHub Actions performs the repository's static checks. In-game appearance and behavior remain unverified.
