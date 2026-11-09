-- Emojis de pixel que suben por el chat del directo cuando sale algo bueno
-- (o muy malo). Cada uno es un dibujo pequeño (7x7 o 9x9); los de texto se escriben.
-- Todos son nuestros: nada de emotes de otros (ni caras de streamers).
local p = require "datos.paleta"
local fuentes = require "src.fuentes"

local lg = love.graphics

local emojis = {}

local COLORES = { r = p.rojo, o = p.naranja, y = p.amarillo, w = p.blanco, k = p.negro, g = p.verde, l = p.lima, c = p.cian,
    v = p.violeta, b = p.celeste, a = p.azul }

local DIBUJOS = {
    corazon = { ".rr.rr.", "rwrrrrr", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..." },
    fuego = { "...o...", "..oo.o.", ".ooooo.", ".oyyoo.", "oyyyyro", "oyyyyro", ".orrro." },
    calavera = { ".wwwww.", "wwwwwww", "wkkwkkw", "wkkwkkw", "wwwkwww", ".wwwww.", ".w.w.w." },
    ojos = { ".......", "www.www", "wkw.wkw", "wkw.wkw", "www.www", ".......", "......." },
    estrella = { "...y...", "..yyy..", "yyyyyyy", ".yyyyy.", "..yyy..", ".yy.yy.", "y.....y" },
    moneda = { "..yyy..", ".yoooy.", "yoyyyoy", "yoyoyoy", "yoyyyoy", ".yoooy.", "..yyy.." },
    corona = { "y..y..y", "yy.y.yy", "yyyyyyy", "yrycyry", "yyyyyyy", ".......", "......." },
    -- la rana del canal
    rana = { ".ggg.ggg.", "gwkwgwkwg", "gwwwgwwwg", "ggggggggg", "grgggggrg", "ggkkkkkgg", ".ggggggg.", "..lllll.." },
    -- cara de flipar con la boca abierta
    flipa = { "..yyyyy..", ".yyyyyyy.", "yykyyykyy", "yykyyykyy", "yyyyyyyyy", "yyykkkyyy", "yyykrkyyy", ".yykkkyy.", "..yyyyy.." },
    -- llorando de risa
    risa = { "..yyyyy..", ".yyyyyyy.", "ykkyyykky", "byyyyyyyb", "byyyyyyyb", "bkkkkkkkb", "ykwwwwwky", ".ykkkkky.", "..yyyyy.." },
    payaso = { ".rr...rr.", "rrwwwwwrr", "rwkwwwkwr", ".wwwwwww.", ".wwwrwww.", ".wrwwwrw.", ".wwrrrww.", "..wwwww.." },
    diamante = { ".bcccb.", "bcwccwb", "bcccccb", ".bcccb.", "..bcb..", "...b...", "......." },
    cohete = { ".....ww", "....wcw", "...www.", ".awww..", ".www...", "oow....", "yo....." },
    stonks = { "k......", "k.....l", "k....l.", "k.l.l..", "kl.l...", "k......", "kkkkkkk" },
    llora = { "..yyyyy..", ".yyyyyyy.", "yykyyykyy", "ybyyyyyby", "ybyyyyyby", "yyykkkyyy", "yykyyykyy", ".yyyyyyy.", "..yyyyy.." },
    gafas = { "..yyyyy..", ".yyyyyyy.", "kkkkkkkkk", "ykkkykkky", "yykyyykyy", "yyyyyyyyy", "yykyyykyy", ".yykkkyy.", "..yyyyy.." },
    sobre = { "wwwwwww", "rrrrrrr", "rwrwrwr", "rrrrrrr", "rryyyrr", "rryoyrr", "rryyyrr", "rrrrrrr", "wwwwwww" },
    carta = { "yyyyyyy", "ycccccy", "ycbbbcy", "ycbwbcy", "ycccccy", "ywwwwwy", "ywkkkwy", "ywwwwwy", "yyyyyyy" },
    trofeo = { "y.yyy.y", "yyyyyyy", ".yyyyy.", "..yyy..", "...y...", "..yyy..", ".ooooo." },
    rayo = { "....yy.", "...yy..", "..yy...", ".yyyyy.", "...yy..", "..yy...", ".yy...." },
    billete = { "ggggggggg", "glllllllg", "gllgggllg", "glllllllg", "ggggggggg" },
    pulgar = { "...y...", "..yy...", "..yy...", "yyyyyy.", "yyyyyyy", "yyyyyy.", "yyyyy.." },
    abajo = { "yyyyy..", "yyyyyy.", "yyyyyyy", "yyyyyy.", "..yy...", "..yy...", "...y..." },
    manos = { "...w...", "..www..", "..www..", ".wwwww.", ".wwwww.", "wwwwwww", ".w...w." },
    dado = { "wwwwwww", "wkwwwkw", "wwwwwww", "wwwkwww", "wwwwwww", "wkwwwkw", "wwwwwww" },
    bomba = { "....o.y", "...k...", "..kkk..", ".kkkkk.", ".kwkkk.", ".kkkkk.", "..kkk.." },
    cerebro = { ".vvvvv.", "vvwvvvv", "vvvvwvv", "vwvvvvv", "vvvvvwv", ".vvvvv.", "..v.v.." },
    -- los de la jerga de los chats de aqui
    palomitas = { ".w.w.w.", "wwywwyw", "wywwwyw", "rwrwrwr", "rwrwrwr", ".rwrwr.", ".rwrwr." },
    claqueta = { "kwkwkwk", "wkwkwkw", "kkkkkkk", "kwwwwwk", "kwkkkwk", "kwwwwwk", "kkkkkkk" },
    chancla = { "..aaa..", ".abbba.", ".abwba.", ".abbba.", ".abbba.", ".abbba.", "..aaa.." },
    tortilla = { ".ooooo.", "oyyoyyo", "oyyyyoy", "oyoyyyo", "oyyyoyo", ".ooooo.", "......." },
    musculo = { "..yy...", ".yyyy..", ".y.yy..", "...yyy.", "..yyyyy", ".yyyyyy", "..yyyy." },
    enfado = { "..rrrrr..", ".rrrrrrr.", "rkrrrrrkr", "rrkrrrkrr", "rrrrrrrrr", "rrrkkkrrr", "rrkrrrkrr", ".rrrrrrr.", "..rrrrr.." },
    mueca = { "..yyyyy..", ".yyyyyyy.", "yykyyykyy", "yykyyykyy", "yyyyyyyyy", "ykykykyky", "yykykykyy", ".yyyyyyy.", "..yyyyy.." },
    dormido = { "..yyyyy.w", ".yyyyyyy.", "yyyyyyyyy", "ykkyyykky", "yyyyyyyyy", "yyyyyyyyy", "yyyykyyyy", ".yyyyyyy.", "..yyyyy.." },
    sudor = { "..yyyyy..", ".yyyyyyb.", "yykyyykbb", "yykyyykbb", "yyyyyyyyy", "yyyyyyyyy", "yykkkkkyy", ".yyyyyyy.", "..yyyyy.." },
    guino = { "..yyyyy..", ".yyyyyyy.", "yykyyyyyy", "yykyykkky", "yyyyyyyyy", "ykyyyyyky", "yykkkkkyy", ".yyyyyyy.", "..yyyyy.." },
    hola = { ".y.y.y.", ".y.y.y.", ".yyyyyy", "yyyyyyy", ".yyyyy.", "..yyy..", "..yyy.." },
    pizza = { "ooooooo", ".ryyry.", ".yyyyy.", "..ryr..", "..yyy..", "...y...", "......." },
    roto = { ".rr.rr.", "rrrkrrr", "rrk.rrr", ".rrk.r.", "..rkr..", "...r...", "......." },
    cebolla = { "...g...", "..vwv..", ".vwvwv.", "vwvwvwv", "vwvwvwv", ".vwvwv.", "..vvv.." },
    bocata = { "..ooo..", ".ooooo.", "rgrrrgr", "yyyyyyy", ".ooooo.", "......." },
    gato = { "w.....w", "ww...ww", "wwwwwww", "wgwwwgw", "wwwwwww", "wwwrwww", ".wwwww." },
    perro = { "o.....o", "oo...oo", "ooooooo", "okoooko", "ooooooo", "oookooo", ".oorroo" },
    lupa = { ".www...", "wcwcw..", "wcccw..", "wcccw..", ".wwwo..", "....oo.", ".....oo" },
    reloj = { ".kkkkk.", "kwwkwwk", "kwwkwwk", "kwwkkwk", "kwwwwwk", "kwwwwwk", ".kkkkk." },
    regalo = { "..r.r..", "...r...", "yyyryyy", "yyyryyy", "rrrrrrr", "yyyryyy", "yyyryyy" },
    ancla = { "...b...", "..bwb..", "...b...", "bbbbbbb", "...b...", "b..b..b", ".bbbbb." },
    globo = { ".rrr...", "rrwrr..", "rrrrr..", "rrrrr..", ".rrr...", "..r....", "...r..." },
    pato = { "..yy...", ".yyky..", "..yyoo.", "..yy...", "yyyyy..", ".yyyy..", "..oo..." },
}
local TEXTOS = { ["67"] = p.lima, W = p.cian, GG = p.amarillo, L = p.rojo, OMG = p.violeta, POG = p.lima, ["100"] = p.rojo,
    F = p.blanco, RIP = p.grisclaro, EZ = p.lima, GL = p.cian, ZZZ = p.celeste, ["?!"] = p.naranja,
    XD = p.amarillo, OLE = p.rojo, ILLO = p.naranja, UFF = p.celeste, ["+1"] = p.lima, TOP = p.lima, GOD = p.amarillo,
    CLIP = p.violeta, YOLO = p.naranja, OP = p.rojo, BRB = p.grisclaro, AFK = p.grisclaro }

-- emotes de Twitch (y palabras sueltas) que se cambian por los nuestros en el
-- chat real; en minusculas
local DE_TWITCH = {
    lul = "risa", kekw = "risa", lmao = "risa", omegalul = "risa", ["4head"] = "risa", lol = "risa", xd = "risa",
    pogchamp = "flipa", pog = "flipa", poggers = "flipa", pogu = "flipa", notlikethis = "flipa", wow = "flipa",
    ["<3"] = "corazon", kappa = "payaso", pepega = "payaso", clown = "payaso",
    biblethump = "llora", sadge = "llora", pepehands = "llora", feelsbadman = "llora",
    monkas = "ojos", residentsleeper = "ZZZ", ez = "EZ", gg = "GG", w = "W", l = "L", f = "F", rip = "RIP",
    kreygasm = "fuego", fire = "fuego", hypers = "cohete", catjam = "rana", stonks = "stonks", ["67"] = "67",
    ["6-7"] = "67", gl = "GL", coolcat = "gafas", ["b)"] = "gafas", ["8)"] = "gafas",
    clip = "claqueta", salseo = "palomitas", illo = "ILLO", quillo = "ILLO", ole = "OLE", uff = "UFF", yolo = "YOLO",
    tilt = "enfado", mald = "enfado", malding = "enfado", cringe = "mueca", chetado = "musculo", chetada = "musculo",
    afk = "AFK", brb = "BRB", mimir = "dormido", op = "OP", ["+1"] = "+1",
}

-- lo mismo para el chat del juego: las palabras mas tipicas de los chats de
-- aqui pasan a ser emojis nuestros (en minusculas y sin signos)
local DE_CHAT = {
    xd = "XD", xdd = "XD", xddd = "XD", jaja = "risa", jajaja = "risa", jajajaja = "risa", f = "F", gg = "GG", ez = "EZ",
    pog = "POG", poggers = "POG", sadge = "llora", kappa = "payaso", kreygasm = "fuego", clip = "claqueta", clipealo = "claqueta",
    salseo = "palomitas", illo = "ILLO", quillo = "ILLO", ole = "OLE", uff = "UFF", tilt = "enfado", tilteado = "enfado",
    mald = "enfado", malding = "enfado", cringe = "mueca", chetado = "musculo", chetada = "musculo", chetadisima = "musculo",
    chetadisimo = "musculo", mimir = "dormido", yolo = "YOLO", w = "W", l = "L", afk = "AFK", brb = "BRB", aura = "estrella",
    fuego = "fuego", bulk = "calavera", rip = "RIP", top = "TOP", god = "GOD", omg = "OMG", cine = "claqueta",
}

local imagenes = {}
local function imagen(k)
    if imagenes[k] then return imagenes[k] end
    local dibujo = DIBUJOS[k]
    local d = love.image.newImageData(#dibujo[1], #dibujo)
    for y, fila in ipairs(dibujo) do
        for x = 1, #fila do
            local col = COLORES[fila:sub(x, x)]
            if col then d:setPixel(x - 1, y - 1, col[1], col[2], col[3], 1) end
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    imagenes[k] = img
    return img
end

-- pinta un emoji en (x, y) a escala e (para los que van dentro del chat)
function emojis.pintar(k, x, y, e, a)
    e = e or 1
    if TEXTOS[k] then
        local c = TEXTOS[k]
        fuentes.texto(k, x, y + 1, e, { c[1], c[2], c[3], a or 1 })
    elseif DIBUJOS[k] then
        lg.setColor(1, 1, 1, a or 1)
        lg.draw(imagen(k), x, y, 0, e, e)
    end
end

-- lo que ocupa a lo ancho (escala 1)
function emojis.ancho(k)
    if TEXTOS[k] then return fuentes.ancho(k) end
    return DIBUJOS[k] and #DIBUJOS[k][1] or 0
end

function emojis.existe(k)
    return TEXTOS[k] ~= nil or DIBUJOS[k] ~= nil
end

-- separa un mensaje del chat real: devuelve el texto sin los emotes que
-- conocemos y la lista de emojis nuestros que les tocan (como mucho 6)
function emojis.deTwitch(texto)
    local lista, resto = {}, {}
    for palabra in texto:gmatch("%S+") do
        local k = DE_TWITCH[palabra:lower()]
        if k then
            if #lista < 6 then table.insert(lista, k) end
        else
            table.insert(resto, palabra)
        end
    end
    return table.concat(resto, " "), lista
end

-- un mensaje del chat del juego: el texto sin las palabras que pasan a emoji
-- y esos emojis (como mucho 4). Las que van repetidas se quedan en uno
function emojis.deChat(texto)
    local lista, resto, vistos = {}, {}, {}
    for palabra in texto:gmatch("%S+") do
        local limpia = palabra:lower():gsub("[%.,!%?¡¿:]", "")
        local k = DE_CHAT[limpia]
        if k and #lista < 4 then
            if not vistos[k] then table.insert(lista, k) end
            vistos[k] = true
        else
            table.insert(resto, palabra)
        end
    end
    return table.concat(resto, " "), lista
end

-- todos los emojis (para las pruebas y para lanzar al azar)
function emojis.todos()
    local l = {}
    for k in pairs(DIBUJOS) do table.insert(l, k) end
    for k in pairs(TEXTOS) do table.insert(l, k) end
    table.sort(l)
    return l
end

local vivos = {}
local VIDA = 2.4

-- tipos: lista de nombres; n: cuantos; durante: segundos en que van saliendo
function emojis.lanzar(tipos, n, durante)
    for _ = 1, math.min(n, 24 - #vivos) do
        table.insert(vivos, { k = tipos[love.math.random(#tipos)], t = -love.math.random() * (durante or 1),
                              x = 0.5 + love.math.random() * 0.36, fase = love.math.random() * 6 })
    end
end

function emojis.update(dt)
    for i = #vivos, 1, -1 do
        local e = vivos[i]
        e.t = e.t + dt
        if e.t > VIDA then table.remove(vivos, i) end
    end
end

function emojis.limpiar()
    vivos = {}
end

-- suben desde abajo a la derecha del chat (x, y, w, h)
function emojis.dibujar(x, y, w, h)
    for _, e in ipairs(vivos) do
        if e.t >= 0 then
            local q = e.t / VIDA
            local ex = math.floor(x + w * e.x + math.sin(e.t * 3 + e.fase) * 4)
            local ey = math.floor(y + h - 16 - q * (h - 40))
            local a = q > 0.75 and (1 - q) / 0.25 or 1
            if TEXTOS[e.k] then
                local c = TEXTOS[e.k]
                fuentes.texto(e.k, ex, ey + 2, 2, { c[1], c[2], c[3], a })
            else
                lg.setColor(1, 1, 1, a)
                lg.draw(imagen(e.k), ex, ey, 0, 2, 2)
            end
        end
    end
    lg.setColor(1, 1, 1)
end

return emojis
