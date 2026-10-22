# Changelog

Numeración `0.X.Y`: el último número sube con cada versión de prueba (una
parte de una fase); el del medio solo cuando termino una fase entera y la doy
por buena. Los arreglos de una versión que todavía estoy probando van en esa
misma versión. El juego se queda por debajo de 1.0 hasta que esté completo.

## v0.8.2 - 2026-10-22 - Paso del día, venta en directo y reajustes

- **Paso del día con fundido a negro**: la pantalla se funde, se pone el sol,
  sale la luna, el contador pasa de DÍA X a DÍA X+1 y se ve lo que ganaste y
  los sobres que abriste el día anterior. Tocar lo acorta; mientras dura no
  se puede tocar nada. Las notificaciones salen al volver la imagen.
- **Venta de sobres en directo** (nuevo tipo de directo, VENTA DE SOBRES):
  como los directos de internet, el chat te compra sobres que tienes
  guardados. Arriba del chat salen las compras (sobre, precio y tiempo, hasta
  3 a la vez, 90 s). Al abrir un sobre de ese set cobras al momento y las
  cartas son del comprador: se ven, pero se van al acabar. Pagan el precio de
  mercado del sobre con un margen del 8-22% que sube con la gente que mira
  (hasta +15% más). Si le toca holo o mejor lo celebra y ganas seguidores.
  Con más espectadores llegan más compradores (hasta 4 por minuto). El
  resumen del directo enseña los sobres vendidos y lo cobrado.
- **1ª ediciones y sellado suben más rápido** tras agotarse: una carta de 1ª
  ed va x1,9 a los 30 días y x3,4 a los 100 (antes x1,5 y x2,2); los sobres y
  cajas cerrados de 1ª ed, x2,3 a los 30 y x4,6 a los 100.
- **Mejoras reajustadas** (medido abriendo 20.000 sobres de cada set):
  - SUERTE: cada una sube unos 6-8 puntos lo que trae un sobre y con las tres
    al máximo queda en un ~100-105% (el imán de god packs a x3,5 daba tanto
    como las otras dos juntas). Segunda oportunidad hasta 16%, carta extra
    hasta 45%, imán hasta x2,2.
  - VENTA: ESCAPARATE más caro y hasta +5 anuncios; CUENTA PRO y BUENA
    REPUTACIÓN más baratas (la reputación llega más lejos).
  - DIRECTO: CÁMARA HD más cara; MICRO DE ESTUDIO hasta x2,5 propinas y
    más barato; ARO DE LUZ hasta x2,3 en peticiones y también sube el margen
    de la venta de sobres.
  - Cada nivel cuesta x2-2,3 el anterior (antes x2,4).

## v0.8.1 - 2026-10-21 - Móvil nuevo, tutorial, mejoras y directo

- **Móvil rediseñado**: ahora parece un móvil y no una tablet (más estrecho y
  alto, esquinas redondeadas, cámara en la pantalla, batería). Las apps van
  en 3 columnas sin que nada las tape y solo queda un botón de PASAR DÍA, el
  del panel de la izquierda.
- **MERCADO por secciones**: al entrar en un set eliges SOBRES 1ª ED, CAJAS
  1ª ED, SOBRES REIMPR., CAJAS REIMPR. o CARTAS DEL SET, y salen ya sus
  precios y vendedores. Las de reimpresión solo aparecen cuando ese set ya
  ha tenido una.
- **App MEJORAS** (sustituye a SUERTE), con tres pestañas:
  - SUERTE: las de siempre.
  - VENTA: CUENTA PRO (comisión del 8% hasta el 3%), ESCAPARATE (hasta 6
    anuncios más) y BUENA REPUTACIÓN (más ofertas de +20%).
  - DIRECTO: CÁMARA HD (hasta x1,5 seguidores), MICRO DE ESTUDIO (hasta
    x1,75 propinas) y ARO DE LUZ (peticiones del chat hasta x1,5).
