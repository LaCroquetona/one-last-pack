#!/bin/bash
# Abre un reporte de bug: enseña lo que cuenta el jugador y carga su partida
# en el arnes (fotos de cada pantalla en la carpeta de guardado de LOVE).
# uso: JUEGO=/ruta/one-last-pack ./reporte.sh reporte_XXXX.txt
#      SOLO_SACAR=1 ... solo saca la partida (reporte_partida.lua)
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
SALIDA=${TMPDIR:-/tmp}/reporte_partida.lua
python3 "$AQUI/reporte.py" "$1" "$SALIDA"
if [ -z "$SOLO_SACAR" ]; then
    PARTIDA="$SALIDA" GUION=guion_reporte.lua "$AQUI/correr.sh"
fi
