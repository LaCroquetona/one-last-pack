#!/bin/bash
# uso: JUEGO=/ruta/one-last-pack ./bots.sh
AQUI=$(cd "$(dirname "$0")" && pwd)
T=${TMPDIR:-/tmp}/olp_bots
rm -rf $T && mkdir -p $T && cp -r "$JUEGO"/src "$JUEGO"/datos $T/ && cp $AQUI/bots/main.lua $T/
printf 'function love.conf(t) t.window=false t.modules.audio=false t.modules.sound=false t.modules.graphics=false t.identity="olp_bots" end\n' > $T/conf.lua
cd $T && love . 2>&1 | grep -v XDG
