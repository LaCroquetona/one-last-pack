-- Directos: cuanta gente te ve, cuando te siguen, cuando dan propinas y lo
-- que dice el chat. El dinero va en centimos.
-- Las frases del chat estan en datos/chat.lua.
return {
    -- espectadores segun tus seguidores: base + raiz(seguidores) * raiz + seguidores * lineal
    -- (0 seguidores: 0-1; 30: unos 5; 400: unos 26; 2.000: unos 80)
    espectadores = { base = 0.5, raiz = 0.9, lineal = 0.02, ruido = 0.25 },
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
    },

    -- propinas: cada espectador puede dar una al acabar un sobre (prob), y
    -- al salir una carta buena (prob x lo de su rareza)
    propinas = {
        prob = 0.012,
        rareza = { holo = 3, fullart = 8, secreta = 20 },
        chase = 12, godpack = 40,
        -- cuanto dan: {minimo, maximo, peso, espectadores que hacen falta}
        -- (las propinas gordas solo llegan a canales con gente)
        cantidades = { { 20, 60, 65, 0 }, { 60, 150, 27, 5 }, { 150, 400, 7, 25 }, { 400, 1000, 1, 60 } },
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
        porMinuto = 1.0, porEspectador = 0.1, maxPorMinuto = 4, espectadoresMin = 1,
        max = 3, segundos = 90,
        margen = { 1.08, 1.22 }, margenPorEspectador = 0.0025, margenMax = 0.15,
        -- seguidores extra si al comprador le toca algo bueno (holo o mejor)
        seguidoresSuerte = 3,
        textos = {
            es = { compra = { "me pillo un {s}", "VENDEME UN {s}", "quiero un {s} pls", "un {s} para mi", "abreme un {s} que lo pago",
                              "yo compro un {s}", "{s} para el menda", "me llevo un {s} bro", "pago un {s} pa ver que sale", "un {s} y que salga la chase" },
                   bien = { "LETS GOOO QUE ES MIO", "NO PUEDE SER MI CARTAAA", "GOAT GOAT GOAT", "vale esto ya lo pago", "MADRE MIA QUE SUERTE", "te compro otro ya" },
                   mal = { "bueno otra vez sera", "L tremenda", "todo bulk bro", "mi cartera llora", "ni una rara jajaja", "el siguiente sale fijo" },
                   caducada = { "bueno me voy que tardas", "se me ha quitado la gana", "otro dia lo compro" } },
            en = { compra = { "ill buy a {s}", "SELL ME A {s}", "one {s} for me pls", "open a {s} for me", "taking a {s}",
                              "i want a {s}", "{s} please", "ill pay for a {s}", "one {s} lets go", "{s} for me bro" },
                   bien = { "LETS GOOO ITS MINE", "NO WAY MY CARD", "GOATED PULL", "worth every cent", "INSANE LUCK", "buying another one" },
                   mal = { "unlucky", "massive L", "all bulk bro", "my wallet is crying", "not even a rare lol", "next one hits for sure" },
                   caducada = { "too slow im out", "nvm", "maybe next stream" } },
        },
    },

    -- tipos de directo
    tipos = {
        { id = "apertura", nombre = "APERTURA" },
        { id = "venta", nombre = "VENTA DE SOBRES" },
        { id = "evaluacion", nombre = "EVALUACIÓN", proximamente = true },
        { id = "coleccion", nombre = "COLECCIÓN", proximamente = true },
    },

    -- nombres del chat: trozo + trozo (+ numero a veces)
    nombres = {
        a = { "xX", "el", "la", "mr", "don", "lil", "big", "pro", "sir", "mini", "super", "the", "real", "not", "tito", "abuelo",
              "doña", "mega", "ultra", "baby", "tia", "profe", "capi", "dr", "miss", "uncle", "its", "just", "yo_soy" },
        b = { "Sobrero", "Pakito", "Holo", "Rizz", "Skibidi", "Sigma", "Aura", "Bicho", "Pack", "Carta", "Foil", "Chase",
              "Bulk", "Gamer", "Kevin", "Lucia", "Mateo", "Nerea", "Iker", "Vega", "Pollito", "Mango", "Cheto", "Ripper",
              "Toploader", "Funda", "Brainrot", "Goat", "Ipad", "Nugget", "Patata", "Croqueta", "Fideo", "Tigre", "Ninja",
              "Pepe", "Manolo", "Jaime", "Sara", "Hugo", "Leo", "Alba", "Dani", "Pablo", "Marta", "Ruben", "Ainhoa", "Unai",
              "Gato", "Pato", "Churro", "Tortilla", "Gamba", "Boqueron", "Tostada", "Pixel", "Turbo", "Cohete", "Rayo",
              "Bruma", "Plasma", "Brasa", "Sobrecito", "Mazo", "Binder", "Slab", "Gema", "Dragon", "Lobo", "Zorro",
              "Panda", "Koala", "Waffle", "Taco", "Noodle", "Cookie", "Lemon", "Shadow", "Storm", "Blaze", "Frost" },
        c = { "TCG", "Hunter", "Lover", "Fan", "King", "Queen", "Master", "Kid", "Boss", "Main", "Rips", "Cards", "Lord", "",
              "Pro", "YT", "Live", "Plays", "OG", "Prime", "Lol", "XD", "Max", "Jr", "Uwu", "Vibes", "Squad", "" },
    },
    colores = { "rojo", "naranja", "amarillo", "lima", "verde", "celeste", "cian", "violeta", "blanco", "grisclaro" },

    -- las frases del chat estan en datos/chat.lua
    textos = require "datos.chat",
}
