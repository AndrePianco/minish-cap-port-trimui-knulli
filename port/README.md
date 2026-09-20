## Notes

Thanks to [999sian](https://github.com/999sian/tmc) and the Project Picori contributors for the native PC port of *The Legend of Zelda: The Minish Cap*, to the [zeldaret](https://github.com/zeldaret/tmc) team for the decompilation it is built on, and to [bmdhacks](https://github.com/bmdhacks/SDL/tree/sdl2-backend) for the SDL3-to-SDL2 shim that lets an SDL3 program run on these handhelds.

**This port does not include the game.** Copy your ROM into `ports/picori/` as `baserom.gba` (USA), `baserom_eu.gba` (Europe) or `baserom_jp.gba` (Japan). The first launch extracts the game assets from the ROM into `ports/picori/assets/`; later launches skip that.

## Controls

| Button | Action |
|--|--|
| D-pad / left stick | Move |
| A | Sword / confirm |
| B | Item / cancel |
| X | Save-state picker, ready to save |
| Y | Save-state picker, ready to load |
| L1 | GBA L |
| R1 | GBA R |
| L2 | Save a state to a new slot |
| R2 (hold) | Fast-forward |
| Start | Pause menu |
| Select | Select |
| Menu (Guide) | Port settings |
| Start + Select | Quit |

The settings menu opens on whichever button your firmware reports as the controller's Guide button: Menu on muOS and Knulli, R3 on the R36S under AmberELEC. It is a handheld menu, one group of settings at a time: D-pad moves, A opens or toggles a row, B backs out and closes it from the top level, L1 and R1 step through the groups. The footer lists the buttons. The launcher sizes its text from the panel, so nothing in it needs a mouse or a restart.

## Save states

Save states are separate from the in-game save. L2 takes one at any time and rolls through twenty slots, so a run leaves a history instead of one overwritten state. The game also autosaves to a three-slot ring every minute.

X and Y open the picker, a full-screen page with one slot's screenshot, when it was written, and a filmstrip of the neighbouring slots. X opens it ready to save, Y ready to load, and A does whichever the page is on. Left and right move one slot, up and down (or L1 and R1) jump five, B closes. Pressing the other of X and Y switches the page instead of acting, so arriving through the wrong door costs one press and never a run.

X and Y are the port's two extra equip slots on a keyboard (C and V). Nothing in the game assigns an item to them on a handheld, so this package uses them for the picker.

## Saves

The in-game save (`tmc.sav`), the save states (`state_*.bin`), the config and the extracted assets all live in `ports/picori/`. Deleting the port folder removes them; copying the folder to another card keeps them.

## Known issues

- The first launch after copying the ROM spends some seconds extracting assets before anything is drawn. Later launches show the Nintendo logo within a few seconds.

## Source

Built from the `rg35xx-sp-audio-ui` branch of <https://github.com/lorencouse/tmc>, a fork of [999sian/tmc](https://github.com/999sian/tmc) that adds a linear audio resampler, a bigger audio buffer for Linux handhelds, a scalable handheld settings menu, a stretch aspect mode and the save-state picker.

Licensed GPL-3.0-or-later, same as Project Picori. Third-party licences are in `picori/licenses/`.

## Compile

### tmc_pc

Built in a Debian bullseye container on an arm64 host, so the binary loads on old CFW glibc (it needs GLIBC 2.29). `TMC_SDL3_SHARED=1` links SDL3 as a shared library so the shim below can replace it.

```shell
git clone -b rg35xx-sp-audio-ui https://github.com/lorencouse/tmc.git
cd tmc
git submodule update --init --recursive --depth 1
TMC_SDL3_SHARED=1 python3 build.py --usa --slim
```

The binary is `build/pc/tmc_pc`, shipped as `picori/tmc_pc.aarch64`.

### SDL3-on-SDL2 shim

```shell
git clone --recursive -b sdl2-backend https://github.com/bmdhacks/SDL.git
git clone https://github.com/KhronosGroup/SPIRV-Cross.git
cd SDL && mkdir build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-march=armv8-a" \
  -DSDL_SDL2_BACKEND=ON \
  -DSDL_SPIRV_CROSS_DIR=../../SPIRV-Cross \
  -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF \
  -DSDL_PIPEWIRE=OFF -DSDL_PULSEAUDIO=OFF -DSDL_ALSA=OFF \
  -DSDL_SNDIO=OFF -DSDL_OSS=OFF -DSDL_JACK=OFF \
  -DSDL_OFFSCREEN=OFF -DSDL_DUMMYVIDEO=OFF \
  -DSDL_DUMMYAUDIO=OFF -DSDL_DISKAUDIO=OFF \
  -DSDL_VULKAN=OFF -DSDL_GPU=ON -DSDL_RENDER_GPU=ON \
  -DSDL_UNIX_CONSOLE_BUILD=ON
make -j$(nproc)
```

The shim is `build/libSDL3.so.0.*`, shipped as `picori/libs.aarch64/libSDL3.so.0`.
