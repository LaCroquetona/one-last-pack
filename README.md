# One Last Pack

Juego de abrir sobres y completar la colección. Hecho con LÖVE 11.5.
Versión actual: 0.2.0 (lo que cambia en cada versión está en `CHANGELOG.md`).

## Ejecutar

1. Instala LÖVE desde love2d.org (versión 11.5)
2. Arrastra la carpeta `one-last-pack` encima de `love.exe`, o desde terminal: `love one-last-pack`

## Controles

- TAB: cambiar entre tienda y armario
- Espacio: abrir un sobre guardado
- Mantener click o espacio: cargar y rasgar el sobre
- Click / espacio: revelar la siguiente carta (manteniendo pasan solas las normales)
- Flechas: pasar páginas del álbum
- ESC: salir

La partida se guarda sola en `partida.txt` (en Windows está en `%APPDATA%/LOVE/one-last-pack/`). Bórralo para empezar de cero.

## Dónde se toca cada cosa

- `datos/cartas.lua`: las cartas del set, una línea por carta.
- `datos/sobres.lua`: precio, huecos del sobre y sus probabilidades, god pack, piedad y con qué se empieza.
- `datos/rarezas.lua`: colores, precio de venta y suspense de cada rareza.
- `datos/elementos.lua`: colores y trama de fondo de cada elemento.
- `datos/paleta.lua`: los 16 colores (Sweetie 16).
- `sprites/`: si una carta tiene `sprite = "algo.png"`, se usa ese dibujo en vez del bicho generado.
- `src/bicho.lua`: el generador de bichos.
- `src/carta.lua`: cómo se pinta cada capa de la carta.
- `src/apertura.lua`, `src/tienda.lua`, `src/armario.lua`: las tres pantallas.
