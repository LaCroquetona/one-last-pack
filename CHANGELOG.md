# Changelog

Numeración `0.X.Y`: el último número sube con cada versión de prueba (una
parte de una fase); el del medio solo cuando termino una fase entera y la doy
por buena. Los arreglos de una versión que todavía estoy probando van en esa
misma versión. El juego se queda por debajo de 1.0 hasta que esté completo.

## v0.5.3 - 2026-10-19 - Precio y carta nueva al abrir

- **Precio al revelar**: al girar una carta sale lo que vale al lado,
  contando desde cero. Cuanto más vale, más se nota:
  - menos de 0,50 €: un número pequeño y gris;
  - hasta 5 €: en amarillo, con su moneda;
  - hasta 30 €: grande, contando con tic-tac y un chorro de monedas;
  - más de 30 €: enorme, parpadeando y temblando, con lluvia de monedas
    mientras cuenta, destello y sacudida al terminar.
  La carta no pasa hasta que se ha visto su precio.
- **Carta nueva**: cartel de ¡NUEVA! que entra con rebote encima de la
  carta, confeti, doble sonido, chispas y "+1 A TU COLECCIÓN (13/40)".
  En el resumen, las nuevas tienen un marco amarillo que late.
- El resumen del sobre enseña el precio de cada carta.
- Partículas nuevas: monedas que giran, saltan y rebotan, y confeti.
- **Montones en el armario**: al pasar el ratón por un montón, las copias
  de detrás se abren en abanico (con su sello si son de 1ª edición).
- Las cartas se inclinan menos al pasar el ratón; antes se giraban de más.
- **Arreglado**: en algunos casos guardar la partida podía fallar al
  escribir listas con huecos.

## v0.5.2 - 2026-10-19 - Vender repes

- **Arreglado**: vender repes dejaba sin vender las copias repetidas de las
  raras o mejores, porque el auto-enfundado les ponía funda a todas y las
  enfundadas nunca se vendían en lote. Parecía que el botón no hacía nada.
- El auto-enfundado ya solo enfunda la primera copia de cada carta; las
  repes no gastan funda.
- Vender repes deja una copia en el armario, además de las que tengas
  publicadas en el móvil, y vende el resto aunque esté enfundado. Las
  fundas de lo que vendas vuelven a la caja. "Vender todo" sigue sin tocar
  las enfundadas.
- El botón de repes dice exactamente lo que vas a cobrar: antes no contaba
  que vender muchas copias de una carta baja su precio.
- Al pasar el ratón por el botón de repes se explica qué vende y cuántas se
  quedan por estar en el móvil.

## v0.5.1 - 2026-10-19 - Arreglo de god packs

- **Arreglado**: en un god pack podía salir dos veces la misma carta cuando
  ya habían salido todas las de una rareza (por ejemplo, dos veces la única
  secreta del set). Ahora se vuelve a tirar la rareza.

## v0.5.0 - 2026-10-19 - Ciclo de sets, mercado nuevo y móvil nuevo

- **Sets que salen, se agotan y se reimprimen.** Cada 16 días más o menos
  sale un set nuevo, que se pisa unos 8 días con el anterior. Mientras se
  imprime, sus sobres están en la tienda a su precio. Cuando se agota, solo
  se consiguen de reventa, y tarde o temprano vuelve como reimpresión. Las
  reimpresiones van en rueda, así que la tienda nunca se queda vacía. Las
  fechas se sortean al empezar cada partida (`datos/calendario.lua`).
- **Set 3** (60 cartas, elemento nuevo: tierra, sobre de 8 cartas a 5,00 €)
  y **Set 4** (50 cartas, elemento nuevo: astral, sobre de 8 cartas a
  12,00 €). Los sets que aún no han salido no se ven en la tienda ni en el
  armario hasta que se anuncian.
- **Primera edición.** Las cartas de los sobres de la primera tirada llevan
  un sello dorado. Cuando llega la reimpresión, las normales bajan y las de
  1ª edición siguen subiendo. Los sobres cerrados también son de 1ª edición
  o de reimpresión, y se abren antes los de reimpresión.
- **Precios con ancla.** Cada carta persigue cada día un precio objetivo que
  sale de su valor, la fase de su set, las noticias y las burbujas. Se mueve,
  pero siempre por algo. Fuera las tendencias por elemento.
- **Chase.** Cada set tiene dos cartas que todo el mundo busca. Se mueven
  más y pueden tener **burbujas**: suben muy rápido, se venden muchísimo y
  acaban pinchando.
- **Noticias nuevas**: anuncio de set, lanzamiento, últimos días, agotado,
  rumor de reimpresión (no siempre se cumple), reimpresión, aniversario,
  escasez. La primera vez que sale cada tipo explica qué significa.
