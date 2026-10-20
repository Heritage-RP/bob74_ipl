# Patches

Upstream: https://github.com/Bob74/bob74_ipl (master)

Fork of bob74_ipl for the core of Heritage-RP/PRODUCTION-SERVER. Every patch is generic: a server sets its own values
through convars or other resources (Heritage-RP/PRODUCTION-SERVER docs/dev/forks.md).

| Patch | Kind | Upstream | Files |
|---|---|---|---|
| Villa lots switch: replicated convar `bob74_ipl_mansions` — `villas` (default, as upstream) or `original`: the villas of "A Safehouse in the Hills" are not loaded and the pre-DLC map comes back on their three lots, as the game's `building_controller` script does (no hole on build 3717+, PRODUCTION-SERVER#82, #332, #367) | generic | candidate | `client.lua`, `fxmanifest.lua`, `hrp/mansions.lua`, `tests/lua/mansions_spec.lua` |
| Logs through HrpLog (`@hrp-metrics/lib/log.lua`, first client script) instead of `print` | generic | no | `fxmanifest.lua`, `lib/common.lua`, `dlc_bikers/gang.lua`, `dlc_finance/office*.lua` |
| Tests: `tests/run.sh` runs every `tests/lua/*_spec.lua` in Lua 5.4 through docker (`just test`) | generic | no | `tests/**` |
| Documentation of the fork | generic | no | `README.md`, `PATCHES.md` |
