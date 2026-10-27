# Lee un reporte de bug del juego: enseña lo que cuenta el jugador, el error
# y sus ultimas acciones, y saca su partida a un archivo para cargarla.
# uso: python3 reporte.py reporte_XXXX.txt [salida_partida.lua]
import base64
import sys
import zlib

texto = open(sys.argv[1], encoding="utf-8", errors="replace").read()
salida = sys.argv[2] if len(sys.argv) > 2 else "partida.lua"

secciones = {}
actual = "cabecera"
for linea in texto.splitlines():
    if linea.startswith("--- ") and linea.endswith(" ---"):
        actual = linea.strip("- ").strip()
        continue
    secciones.setdefault(actual, []).append(linea)

print("\n".join(secciones.get("cabecera", [])).strip())
print("\nQUE HA PASADO:\n  " + "\n  ".join(secciones.get("QUE HA PASADO", [])).strip())
if "ERROR" in secciones:
    print("\nERROR:\n" + "\n".join(secciones["ERROR"]).strip())
acciones = [a for a in secciones.get("ULTIMAS ACCIONES", []) if a.strip()]
print("\nULTIMAS ACCIONES (%d, las 40 ultimas):" % len(acciones))
print("\n".join(acciones[-40:]))

codigo = "".join(l.strip() for l in secciones.get("PARTIDA", []))
if not codigo or codigo.startswith("("):
    print("\nEl reporte no trae partida")
    sys.exit(1)
partida = zlib.decompress(base64.b64decode(codigo))
open(salida, "wb").write(partida)
print("\nPartida guardada en %s (%d bytes)" % (salida, len(partida)))