- **Tutorial** guiado en la partida nueva (14 pasos, con flecha a lo que hay
  que tocar). Se puede saltar y repetir desde el menú (VER TUTORIAL). Las
  partidas de antes no lo enseñan.
- **Directo más llamativo**: el móvil del trípode parpadea en rojo y se puede
  tocar para emitir, el botón late y brilla con un bocadillo, y si abres un
  sobre sin directo te avisa (en tus 3 primeros directos). En la mesa vacía
  sale el consejo de empezar un directo antes.
- Arreglo: con 5 sets o más, la flecha > de la tienda quedaba tapada por el panel. Las pestañas se estrechan un poco cuando hay flechas.
- Arreglo: al empezar una partida nueva con una caja de sobres a medias, la caja se quedaba en la mesa. Ahora se va con lo demás.
- **Emojis nuevos**, todos propios: rana, cara de flipar, llorando de risa,
  payaso, diamante, cohete, gráfica que sube y los textos L, OMG, POG y 100.

## v0.8.0 - 2026-10-21 - Pantalla de móvil, sets nuevos y dorso

Fase 3 terminada: empieza la fase 4.

- **Pantallas alargadas** (móviles 20:9 como el Redmi Note 13): el juego ya no
  se queda en un 16:9 con bandas. Se ve más mesa a los lados, la barra de
  arriba va de borde a borde (botones a la izquierda, dinero a la derecha) y
  se respeta la zona de la cámara.
- **Texto más grande en el móvil** (x4/3), automático en Android. Lo que no
  cabe en su botón se queda a su tamaño. El juego se dibuja ahora al triple
  de resolución para que la letra grande salga nítida (en PC se ve igual).
- **4 sets nuevos**, uno cada 18 días como siempre, cada uno con su elemento
  y su sobre:
  - S5 (6 €, 60 cartas, 8 por sobre): veneno.
  - S6 (3 €, 70 cartas, 7 por sobre): viento.
  - S7 (15 €, 50 cartas, 8 por sobre): dragón. El caro y el más duro.
  - S8 (9 €, 80 cartas, 10 por sobre): luz.
  Equilibrados como los de antes: un sobre trae de media un 85-90% de lo que
  cuesta sin mejoras.
- **Dorso nuevo, "constelación rombo"**, igual para todas las cartas.
- Con muchos sets: la tienda los enseña de 4 en 4 con flechas, las pestañas
  del armario se desplazan con flechas, SELLADO va por páginas y la caja de
  la mesa enseña primero los sobres que tienes (caben 4).
- Las partidas de antes siguen igual: los sets nuevos salen cuando les toca
  y las fechas de los viejos no cambian.

## v0.7.4 - 2026-10-20 - Vendedores, logros y torneos

- **Vendedores de segunda mano** en Móvil > MERCADO. Cada set tiene ofertas
  de sobres y cajas (1ª ed y reimpresión), y la ficha de cada carta, las de
  quien la vende. Cada vendedor tiene nombre, estrellas, ventas, unidades y
  precio, y eliges a quién comprar. Las ofertas cambian cada día.
- **Precios en campana**: mientras la tienda vende el set, alrededor de su
  precio oficial (la tienda no cambia y siempre está); cuando ya no, del
  precio de mercado. Lo normal, cerca; de vez en cuando un chollo (como
  mucho dos unidades) o alguien carísimo. Las cartas suelen salir algo por
  encima de lo que valen; los de más estrellas piden un poco más.
- Ya no hay botón de comprar sobres de reventa a precio fijo: son los
  vendedores.
- **Logros** (app LOGROS): 17, de abrir sobres, sacar cartas buenas,
  completar un set, el directo y el dinero. Avisan al conseguirlos; no dan
  dinero. En partidas de antes se marcan solos sin avisar.
- **Torneo nacional**: de vez en cuando se anuncia con unos días de
  antelación diciendo de qué set se espera mucho. Ese día gana un mazo con
  tres cartas de ese set y se disparan unos días. (DEV: TORNEO NACIONAL lo
  anuncia y la segunda vez lo resuelve.)
