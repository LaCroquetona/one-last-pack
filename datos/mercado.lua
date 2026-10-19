-- Todo el dinero va en centimos: 200 = 2,00 €
-- El precio de cada carta persigue cada dia un "precio objetivo" que sale de
-- su valor base (datos/sets.lua), la fase de su set, las noticias y las
-- burbujas. Asi se mueve, pero siempre con un motivo.
return {
    -- cada carta se aleja un poco del valor de su rareza (entre estos dos)
    variacion = { 0.8, 1.3 },
    -- la tienda te paga esta parte del valor si vendes al momento
    ventaRapida = 0.5,
    -- lo que se queda la app por cada venta del movil (cartas y sobres cerrados)
    comision = 0.08,
    -- comprar sobres cerrados de reventa cuesta esto mas que su precio de mercado
    recargoReventa = 0.06,

    -- cuanto se acerca el precio a su objetivo cada dia (0.3 = un 30%), y en burbuja
    seguimiento = 0.3,
    seguimientoBurbuja = 0.6,
    -- ruido diario del precio (0.03 = un 3% arriba o abajo, mas o menos)
    ruido = 0.03,

    -- vender una copia suma esto a la saturacion de la carta (en el movil, la mitad);
    -- el precio se divide entre (1 + saturacion * golpe) y cada dia se recupera
    saturacion = { golpe = 0.15, recuperacion = 0.6 },

    -- precio de una carta normal segun la fase de su set (1 = su valor base)
    fases = {
        -- al salir: sube y vuelve a la normalidad en unos dias
        hype = { normal = 0.25, chase = 0.6, dias = 3 },
        -- mientras se imprime va bajando hasta perder esto al final de la tirada
        caidaTirada = 0.18,
        -- agotada sin reimprimir: sube hasta ganar esto
        subidaAgotado = 0.6, ritmoAgotado = 7,
        -- durante una reimpresion
        reimpresion = 0.72,
        -- agotada otra vez tras una reimpresion
        subidaTrasReimpresion = 0.45, ritmoTrasReimpresion = 10,
        -- cuando hay rumor de reimpresion
        caidaRumor = 0.12,
        -- las chase se mueven mas: (m - 1) * esto + 1
        chase = 1.6,
    },

    -- primera edicion: hasta que llega la primera reimpresion todas las copias
    -- lo son. Despues su precio sigue subiendo desde que se agoto la tirada
    -- (hasta ganar subida) y cada reimpresion nueva le quita caidaReimpresion
    primera = { subida = 1.0, ritmo = 25, caidaReimpresion = 0.08, rampa = 5 },

    -- sobres cerrados respecto a su precio de tienda
    sellados = {
        tirada = 0.95,
        subidaPrimera = 1.4, ritmoPrimera = 15,   -- 1ª edicion agotada
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
        dias = { 4, 7 },          -- dias subiendo
        subida = { 1.15, 1.3 },   -- cada dia que sube
        pinchazo = 0.55,          -- lo que queda al pinchar (dos dias seguidos)
        volumen = 4,
    },

    -- almacen: cuantos sobres cerrados caben por estanteria y cartas por caja
    almacen = {
        sobresPorEstanteria = 20, cartasPorCaja = 250,
        estanterias = 1, cajas = 2,                  -- al empezar
        precioEstanteria = 500, subidaEstanteria = 1.6,
        precioCaja = 300, subidaCaja = 1.5,
    },

    anuncios = {
        maximo = 6,
        probOferta = 0.7,      -- cada dia, por anuncio
        probSegunda = 0.3,
        ofertasMax = 3,        -- por anuncio a la vez
        rango = { 0.75, 1.2 }, -- lo que ofrecen respecto al valor
        dias = 2,              -- lo que dura una oferta
        subida = 0.15,         -- "pedir mas"
    },

    probNoticia = 0.4,
    -- noticias al azar de una carta ({carta}) o un set ({set})
    -- efecto: multiplica el precio objetivo esos dias
    noticias = {
        { tipo = "carta", clave = "viral",    texto = "{carta} sale en un vídeo viral", efecto = 2.0, dias = 3, peso = 1 },
        { tipo = "carta", clave = "streamer", texto = "Un streamer busca {carta} para su colección", efecto = 1.6, dias = 4, peso = 2 },
        { tipo = "carta", clave = "torneo",   texto = "Torneo regional: el mazo ganador lleva {carta}", efecto = 1.4, dias = 5, peso = 2 },
        { tipo = "carta", clave = "falsas",   texto = "Aparecen copias falsas de {carta}", efecto = 0.7, dias = 4, peso = 1 },
        { tipo = "carta", clave = "habla",    texto = "Todo el mundo habla de {carta}", efecto = 1.3, dias = 3, peso = 1, soloChase = true },
        { tipo = "set",   clave = "aniversario", texto = "Aniversario del {set}: los coleccionistas vuelven a por él", efecto = 1.2, dias = 3, peso = 1, soloAgotado = true },
        { tipo = "set",   clave = "rumor",    texto = "Se rumorea una reimpresión del {set}", efecto = 0.88, dias = 3, peso = 1, soloAgotado = true },
        { tipo = "set",   clave = "escasez",  texto = "Escasez del {set}: hoy llegan menos sobres a la tienda", efecto = 1.1, dias = 1, peso = 0.5, soloTienda = true },
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
