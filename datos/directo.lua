-- Directos: cuanta gente te ve, cuando te siguen, cuando dan propinas y lo
-- que dice el chat. El dinero va en centimos.
-- Las frases del chat estan en datos/chat.lua.
return {
    -- espectadores segun tus seguidores: base + raiz(seguidores) * raiz + seguidores * lineal
    -- (0 seguidores: 0-1; 30: unos 5; 400: unos 26; 2.000: unos 80)
    espectadores = { base = 0.5, raiz = 0.9, lineal = 0.02, ruido = 0.25,
        -- a partir de "umbral" seguidores la gente sube mucho mas lento: los
        -- seguidores de mas cuentan solo "despues" (los sigues teniendo)
        umbral = 800, despues = 0.2 },
    -- ritmo: abrir mas de "normal" sobres por minuto (mirado en los ultimos
    -- "ventana" segundos) no da mas: cada sobre trae menos propinas y
    -- seguidores de lo normal y las holo menos subidon. Lo viral, entero
    ritmo = { normal = 4, ventana = 60 },
    -- hasta cuantos directos hechos se avisa de que abres sobres sin directo
    avisarHasta = 3,
    -- lo que tarda la gente en llegar al empezar y en moverse (por segundo)
    llegada = 0.08,
    -- una carta buena trae mirones: el directo sube esto (x) y se va pasando
    subidon = { holo = 0.15, fullart = 0.4, secreta = 0.8, chase = 0.5, godpack = 1.0, baja = 0.012 },
    -- si no abres sobres la gente se aburre: a partir de "desde" segundos
    -- se va esta parte cada segundo (con un minimo de gente que se queda)
    aburrimiento = { desde = 40, ritmo = 0.012, queda = 0.35 },
    -- fuera de la mesa (tienda, armario) se va mas rapido
    fuera = { ritmo = 0.02, queda = 0.2 },

    -- seguidores nuevos por cada sobre abierto en directo
    seguir = {
        porSobre = 0.12,          -- aunque no te vea nadie, alguien te encuentra
        porEspectador = 0.008,
        -- cuantos mas tienes, mas cuesta conseguir nuevos: todo se divide
        -- entre 1 + seguidores / esto
        cansancio = 1500,
        -- extra segun la mejor carta del sobre (se multiplica por 1 + espectadores * 0.02)
        mejor = { holo = 0.8, fullart = 2.4, secreta = 6.5 },
        chase = 4, godpack = 16,
        -- con gente mirando tambien se sigue sin abrir (por espectador y minuto)
        porMinuto = 0.0032,
        -- al empezar el canal (menos de "hasta" seguidores) se gana x"mult":
        -- que llegues pronto a la venta de sobres
        arranque = { hasta = 30, mult = 2.5 },
    },

    -- propinas: cada espectador puede dar una al acabar un sobre (prob), y
    -- al salir una carta buena (prob x lo de su rareza)
    propinas = {
        prob = 0.01,
        rareza = { holo = 3, fullart = 8, secreta = 14 },
        chase = 10, godpack = 30,
        -- tope de probabilidad por espectador (aunque el multiplicador sea alto)
        probMax = 0.35,
        -- cuanto dan: {minimo, maximo, peso, espectadores que hacen falta}
        -- (las propinas gordas solo llegan a canales con gente)
        cantidades = { { 20, 60, 70, 0 }, { 60, 150, 24, 10 }, { 150, 400, 5, 40 }, { 400, 1000, 1, 100 } },
        -- con mucha gente, en lo normal (el sobre, raras, holos) solo dan
        -- propina "tope" espectadores y de los de mas solo esta parte: que una
        -- rara no pague mas que el sobre. Lo gordo (viral) cuenta con toda la
        -- gente: un god pack o una secreta en directo es un clip viral
        tope = 22, despuesTope = 0.1,
        -- desde esta propina (centimos) sale destacada arriba del chat unos segundos
        destacada = 150, segundosDestacada = 8,
        viral = { secreta = true, chase = true, godpack = true },
    },

    chat = {
        -- mensajes sueltos por espectador y segundo (con un maximo)
        ritmo = 0.015, maxRitmo = 2.5,
        -- parte de los mensajes que salen en el otro idioma
        otroIdioma = 0.12,
        -- mensajes por espectador al salir cada rareza (con muy poca gente
        -- solo se reacciona a lo bueno)
        reaccion = { comun = 0.05, infrecuente = 0.05, rara = 0.08, holo = 0.25, fullart = 0.5, secreta = 0.8 },
        maxReaccion = 14,
        -- con 3 o menos espectadores: probabilidad de un mensaje al acabar el sobre
        finSobre = 0.35,
        max = 40,
    },

    -- venta de sobres en directo (como en internet): el chat te compra sobres
    -- que tienes guardados, los abres en directo y las cartas son para quien
    -- paga. Cobras el precio de mercado del sobre con un margen.
    -- porMinuto + espectadores * porEspectador compradores al minuto (con tope);
    -- margen: lo que pagan sobre el precio de mercado, sube con la gente
    -- (margenPorEspectador, hasta margenMax); segundos: lo que esperan
    venta = {
        porMinuto = 0.5, porEspectador = 0.3, maxPorMinuto = 4, espectadoresMin = 1,
        max = 3, segundos = 90,
        margen = { 1.0, 1.06 }, margenPorEspectador = 0.0015, margenMax = 0.05,
        -- hace falta tener estos seguidores para hacer directos de venta
        desbloqueo = 50,
        -- el primer comprador llega pronto (segundos) si tienes sobres
        primero = 10,
        -- hype: lo que abres en directo (tuyo o vendido) da ganas de comprar.
        -- Sube los compradores (x 1 + hype) y lo que pagan (+ hype * margenHype,
        -- hasta hypeMax de hype); se va pasando (baja por segundo)
        hype = { sobre = 0.15, rara = 0.1, holo = 0.35, fullart = 0.8, secreta = 1.5, chase = 0.8, godpack = 2,
                 baja = 0.012, max = 3, margen = 0.04 },
        -- seguidores extra si al comprador le toca algo bueno (holo o mejor)
        seguidoresSuerte = 3,
        -- que piden (pesos): un sobre, varios del mismo set (2 a "maxVarios"),
        -- un blister entero o una ETB (solo si los tienes). Los de varios
        -- sobres o productos esperan "masTiempo" veces mas
        pedir = { sobre = 70, varios = 16, blister = 9, etb = 5 },
        maxVarios = 4, masTiempo = 1.5,
        -- compras de tu chat de Twitch (!comprar): como mucho estas a la vez entre
        -- todos y una por persona; con el tope lleno el !comprar no sale
        chatMax = 3,
        textos = {
            es = { compra = { "me pillo un {s}", "VENDEME UN {s}", "quiero un {s} pls", "un {s} para mi", "abreme un {s} que lo pago",
                              "yo compro un {s}", "{s} para el menda", "me llevo un {s} bro", "pago un {s} pa ver que sale", "un {s} y que salga la chase" },
                   varios = { "me pillo {n} de {s}", "dame {n} {s} que hoy cobro", "{n} sobres de {s} pa mi", "abreme {n} de {s} seguidos",
                              "pack de {n} {s}, me la juego", "{n} {s} y si no sale nada lloro" },
                   blister = { "me llevo un blister de {s}", "abre un blister de {s} pa mi", "blister de {s} entero, lo pago",
                               "quiero el blister de {s}", "el blister de {s} es mio" },
                   etb = { "ME PILLO UNA ETB DE {s}", "abreme una ETB de {s} entera", "ETB de {s} pa mi, sin miedo",
                           "pago la ETB de {s}, hoy me arruino", "ETB {s} y que salga la chase" },
                   otro = { "otro mas!", "sigue sigue", "el siguiente es el bueno", "venga el otro", "vamos con el siguiente", "uno mas" },
                   bien = { "LETS GOOO QUE ES MIO", "NO PUEDE SER MI CARTAAA", "GOAT GOAT GOAT", "vale esto ya lo pago", "MADRE MIA QUE SUERTE", "te compro otro ya" },
                   mal = { "bueno otra vez sera", "L tremenda", "todo bulk bro", "mi cartera llora", "ni una rara jajaja", "el siguiente sale fijo" },
                   caducada = { "bueno me voy que tardas", "se me ha quitado la gana", "otro dia lo compro" },
                   rechazada = { "vale vale no me lo vendas", "me has hecho la cobra", "pues me voy a otro canal" } },
            en = { compra = { "ill buy a {s}", "SELL ME A {s}", "one {s} for me pls", "open a {s} for me", "taking a {s}",
                              "i want a {s}", "{s} please", "ill pay for a {s}", "one {s} lets go", "{s} for me bro" },
                   varios = { "ill take {n} {s}", "{n} {s} packs for me", "open {n} {s} in a row", "{n} {s} lets gamble" },
                   blister = { "ill take a {s} blister", "open a {s} blister for me", "whole {s} blister, paying", "the {s} blister is mine" },
                   etb = { "IM BUYING A {s} ETB", "open a whole {s} ETB for me", "{s} ETB for me, no fear", "paying for the {s} ETB" },
                   otro = { "next one!", "keep going", "next one hits", "come on the next", "one more" },
                   bien = { "LETS GOOO ITS MINE", "NO WAY MY CARD", "GOATED PULL", "worth every cent", "INSANE LUCK", "buying another one" },
                   mal = { "unlucky", "massive L", "all bulk bro", "my wallet is crying", "not even a rare lol", "next one hits for sure" },
                   caducada = { "too slow im out", "nvm", "maybe next stream" },
                   rechazada = { "ok dont sell it then", "rejected lol", "fine ill go elsewhere" } },
        },
    },

    -- tipos de directo
    tipos = {
        { id = "apertura", nombre = "APERTURA" },
        { id = "venta", nombre = "VENTA DE SOBRES" },
        { id = "evaluacion", nombre = "EVALUACIÓN", proximamente = true },
        { id = "coleccion", nombre = "COLECCIÓN", proximamente = true },
    },

    -- nombres del chat: trozo + trozo (+ numero a veces) o uno entero de
    -- "enteros" (los mas graciosos, para que no salgan todo el rato)
    nombres = {
        enteros = { "ManosDeMantequilla", "BulkLord", "SobreAdicto2009", "ElDelToploader", "RasgaSobres", "HoloEnLaSopa",
            "SinFundaNiNa", "TuPrimoElDeLaSecreta", "PapaDeLaChase", "MiMadreNoLoSabe", "ComunesConQueso", "xX_BulkSlayer_Xx",
            "SoloMiroNoCompro", "GradeameEsta", "PSA10DeCorazon", "NoLoAbrasHuelelo", "AbuelaGamer", "TitoDelBulk",
            "SecretaEnElBano", "CeroHolos", "MaldicionDelBulk", "MiPagaEnSobres", "HipotecaEnSobres", "VendoRinonPorChase",
            "CroquetaHolografica", "TortillaFullArt", "FanDelBichoAzul", "FundaDobleTriple", "OlorASobreNuevo",
            "ProbabilidadCero", "PiedadPorFavor", "GodPackOBust", "NPC_de_la_Tienda", "ElQueLlegaTarde", "AFK_desde_2019",
            "MasSuerteQueTu", "ElDelOtroCanal", "ComproTuBulk", "TopLoaderHumano", "CartaDoblada", "SobrePesado",
            "ManifestandoSecreta", "ElSobreMeMira", "RizzDeCarton", "AuraDeFunda", "BinderVacio", "MiAlbumLlora",
            "ProfeDeBulk", "SuegraDelSobre", "CuentaAtrasDeLaChase", "NoEnfundoYQue", "ElBulkEsArte", "JuegoConLasComunes",
            "PatrocinadoPorMiAbuela", "TengoDeberesPeroBueno", "ElReyDelBlister", "LataDeTin", "EtbEnElSalon",
            "Croquetina_Fan", "CajaDeZapatosTCG", "MirandoDesdeElBus", "SobreDeLaSuerte", "EstoEsInversion",
            "HoloOMuerte", "NoSePeroSiSe", "LadronDeFundas", "DueloDeBulk", "MiPerroAbreMejor", "ElSobreEstaFrio" },
        a = { "xX", "el", "la", "mr", "don", "lil", "big", "pro", "sir", "mini", "super", "the", "real", "not", "tito", "abuelo",
              "doña", "mega", "ultra", "baby", "tia", "profe", "capi", "dr", "miss", "uncle", "its", "just", "yo_soy" , "porro" ,"petardo" , "Elba", "Elena"},
        b = { "Sobrero", "Pakito", "Holo", "Rizz", "Skibidi", "Sigma", "Aura", "Bicho", "Pack", "Carta", "Foil", "Chase",
              "Bulk", "Gamer", "Kevin", "Lucia", "Mateo", "Nerea", "Iker", "Vega", "Pollito", "Mango", "Cheto", "Ripper",
              "Toploader", "Funda", "Brainrot", "Goat", "Ipad", "Nugget", "Patata", "Croqueta", "Fideo", "Tigre", "Ninja",
              "Pepe", "Manolo", "Jaime", "Sara", "Hugo", "Leo", "Alba", "Dani", "Pablo", "Marta", "Ruben", "Ainhoa", "Unai",
              "Gato", "Pato", "Churro", "Tortilla", "Gamba", "Boqueron", "Tostada", "Pixel", "Turbo", "Cohete", "Rayo",
              "Bruma", "Plasma", "Brasa", "Sobrecito", "Mazo", "Binder", "Slab", "Gema", "Dragon", "Lobo", "Zorro",
              "Panda", "Koala", "Waffle", "Taco", "Noodle", "Cookie", "Lemon", "Shadow", "Storm", "Blaze", "Frost" , "Pedro","Perro","ginnaso", "polla" , "ginna" , "sodeagua", "","","€€","",""," "," "," "},
        c = { "TCG", "Hunter", "Lover", "Fan", "King", "Queen", "Master", "Kid", "Boss", "Main", "Rips", "Cards", "Lord", " ",
              "Pro", "YT", "Live", "Plays", "OG", "Prime", "Lol", "XD", "Max", "Jr", "Uwu", "Vibes", "Squad", "sanchez", " "," "," "," "," "," "," "," " },
    },
    colores = { "rojo", "naranja", "amarillo", "lima", "verde", "celeste", "cian", "violeta", "blanco", "grisclaro" },

    -- las frases del chat estan en datos/chat.lua
    textos = require "datos.chat",
}
