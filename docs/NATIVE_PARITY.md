# 1.13.0-test.1 coverage

Wild Skies runs independently on Gen1, Gen2 and native Gen3. No companion mod is
required. Shared option keys/defaults live in `options.lua`; all five are active
in Mod Manager and in-game OPTIONS. Gen1/2 retain their original implementation.

| Option | Native Gen3 behavior |
|---|---|
| `density` | 3/6/10 birds per map, with 8/4/2.5-second refill; excess birds leave when lowered |
| `size` | Live sprite footprint, scaled by native Pokédex height and 0.7/1/1.3/1.6 size choice |
| `bumps` | Ground encounters require a bold bird within the low 12-pixel flight band; towns remain peaceful |
| `skyart` | AUTO uses registered art or optional Wilds species sheets, with standalone native icons; PORTRAIT and CLASSIC force native front art or icons |
| `motion` | Live flapping, bobbing and banked sprite variants; flight simulation continues when disabled |

The native adapter reads native species IDs/types and each map's encounter
table. Flightless Doduo/Dodrio/Natu stay out; bats can populate caves by day.
Birds cruise in the 28–76-pixel band, sometimes descend, perch on safe native
collision cells, flush, flock, and leave. Open-sky legendary sightings retain
the 1/1000 roll and 48–52 level band. Neighbor fields retain their own identities
through native map seams. Rendered actors use ordinary native `raiseY` altitude,
which both stock rendering and Battle Art understand; shadows are separate
native actors. Native SKY DEX previews AUTO/PORTRAIT/CLASSIC art.

## Public optional integration

`flyerAt(cellX,cellY,radius,altitude?,tolerance?)` reads a bold eligible flyer.
`takeFlyer` takes the same arguments. Local results contain numeric native Gen3
`species`, exact `level`, `id`, and `altitude`; shared takes return `nil,'pending'`.
`takeFlockmate` is rest-exempt and excludes legends/shared rosters. `spawnFlyer`
accepts a native number or canonical name; `summonFlyer` emits the existing
arrival/failure events. Sprite sources retain `resolve(exports,game,species,dex)`
and may return a native graphics ID/sheet or an image/frame definition.

Ride uses only public flyer methods and receives airborne grants through
`startSharedSkyEncounter`. Doubles sources are scoped to a specific local sky
encounter and choose an actual flockmate; shared fights remain single because
the protocol claims one bird. Legendary sightings veto doubles.

## Authority contract

The existing SKY provider API is available on all generations. Register
`{role,localAuthority,requestClaim,finishClaim}` with
`registerSharedSkyProvider(id,provider)`. An explicit guest role suppresses
generation before the first snapshot. Snapshots use canonical **string** species
keys and pixel `x/y/alt`, plus exact level, velocity, facing, mode and boldness.
Native local APIs convert these keys to native numeric species IDs.

`canClaimSky(position,row,context,map)` checks a supported host map, boldness,
one-cell contact, peaceful towns, ground setting and altitude. Air contact uses
the authoritative player altitude and a 20-pixel vertical tolerance.
`grantSharedSkyFieldContact(map,id,authoritativeRow)` consumes an existing pending
claim and returns whether native battle entry succeeded. Pending claims survive
roster removal snapshots, including a synchronous grant. Failed starts do not
locally remove the bird. A battle result calls `finishClaim`: native `catch`
(legacy `caught`) or `win` commits; escape/loss releases the host's original row.
Guests never recreate a survivor with `spawnFlyer`. Online owns transport and
reservation state; Skies owns ecology and presentation.

Native snapshots support loaded map definitions, including remote maps with
native encounter data. Missing definitions fail closed. Legacy remote snapshots
are limited to the current map and native resident neighbors.

## Verification and remaining differences

`luajit tests/gen3_skies_unit_test.lua` checks standalone native boot, all option
rows, live art changes, ecology filters, neighbor projection, Sky Dex, shared
species conversion, guest authority, altitude checks and grant/removal/survivor
ordering. All 53 assertions pass. These are contract doubles, not gameplay. All new modules compile.
The 19 inherited tests require `tests.modkit`, which is absent from this checkout
and the official 0.3.1 engine package; their fixture-dependent run is pending.

Native rooftop perches await a renderer-independent roof-height API: current
Battle Art roof data depends on the active rendered footprint. Native ground
perches are implemented. Native ambient fallback pools use curated FRLG species
instead of legacy world-wide encounter-frequency weighting. Native night ecology
uses the local clock because FRLG has no native day/night encounter slots. Sky
Dex is a native preview page rather than the legacy Modern UI adapter. No
all-map art, all-cart gameplay, controller or long-running network certification
is claimed before the packaged test release.