- **Emojis en el chat**: suben por el chat con las raras o mejores, las
  chase, los god packs, las cajas y las propinas (calaveras si el sobre es
  malo y hay gente).

## v0.7.3 - 2026-10-20 - Peticiones, encargos y suerte

Arreglos tras probarla:

- **Caja nueva (booster box)**: dibujo de pixel en vista 3/4 con tapa,
  frente y lateral, rombo del set, banda BOOSTER BOX, borde de la tapa y
  reflejos del plástico. Abierta se ven los 18 sobres de pie en dos filas.
  En la caja lateral sale una versión pequeña.
- **Lo que llevas en la mano gira limpio**: sobres, cajas, fundas y cartas
  se pintan encima a la resolución de la pantalla, sin escalones al girar.
  La caja al abrirse y la tapa volando, igual.
- **Péndulo también en las cartas de la mesa**: cuelgan del punto por donde
  las coges y el centro se queda atrás al moverlas; al soltarlas se
  asientan poco a poco. La caja pesa más y se mece menos.

- **Fundas y top loaders por rareza.** En el armario (abajo a la izquierda)
  eliges desde qué rareza se ponen solas la funda (F) y el top loader (T)
  a las cartas nuevas: NO, RARA+, HOLO+, FULL+ o SECR. Ahora se protegen
  todas las copias de esa rareza, no solo la primera (por eso parecía que
  unas sí y otras no). Por defecto: funda desde holo y top desde full art.
- **Top loaders**: se compran en la tienda (10 por 1,50 €), van encima de
  la funda y se ven en la carta. Se ponen a mano desde la bandeja (TOP) o
  en la mesa (PONER/QUITAR TOP). Al vender o quitar la funda vuelven.
- **Vender en lote por protección**: solo sin funda, solo con funda, solo
  con top loader o todas.
- **God packs**: todas las cartas son holo o mejor (sin raras). La chase
  puede salir con su probabilidad normal.
- **Set 2 con mejor pull rate**: holo o mejor en el 25% de los sobres
  (antes ~19%); sus cartas valen algo menos para que el sobre siga dando
  de media un 85%. Los 4 sets quedan con un 85% de media.
- **Más días entre sets**: sale uno cada 18 días (antes 16).
- **Directos más rentables**: más gente da propina y las propinas son algo
  más grandes (con 5 espectadores, hasta 1,50 €).
- Sin espectadores ya no escribe nadie en el chat.
- **Tienda separada en SOBRES y CAJAS**: cada set tiene su caja aparte,
  con su dibujo y su precio. Las cajas se venden en el móvil (MERCADO >
  el set), con la comisión, no en la tienda.
- **Colección sellada** (armario > SELLADO): tus sobres y cajas cerrados
  de cada set, de 1ª edición y de reimpresión. Lo APARTADO no sale en la
  mesa ni lo abre el ESPACIO, para no abrirlo sin querer.
- En la caja lateral de la mesa caben cajas de los 4 sets (antes solo se
  veían 2). La caja abierta va arriba a la derecha y el resumen del sobre
  baja un poco para no taparla.

- **Cajas selladas** de verdad. Se compran cerradas en la tienda (un 10%
  más baratas que sus 18 sobres, 2 al día por set) y se quedan cerradas:
  en la tienda puedes venderlas al momento por lo que valen sus sobres
  cerrados (un 85%; mientras la tienda las vende, nunca más del 90% de lo
  que cuesta nueva), así que una caja de 1ª edición guardada sube con el
  tiempo.
  - **Abrir una caja** es en la mesa: salen en la caja de cartón de la
    izquierda; la arrastras al tapete, cae rebotando, tiembla con su aura,
    salta la tapa dando vueltas con destello, confeti y rayos, asoman los
    sobres y la caja abierta se va a la esquina de abajo a la derecha.
    En directo el chat lo celebra ("BOX BREAK!").
  - De la caja abierta se arrastran los sobres al tapete (o con ESPACIO,
    que saca primero de la caja abierta y luego de tus sobres guardados).
    Si abres otra caja, los sobres que quedaban en la anterior pasan a tus
    sobres guardados.
  - La caja se ve desde arriba y un poco inclinada: tapa, frente con
    "BOOSTER BOX", laterales y los sobres de pie dentro.
