# Changelog

Numeración `0.X.Y`: el último número sube con cada versión de prueba (una
parte de una fase); el del medio solo cuando termino una fase entera y la doy
por buena. Los arreglos de una versión que todavía estoy probando van en esa
misma versión. El juego se queda por debajo de 1.0 hasta que esté completo.

## v0.2.0 - 2026-10-19 - Tienda, armario y cartas nuevas

- **Sobres por huecos**, como los de Pokémon: 7 cartas (3 comunes fijas,
  2 infrecuentes que pueden subir a rara, 1 comodín de cualquier rareza y 1
  rara o mejor). Todo se configura en `datos/sobres.lua`. Dentro de un sobre
  ya no se repite carta.
- **Dinero y tienda**: se empieza con $1.000 y un sobre. Los sobres cuestan
  $120 y se compran de uno en uno o de cinco en cinco. La tienda enseña las
  probabilidades de cada hueco, el god pack y la piedad. Si te quedas sin
  dinero, sin sobres y sin repes, hay un sobre de rescate gratis.
- **Armario** con los sobres guardados y tres formas de ver las cartas:
  - Copias: un montón por carta, las repetidas apiladas con su contador.
  - Rareza: un montón por rareza; al pulsarlo se abren sus cartas debajo.
  - Álbum: carpeta de dos páginas de 3x3. Las que faltan salen como hueco
    oscuro con la silueta del bicho.
- **Vender repes**: carta a carta o todas de golpe. La última copia de cada
  carta nunca se vende.
- **Hover estilo Balatro**: las cartas se inclinan hacia el ratón, se levantan
  y les pasa un reflejo; tooltip con rareza, copias y precio.
- **Cartas nuevas** al estilo de Bitlatro: paleta Sweetie 16, contorno negro,
  esquinas de pixel, fondo con trama según el elemento y un bicho de pixel
  generado para cada carta (cuernos, patas, ojos y panza distintos). Nombres
  provisionales para las 40.
- Fuente de pixel propia de 3x5.
- Dorso y sobre redibujados en pixel art.
- Sonidos de interfaz: pasar por encima, click y monedas.
- La partida de la v0.1 se carga sin perder nada.

## v0.1.0 - 2026-10-19 - Prototipo de apertura

- Mantener click o espacio para cargar el sobre y rasgarlo. Si trae holo o
  mejor, brilla del color de la rareza antes de abrirse.
- Revelado de peor a mejor: las normales pasan solas, las raras tiemblan con
  latidos antes de girarse.
- 6 rarezas (común, infrecuente, rara, holo, full art, secreta) con brillo
  arcoíris por shader en las tres últimas, rayos, cámara lenta y fondo teñido.
- God pack (1 de cada 200) y piedad (holo o mejor segura a los 12 sobres sin).
- Álbum de 40 cartas y guardado automático en `partida.txt`.
- Sonidos generados por código.
