#!/bin/bash
# uso: JUEGO=/ruta/one-last-pack ./correr.sh            (partida nueva, guion.lua)
#      JUEGO=... PARTIDA=/ruta/partida.lua GUION=guion_conversion.lua ./correr.sh
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
T=${TMPDIR:-/tmp}/olp_prueba
SAVE=$HOME/.local/share/love/one-last-pack
GUION=${GUION:-guion.lua}
rm -rf $T && mkdir -p $T && cp -r "$JUEGO"/main.lua "$JUEGO"/conf.lua "$JUEGO"/src "$JUEGO"/datos $T/
[ -d "$JUEGO"/musica ] && cp -r "$JUEGO"/musica $T/
[ -d "$JUEGO"/sprites ] && cp -r "$JUEGO"/sprites $T/
mv $T/main.lua $T/main_juego.lua
cp $AQUI/harness.lua $T/main.lua && cp $AQUI/$GUION $T/guion.lua
rm -rf $SAVE && mkdir -p $SAVE
if [ -n "$PARTIDA" ] && [ "$GUION" = guion_conversion.lua ]; then
# lo que se espera de la partida de prueba (formato v5: coleccion/primeras/fundas)
luajit -e '
local d = dofile(arg[1])
local n,p1,f=0,0,0
for id,c in pairs(d.coleccion or {}) do n=n+c; p1=p1+math.min(c,(d.primeras or {})[id] or 0); f=f+math.min(c,(d.fundas or {})[id] or 0) end
io.open(arg[2],"w"):write(string.format("return { n=%d, p1=%d, f=%d, anuncios=%d, dinero=%d }\n", n,p1,f,#(d.anuncios or {}),d.dinero))' "$PARTIDA" $T/esperado.lua
fi
if [ -n "$PARTIDA" ]; then cp "$PARTIDA" $SAVE/partida.lua; fi
cd $T && OLP_PRUEBA=1 SDL_AUDIODRIVER=dummy timeout 900 xvfb-run -a -s "-screen 0 2560x1440x24" love . 2>&1 | grep -v "ALSA\|pw.conf\|ALSOFT\|Could not"