- **Peticiones del chat.** En directo, alguien del chat te pide que abras
  un sobre concreto ("¡ABRE UN S2!") y te paga si lo haces en 2 minutos.
  La petición sale fija arriba del chat con lo que paga y el tiempo que
  queda (parpadea al final). Si la cumples, cobras, el chat lo celebra y
  ganas un par de seguidores; si no, se va con un "L". Salen más cuanta
  más gente te ve (hacen falta 2 espectadores) y a veces piden sobres que
  no tienes: la tienda no corta el directo.
- **Encargos.** App nueva en el móvil, ENCARGOS: gente que te paga por
  abrir sobres concretos en unos días ("abre 3 sobres S2", a veces de 1ª
  edición, que pagan más). Te quedas las cartas: te pagan por abrirlos.
  Aceptas o rechazas; puedes tener 3 en marcha. Cada día puede llegar uno
  nuevo (más con más seguidores) y avisa al cumplirlo o si se acaba el
  plazo. Se cambian en `datos/encargos.lua`.
- **Mejoras de suerte** en una app nueva del móvil, SUERTE, cada una con
  5 niveles y cada nivel más caro:
  - Segunda oportunidad: el hueco de rara o mejor se tira dos veces y te
    quedas la mejor (del 8% al 40% de los sobres).
  - Carta extra: el sobre trae una carta más (del 6% al 30%).
  - Imán de god packs: multiplica la probabilidad (de x1,5 a x3,5).
  Con todo al máximo un sobre trae de media un 93-98% de lo que cuesta:
  ayudan, pero no regalan dinero. Se cambian en `datos/mejoras.lua`.
- **Ganar dinero cuesta más.**
  - Las cartas valen un 15% menos: un sobre trae de media un 72-77% de lo
    que cuesta sin mejoras (el resto sale del móvil, los directos, los
    encargos y la suerte).
  - Los premios por completar ya no dan dinero, solo sobres: 2, 3 y 4 al
    25%, 50% y 75% y 8 al completarlo. Fuera el premio por tenerlo entero
    en 1ª edición (al empezar siempre abres de 1ª).
  - En el móvil las ofertas muy altas salen mucho menos: casi todas rondan
    el valor de la carta y las del +30-40% son raras (`curva` en
    `datos/mercado.lua`).
  - Propinas mucho más pequeñas: casi siempre de 0,10 a 0,30 €; de 0,40 a
    1 € hacen falta 5 espectadores, de 1 a 3 € unos 25, y de 3 a 8 € unos
    80.
  - Los encargos pagan entre un 15% y un 35% de lo que cuestan los sobres
    que piden, y las peticiones del chat entre un 15% y un 40% del sobre.
- **Set 1 con 80 cartas** (antes 40): 40 cartas nuevas de todas las
  rarezas (16 comunes, 10 infrecuentes, 7 raras, 4 holo, 2 full art y una
  secreta más). Completarlo cuesta bastante más. Las cartas se renumeran
  por rareza; en las partidas de antes no se pierde nada.
- **Arreglado**: en un directo con casi nadie mirando podía caer una
  propina de casi 100 €.
- DEV: encargo nuevo y petición del chat al momento.
- **Arreglado**: el álbum del armario daba error al quitar el premio de 1ª
  edición. El guion de pruebas ahora recorre todas las vistas del armario
  y todas las apps del móvil.

## v0.7.2 - 2026-10-20 - La mesa y los directos

