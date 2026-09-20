# Weston-era port notes (historical)

These are the working notes from the first version of this package, which ran
the game under PortMaster's weston runtime with a static SDL3 build. That
launcher was replaced in September 2026 by the SDL3-on-SDL2 shim package
described in the top-level README, so the launcher internals, teardown logic
and PipeWire tuning below no longer describe the shipped port. The
measurements of the game itself (frame time, save states, ABI floor, device
support) still apply.

---

# muos-rg35xx-sp-picori

Packaging for **Project Picori** (*The Legend of Zelda: The Minish Cap* PC port)
as an installable port for the Anbernic RG35XX SP running muOS.

> ### Status: finished, and looking for a maintainer
>
> This port works and is complete as far as its original porter intends to take
> it. It is **not** actively maintained — issues and pull requests may sit
> unanswered.
>
> **You do not need anyone's permission to continue it.** Everything here is
> GPL-3.0-or-later. Fork it, take the name, submit updates to PortMaster under
> your own account — none of that requires asking.
>
> Start at [**Taking this over**](#taking-this-over): which repo a given bug
> lives in, the three lines you change to ship a binary from your own fork,
> what is device-specific and what is not, and what is known to be unfinished.

The player-facing documentation is [`port/picori/README.md`](port/picori/README.md).
This file is about building the package.

## Build

```sh
./build.sh 1.0.0            # -> dist/1.0.0/picori.zip
```

`build.sh` fetches the `tmc_pc` binary from a tagged release on the fork,
verifies it against a pinned SHA-256, stages `port/` around it and zips the
result. The 59 MB binary is deliberately not in git.

To build against a local compile instead:

```sh
TMC_BINARY=/path/to/tmc_pc ./build.sh 1.0.0-dev
```

## Test

```sh
./tools/test-launcher.sh
```

Runs the launcher against a sandboxed PortMaster/sysfs/weston/PipeWire stub and
asserts that the CPU governor and the forced PipeWire clock are restored on all
three exit paths (missing ROM, clean quit, killed mid-game). Both of those are
system-wide settings, so a teardown bug misconfigures the device until reboot;
this suite caught exactly that twice. Run it after touching the launcher.

## Layout

The zip unpacks into `ports/`, following PortMaster convention:

```
Legend of Zelda - The Minish Cap.sh    launcher
picori/
  tmc_pc                  fetched at build time, not in git
  config.json             port settings (device-tuned defaults)
  tmc_pc.gptk             pad -> virtual keyboard map
  picori-weston.ini       320x240 X screen, 2x compositor upscale
  port.json               PortMaster metadata
  gameinfo.xml            frontend metadata
  README.md               player documentation
  version.txt             stamped by build.sh
  baserom.gba             SUPPLIED BY THE USER, never shipped
```

## Where the binary comes from

Upstream is [999sian/tmc](https://github.com/999sian/tmc) (GPL-3.0-or-later).
The shipped build is the fork
[lorencouse/tmc @ `rg35xx-sp-audio-ui`](https://github.com/lorencouse/tmc/tree/rg35xx-sp-audio-ui),
five commits ahead of `master`, all of them handheld-class fixes:

| Commit | What |
|--------|------|
| LINEAR resampler | Upstream's SINC resampler costs a whole A53 core here — music played at half speed |
| 44.1 kHz synth | The SP codec's "48000" clock runs fast; 44.1 kHz is the honest rate |
| `TMC_UI_SCALE` | The ImGui overlay is fixed 380–620 px wide, off-screen on a 320 px display |
| `aspect_mode: "stretch"` | Fill a 4:3 panel instead of letterboxing the native 3:2 frame |
| `aspect_mode: "pixel_perfect"` | Integer scaling — every game pixel becomes an identical NxN block |
| `TMC_AUDIO_TRACE` | Logs frames/s pulled and the negotiated device format |

None of these are SP-specific hacks, so the intent is to upstream them and go
back to shipping official release builds. Until then this repo pins a fork tag.

## Picture quality

Two independent defects were measured on the panel and fixed:

1. **The compositor was blurring everything.** At weston `scale=2` the X screen
   is 320x240 and weston bilinear-upscales it to the 640x480 panel. Captured
   from `/dev/fb0`: **0 of 320** column pairs identical, and one scanline
   carried **326 distinct colours** from a 320px source. `scale=1` makes the X
   screen match the panel, so weston composites 1:1 and filters nothing —
   the same capture then gives 110/320 identical column pairs and 21 colours.
2. **Nothing scaled by an integer.** Every mode was fractional: 1.3333x/1.5x
   under stretch, so nearest-neighbour produced source pixels of *different
   widths* (a repeating 2,1,1). `pixel_perfect` (added in v0.8.3-sp2) snaps to
   the largest whole multiple.

The cost, measured in real decoupled play on the same scene:

| | `present` | fps | tps |
|---|---|---|---|
| `scale=2` (old) | 3.24 ms | ~30 | 60.00 |
| `scale=1` (now) | 7.5 ms | ~26.5 | 60.00 |

The X socket has no MIT-SHM, so the whole window is copied every frame and the
transfer dominates — which is why pixel-perfect saves less than its pixel count
suggests (15.4 vs 19.1 ms on the bench). **Game speed is unaffected either way**;
only the render cadence moves. Those `fps` figures are pre-v1.2.0; see below.

## Frame rate

The port now holds **60 fps**. It used to run at 30, and both halves of that
were self-inflicted:

1. **`frame_time_ns` was 33333333** — a 30 fps render cadence, written into the
   shipped `config.json`. Under decoupled pacing this caps only the render
   grid, so the game was always *ticking* at 60; it just drew every other tick.
2. **Raising the cap alone made it worse, not better** (~14 fps). The decoupled
   pacer only presents when `now + presentCostEMA <= tickDeadline`. A present
   cost ~16.5 ms against a 16.67 ms tick window, so the fit test failed every
   time and frames only went out on the 100 ms starvation override. Skipped
   presents keep the EMA high, which skips more — a death spiral.

The fix is `internal_scale: 2`, which is counter-intuitive: it does *more*
work and runs faster. SDL's software renderer scales 240x160 -> 640x480 (2.67x)
far more slowly per output pixel than 480x320 -> 640x480 (1.33x). Pre-expanding
2x in the port's own tight loop costs ~3.7 ms of render but takes the whole
present from 16.5 ms to ~8.7 ms — comfortably inside the tick window, so every
tick presents.

Measured on device, 45-90 s runs, governor pinned, frontend stopped:

| `frame_time_ns` | `internal_scale` | `present`/present | presents per 120 ticks | fps |
|---|---|---|---|---|
| 33333333 (30) | 1 | 16.5 ms | 60 | 30.0 |
| 16666667 (60) | 1 | 16.5 ms | 29 | ~14 |
| 20000000 (50) | 1 | 16.3 ms | 36 | ~18 |
| 16666667 (60) | 4 | 20+ ms | 18 | ~10 |
| **16666667 (60)** | **2** | **8.7 ms** | **120** | **60.00** |

Over a 90 s run: 82 of 85 samples at exactly 60.00 fps, 2 at 59.02, 1 at 58.03,
zero audio underruns, ~40% of the four cores total (game 21%, weston 13%,
Xwayland 9%).

**The prescale is pixel-identical, not a quality trade.** Both paths are
nearest, and `floor(floor(x*480/640)/2) == floor(x*240/640)` for all x because
`floor(floor(y)/n) == floor(y/n)` for positive integer n; vertically both
reduce to `floor(y/3)`. Pixel-perfect becomes a straight 1:1 blit. `4` is past
the sweet spot — the 960x640 intermediate costs more than the cheaper blit
saves.

### Follow-up (2026-09-03): the 60 was partly luck, and where the time really goes

A later report of "dropping a lot of frames" led to a full pacing study with
the port's profiler, the muOS frontend stopped and the governor pinned. The
same binary and config measured 37-57 fps on one launch and 12-15 on the next,
and every run eventually fell into a regime of ~8 fps. What was found:

- **The panel is 640x480 @ 59.98 Hz** (framebuffer driver), but the crusty
  fake-DRM layer that weston runs on reports **66.8 Hz**. SDL's software
  renderer has no real vsync: it sleeps to a timer at the *reported* rate
  after each copy. A weston `mode=` line can force 59.9 or 120 Hz and the
  shim accepts it, but the custom-mode path presented *slower* (18 ms per
  present) than the native one, so the shipped config keeps the native mode.
- **Per present, in motion:** ~4.5 ms raster + 2x prescale, 0.3 ms texture
  upload, ~5 ms for the X copy. With a 5-7 ms game tick that is 15-17 ms per
  frame against a 16.67 ms budget — 60 fps only in light scenes.
- **The X copy is the variable.** It costs ~5 ms while frames stream and
  ~17 ms after the compositor has gone idle (a static screen, or a run of
  skipped presents). The pacer's cost-fit check then refused the next
  present too, which made the following one dearer: a spiral down to the
  100 ms starvation floor. Fork `v0.8.3-sp3` caps consecutive skips at two.
- **Vsync-locked ticks** (present every tick, re-seat the grid on the
  return) were tried and measured: they serialise the copy with the game
  and dropped game speed to ~50 ticks/s here. The feature is in the fork as
  an opt-in (`vsync_lock_ticks`, off) because it is right where a present
  genuinely blocks on a refresh.
- **Fast-forward** was bounded by presenting at 60 Hz: a tick that does not
  present skips the raster too and costs ~2.3 ms, so `fast_forward_fps: 15`
  took R2 from ~2x to **5-7x** (306-415 ticks/s measured). With the present
  thread on that same setting reached 640-970 ticks/s but showed only 14
  frames a second, which players read as a slideshow. Re-measured on the SP
  (same scene, `TMC_REPRO_FASTFORWARD_AT`, first 10 s of fast-forward):

  | `fast_forward_fps` | real presents/s | ticks/s |
  |---:|---:|---|
  | 15 | 14 | 640-970 |
  | 30 | 26 | 360-660 |
  | **35** | **30** | **305-550** |
  | 45 | 35 | 165-235 |
  | 60 | 43 | 135-170 |

  Real cadence trails the setting because the pacer schedules the next
  present from the end of the current one, not on a grid. The cliff past
  ~30 presents/s is the display pipeline (worker copy, Xwayland, weston)
  crowding the game thread off the four cores. 35 is the shipped value.

### The present thread (built, not yet measured here)

What fixes normal play properly is a **present thread**: the X copy blocks the
game thread for 5-17 ms, and nothing in pacing can hide that. That now exists
in the fork as `present_thread` (`config.json`, default off;
`TMC_PRESENT_THREAD=1` overrides for one session).

The game thread rasters and prescales as before, hands the finished pixels to
a worker and returns; the worker owns the texture and does upload -> clear ->
compose -> present. Handoff is latest-wins over two staging buffers, so the
engine never blocks on the display and a slow present costs display rate,
never game speed. The pacer needs no changes: its present-cost EMA measures
what the game thread actually pays, which is now a memcpy, so the cost-fit
check that was refusing presents starts passing on its own.

Overlays are the catch. The settings menu, soft slots and touch controls draw
through the same renderer *and* read live game state, so they can never run on
the worker. The ImGui frame is therefore built first — that touches no
renderer — and whether it produced any draw data picks the path: an empty draw
list (normal gameplay in console mode) presents threaded, anything else drains
the worker and presents synchronously as before.

Measured on the SP, launcher-driven, 95 s runs, same scene, same binary.
Statistics are over the 85 in-run samples, excluding the teardown tail:

| CPU | `present_thread` | fps mean | fps min | present (game thread) | tps |
|---|---|---|---:|---|---|
| 1.512 GHz | off | 59.70 | 55.08 | 8.92 ms (raster 4.7 + flip 4.1) | 60.01 |
| 1.512 GHz | **on** | 59.44 | 55.08 | **6.15 ms** (flip 0) | 60.01 |
| 1.200 GHz | off | 57.85 | **40.33** | ~9.5 ms | 60.01 |
| 1.200 GHz | **on** | **59.78** | **57.05** | ~5.2 ms | 60.01 |

**At full clock this scene has headroom, so the frame rate does not move** —
the flip simply stops being the game thread's problem, worth ~2.8 ms/frame.
The handoff is not free: it copies the finished 480x320 frame into staging,
which is why the raster column absorbs part of what the flip column gives up.

The bottom two rows are the point. Underclocking to 1.2 GHz puts the same
scene over budget, which is the condition the port actually cares about, and
there the saved time converts into frames: **the worst second goes from 40.3
to 57.1 fps** and the mean recovers to within a frame of 60. The gain is in
the floor, not the average — which is what "drops frames in busy scenes"
means to a player.

Game speed (`tps`) is 60.01 in every configuration; decoupled pacing was
already protecting that. What changes is whether the display keeps up.

The per-second census (`TMC_PACE_LOG=1`) reports 61 of 61 presents threaded
with zero fallbacks to synchronous, so the overlay check is not quietly
disabling the path.

### Two measurement traps, both hit while producing the table above

- **Not every launch brings up the same backend.** One run showed
  `fps mean=30.95`, which read as a catastrophic baseline. It had no
  `PPU: SDL_Renderer driver = ...` line at all: `SDL_CreateGPUDevice` failed
  *and* the SDL_Renderer failed, so it silently fell back to the surface
  path. Its present census was all zeros, which is the tell. Any run used for
  comparison has to be gated on the backend line and a non-zero census first.
- **Tearing weston down with `kill -9` poisons the next launch.** Runs that
  followed a `pkill -9 weston` measured `flip=70 ms` and `tps=29` on *both*
  settings — a half-torn-down compositor makes the X copy roughly fifteen
  times more expensive. Let the launcher's own `cleanup()` run and give it
  time; every run from a clean state reads as the table.

Both of these produce numbers that look like real findings, so they are
recorded here rather than quietly fixed.

Dead ends, ruled out by measurement rather than guessed at:

- **Native Wayland** (drop Xwayland): the shipped SDL3 prints
  `SDL compiled video drivers: x11 kmsdrm offscreen dummy evdev` — no Wayland
  driver is built in, so this needs a fork rebuild.
- **MIT-SHM**: `ipcs -m` says *kernel not configured for shared memory* and
  there is no `/proc/sysvipc`. Genuinely impossible, not a config miss.
- **Hardware blit** via westonwrap's `crusty_x11egl` gfx mode: EGL comes up
  (`GL version: OpenGL ES 3.2`) but SDL still reports
  `SDL_Renderer driver = software` and `SDL_CreateGPUDevice failed`. No gain.
- **`vsync: false`**: made it *worse* (~8 fps). Present blocks ~16 ms either
  way, and turning vsync off only removed the pacing that was keeping the EMA
  honest.

## Shutdown

Until v1.2.1 every quit ended in `SIGABRT` and left a ~900 KB `bugreport_*`
directory in the port folder. Not a game bug — a launcher ordering bug.

`GAME_PID` is the pid of `westonwrap.sh`, not of `tmc_pc`. Signalling the
wrapper tore weston down (and Xwayland with it) while the game was still
attached to the display, so inside `tmc_pc`:

```
X connection to :0 broken (explicit kill or server shutdown).
free(): corrupted unsorted chunks
[BUG] CRASH (SIGABRT)
```

libX11's default IO error handler ran on a display that had already gone
away, and glibc tripped over the heap on the way out. The captured state was
worthless too (`Area 0x0`, `HP 0/0`, `Frame 0`) because it was teardown, not
gameplay — so the bug reporter only ever produced noise.

The fix is ordering: `cleanup()` now finds `tmc_pc` by name, sends it
`SIGTERM`, waits up to 5 s for it to actually be gone, and only then
terminates the wrapper. Verified on hardware — clean exit, no `SIGABRT`, no
bugreport bundle, no survivors, governor back to `ondemand`.

This also corrects a note that stood since the 60 fps work: `tmc_pc` *does*
exit on `SIGTERM`. It had simply never been sent one.

**Still open (fork-side, not fixable here):** the game does not flush a save
when it exits. Progress falls back to the interval autosave ring, so the
worst case is bounded rather than lost, but a save-on-`SIGTERM` handler in
`999sian/tmc` would close it.

## Save states

Twenty manual slots plus a three-deep auto-save ring, all in **MENU → Saves**.
One manual slot is *selected*; that is what the load button restores, and the
selection persists in `config.json` as `savestate_slot`.

| Button | Action |
|---|---|
| **L2** | Quick-save to a new slot (counts up, wraps at 20) |
| **R2** (hold) | Fast-forward |
| **Y** | Load the selected slot |
| **SELECT + L2 / R2** | Previous / next slot |

The picker shows a **preview thumbnail** and a timestamp per slot. Twenty
identical dates would tell you nothing about which state is the fight you
wanted, so each save captures the frame that was on screen.

Within a session a load is exact. A state from an **earlier session** restores
the save file and re-enters the same room at the same position through the
game's own continue path (toast: "room re-entered"): inventory, flags, health
and position carry over, room state starts fresh. See below for why.

### What had to change in the fork

Save states existed but every route to them was a hard-wired keyboard case —
F5/F6 quick, F1-F4 direct. There is no keyboard on this device, so the only
way in was the F8 menu, and the Controls tab, which rebinds every other
action, had nothing to offer. Fast-forward was TAB-only for the same reason.

Six bindable actions now exist — `state_save`, `state_save_new_slot`,
`state_load`, `state_next_slot`, `state_prev_slot` and `fast_forward` — acting
on a selected slot rather than a fixed one, so a handful of binds reach all
twenty. Thumbnails ride in a `state_N.thumb` sidecar rather than inside the
state file so that adding them did not by itself force a format bump. A state
with no sidecar simply shows no picture.

The first on-device test then found the real bug: **a mid-game load stranded
Link off-screen with controls dead.** The upstream snapshot covered the four
GBA memory arrays plus a hand-picked few structs, but this port moved nearly
all of the GBA's RAM residents into host globals — the entity list heads,
entity counters, textbox system, area/room variables, fade, priority handler
and script contexts were all outside it, so a load restored entity bodies from
one moment and bookkeeping from another. The region table now lives beside the
globals (`gPortStateRegions`, 97 regions) and covers everything mutable; a
900-frame headless replay after restore is byte-identical. That did force the
format bump: states from before 1.3.0 show as empty.

Cross-session loads were a second, pre-existing problem: the snapshot is full
of host pointers (entity links, script contexts, the text cursor into an asset
buffer) valid only in the process that wrote them, and relocating them all
means chasing hundreds of heap allocations in the asset loader. Rather than
ship a heuristic, a state carries its writer's session id; a foreign state
restores the save file and re-enters the room through the engine's own
continue path. Exact cross-session restores would need the asset cache moved
to a fixed-address arena — a follow-up, not a blocker.

### What had to change here

SDL sees no gamepad on this device (weston/libinput refuses muOS-Keys, so
gptokeyb hands the port a virtual keyboard). The port can therefore only bind
*keys* — and the SP's buttons send a fixed set of them. Two facts made the
layout work:

- **X, Y, L2 and R2 were free.** They are the port's soft-slot buttons, but no
  `tmc.softslots` sidecar has ever been written, so nothing was assigned to
  them. Y, L2 and R2 now carry the save-state and fast-forward keys; X stays
  free for soft slots.
- **The button names are scrambled.** muOS-Keys reports the pad under borrowed
  key codes, so SDL's `l2`/`r2` are the case's L2/R2 but SDL's `back`/`start`/
  `guide` are SELECT/START/MENU. Decoded from `/proc/bus/input/devices`
  against the launcher's `SDL_GAMECONTROLLERCONFIG`; the table is in
  `tmc_pc.gptk`. There is no `BTN_TR2`, `BTN_MODE` or `BTN_THUMBL/R` in the
  key bitmap at all — the SP has no sticks and no spare button beyond those.

Slot cycling needs a modifier, and the spare keys for it come from a gptokeyb
hotkey layer: `[controls:hk_hotkey]`, activated by `-H back` on the gptokeyb
command line, remaps L2/R2 while SELECT is held.

Two things worth knowing if you edit that layer:

- A key **left out of a layer is unbound while the hotkey is held**, not
  inherited from `[controls]`. `gptokeyb2 -d` prints it empty. Everything
  that is not an override is therefore repeated verbatim, or holding SELECT
  would also mute the face buttons, START and the MENU overlay.
- `hotkey =` is **not** a `[config]` key. It is the `-H` command-line option;
  the parser prints "unknown global hotkey" and carries on without it.

The auto ring (slots 21-23) is loadable from the menu but not selectable — it
overwrites itself on a schedule, so a hand-made state parked there would
silently vanish.

## Runtime requirements

Determined by reading the ELF directly:

- **glibc ≥ 2.29**, no `libstdc++` at all (it is linked statically)
- Dynamic deps: `libpng16`, `libEGL`, `libGLESv2`, `libgomp`, `librt`,
  `libpthread`, `libdl`
- SDL3 is statically linked — which is *why* the launcher must use westonwrap
  gfxmode `system`: crusty hooks any binary exporting SDL symbols as if it
  were SDL2 and crashes this one.
- PortMaster runtime `weston_pkg_0.2.squashfs`
- PipeWire (the launcher forces `clock.force-rate 44100` / `force-quantum 768`
  on the system graph for the session, and restores them on exit)

That floor sits below every entry in PortMaster's catalogue (the highest
`min_glibc` across its 1,422 entries is 2.32), so the ABI is no longer what
keeps a device out. Confirmed by reading the shipped `v0.8.3-sp4` binary --
the release asset itself, not CI's report of it:

```
$ objdump -p tmc_pc | grep NEEDED
  libpng16.so.16  librt.so.1  libEGL.so.1  libGLESv2.so.2  libpthread.so.0
  libdl.so.2  libm.so.6  libgomp.so.1  libc.so.6
$ objdump -T tmc_pc | grep -oE 'GLIBC_[0-9.]+'   | sort -uV | tail -1  -> GLIBC_2.29
$ objdump -T tmc_pc | grep -oE 'GLIBCXX_[0-9.]+' | sort -uV | tail -1  -> (none)
```

`librt`, `libpthread` and `libdl` appear in `NEEDED` where they did not
before; that is the point, and it is harmless on a modern glibc, where all
three survive as stubs.

Before this release the port needed **glibc 2.34** and `GLIBCXX_3.4.30`,
higher than anything in the catalogue -- older CFW could not load it at all.

## Device support

The port was written for, and every measurement in this file was taken on,
the RG35XX SP. Nothing in it is *conceptually* SP-specific though — it is a
software-rendered aarch64 binary under the stock PortMaster weston runtime —
so the work in flight is to widen it to the rest of the aarch64 handhelds
without giving up the tuning that made 60 fps reachable here.

Three things gated that, in order of how many devices each one costs.

**1. The runtime ABI floor.** The single biggest one, and it is decided
entirely by the build container: nothing else matters if the loader refuses
the binary. The fork now links `-static-libstdc++ -static-libgcc` on Linux
(`xmake.lua`) and builds its aarch64 leg inside `debian:bullseye` (glibc
2.31) rather than on `ubuntu-22.04-arm` (2.35). bullseye's stock GCC 10 is
enough — the only C++20 in the tree is `<span>` and `<numbers>`, so no LLVM
backport is needed.

Measured, by the CI step against the ELF it just produced:

| | `v0.8.3-sp3` (previous) | `v0.8.3-sp4` (shipped) |
|---|---|---|
| glibc | `GLIBC_2.34` | **`GLIBC_2.29`** |
| libstdc++ | `GLIBCXX_3.4.30` | **none (static)** |

2.29, not the 2.31 the container could have permitted — the code simply
never reaches for anything newer. Against a catalogue whose highest
`min_glibc` is 2.32, that clears every entry.

Getting there turned up two link bugs that a modern-only build matrix
could not have surfaced, both of which would have broken an old-glibc
device on their own, independently of the libstdc++ problem:

- `shm_open`/`shm_unlink` (`port_shm_framebuffer.c`) only moved from
  `librt` into libc in **2.34**, so nothing had ever needed `-lrt`.
- `pthread_create` (`std::thread`, in the extractor's `ParallelFor`) moved
  in the same release, so nothing had needed `-lpthread` either.

Both now come from `add_linux_posix_syslinks()` in `xmake.lua`, and both
are correct on every glibc — the libraries survive as stubs after 2.34.

CI gates the result. `_build.yaml`'s "Report the runtime ABI floor" step
reads the produced ELF and fails the build if it needs anything above
`matrix.glibc_max`, or if a `GLIBCXX_`/`CXXABI_` reference reappears
(which would mean `-static-libstdc++` had stopped reaching the link). The
floor cannot drift back up unnoticed.

`libgomp.so.1` is still a dynamic dependency (the OpenMP scanline workers)
and is *not* covered by those flags. It is present on muOS; whether every
target CFW ships it is unverified. The step prints `NEEDED` on every build,
so this stays visible.

Two workflow bugs were fixed along the way that were never about the
container, both worth knowing about because they made good builds look
broken. The SDL3 audio gate ran `strings "$BIN" | grep -qx "$backend"`
under `bash -e -o pipefail`: `grep -q` exits on match, SIGPIPEs `strings`,
and the pipeline returns 141 **on success**, which pipefail reads as
failure. It survived for years on the hosted runners because whether
`strings` still had output buffered when grep quit is a timing accident.
Both that gate and the ABI step now dump to a file and read the file.

**2. The panel.** `config.json`'s `aspect_mode` and `internal_scale` were
tuned for one 4:3 640x480 screen. The launcher now derives them from the
actual panel — `DISPLAY_WIDTH`/`DISPLAY_HEIGHT` where PortMaster exports
them, else `/sys/class/graphics/fb0/virtual_size`, else the SP's — and
seeds them **once**, on first launch, so a player's own Settings changes
are never overwritten:

| Panel | `aspect_mode` | `internal_scale` | Why |
|---|---|---|---|
| 4:3, ≥480 wide (SP, RG40XX, RG353) | `stretch` | 2 | The measured SP config |
| 4:3, <480 wide | `stretch` | 1 | Too narrow for the 480x320 prescale to pay |
| 1:1 720x720 (RGB30, CubeXX) | `pixel_perfect` | 3 | 3:2 stretched to square is grotesque; see below for the 3 |
| 16:9 1280x720 (TrimUI Smart Pro class) | `pixel_perfect` | 2 | Likewise; the panel takes a 4x frame, which 2 divides |

**`internal_scale` and `pixel_perfect` interact** (found by a CubeXX tester on
v1.5.3, who got a 480x320 box in the middle of a 720x720 screen). The port
hands SDL the *prescaled* frame, 240·S x 160·S, and pixel-perfect then fits
the largest whole multiple of that. A 720x720 panel takes a 3x GBA frame
(720x480), which S=2 cannot reach: only one 480x320 copy fits. So for
pixel-perfect panels the launcher computes k = min(W/240, H/160) and picks
the largest of 3, 2, 1 that divides k — 3 on 720x720, 2 on 1280x720 (k=4),
1 on the rare panel where nothing else fits. Three rather than one because
SDL's software scaler at large ratios is exactly what the prescale exists to
avoid (see **Frame rate**). The seed marker now carries a rule number, so an
install seeded by the old rule is re-seeded once — but only while
`aspect_mode`/`internal_scale` still read what the old rule wrote, so a
player's own Settings changes are never touched.

`weston.ini` is generated at launch too. The shipped `picori-weston.ini`
names the SP's output (`VGA-0`), and weston silently ignores an `[output]`
section matching no real output — so on a device that calls its panel
something else the section was simply inert. The generated file repeats the
same `scale=1` block under every name these handhelds use; at most one
matches and the rest cost nothing.

**3. muOS-only audio.** `SDL_AUDIODRIVER=pipewire` and the forced
`clock.force-rate 44100` / `clock.force-quantum 768` are measured against
*this* codec on a CFW that runs PipeWire. ArkOS and friends run bare ALSA or
PulseAudio, where `pw-metadata` does not exist and naming the pipewire
driver leaves the port silent. The launcher now probes for a live graph and
only takes that path when there is one; otherwise it passes no driver at all
and lets SDL's own probe decide.

### What is still unverified

Honesty about the limits of the above: **it has been tested on the SP, in the
sandbox, and — for the input question only — on one x86_64 device.** `tools/test-launcher.sh` covers the
panel matrix, the first-launch-only seeding, the generated `weston.ini` and
both audio paths, but a sandbox cannot tell you whether the game is playable.

One thing still needs someone with other hardware; the other has now been
measured (see **Input doubling: measured**, below).

- **CPU headroom.** RK3326 devices (RG351, RG353, OGA) are 4x A35 at
  1.3 GHz — slower per clock than the SP's A53 at 1.512 GHz — so the 60 fps
  cap that `internal_scale: 2` makes reachable here probably is not
  reachable there. The port's own Settings menu is the escape hatch, but
  the shipped defaults for that tier are a guess until measured.

### Input doubling: measured

Tested on a Steam Deck (x86_64, SteamOS 3, glibc 2.41) on 2026-09-03. The Deck
is not a port target — it was used purely as a device where SDL enumerates a
real gamepad *and* a keyboard from the same physical controls, which is the
condition the SP cannot reproduce. The earlier note in this section claimed
"presses arrive twice" for every dual-bound action. That is wrong, and the
correction matters because it removes a blocker rather than adding one.

The port has two input paths, and only one of them can double:

- **Gameplay and menus are immune.** `Port_Config_InputPressed` polls and
  returns `true` on the first matching bind, so `SDLK:` + `SDL_GAMEPAD:` on
  one action is a logical OR, not a count. The sub-frame edge cache is a
  `std::array<bool>` set to `true` and cleared once per frame by
  `Port_Config_ClearInputEdges()` (`port_bios.c`), so it cannot accumulate
  either. Menu nav converges the same way: the hook only accepts keyboard
  events and both sources feed one idempotent `AddKeyEvent`.
- **The save-state actions can double.** They are handled per SDL *event* via
  `Port_Config_EventIsInputDown` (`port_bios.c`), so one action bound to two
  inputs that both fire runs the handler twice.

Measured, with `state_save_new_slot` dual-bound and driven by synthetic key
events (two keys exercise the identical `sBinds` loop a key+pad pair would):

| case | binds | fired | `[quicksave]` lines |
|------|-------|-------|---------------------|
| I | Home + End | Home only | 1 |
| J | Home + End | End only  | 1 |
| K | Home + End | both, one chord | **2** |

Case K wrote `state_1.bin` and `state_2.bin` in the same second from a single
press. So the doubling is real, but it is confined to the save-state actions.

**The shipped `config.json` is not exposed.** Every dual-bound action in it
(`a`, `b`, `up`, `down`, `select`, `start`, `l`, `r`, `soft_*`, `roll_attack`)
is a polled gameplay action, and all six save-state actions (`state_save`,
`state_load`, `state_next_slot`, `state_prev_slot`, `state_save_new_slot`,
`fast_forward`) are bound to exactly one `SDLK:` each. No shipped action can
double on any device. This is not a PortMaster blocker.

The latent hazard, worth fixing in the fork rather than here: the Controls tab
can *append* a binding, so a player on a pad-visible device who adds a pad
button to a save-state action that gptokeyb also drives will get two saves per
press. A per-frame guard on the save-state block, mirroring the edge cache's
existing per-frame semantics, is the natural fix.

Two incidental findings from the same session:

- SDL ignores Steam's virtual gamepad unless the app runs under Steam, so the
  port reports `SDL gamepads found: 0` on a Deck until
  `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD=1` is set. Anyone retesting
  this on a Deck will hit that false negative first.
- A save-state action bound to a printable letter key (`n`) never fired, while
  navigation keys (`Home`, `End`, `PageUp`/`PageDown`) fired reliably. Not
  root-caused, and possibly an artifact of synthetic X key injection rather
  than a port bug. It does not affect the shipped mapping, which uses only
  non-printable keys for these actions — but rebinding one to a letter may not
  work, and that is worth a real-hardware check before anyone documents it as
  supported.

Out of scope: **armhf**. The fork releases an arm64 asset only, and the
32-bit-only devices (RG350, RS97, PocketGo) could not hold the tick rate for
a software PPU regardless.

## Status

Tier A: installable. Not yet submitted to PortMaster.

- [x] Launcher hardened with trap-based teardown (governor + PipeWire settings
      are system-wide; a crash previously left them applied until reboot)
- [x] Game runs backgrounded under `wait` so signals are not deferred
- [x] ROM presence + SHA-1 validation across all three regions
- [x] First-launch asset-extraction notice (~2 min on a still screen)
- [x] `port.json` / `gameinfo.xml` / player README
- [x] `screenshot.png` (captured from the device) and `cover.png`
- [x] Tagged release [`v0.8.3-sp4`](https://github.com/lorencouse/tmc/releases/tag/v0.8.3-sp4)
      on the fork; `build.sh` fetches and verifies from it
- [x] Reproducible build verified from a fresh clone
- [x] Shipped configs verified byte-identical to the working device install
- [x] Launcher verified on hardware (governor pinned + restored, audio thread
      lifted to SCHED_FIFO, frontend hands off cleanly)
- [x] End-to-end install test from the zip on a clean install: extracted
      `picori-1.2.0.zip` into a bare `ports/picori`, supplied only
      `baserom.gba`, and launched. Asset extraction ran from scratch
      (~2 min), the game reached gameplay at a steady 60 fps, and the
      teardown restored the governor to `ondemand` with no stray
      processes. The no-ROM path was checked too: it prints both
      `pm_message` lines and exits 0.
- [x] Shutdown `SIGABRT` fixed — `cleanup()` reaps `tmc_pc` before tearing
      down weston, so quitting no longer aborts inside libX11's IO error
      handler or writes a `bugreport_*` bundle (see **Shutdown**)
- [x] Save-state management: 20 manual slots + auto ring with preview
      thumbnails and timestamps in **MENU → Saves**, driven by L2 (save to a
      new slot), Y (load) and R2 (fast-forward) (see **Save states**)
- [x] Portability pass for devices other than the SP: static libstdc++ and a
      glibc-2.31 build container in the fork with a CI gate on the resulting
      ABI floor; panel-derived `aspect_mode`/`internal_scale` seeded once on
      first launch; a generated `weston.ini` that is not tied to one output
      name; the PipeWire path taken only where a graph answers. Covered by
      20 new checks in `tools/test-launcher.sh` (see **Device support**)
- [x] Fork CI builds the aarch64 leg against glibc 2.31 and the ABI gate
      passes: the produced binary needs **`GLIBC_2.29`** and no libstdc++
      at all (run
      [33807524582](https://github.com/lorencouse/tmc/actions/runs/33807524582),
      branch `portmaster-abi-floor`)
- [x] Full matrix green on that branch — Linux x86_64/arm64, Windows
      x86_64/arm64, macOS Intel/Apple Silicon and the Android APK (run
      [33808370409](https://github.com/lorencouse/tmc/actions/runs/33808370409)).
      The `-lrt`/`-lpthread` additions are `is_plat("linux")`-gated and did
      not disturb the macOS or Windows legs, and only the arm64 cache key
      gained its `-bullseye` suffix. The desktop Linux build benefits too:
      x86_64 still needs `GLIBC_2.34` (it is built on ubuntu-22.04) but has
      likewise dropped its `libstdc++` dependency
- [x] Retagged the fork as `v0.8.3-sp4` (release run
      [33809887410](https://github.com/lorencouse/tmc/actions/runs/33809887410),
      all seven legs green); `build.sh` pins that tag and the new binary's
      SHA-256, and `port.json`'s `min_glibc` is now **2.29**. The published
      aarch64 asset was downloaded and read directly to confirm it — max
      `GLIBC_2.29`, no `GLIBCXX_`/`CXXABI_`, no `libstdc++` in `NEEDED`
- [x] Input doubling confirmed on a non-SP device (Steam Deck, x86_64, glibc
      2.41 — used as a test rig, not a port target). Doubling is real but
      confined to the save-state actions, which the shipped `config.json`
      binds to exactly one key each; every dual-bound action is on the polled
      path and cannot double. Not a submission blocker — see **Input
      doubling: measured**. The shipped build also ran there unmodified: all
      dynamic deps resolved against stock SteamOS, and it took the Vulkan
      `SDL_GPU` path at 60 fps rather than the SP's software fallback
- [x] GPL compliance in the shipped zip: `LICENSE` now ships inside
      `picori/` (the binary is GPL-3.0-or-later and the archive carried no
      licence text — `build.sh` stages only `port/`, and the licence lived at
      the repo root). `build.sh`'s required-files check now includes it, so a
      build fails rather than silently dropping it, and the player README
      points at the **tag** `v0.8.3-sp4` for source rather than the mutable
      branch. Rebuilt as `picori-1.4.1.zip`
- [ ] Still open from that item: whether the RK3326 tier (RG351, RG353, OGA)
      needs different shipped defaults — needs one of those devices, not a
      Deck
- [x] Package restructured to the layout Multiverse ports actually use
      (metadata at the port root, game files in `picori/`, third-party
      licences in `picori/licenses/`), and the cover regenerated at 640x480
      4:3. Built as `picori-1.5.0.zip`
- [ ] PortMaster submission → **Multiverse**. Blocked on cross-CFW testing,
      which the spec requires and which needs hardware — see **Submitting to
      PortMaster** for what is left and the two deliberate deviations.

Note for anyone benchmarking: launching the port over adb (rather than from
the muOS Ports menu) leaves `muxplore` running. It keeps drawing to `/dev/fb0`
and keeps `/dev/input/event1` open — the same device gptokeyb2 reads — so the
screen double-draws and every button press reaches both the game and the muOS
menu. That is not a port bug; launch from the Ports menu.

Known cosmetic gaps, from the device log: `SDL_CreateGPUDevice` fails and the
port falls back to software rendering, and no TTS backend exists — so
`gpu_raster` and `tts_enabled` in the shipped `config.json` are inert here.

## Taking this over

This port is GPL-3.0-or-later and nobody needs the original porter's
permission to continue it. What follows is what you would otherwise have to
reverse-engineer.

### The two repositories

Packaging and engine are separate, and which one you need depends on the bug:

| Symptom | Lives in |
|---|---|
| Launcher, weston, audio routing, governor, gptokeyb map, PortMaster metadata | **this repo** |
| Rendering, gameplay, save states, the settings overlay, pacing | the **fork**, [lorencouse/tmc](https://github.com/lorencouse/tmc) |
| Anything reproducible on desktop Linux with no handheld involved | upstream [999sian/tmc](https://github.com/999sian/tmc) |

A packaging fix needs nothing but this repo and `./build.sh <version>`. The
binary is fetched from a tagged release and checked against a pinned SHA-256,
so a fresh clone reproduces the shipped zip byte-for-byte.

### Rebuilding the engine under your own account

`build.sh` does not build `tmc_pc`; it downloads it. To ship a binary of your
own, fork the fork, push a tag, let its CI produce
`tmc-multi-linux-arm64-<tag>.tar.gz`, then change **three lines** near the top
of `build.sh`:

```sh
TMC_REPO="lorencouse/tmc"        # -> your fork
TMC_TAG="${TMC_TAG:-v0.8.3-sp4}" # -> your tag
TMC_SHA256="ee01c50e..."         # -> sha256sum of your tmc_pc
```

The fork's CI builds seven legs; the aarch64 one runs in a container against
an old glibc so the result works on CFW images stuck on 2.29. That gate is
what keeps the binary installable on the older devices — do not "simplify" it
away. `min_glibc` in `port.json` must match whatever floor you actually build
against.

For local iteration, `TMC_BINARY=/path/to/tmc_pc ./build.sh 9.9.9` skips the
download; the SHA-256 check will fail loudly, which is the intended reminder
to update the pin before publishing.

### What is device-specific and what is not

The fork carries ~35 commits on top of upstream. Most are **not**
SP-specific — save-state slots, the pixel-perfect aspect mode, the settings
overlay, an out-of-bounds map-tile crash guard, a TTS shutdown race fix. Those
belong upstream and every one that lands there is one less reason for this
fork to exist.

Genuinely device-conditional, all behind
`#if defined(__linux__) && defined(__aarch64__)`:

- the LINEAR audio resampler (upstream's SINC costs a whole A53 core)
- a 44.1 kHz render rate
- `TMC_UI_SCALE` for the ImGui overlay on small panels

Note the middle one assumes every Linux/aarch64 target shares the SP's codec
behaviour, which is true of the handhelds and not obviously true of ARM
desktops. If it ever needs narrowing, that is the commit to look at.

### The highest-value next step: upstreaming

Every fork commit that lands in [999sian/tmc](https://github.com/999sian/tmc)
is one less reason this fork has to exist, and one less thing a future
maintainer has to inherit. The 35 commits were triaged once; the result is
recorded here so nobody has to redo it.

**Ready to send as-is.** Standalone fixes, no device assumptions, small
diffs — three independent PRs:

| Commit | What |
|---|---|
| `4d32c0f3f` | Out-of-bounds map-tile guards + CR handling in the dungeonmap parser. A crash fix, touches `src/`, benefits every platform |
| `da80cb10b` | Join the TTS worker in `~State` — a 14-line shutdown race |
| `87ae2b5ba` | Slot previews via out-param instead of a static |

**Worth upstreaming after a rebase.** Real features, but developed
incrementally and interleaved with changelog edits — squash before proposing:

- **Save states** — `9f383127f`, `4f4e25724`, `a5588a744`, `eaf2110c5`.
  ~1000 lines: 20 slots, previews, keyboard-free rebinding, foreign-state
  resume through the engine. The single biggest reason anyone currently has
  to adopt this fork rather than build upstream.
- **Aspect modes** — `2e87170bb` (stretch), `430f7e5ce` (pixel-perfect).
  ~70 lines, self-contained, useful on any non-3:2 display.
- **Settings overlay** — `38974f681`. 500 lines and opinionated about UI;
  worth asking upstream before writing the PR.
- **Pacing / present thread** — `1d667ee9b` plus the vsync-lock and pace-log
  commits. The present thread is opt-in and genuinely useful; the pace-log
  commits are diagnostics that accreted during the investigation and should
  be squashed hard or dropped.
- **Region/language** — `d77c98235`. A real refactor with a test, and stands
  on its own merits.

**Leave in the fork.** Device-conditional (see above), plus the nine CI and
`xmake.lua` commits from `5cd376d1e` to `bfdb87ea0` — those exist to hit a
glibc floor upstream has no reason to care about.

If someone does only the three ready-to-send fixes and the two aspect-mode
commits, that is five small PRs and it measurably shrinks what the next
maintainer inherits.

### Submitting to PortMaster

Target is **Multiverse**
([PortsMaster-MV/PortMaster-MV-New](https://github.com/PortsMaster-MV/PortMaster-MV-New)),
not the main repo: every Nintendo-decomp port (Ship of Harkinian, sm64coopdx,
zelda3) lives there. The requirements are at
[portmaster.games/packaging.html](https://portmaster.games/packaging.html).

The tree under `port/` is laid out to match what Multiverse ports actually
look like on disk (compare `ports/soh` and `ports/dusklight`): metadata at the
port root, game files in `picori/`, third-party licences in
`picori/licenses/`.

**What still blocks a PR**, and it is a process gap rather than a code one:

> Pull requests without documented cross-CFW testing will be rejected.

The port has been tested on exactly one device on one CFW — an RG35XX SP
running muOS. The spec asks for AmberELEC, ArkOS, ROCKNIX and muOS at 640x480
minimum, with the results posted in the PortMaster Discord's
`#testing-n-dev` channel *before* the PR is opened. That needs hardware and a
human; no amount of packaging work substitutes for it.

**Two deliberate deviations from the spec.** Both were left alone because the
launcher currently works on the one device anyone has run it on, and a
conforming launcher that has never been executed is worse than a slightly
non-conforming one that has:

1. The binary is `tmc_pc`, not `tmc_pc.aarch64`. The suffix is the documented
   convention (`soh.elf.aarch64`, `dusklight.aarch64`). Renaming touches four
   runtime sites — the `exec` line, the gptokeyb2 target, `pidof tmc_pc` in
   `cleanup()`, and the audio-thread scan — and each one fails silently if
   missed.
2. `pm_platform_helper` is not called before launch. `get_controls` and
   `pm_finish` are.

Fix both together with one smoke test on real hardware, not blind.

Softer: `cover.png` is 640x480 and 4:3 as required, but it is character art on
white rather than the gameplay-plus-logo composition the guide prefers.

### Things known to be unfinished

- Whether the RK3326 tier (RG351, RG353, OGA) wants different shipped
  defaults. Nobody has run this on one. See **Device support**.
- The player README under `port/picori/` is written for the SP specifically,
  while `port.json` claims all of aarch64. On a 1:1 or 16:9 panel the launcher
  seeds `pixel_perfect`, so the README's "(default)" column is wrong there.
- A save-state action bound to a printable letter key never fired during the
  x86_64 test while `Home`/`End` fired reliably. Unexplained, does not affect
  the shipped mapping, and may be an artefact of synthetic key injection —
  worth one check on real hardware. See **Input doubling: measured**.
- `port_bios.c` in the fork evaluates the save-state block per SDL event, so
  an action bound to two keys at once fires twice. No shipped binding is
  exposed to it, but a per-frame guard would close it for good.

## Licence

The port binary is GPL-3.0-or-later (Project Picori). The launcher and
packaging in this repo are released under the same terms — see `LICENSE`.

No game data is included or distributed. *The Legend of Zelda: The Minish Cap*
is property of Nintendo.
