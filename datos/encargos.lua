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
