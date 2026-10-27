#!/bin/bash
# uso: JUEGO=/ruta/one-last-pack ./simular.sh 1 2 3   (semillas) -> sim_N.csv
AQUI=$(cd "$(dirname "$0")" && pwd)
T=${TMPDIR:-/tmp}/olp_sim
rm -rf $T && mkdir -p $T && cp -r "$JUEGO"/src "$JUEGO"/datos $T/ && cp $AQUI/sim/main.lua $T/
printf 'function love.conf(t) t.window=false t.modules.audio=false t.modules.sound=false t.modules.graphics=false end\n' > $T/conf.lua
cd $T && for s in ${@:-1 2 3}; do love . $s $PWD/sim_$s.csv 2>&1 | grep -v XDG; done; ls $T/*.csv
