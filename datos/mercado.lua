-- Todo el dinero va en centimos: 200 = 2,00 €
-- Cada carta tiene dos precios: el de 1ª edicion (desde que sale el set) y el
-- normal (desde la primera reimpresion). Cada dia persiguen un "precio
-- objetivo" que sale de:
--   valor base (datos/sets.lua) x fase del set (calendario) x tendencia del set
--   x tendencia de la carta x golpes de noticias x burbuja
-- y la 1ª edicion ademas x vintage (sube sin techo desde que se agota) x tirada.
return {
    -- cada carta se aleja un poco del valor de su rareza (entre estos dos)
    variacion = { 0.8, 1.3 },
    -- la tienda te paga esta parte del valor si vendes al momento (1 = todo)
    ventaRapida = 1.0,
    -- lo que se queda la app por cada venta del movil (cartas y sobres cerrados)
    comision = 0.08,
    -- comprar sobres cerrados de reventa cuesta esto mas que su precio de mercado
    recargoReventa = 0.06,

    -- cuanto se acerca el precio a su objetivo cada dia (0.3 = un 30%), y en burbuja
    seguimiento = 0.3,
    seguimientoBurbuja = 0.6,
    -- ruido diario del precio (0.015 = un 1,5% arriba o abajo, mas o menos)
    ruido = 0.015,

    -- vender una copia suma esto a la saturacion de la carta (en el movil, la mitad);
    -- el precio se divide entre (1 + saturacion * golpe) y cada dia se recupera
    saturacion = { golpe = 0.15, recuperacion = 0.6 },

    -- Rachas: cada carta y cada set van un tiempo subiendo, bajando o quietos.
    -- deriva: lo que sube o baja al dia en una racha (0.01 = un 1%);
    -- dias: lo que dura; pesos: lo facil que sale cada tipo;
    -- vuelta: lo que vuelve cada dia hacia su precio normal (muy poco: las
    -- rachas dejan huella); max: lo lejos que puede irse (en veces, x3 = 3)
    rachas = {
        carta = { pesos = { quieta = 2, sube = 1, baja = 1 }, deriva = { 0.003, 0.012 }, dias = { 5, 20 }, vuelta = 0.005, max = 3 },
        set = { pesos = { quieta = 2, sube = 1, baja = 1 }, deriva = { 0.002, 0.007 }, dias = { 10, 35 }, vuelta = 0.002, max = 2.5 },
        -- las chase se mueven mas
        chase = 1.5,
        -- un set que empieza a subir rapido sale en las noticias (deriva minima)
        noticiaModa = 0.005,
    },

    -- Golpes de las noticias: un pico que se va deshaciendo (baja: lo que se
    -- deshace cada dia) pero deja una parte para siempre (memoria)
    golpes = { baja = 0.08, memoria = 0.3 },

    -- lo que arrastra una chase a su set: si la chase sube un 30%, el set un 6%
    contagio = 0.2,

    -- precio segun la fase del set (1 = su valor base)
    fases = {
        -- al salir todo el mundo quiere las cartas: valen algo mas y se va
        -- pasando en una semana o asi (abrir el dia de salida compensa)
        hype = { normal = 0.35, chase = 0.7, dias = 6 },
        -- mientras se imprime la 1ª edicion va bajando hasta perder esto
        caidaTirada = 0.1,
        -- normales: durante una reimpresion
        reimpresion = 0.72,
        -- normales: agotadas tras una reimpresion suben un poco, con techo
        subidaTrasReimpresion = 0.45, ritmoTrasReimpresion = 10,
        -- cuando hay rumor de reimpresion
        caidaRumor = 0.12,
        -- las chase se mueven mas: (m - 1) * esto + 1
        chase = 1.6,
    },

    -- Vintage: la 1ª edicion agotada sube sin techo, cada vez mas despacio pero
    -- sin pararse: (1 + dias / tau) ^ alfa. Con tau 30 y alfa 0.55: x2,2 a los
    -- 100 dias, x3,7 a los 300, x5,3 a los 600. Las chase y los sobres cerrados
    -- con su propio alfa
    vintage = { tau = 30, alfa = 0.55, alfaChase = 0.75, alfaSellado = 0.7, caidaRumor = 0.05 },

    -- Tirada de 1ª edicion: cada set imprime como minimo "minima" sobres. Lo que
    -- compras tu nunca pasa de una "cuota" de la tirada (entre 5% y 15%, se
    -- sortea por set): si compras mas, se imprime mas. Cuanto mas grande la
    -- tirada respecto a la minima, mas baratas sus 1ª ediciones: (tirada/minima)^-efecto
    -- maxNoticias: los almacenes no suben la tirada por encima de minima x esto
    tirada = { minima = 2000, cuota = { 0.05, 0.15 }, efecto = 0.3, maxNoticias = 4 },

    -- sobres cerrados respecto a su precio de tienda
    sellados = {
        tirada = 0.95,
        -- al salir los sobres cerrados apenas suben (la tienda aun los tiene)
        hype = 0.15,
        reimpresion = 0.92,
        subidaReimpresion = 0.45, ritmoReimpresion = 12,
        caidaRumor = 0.1,
    },

    -- sobres que llegan a la tienda cada dia
    stock = { lanzamiento = 10, impresion = 20, reimpresion = 25 },

    -- ventas al dia de cada rareza (para las barras de volumen de las graficas)
    volumen = { comun = 40, infrecuente = 20, rara = 8, holo = 4, fullart = 2, secreta = 1 },

    -- burbujas: solo en chase, a partir de cierto dia
    burbuja = {
        prob = 0.03, desdeDia = 12,
        dias = { 7, 14 },         -- dias subiendo
        subida = { 1.05, 1.11 },  -- cada dia que sube
        pinchazo = 0.8,           -- lo que queda cada dia que se desinfla
        diasPinchazo = 4,
        volumen = 4,
    },

    anuncios = {
        maximo = 6,
        probOferta = 0.7,      -- cada dia, por anuncio
        probSegunda = 0.3,
        ofertasMax = 3,        -- por anuncio a la vez
        rango = { 1.0, 1.4 },   -- lo que ofrecen respecto al valor (antes de la comision)
        dias = 2,              -- lo que dura una oferta
        subida = 0.15,         -- "pedir mas"
    },

    probNoticia = 0.4,
    -- noticias al azar de una carta ({carta}) o un set ({set})
    -- efecto: golpe al precio (x2 = lo dobla de golpe; luego se va deshaciendo
    -- y deja su memoria, ver golpes); dias: los que se vende mas de lo normal.
    -- solo1 / soloNormal: solo a esa edicion; tirada: multiplica la tirada de
    -- 1ª edicion (hay mas copias para siempre); desde: dia minimo
    noticias = {
        { tipo = "carta", clave = "viral",    texto = "{carta} sale en un vídeo viral", efecto = 2.0, dias = 3, peso = 1 },
        { tipo = "carta", clave = "streamer", texto = "Un streamer busca {carta} para su colección", efecto = 1.6, dias = 4, peso = 2 },
        { tipo = "carta", clave = "torneo",   texto = "Torneo regional: el mazo ganador lleva {carta}", efecto = 1.4, dias = 5, peso = 2 },
        { tipo = "carta", clave = "falsas",   texto = "Aparecen copias falsas de {carta}", efecto = 0.7, dias = 4, peso = 1 },
        { tipo = "carta", clave = "habla",    texto = "Todo el mundo habla de {carta}", efecto = 1.3, dias = 3, peso = 1, soloChase = true },
        { tipo = "set",   clave = "aniversario", texto = "Aniversario del {set}: los coleccionistas vuelven a por él", efecto = 1.2, dias = 3, peso = 1, soloAgotado = true },
        { tipo = "set",   clave = "rumor",    texto = "Se rumorea una reimpresión del {set}", efecto = 0.88, dias = 3, peso = 1, soloAgotado = true },
        { tipo = "set",   clave = "escasez",  texto = "Escasez del {set}: hoy llegan menos sobres a la tienda", efecto = 1.1, dias = 1, peso = 0.5, soloTienda = true },
        -- crashes: poco frecuentes y solo cuando ya hay historia
        { tipo = "set",   clave = "almacen1", texto = "Encuentran un almacén lleno de sobres de 1ª edición del {set}", efecto = 0.6, dias = 6, peso = 0.12,
          soloAgotado = true, solo1 = true, tirada = { 1.4, 2.0 }, desde = 60 },
        { tipo = "set",   clave = "almacen",  texto = "Aparece un almacén con cajas de reimpresión del {set}", efecto = 0.7, dias = 4, peso = 0.15,
          soloReimpreso = true, soloNormal = true, desde = 60 },
    },

    -- lo que se explica la primera vez que sale cada noticia
    explicaciones = {
        lanzamiento = "Los sobres de un set nuevo se compran en la tienda a su precio. Sus cartas son de 1ª edición y al principio todo el mundo las quiere.",
        anuncio = "Un set anunciado saldrá en la tienda en unos días. Míralo en la app Calendario.",
        ultimos = "Cuando un set deja de imprimirse ya no hay sobres en la tienda: solo de reventa. Sus cartas suelen subir.",
        agotado = "Este set ya solo se consigue de reventa (app Mercado). Sus cartas y sobres cerrados suelen subir con el tiempo.",
        rumor = "Un rumor no siempre se cumple. Si llega la reimpresión, las cartas normales bajan, pero las de 1ª edición valen más.",
        reimpresion = "Vuelven los sobres a la tienda, pero ya no son de 1ª edición. Las cartas normales bajan y las de 1ª edición suben.",
        burbuja = "Cuando una carta sube muy rápido y se vende muchísimo, puede ser una burbuja: tarde o temprano pincha.",
        escasez = "Hoy la tienda recibe menos sobres de ese set.",
        almacen1 = "Si aparecen muchas copias de golpe, hay más oferta para siempre: la 1ª edición de ese set se hunde y tarda en recuperarse.",
        almacen = "Más reimpresiones en el mercado: las cartas normales de ese set bajan. Las de 1ª edición casi no lo notan.",
        moda = "Cuando un set se pone de moda sube todo: sus cartas, sus sobres cerrados... Las modas duran semanas, pero se acaban.",
        caida = "A veces un set pierde interés durante unas semanas y baja poco a poco. No siempre vuelve a donde estaba.",
    },

    compradores = {
        "Cartofan", "Mari_TCG", "El Paco", "Holohunter", "La Abuela", "Novato22",
        "Pepe Cartas", "Trader_MLG", "Rubén", "Lola Packs", "Coleccionista", "Sobrero",
        "Nachete", "Bicho_Max", "Carmen", "Dani Foil", "Toñi", "Holo_Hugo",
        "Martita", "Kevin TCG", "Don Sobre", "Pili", "Cartero88", "Mr. Brillo",
        "Lucía", "Abuelo Paco", "PackLover", "Sergio", "Rarezas_Bcn", "Alba",
        "Fundas Juan", "Tito Holo", "Sobrina Ana", "MetaChaser", "El Gradeador", "Nena Pack",
    },
}
