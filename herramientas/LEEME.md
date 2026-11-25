# Herramientas

No son parte del juego. Sirven para probarlo sin jugarlo, para ver si la economía aguanta y para hacer la APK. Funcionan en Linux con LÖVE 11.5, xvfb (pantalla virtual), luacheck y, para la APK, zipalign y apksigner.

`JUEGO` es siempre la carpeta del juego, por ejemplo `JUEGO=~/one-last-pack ./correr.sh`.

## Arnés de pruebas

`correr.sh` copia el juego a una carpeta temporal, renombra `main.lua` a `main_juego.lua` y pone `harness.lua` en su sitio. El arnés arranca el juego en una pantalla virtual, pulsa botones por su id, arrastra, comprueba la lógica y hace capturas (`foto_*.png` en la carpeta de guardado de LÖVE). Al final dice cuántos pasos han ido bien y cuántos han fallado.

- `guion.lua` (el de por defecto): partida nueva de principio a fin. Mesa, fundas, directo, cajas, encargos, peticiones del chat, mejoras y todas las pantallas.
- `guion_visual.lua`: capturas de lo que se arrastra (caja, sobre y carta con su péndulo).
- `guion_carga.lua` y `guion_conversion.lua` (con `PARTIDA=...`): cargan una partida de antes y comprueban que se convierte bien.

Se elige con `GUION=guion_visual.lua`. Con `OLP_VENTANA=2400x1080 OLP_MOVIL=1` se prueba como en un móvil alargado con el texto grande. La mascota está apagada en las pruebas para que no tape nada; `GUIA=1` la enciende.

El arnés juega siempre igual: semilla fija (`SEMILLA=N` para otra) y reloj fijo a 60 frames por segundo, así que dos pasadas dan las mismas capturas. Para ir rápido solo pinta 1 de cada 4 frames (`OLP_PINTAR=1` los pinta todos), y siempre antes de cada clic y de cada foto. Ignora el ratón y el foco de la pantalla virtual: los pone el guion.

- `SALTAR=1`: los sobres se abren sin animación (para guiones que no prueban la apertura).
- `PARTIDA=/ruta/partida.lua`: empieza con esa partida guardada.
- `OLP_TIEMPO=N`: segundos antes de cortar la prueba (900 por defecto).
- `OLP_DATOS=/carpeta` y `OLP_PANTALLA=N`: otra carpeta de guardado y otra pantalla virtual, para correr dos pruebas a la vez (PC y móvil).

## Bots de economía

`bots.sh` + `bots/main.lua`: bots que juegan 240 días cada uno con una estrategia y dicen cuánto dinero y patrimonio tienen, cuántos sobres abren y, los que hacen directo, seguidores y propinas. `ESCENARIOS=1` hace que el bot `meneses` juegue con la semilla 1 y guarde partidas de prueba (día 20, día 300, armario lleno, directo de venta y MASTER SET del S1) en la carpeta de guardado de los bots.

Estrategias: `nada`, `abreRapido`, `abreMovil`, `lanzamiento` (compra el día de salida), `guardar` (sobres cerrados), `mixto`, `directo`, `vendeDirecto` (el que sabe: revende en directos de venta), `ludopata`, `especulador`, `novato` y `meneses` (como juego yo: compro todo, cajas de tienda y de vendedores, las vendo en directo y vendo rápido lo malo).

- `SOLO=directo`: solo esa estrategia.
- `SEMILLAS=12`: 12 partidas por estrategia.
- `RITMO=9`: 9 sobres por minuto, como un jugador rápido.
- `MINUTOS=20`: minutos de directo al día.
- `PRODUCTOS=no`: `meneses` no compra ETB, tins ni blísters (para comparar).
- `TRAZA=1`: cada 10 días, dinero, seguidores, propinas y venta. `TRAZA=todas`: el día 20 de cada partida.

La referencia que uso: un buen jugador tiene para unas 2 cajas el día 20 y un novato no se arruina.

## Simulador de mercado

`simular.sh 1 2 3` + `sim/main.lua`: simula 600 días de mercado sin jugar, con las semillas que le pases, y saca un CSV por semilla (`sim_N.csv`) con los precios de las chase, de algunas holo y de los sobres sellados, más las noticias. Sirve para dibujar las gráficas y ver si las burbujas y los crashes quedan bien.

## Simulador de las ALT

`GUION=guion_v0105_alt.lua SOBRES=100000 ./correr.sh`: abre esos sobres de cada set y cuenta, de cada carta con ALT, cuántas salen normales y cuántas ALT, más lo que vale el sobre de media. Lo deja en `sim_alt.txt` en la carpeta de guardado. Ninguna ALT debería pasar de 1 de cada 5 copias de su carta.

## Reportes de bugs

`reporte.sh reporte_XXXX.txt` (con `reporte.py` y `guion_reporte.lua`) abre un reporte que guarda el juego: enseña lo que cuenta el jugador, el error y sus últimas acciones, saca su partida y la carga en el arnés con una captura de cada pantalla. `SOLO_SACAR=1` solo saca la partida.

## APK

`hacer_apk.sh VERSION` mete el juego en una APK base de love-android (`APK_BASE=...`), pone la versión con `version_apk.py`, la alinea y la firma. Deja la APK en `builds/`.

La clave de firma va en `herramientas/clave/` y no está en el repo. Sin ella las APK nuevas no se instalan encima de las anteriores. `CLAVE` y `ALIAS` cambian la clave; `CLAVE=no` la deja sin firmar.
