-- Encargos: gente que te paga por abrir sobres concretos.
-- Los del movil (app ENCARGOS) duran dias; las peticiones del chat, segundos.
-- El dinero va en centimos. Te quedas las cartas: te pagan por abrirlos.
return {
    movil = {
        -- cada dia, probabilidad de que llegue una oferta (sube con los seguidores)
        prob = 0.55, probPorSeguidor = 0.0002, probMax = 0.9,
        ofertasMax = 3, activosMax = 3,
        sobres = { 1, 4 },            -- cuantos sobres piden
        pago = { 0.15, 0.35 },        -- lo que pagan, en veces el precio de los sobres
        dias = { 3, 6 },              -- plazo para hacerlo
        diasOferta = 2,               -- lo que espera la oferta a que la aceptes
        primera = 0.25,               -- a veces piden que sean de 1ª edicion (pagan x1.5)
        -- clase de encargo y su peso: abrir sobres, enfundar cartas, ponerles top
        -- o sacar cartas de una rareza (cuenta lo que sale desde que lo aceptas)
        clases = { abrir = 6, enfundar = 1.5, top = 1, rareza = 2.5 },
        enfundar = { n = { 5, 12 }, pagoPor = 25 },   -- centimos por carta
        top = { n = { 2, 5 }, pagoPor = 60 },
        -- cuantas piden de cada rareza, plazo y peso; pagan como los de abrir
        -- (pago) por los sobres que hacen falta de media para sacarlas
        rareza = {
            comun       = { n = { 25, 40 }, dias = { 3, 5 }, peso = 0.6 },
            infrecuente = { n = { 12, 20 }, dias = { 3, 5 }, peso = 1 },
            rara        = { n = { 5, 10 }, dias = { 3, 6 }, peso = 1.5 },
            holo        = { n = { 1, 3 }, dias = { 4, 7 }, peso = 1.2 },
            fullart     = { n = { 1, 1 }, dias = { 6, 9 }, peso = 0.6 },
            secreta     = { n = { 1, 1 }, dias = { 8, 12 }, peso = 0.25 },
        },
    },
    chat = {
        -- peticiones por minuto en directo: base + por espectador (con un maximo)
        porMinuto = 0.25, porEspectador = 0.01, maxPorMinuto = 1.5,
        espectadoresMin = 2,
        segundos = 120,               -- tiempo para cumplirla
        pago = { 0.15, 0.4 },         -- en veces el precio del sobre (+ un poco por espectador)
        porEspectador2 = 0.004,
        seguidores = 2,               -- seguidores extra al cumplirla
        tuyos = 0.7,                  -- probabilidad de pedir un sobre que tienes
    },
    textos = {
        es = { "ABRE UN {s}!", "PORFA ABRE UN {s}", "TE PAGO SI ABRES UN {s}", "QUIERO VER UN {s}", "UN {s} PARA MI" },
        en = { "OPEN A {s}!", "PLS OPEN A {s}", "ILL PAY IF YOU OPEN A {s}", "I WANT TO SEE A {s}", "RIP A {s} FOR ME" },
        cumplida = { es = { "W!!", "GRACIAS CRACK", "ESE ERA EL MIO", "TOP" }, en = { "W!!", "THANKS KING", "THATS MY PACK", "GOATED" } },
        caducada = { es = { "bueno nada", "L", "otra vez sera" }, en = { "oh well", "L", "next time" } },
    },
}