- **Stock diario.** La tienda recibe cada día un número de sobres de cada set
  (menos en el lanzamiento). El precio en tienda ya no sube por comprar
  muchos.
- **Almacén.** Los sobres cerrados ocupan sitio en estanterías (20 cada una)
  y las cartas en cajas (250 cada una). Si no caben, no puedes comprar más
  sobres. Se compran más en la tienda.
- **Comisión.** Las ventas por el móvil (cartas y sobres cerrados) pagan un
  8% a la app. Comprar sobres de reventa cuesta un 6% más que su precio.
- **Móvil nuevo**: pantalla de inicio con iconos, avisos y fondo de pantalla,
  apps que se abren desde su icono y scroll con la rueda. Apps:
  - Cartera: valor de tu colección con su gráfica, tus cartas más caras, las
    que más suben y bajan y las que sigues.
  - Mercado: cada set con su fase y sus sobres cerrados para comprar o vender
    de reventa, y todas sus cartas por precio.
  - Ficha de cada carta: gráfica de precio (7 días, 30 días o todo) con la
    línea de 1ª edición, barras de ventas por día, marcas de noticias y el
    valor de cada día al pasar el ratón. Se puede seguir y publicar desde
    ahí. La carta se ve en grande al lado.
  - Ventas, Noticias y Calendario (lo que se sabe de cada set en los
    próximos días).
- **Cartas más vivas.** Se inclinan en 3D con perspectiva al pasar el ratón
  y se balancean un poco en reposo. Cada rareza tiene su acabado: reflejo
  (rara), foil a rayas en el dibujo (holo), purpurina (full art) y oro con
  estrellas (secreta). En las holo o mejores el bicho respira y parpadea.
- **Revelado**: destello que cruza la carta al girarla, nombre de la rareza
  que cae de golpe, chispas en las full art y secretas, y el fondo se
  oscurece con las mejores.
- Botón FICHA en el armario y selector de edición cuando tienes copias
  normales y de 1ª edición.
- D pasa el día desde cualquier pantalla.
- Herramientas de desarrollador: pasar 16 y 30 días, burbuja en una chase,
  más almacén.
- La partida se guarda como mucho una vez por segundo y siempre al salir.
- **Partidas anteriores**: ya no se cargan, hay que empezar una nueva.

## v0.4.0 - 2026-10-19 - Set 2 y escritorio

- **Set 2**: 70 cartas nuevas con dos elementos nuevos, hielo y metal.
  Tiene su propio sobre (azul) a 8,00 € con 10 cartas: 4 comunes,
  3 infrecuentes, 2 comodines y 1 rara o mejor.
- El set 2 es más difícil: solo un 19% de los sobres trae holo o mejor
  (en el set 1, un 32%), el god pack es 1 de cada 500 y la piedad llega a
  los 20 sobres. A cambio sus cartas valen mucho más: una holo ronda los
  15 €, una full art los 60 € y una secreta los 300 €. De media un sobre
  trae 9,83 € en cartas, pero la mitad de las veces no llega a 3,58 €.
- Cada set tiene sus propios valores en `datos/sets.lua` y cada sobre sube
  de precio por separado si compras muchos.
- **Tienda** con selector de sobre. **Armario** con pestañas de set en la
  barra de arriba: copias, rareza, álbum y mesa enseñan solo las cartas de
  ese set. El panel de sobres tiene una fila y un botón de abrir por tipo.
  La barra enseña el progreso de cada set.
