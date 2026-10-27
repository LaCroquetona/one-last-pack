#!/usr/bin/env python3
# Pone la version del juego en el AndroidManifest.xml (binario) de la APK:
# versionName = "0.9.0" y versionCode = 900 (0.X.Y -> X*100 + Y).
# Sin esto Android enseñaba la version de la APK base (0.5.3).
# uso: python3 version_apk.py AndroidManifest.xml 0.9.0
import struct
import sys

ruta, version = sys.argv[1], sys.argv[2]
d = bytearray(open(ruta, 'rb').read())

POOL = 8
_, hs, tam = struct.unpack_from('<HHI', d, POOL)
n, nestilos, flags, ini, ini_estilos = struct.unpack_from('<IIIII', d, POOL + 8)
if flags & 0x100 or nestilos:
    sys.exit('manifiesto en UTF-8 o con estilos: no se sabe parchear')
offs = struct.unpack_from('<%dI' % n, d, POOL + hs)
textos = []
for o in offs:
    p = POOL + ini + o
    largo = struct.unpack_from('<H', d, p)[0]
    textos.append(d[p + 2:p + 2 + 2 * largo].decode('utf-16-le'))


def atributos():
    # recorre los elementos y devuelve (posicion del atributo, nombre)
    p = POOL + tam
    while p < len(d):
        tipo, _, t = struct.unpack_from('<HHI', d, p)
        if tipo == 0x0102:
            inicio, paso, cuantos = struct.unpack_from('<HHH', d, p + 24)
            for k in range(cuantos):
                a = p + 16 + inicio + k * paso
                nombre = struct.unpack_from('<I', d, a + 4)[0]
                yield a, textos[nombre] if nombre < len(textos) else ''
        p += t


partes = version.split('.')
codigo = int(partes[1]) * 100 + int(partes[2]) if len(partes) == 3 else int(partes[-1])
cambiado = False
for a, nombre in atributos():
    if nombre == 'versionName':
        idx = struct.unpack_from('<I', d, a + 8)[0]
        textos[idx] = version
        cambiado = True
    elif nombre == 'versionCode':
        struct.pack_into('<I', d, a + 16, codigo)
if not cambiado:
    sys.exit('no hay versionName en el manifiesto')

# rehace la tabla de textos (los largos cambian) y los tamaños
datos, nuevos = bytearray(), []
for t in textos:
    nuevos.append(len(datos))
    b = t.encode('utf-16-le')
    datos += struct.pack('<H', len(b) // 2) + b + b'\0\0'
while len(datos) % 4:
    datos += b'\0'
ini_nuevo = hs + 4 * n
pool = bytearray(d[POOL:POOL + hs])
struct.pack_into('<I', pool, 4, ini_nuevo + len(datos))
struct.pack_into('<I', pool, 20, ini_nuevo)
pool += struct.pack('<%dI' % n, *nuevos) + datos
resto = d[POOL + tam:]
fuera = bytearray(d[:POOL]) + pool + resto
struct.pack_into('<I', fuera, 4, len(fuera))
open(ruta, 'wb').write(fuera)
print('version %s (codigo %d)' % (version, codigo))