- **Los sobres se abren en la mesa.** Nueva pestaña MESA (TIENDA · MESA ·
  ARMARIO · MÓVIL). A la izquierda hay una caja de cartón con tus sobres
  guardados y las fundas. Coges un sobre, lo arrastras al tapete (se
  balancea colgando del dedo, con su peso) y cae rebotando. Lo mantienes
  pulsado para rasgarlo y se abre como siempre. Si lo sueltas fuera del
  tapete, vuelve a la caja. La tienda ya es solo para comprar.
- **Las cartas se quedan sueltas en la mesa.** Al acabar el sobre se ve el
  resumen un momento y las cartas pasan a ser cosas de la mesa: se
  arrastran, se tocan para enfundar, vender o guardar, y llevan su cartel
  de NUEVA si lo eran. Al poner otro sobre en la mesa, todo lo que hay
  encima vuelve solo al armario. En el PC, ESPACIO hace lo mismo y abre el
  siguiente. Ya no hay botones de "siguiente sobre" en pantalla.
- **Fundas a mano.** Cuando el sobre ya está abierto, sacas una funda de la
  caja y la sueltas encima de una carta (brilla al enfundarse). Mientras se abre un sobre no se
  pueden coger ni fundas ni sobres.
- **Las copias que sacas a la mesa** (máximo 10) se ven ahora en el tapete,
  igual que las del sobre: todas del mismo tamaño y todas se pueden
  arrastrar. Se enfundan, se venden o se devuelven al armario (con sus
  botones o soltándolas en la caja). Se quita la vista MESA del armario.
- **Cajas de sobres** en la tienda: 18 sobres un 10% más baratos que
  sueltos (S1: 32,40 €; S4: 194,40 €). Llegan 2 cajas al día de cada set
  mientras se vende en la tienda y no gastan los sobres sueltos. Se cambia
  en `datos/sobres.lua`.
- **Directos.** A la derecha de la mesa está el móvil en un trípode. Le
  pones nombre al canal, eliges el idioma del chat (español o inglés) y el
  tipo de directo (de momento solo APERTURA; evaluación y colección salen
  como "próximamente"), y pulsas EMPEZAR DIRECTO. Lo paras cuando
  quieras y sale un resumen con la duración, los sobres abiertos, el pico de
  espectadores, los seguidores nuevos y las propinas.
  - Al principio casi nadie te ve: 0 o 1 espectadores y como mucho un
    mensaje al acabar el sobre. Con más seguidores hay más gente y el chat
    reacciona a cada carta ("???" en el suspense, "F" y "next" con las
    comunes...). Con una chase o una secreta explota y caen propinas.
  - El chat pregunta lo típico (qué set es, cuánto vale, si sorteas algo),
    se impacienta si no abres ("abre ya", "se ha dormido") y habla con
    slang ("6-7", "aura +1000", "W pull", "no cap", "cooked"...). Solo
    texto, sin emojis por ahora. Con el chat en español sale algún mensaje
    en inglés y al revés. Hay unas 800 frases (`datos/chat.lua`): no se
    repite ninguna de las últimas 60 y a veces cambian un poco ("xd",
    "!!", letras alargadas). Muchos más nombres en el chat.
  - Las propinas llegan a tu dinero con su mensaje en amarillo. Los
    seguidores se guardan en la partida: son el progreso del canal. Cuantos
    más tienes, más cuesta conseguir nuevos.
  - En la tienda y el armario el directo sigue (arriba sale "EN DIRECTO N"),
    pero la gente se va yendo si tardas. Ir al MÓVIL o pasar el día lo
    corta: el móvil es el que graba.
  - Los números están en `datos/directo.lua` y las frases en `datos/chat.lua`.
