# One Last Pack

Prototipo de apertura de sobres. Hecho con LÖVE 11.5.

## Ejecutar

1. Instala LÖVE desde love2d.org (versión 11.5)
2. Arrastra la carpeta `one-last-pack` encima de `love.exe`, o desde terminal: `love one-last-pack`

## Controles

- Mantener click o espacio: cargar y rasgar el sobre
- Click / espacio: revelar la siguiente carta (manteniendo pasa las normales solas)
- TAB: álbum
- ESC: salir

La partida se guarda sola en `partida.txt` (en Windows está en `%APPDATA%/LOVE/one-last-pack/`). Bórralo para empezar de cero.

## Dónde se toca cada cosa

- `datos/cartas.lua`: las cartas del set. Una línea por carta.
- `datos/rarezas.lua`: colores, probabilidades y cuánto suspense tiene cada rareza.
- `datos/elementos.lua`: colores de fondo y figura por elemento.
- `sprites/`: si una carta tiene `sprite = "algo.png"`, se usa ese dibujo en vez de la forma.
- `src/generador.lua`: cómo se rellena un sobre (huecos, god pack, piedad).
- `src/apertura.lua`: toda la animación de abrir.
- `src/sonido.lua`: los sonidos se generan por código, cambiarlos por .ogg cuando los haya.