- **Cartas nuevas**: el recuadro del dibujo es más plano y ocupa menos, el
  bicho es más pequeño y el fondo es ahora un paisaje: cielo con degradado
  de pixel y suelo con la trama de cada elemento. Arriba sale el código del
  set (S1, S2) y abajo el número de la carta en su set (#12/70).
- **Escritorio**: el fondo es ahora una mesa de madera que ocupa toda la
  pantalla. Las cartas buenas la tiñen de su color un momento. Si se pone
  una imagen en `sprites/escritorio.png`, se usa esa en su lugar.
- **El móvil se saca y se guarda**: sube desde abajo con un rebote al
  entrar y baja al irte a otra pantalla.
- El resumen de un sobre de 10 cartas se encoge para que quepan, y abrir
  muchos sobres de golpe pasa a cartas pequeñas cuando hay más de 48
  distintas.
- **Arreglado**: un mismo comprador podía mandar varias ofertas al mismo
  anuncio, y volver al día siguiente con otra más alta aunque le hubieras
  pedido más o lo hubieras rechazado. Ahora cada comprador hace una sola
  oferta por anuncio, los que rechazas o se van no vuelven, hay 3 ofertas
  como mucho a la vez y hay 36 compradores en vez de 16. Si una oferta
  caduca sin respuesta, ese comprador puede volver otro día.
- **Vender sobres cerrados** desde la app Mercado del móvil, de uno en uno o
  todos. Lo que te pagan no tiene nada que ver con lo que costaron: cada
  sobre tiene su precio de reventa, que se mueve cada día.
- **Fundas de pago**: empiezas con 20, cada carta enfundada gasta una y al
  quitarla la recuperas. En la tienda se compran 20 por 1,00 €. Sin fundas
  no se enfunda, ni a mano ni en automático.
- Las herramientas de desarrollador dan sobres de los dos tipos.
- Las partidas de la v0.3 se cargan sin perder nada.

## v0.3.1 - 2026-10-19 - Pantalla completa

- Pantalla completa con F11, Alt+Enter o el botón del menú. El juego se
  acuerda de cómo lo dejaste la próxima vez que lo abras.
- La imagen llena siempre la pantalla, también en monitores que no son
  1080p y con el escalado de Windows al 125% o 150%. Se amplía con pixel
  duro y se ajusta suavizado al tamaño exacto, así que el pixel sigue
  nítido. Si la pantalla o la ventana no son 16:9 (16:10, ultrapanorámica,
  ventana maximizada), el fondo de puntos y la barra de arriba se extienden
  por toda la pantalla, así que no queda ningún borde.
- El panel DEV enseña los datos de la pantalla (tamaño de la ventana,
  pixeles reales, escritorio, DPI y escala) por si algo se ve raro.

## v0.3.0 - 2026-10-19 - Mercado, móvil y fundas

- **Euros**: todo el dinero pasa a euros con céntimos. El sobre cuesta 2,00 €
  y una partida nueva empieza con 20,00 €. De media un sobre trae 2,96 € en
  cartas, pero la mitad de las veces no llega a 1,12 €: los pelotazos son
  los que compensan.
- **Mercado vivo**, que avanza por días:
  - Cada carta tiene su valor según su rareza, y unas valen algo más que
    otras de la misma rareza.
  - Vender muchas copias de una carta hunde su precio; se recupera cada día.
  - Cada elemento tiene su tendencia, que sube y baja día a día.
  - Noticias: vídeos virales, torneos, copias falsas, rumores de
    reimpresión, escasez de sobres... cambian precios durante unos días.
  - Comprar muchos sobres seguidos los encarece; cada día bajan.
  - Todos los números están en `datos/mercado.lua`.
- **Móvil** (nueva pestaña) con tres apps: Mercado (precio del sobre,
  tendencia de cada elemento con gráfica, cartas que más suben y bajan),
  Ventas y Noticias. Botón PASAR DÍA (o tecla D).
- **Vender por el móvil**: publicas cartas desde el armario (6 anuncios como
  mucho) y cada día llegan ofertas de compradores. Puedes aceptar, rechazar
  o pedir un 15% más; si pides más, el comprador puede irse. Al aceptar, la
  carta se empaqueta sola (funda, toploader y sobre) y se envía.
- **Venta rápida** en el armario: al momento, pero a la mitad del valor.
- **Vender todo**, y ahora también la última copia de una carta. Las dos
  cosas piden confirmación con un aviso grande en rojo.
- **Fundas**: botón para enfundar y quitar la funda, arrastrar la carta a la
  caja de fundas y opción para enfundar solas las raras o mejores al
  abrirlas. Las cartas enfundadas se ven con su plástico y nunca se venden
  en lote.
- **Arrastrar cartas**: reordenar el armario en la vista de copias, soltar
  cartas en la caja de fundas y una vista nueva, MESA, donde se dejan donde
  quieras.
- **Menú principal**: continuar, partida nueva (con aviso si ya hay una) y
  salir. ESC vuelve al menú guardando.
- **Herramientas de desarrollador** (F1 o botón DEV): dar dinero y sobres,
  abrir 5 o 20 sobres de golpe con un resumen agrupado, velocidad de
  animación x1/x2/x4/x8, saltar la animación de apertura, forzar god pack o
  secreta en el siguiente sobre, pasar días, generar ofertas y noticias,
  reiniciar el mercado y dar una copia de cada carta.
- Las partidas de la v0.2 se cargan con sus cartas y sobres; el dinero pasa
  a los 20,00 € de inicio. La partida se guarda ahora en `partida.lua`.

## v0.2.1 - 2026-10-19 - Pantalla de firma

- Al arrancar sale la firma del autor: el logo aparece pixel a pixel y el
  nombre se escribe letra a letra. Se salta con click o cualquier tecla.
  Nombre y logo se cambian en `datos/firma.lua`; el logo va en
  `sprites/logo.png` y, si no está, sale solo el nombre.
- Logo en pixel art sacado del sello `croquetina_logotipo.svg`: solo el
  cubo-planeta con su anillo y la luna, con los colores del original.
- La fuente de pixel tiene ahora una Ñ que se distingue de la N.

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