- **Economía nueva.** La venta rápida paga el 100% del valor de mercado
  (antes, el 50%). Las ofertas del móvil son del 100% al 140% del valor,
  menos la comisión del 8%. Los valores de las cartas suben para que un
  sobre de 1ª edición a mitad de tirada dé de media un 90% de lo que
  cuesta (el resto sale del móvil, los directos y la suerte). Los
  seguidores llegan un 20% más despacio que en la primera prueba. El hype de salida es más suave (+35% las normales, +70% las chase)
  y la 1ª edición baja menos durante la tirada (un 10% como mucho).
  Con los bots, abrir y vender gana claramente más que esperar, y abrir en
  directo más aún, sin dinero infinito.
- **Android solo en horizontal.** El juego ya no gira a vertical al girar
  el móvil: siempre horizontal (en el PC la ventana se puede seguir
  cambiando de tamaño).
- Herramientas: el guion de pruebas empieza una partida nueva y prueba la
  mesa y el directo (el de convertir partidas v5 sigue como
  `guion_conversion.lua`). Hay un bot que abre en directo y `SOLO=nombre`
  para pasar solo una estrategia.

## v0.7.1 - 2026-10-20 - Premios y un mercado que se puede jugar

(La APK salió numerada como v0.8.0 por error; es una versión dentro de la 0.7.)

- **Premios por completar.** Cada set da sobres al llegar al 25%, 50% y
  75% de sus cartas, y al completarlo sobres y dinero. Completarlo entero
  en 1ª edición da otro premio gordo. Salen con un aviso y confeti, y se
  ven en el álbum (en amarillo los conseguidos). Se cambian en
  `datos/premios.lua`. En las partidas de antes, lo que ya tenías
  completado cuenta como cobrado.
- **El día de salida compensa.** Las cartas de un set recién salido valen
  bastante más los primeros días (todo el mundo las quiere) y se va
  pasando en una semana. Abrir el día de salida y vender las repes suele
  salir rentable; abrir a mitad de tirada, no. Los sobres cerrados casi no
  suben al salir, para que no se pueda comprar y revender sin abrir.
- **El móvil paga mejor.** Los compradores ofrecen entre un 85% y un 135%
  del valor (antes 75%-120%): vender por el móvil en vez de a la tienda se
  nota.
- **Se empieza con 3 sobres** del Set 1 de 1ª edición para abrir nada más
  empezar.
- **Picos más largos.** Las burbujas suben durante 1-2 semanas y se
  desinflan en 4 días; los golpes de las noticias tardan unas dos semanas
  en irse (antes 4-5 días). En la gráfica de 600 días ya no parecen agujas
  de un día.
- **Arreglado**: al empezar una partida nueva se quedaba abierta la bandeja
  de una carta de la partida anterior.

## v0.7.0 - 2026-10-20 - Mercado con memoria

- **Rachas que duran.** Cada carta y cada set van una temporada subiendo,
  bajando o quietos (de una a varias semanas). Lo que sube no vuelve solo a
  la media: el precio se queda donde lo dejó la racha y solo regresa muy
  despacio.
- **Los picos dejan huella.** Una noticia (vídeo viral, torneo, copias
  falsas...) da un golpe al precio que se va deshaciendo, pero un 30% se
  queda para siempre.
- **Sets de moda.** Un set entero puede ponerse de moda o perder interés
  durante semanas, y sale en las noticias. Si sus chase suben mucho, tiran
  del resto del set.
- **1ª edición con precio propio.** Cada carta tiene ya dos precios con su
  historial: el de 1ª edición (desde que sale el set) y el normal (desde la
  primera reimpresión). La gráfica de la ficha enseña las dos líneas.
- **Vintage sin techo.** La 1ª edición agotada sube cada vez más despacio
  pero sin pararse nunca: unas x2 a los 100 días, x3,7 a los 300, x5 a los
  600 (las chase y los sobres cerrados, más). Antes se quedaba plana a los
  dos meses.
- **Tirada de 1ª edición.** Cada set imprime al menos 2.000 sobres de 1ª
  edición. Lo que compras tú nunca pasa de entre un 5% y un 15% de la
  tirada (se sortea por set): si compras más, se imprimen más, y cuanto más
  grande la tirada, más baratas sus 1ª ediciones. No se puede acaparar un
  set. Se ve en la tienda y en el móvil.
