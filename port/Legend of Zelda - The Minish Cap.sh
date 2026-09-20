#!/bin/bash

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/picori"
BINARY="tmc_pc.${DEVICE_ARCH}"

cd "$GAMEDIR"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

if [ ! -f "$GAMEDIR/baserom.gba" ] && [ ! -f "$GAMEDIR/baserom_eu.gba" ] && [ ! -f "$GAMEDIR/baserom_jp.gba" ]; then
  pm_message "Copy your Minish Cap ROM to ports/picori as baserom.gba (USA), baserom_eu.gba or baserom_jp.gba."
  sleep 5
  exit 1
fi

if [ ! -d "$GAMEDIR/assets" ]; then
  pm_message "First launch: extracting game assets from the ROM. This takes a moment."
fi

$ESUDO chmod +x "$GAMEDIR/$BINARY"

mkdir -p "$GAMEDIR/conf"
export XDG_DATA_HOME="$GAMEDIR/conf"
export LD_LIBRARY_PATH="$GAMEDIR/libs.${DEVICE_ARCH}:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
# Skip the port's desktop ROM/language picker; the ROM is found from the paths above.
export TMC_AUTOPLAY=1

PANEL_WIDTH=${DISPLAY_WIDTH:-640}
PANEL_HEIGHT=${DISPLAY_HEIGHT:-480}

# First launch only: non-4:3 panels get integer scaling instead of the 4:3 stretch.
if [ ! -f "$GAMEDIR/conf/.aspect" ]; then
  if [ $(( PANEL_WIDTH * 3 )) -ne $(( PANEL_HEIGHT * 4 )) ]; then
    sed -i 's/"aspect_mode": "stretch"/"aspect_mode": "pixel_perfect"/' "$GAMEDIR/config.json"
  fi
  touch "$GAMEDIR/conf/.aspect"
fi

# First launch only: window_scale = largest whole multiple of 240x160 that fits
# the panel (1280x720 -> 4, 640x480 -> 2). The game opens its window at
# 240x160 * window_scale before it asks for fullscreen; on Knulli and AmberELEC
# that request left a scale-1 window postage-stamp sized. Only the shipped
# default is rewritten, so a scale picked in the settings menu stands.
if [ ! -f "$GAMEDIR/conf/.scale" ]; then
  scale=$(( PANEL_WIDTH / 240 ))
  scale_v=$(( PANEL_HEIGHT / 160 ))
  [ "$scale_v" -lt "$scale" ] && scale=$scale_v
  [ "$scale" -lt 1 ] && scale=1
  [ "$scale" -gt 10 ] && scale=10
  if [ "$scale" -ne 1 ]; then
    sed -i -e "s/\(\"window_scale\"[[:space:]]*:[[:space:]]*\)1,/\1$scale,/" \
           -e "s/\(\"window_scale\"[[:space:]]*:[[:space:]]*\)1\$/\1$scale/" \
           "$GAMEDIR/config.json"
  fi
  touch "$GAMEDIR/conf/.scale"
fi

# Settings-menu text scale from the panel, in tenths, clamped to the game's
# 0.5-2.0 range (1.0 on 640x480, 1.5 on 1280x720). The game would otherwise
# size it from its pre-fullscreen 240x160 window and pin it at the floor.
ui_tenths=$(( PANEL_WIDTH * 10 / 640 ))
ui_tenths_v=$(( PANEL_HEIGHT * 10 / 480 ))
[ "$ui_tenths_v" -lt "$ui_tenths" ] && ui_tenths=$ui_tenths_v
[ "$ui_tenths" -lt 5 ] && ui_tenths=5
[ "$ui_tenths" -gt 20 ] && ui_tenths=20
export TMC_UI_SCALE="${TMC_UI_SCALE:-$(( ui_tenths / 10 )).$(( ui_tenths % 10 ))}"

# SDL3 shim: pass the CFW's SDL2 driver choice through to the SDL2 underneath.
GAME_SDL_VIDEODRIVER=""
if [ -n "$SDL_VIDEODRIVER" ]; then
  export SDL3SHIM_SDL2_VIDEODRIVER="$SDL_VIDEODRIVER"
  GAME_SDL_VIDEODRIVER=sdl2
fi

GAME_SDL_AUDIODRIVER=""
if [ -n "$SDL_AUDIODRIVER" ]; then
  export SDL3SHIM_SDL2_AUDIODRIVER="$SDL_AUDIODRIVER"
  GAME_SDL_AUDIODRIVER=sdl2
fi

$GPTOKEYB2 "$BINARY" -c "$GAMEDIR/picori.ini" &

pm_platform_helper "$GAMEDIR/$BINARY"

SDL_VIDEODRIVER="$GAME_SDL_VIDEODRIVER" SDL_AUDIODRIVER="$GAME_SDL_AUDIODRIVER" ./"$BINARY"

pm_finish
