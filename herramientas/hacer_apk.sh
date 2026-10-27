#!/bin/bash
# uso: JUEGO=/ruta APK_BASE=builds/OneLastPack-v0.9.1.apk ./hacer_apk.sh 0.9.2
#      deja la APK en builds/
#      firma con la clave del juego (herramientas/clave/onelastpack.keystore,
#      alias onelastpack, contraseña android). CLAVE=otra.keystore ALIAS=x
#      para otra; CLAVE=no saca OneLastPack-v0.9.1-sin-firmar.apk
set -e
AQUI=$(cd "$(dirname "$0")" && pwd)
V=$1; T=${TMPDIR:-/tmp}/olp_apk
rm -rf $T && mkdir -p $T/juego $T/assets && cp -r "$JUEGO"/main.lua "$JUEGO"/conf.lua "$JUEGO"/src "$JUEGO"/datos "$JUEGO"/sprites "$JUEGO"/musica $T/juego/
(cd $T/juego && zip -9 -r -q ../assets/game.love .)
cp "$APK_BASE" $T/base.apk
# la version que enseña Android (si no, la de la APK base)
(cd $T && unzip -q -o base.apk AndroidManifest.xml && python3 "$AQUI/version_apk.py" AndroidManifest.xml "$V")
zip -q -d $T/base.apk 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.MF' 'assets/game.love' AndroidManifest.xml || true
(cd $T && zip -q base.apk AndroidManifest.xml assets/game.love && zipalign -f -p 4 base.apk aligned.apk)
CLAVE=${CLAVE:-$AQUI/clave/onelastpack.keystore}
ALIAS=${ALIAS:-onelastpack}
if [ "$CLAVE" = no ]; then
    mkdir -p "$JUEGO/builds" && cp $T/aligned.apk "$JUEGO/builds/OneLastPack-v$V-sin-firmar.apk" && echo "APK sin firmar: OneLastPack-v$V-sin-firmar.apk"
    exit 0
fi
mkdir -p "$JUEGO/builds"
apksigner sign --ks "$CLAVE" --ks-pass pass:android --ks-key-alias "$ALIAS" --key-pass pass:android --out "$JUEGO/builds/OneLastPack-v$V.apk" $T/aligned.apk
apksigner verify "$JUEGO/builds/OneLastPack-v$V.apk" && echo "APK lista: OneLastPack-v$V.apk"