- **Crashes.** A veces aparece un almacén lleno de sobres de 1ª edición de
  un set agotado: su tirada crece para siempre y su 1ª edición se hunde.
  También pueden aparecer cajas de reimpresión que hunden las normales.
- **Ganar dinero cuesta más.** Los valores de las cartas se han bajado para
  que abrir un sobre dé de media un 70% de lo que cuesta, como en los TCG de
  verdad. Se gana guardando sobres y cartas de 1ª edición, acertando rachas
  y con la suerte de sacar una chase. La secreta del Set 1 vale entre 12 y
  16 veces el sobre al salir.
- **Arreglado**: con pocas copias, la bandeja las ponía a la izquierda en
  vez de en el centro, y la carta con el ratón encima se veía doble.
- **Arreglado**: cuando ya había 40 noticias guardadas dejaban de llegar
  avisos de noticias nuevas al móvil.
- **Arreglado**: empezar una partida nueva con la ficha de una carta abierta
  en el móvil podía cerrar el juego.
- Herramientas de desarrollador: pasar 100 y 300 días, poner un set de
  moda, hacer que pierda interés y forzar un crash.
- Las partidas de la v0.6 se convierten al cargar: los precios de hoy se
  respetan.

## v0.6.0 - 2026-10-20 - Copias una a una

- **Cada copia va por separado.** El juego ya no guarda "tienes 25 de esta
  carta, 10 de 1ª edición": guarda cada copia con lo suyo (1ª edición o
  normal, con funda o sin ella, en el móvil, en la mesa). Las partidas de
  la v0.5 se convierten solas al cargarlas, sin perder nada.
- **Bandeja de copias.** Al pulsar un montón se abren abajo todas sus
  copias en fila, primero las de 1ª edición (con una rayita amarilla
  debajo). Click en una para elegirla o mantén y arrastra por encima para
  elegir varias de golpe. Filtros rápidos: todas, 1ª edición, normales,
  sin funda, ninguna. Con las elegidas: vender, publicar en el móvil,
  enfundar, quitar funda o sacarlas a la mesa. Al pasar por encima de una
  copia se ve en grande a la izquierda.
- **Venta en lote con opciones.** Un solo botón, "Vender en lote", abre un
  panel donde eliges: solo repes (deja la mejor copia de cada carta) o
  todo, si entran las de 1ª edición, si entran las enfundadas y si es de
  todos los sets o solo del que estás viendo. Dice cuántas cartas, por
  cuánto y cuántas se irían del álbum. Por defecto no vende ni 1ª edición
  ni enfundadas. Nunca vende las del móvil ni las de la mesa.
- **La mesa ya no es un desorden.** Solo están las copias que sacas desde
  la bandeja (10 como mucho). Al pulsar una se puede enfundar, vender o
  devolver al armario.
- **Fuera el almacén.** Sin estanterías ni cajas: no hay límite de sobres
  ni de cartas.
- **Gráfica de la ficha arreglada.** La línea de 1ª edición empezaba el
  día de la reimpresión, como si hubiera salido después. Ahora la 1ª
  edición va desde que salió el set y la normal desde la primera
  reimpresión.
- **Scroll arrastrando en el móvil.** En Android no hay rueda y las apps no
  se podían mover. Ahora se arrastra la lista con el dedo (o el ratón); un
  toque sin arrastrar sigue abriendo lo que pulsas.
- El armario pasa páginas si un set no cabe (en el Set 2 no se veían las
  últimas 15 cartas).
- Más rápido: el valor de la colección, las ventas en lote y la lista de
  la cartera ya no se recalculan cada frame, solo cuando cambia algo.
- Se ha limpiado código que ya no se usaba y cargas de módulos dentro de
  funciones que se repetían.

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
