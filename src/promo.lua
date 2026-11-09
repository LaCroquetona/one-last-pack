-- Dibujo de las promos (datos/promos.lua), las colabs, las placas del canal y
-- los sobrecitos promo. Cada estilo segun de donde sale la carta:
-- rayos (ETB y preventa), noche (caja), sin marco (blister y tin), apaisada
-- (torneo; en la carta va de lado). Todo a escala entera y sin que ningun
-- texto se salga (promo.cortes apunta los que no caben, para las pruebas).
local p = require "datos.paleta"
local datos = require "datos.promos"
local elementos = require "datos.elementos"
local sets = require "datos.sets"
local fuentes = require "src.fuentes"
local bicho = require "src.bicho"

local lg = love.graphics
local promo = { cortes = {} }

local W, H = 36, 50        -- carta normal
local AW, AH = 50, 36      -- apaisada (torneo y placas del canal)
local ORO, PLATA = datos.ORO, datos.PLATA
local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local function col(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local function R(c, x, y, w, h, a) col(c, a) lg.rectangle("fill", x, y, w, h) end
local function L(c, x, y, w, h, a) col(c, a) lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1) end
local function texto(s, x, y, c, al, w) fuentes.texto(s, x, y, 1, c or p.blanco, al, w) end

-- texto que tiene que caber en w
local function cabe(s, x, y, c, w, al, que)
    if fuentes.ancho(s) > w then table.insert(promo.cortes, (que or "") .. " " .. s) end
    fuentes.texto(s, x, y, 1, c, al or "center", w)
end

-- un lienzo pintado fuera de lo que se este dibujando (se puede pedir a mitad de un frame)
local function lienzo(w, h, f)
    local cv = lg.newCanvas(w, h)
    cv:setFilter("nearest", "nearest")
    lg.push("all")
    lg.origin()
    lg.setShader()
    lg.setCanvas(cv)
    lg.clear(0, 0, 0, 0)
    f()
    lg.pop()
    return cv
end

-- un fondo pixel a pixel (se guarda: muchos se repiten de un set a otro)
local patrones = {}
local function patron(clave, w, h, f)
    if patrones[clave] then return patrones[clave] end
    local d = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local c = f(x, y)
            if c then d:setPixel(x, y, c[1], c[2], c[3], 1) end
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    patrones[clave] = img
    return img
end

local function clave(...)
    local t = {}
    for _, c in ipairs({ ... }) do
        if type(c) == "table" then table.insert(t, string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3])) else table.insert(t, tostring(c)) end
    end
    return table.concat(t, "|")
end

local function estrella(x, y)
    R(p.negro, x - 4, y - 1, 9, 3) R(p.negro, x - 1, y - 4, 3, 9) R(p.negro, x - 3, y - 3, 7, 7)
    R(ORO, x - 3, y, 7, 1) R(ORO, x, y - 3, 1, 7) R(p.amarillo, x - 2, y - 2, 5, 5)
    R(p.naranja, x, y, 1, 1)
end

local function etiqueta(s, x, y, c)
    local w = fuentes.ancho(s) + 3
    R(p.negro, x, y, w, 7)
    texto(s, x + 2, y + 1, c or p.amarillo)
end

-- filo: dorado solo en las exclusivas
local function filo(x, y, w, h, oro)
    L(p.negro, x, y, w, h)
    L(oro and ORO or PLATA, x + 1, y + 1, w - 2, h - 2)
    if oro then R(p.amarillo, x + 2, y + 1, 4, 1) end
end

-- el bicho de su carta del set (22x22), con contorno si se pide
local bichos = {}
local function bich(def, x, y, contorno)
    local img = bichos[def.semilla]
    if not img then
        img = bicho.crear(def.semilla, 22, 22, elementos[def.elemento])
        bichos[def.semilla] = img
    end
    if contorno then
        col(contorno)
        for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do lg.draw(img, x + d[1], y + d[2]) end
    end
    lg.setColor(1, 1, 1)
    lg.draw(img, x, y)
end

local function nombre(def) return def.nombre:upper() end

-- A. RAYOS (ETB y preventa): rayos de colores detras del bicho, numero dentro
-- del dibujo y el nombre en banda negra
local function rayos(def)
    local c1, c2 = def.colores[1], def.colores[2]
    local fondo = patron(clave("rayos", c1, c2), W, 36, function(x, y)
        local a = math.atan2(y - 20, x - 17)
        return (math.floor((a + math.pi) / (math.pi / 8)) % 2 == 0) and c1 or c2
    end)
    lg.setColor(1, 1, 1)
    lg.draw(fondo, 0, 0)
    R(p.negro, 0, 36, W, H - 36)
    filo(0, 0, W, H, def.oro)
    bich(def, 7, 5, p.negro)
    estrella(W - 7, 29)
    etiqueta(def.codigo, 3, 27)
    cabe(nombre(def), 2, 40, def.oro and ORO or p.blanco, W - 4, nil, "rayos")
end

-- B. NOCHE (caja): negra con estrellas y el bicho con aura
local function noche(def)
    R(p.negro, 0, 0, W, H)
    local rng = love.math.newRandomGenerator(def.deCarta or def.id)
    for _ = 1, 22 do R(rng:random() < 0.3 and ORO or p.gris, rng:random(3, W - 4), rng:random(3, 31), 1, 1) end
    for _, s in ipairs({ { 6, 8 }, { 30, 26 } }) do R(p.blanco, s[1] - 1, s[2], 3, 1) R(p.blanco, s[1], s[2] - 1, 1, 3) end
    bich(def, 7, 6, def.colores[1])
    filo(0, 0, W, H, def.oro)
    estrella(W - 7, 7)
    cabe(nombre(def), 2, 32, def.oro and ORO or p.blanco, W - 4, nil, "noche")
    R(def.oro and ORO or p.gris, 6, 38, W - 12, 1)
    etiqueta(def.codigo, 2, H - 9)
end

-- C. APAISADA (torneo): cielo y suelo, el nombre arriba a la izquierda
local function apaisada(def)
    local c = def.colores
    local fondo = patron(clave("apaisada", c[1], c[2], c[3], c[4]), AW, AH, function(x, y)
        if y > 25 then return ((x + y) % 5 == 0) and c[4] or c[3] end
        return (y / 25 * 16 > BAYER[y % 4 + 1][x % 4 + 1] + 0.5) and c[2] or c[1]
    end)
    lg.setColor(1, 1, 1)
    lg.draw(fondo, 0, 0)
    bich(def, 25, 10)
    filo(0, 0, AW, AH, def.oro)
    -- el nombre no puede llegar a la estrella de la esquina
    local nw = fuentes.ancho(nombre(def)) + 4
    if nw > AW - 13 then table.insert(promo.cortes, "apaisada " .. nombre(def)) end
    R(p.negro, 2, 2, nw, 7) texto(nombre(def), 4, 3, p.amarillo)
    estrella(AW - 7, 7)
    etiqueta(def.codigo, 2, AH - 9)
end

-- D. SIN MARCO (blister y tin): todo dibujo, el nombre de lado. Con w y h
-- es la misma carta mas pequeña (la que se ve en el plastico del blister):
-- el nombre que no cabe se corta
local function sinMarco(def, w, h)
    w, h = w or W, h or H
    local c1, c2, c3 = def.colores[1], def.colores[2], def.colores[3]
    local fondo = patron(clave("sinmarco", w, h, c1, c2, c3), w, h, function(x, y)
        if (x + y) % 14 < 2 then return c3 end
        return (y / h * 16 > BAYER[y % 4 + 1][x % 4 + 1] + 0.5) and c2 or c1
    end)
    lg.setColor(1, 1, 1)
    lg.draw(fondo, 0, 0)
    bich(def, math.max(8, w - 26), math.floor(h / 2) - 13)
    local n = nombre(def)
    local cabeN = w == W and h - 14 or h - 5
    if fuentes.ancho(n) > cabeN then
        if w == W then table.insert(promo.cortes, "sin marco " .. n) end
        while #n > 1 and fuentes.ancho(n) > cabeN do n = n:sub(1, -2) end
    end
    R(p.negro, 1, 1, 7, fuentes.ancho(n) + 4)
    lg.push() lg.translate(3, fuentes.ancho(n) + 3) lg.rotate(-math.pi / 2)
    texto(n, 0, 0, p.blanco) lg.pop()
    filo(0, 0, w, h, def.oro)
    estrella(w - 7, 7)
    etiqueta(def.codigo, w - fuentes.ancho(def.codigo) - 5, h - 9)
end

-- colab: marca de broma arriba y COLAB abajo (el numero va en la ficha)
local function colab(def)
    local c1, c2, c3 = def.colores[1], def.colores[2], def.colores[3]
    R(c1, 0, 0, W, H)
    local fondo = patron(clave("colab", c2), W, H - 19, function(x, y) if (x + y * 2) % 10 < 2 then return c2 end end)
    lg.setColor(1, 1, 1)
    lg.draw(fondo, 0, 9)
    R(c2, 0, 0, W, 9)
    cabe(def.marca, 1, 2, c3, W - 2, nil, "colab")
    bich(def, 7, 12)
    R(p.negro, 0, H - 10, W, 10)
    texto("COLAB", 0, H - 8, p.amarillo, "center", W)
    L(p.negro, 0, 0, W, H)
end

local PINTAR = { rayos = rayos, noche = noche, sinmarco = sinMarco, colab = colab }

-- la cara de una promo a 36x50 (la apaisada y la placa del canal, de lado)
function promo.cara(def, canal)
    if def.estilo == "placa" then
        local ancha = promo.placa(def.nivel, canal)
        return lienzo(W, H, function()
            lg.setColor(1, 1, 1)
            lg.draw(ancha, W, 0, math.pi / 2)
        end)
    end
    if def.estilo == "apaisada" then
        local ancha = lienzo(AW, AH, function() apaisada(def) end)
        return lienzo(W, H, function()
            lg.setColor(1, 1, 1)
            lg.draw(ancha, W, 0, math.pi / 2)
        end)
    end
    return lienzo(W, H, function() PINTAR[def.estilo](def) end)
end

-- placa del canal (nivel de datos.canal): apaisada con el nombre en dos lineas
function promo.placa(nivel, canal)
    local d = datos.canal[nivel]
    local c1, c2 = d.c1, d.c2
    return lienzo(AW, AH, function()
        local fondo = patron(clave("placa", c1, c2), AW, AH, function(x, y) return (((x * 2 + y) % 26) < 3) and c2 or c1 end)
        lg.setColor(1, 1, 1)
        lg.draw(fondo, 0, 0)
        R(p.negro, 2, 2, AW - 4, 8)
        texto("OLP", 4, 3, c2)
        cabe(d.cifra, 14, 3, p.blanco, AW - 18, "right", "canal")
        R(p.negro, 2, 11, AW - 4, 15, 0.85)
        local n = (canal or ""):upper()
        local l1, l2 = n, ""
        if #n > 10 then
            local corte = 10
            for i = 10, 4, -1 do
                local ch = n:sub(i, i)
                if ch == "_" or ch == " " then corte = i break end
            end
            l1, l2 = n:sub(1, corte):gsub("[_ ]$", ""), n:sub(corte + 1, corte + 10)
        end
        cabe(l1, 2, l2 == "" and 16 or 13, c2, AW - 4, nil, "canal")
        if l2 ~= "" then cabe(l2, 2, 19, c2, AW - 4, nil, "canal") end
        R(p.negro, 2, 27, AW - 4, 7)
        texto(d.nombre, 0, 28, c2, "center", AW)
        L(p.negro, 0, 0, AW, AH)
        L(c2, 1, 1, AW - 2, AH - 2)
    end)
end

-- sobrecito promo (de la ETB, de la caja o de torneo), del tamaño de un sobre
-- dientes de cierre arriba y abajo de un sobre (en x0..x0+w)
local function dientes(c, x0, y0, w, h)
    for x = 0, w - 1 do
        local d = x % 2
        R(c, x0 + x, y0 + d, 1, 3 - d)
        R(c, x0 + x, y0 + h - 3, 1, 3 - d)
    end
end

-- Sobrecitos promo: del tamaño de un sobre (w x h) y distintos segun de donde
-- salen. C: colores del sobre del set.
--   etb:  del color del set con franjas doradas en diagonal y etiqueta PROMO
--   caja: negro con estrellas, rombo dorado y PROMO en dorado
-- Torneo: sobre entero azul con la copa. Correo: sobre acolchado de papel
-- con el sello de One Last Pack (las placas del canal).
function promo.pintarSobre(origen, set, w, h, C)
    local codigo = sets[set] and sets[set].codigo or ""
    local cx = math.floor(w / 2)
    if origen == "etb" then
        dientes(PLATA, 0, 0, w, h)
        R(C.base, 0, 3, w, h - 6)
        for y = 0, h - 7 do
            for x = 0, w - 1 do
                local k = (x + y) % 11
                if k < 2 then R(ORO, x, 3 + y, 1, 1) elseif k == 2 then R(p.amarillo, x, 3 + y, 1, 1, 0.6) end
            end
        end
        R(C.borde, 0, 3, 1, h - 6) R(C.borde, w - 1, 3, 1, h - 6)
        -- estrella grande con su halo
        R(p.negro, cx - 7, 7, 15, 15, 0.35)
        estrella(cx, 14)
        R(p.negro, 0, 24, w, 9) R(p.blanco, 1, 25, w - 2, 7)
        texto("PROMO", 0, 26, p.negro, "center", w)
        R(p.negro, 5, 34, w - 10, 6)
        texto(codigo, 0, 34, C.letras, "center", w)
    elseif origen == "caja" then
        dientes(ORO, 0, 0, w, h)
        R(p.negro, 0, 3, w, h - 6)
        local rng = love.math.newRandomGenerator(#codigo * 31 + 7)
        for _ = 1, 24 do R(rng:random() < 0.4 and ORO or p.gris, rng:random(1, w - 2), rng:random(4, h - 5), 1, 1) end
        R(ORO, 0, 3, 1, h - 6) R(ORO, w - 1, 3, 1, h - 6)
        local cy = 14
        for dy = -7, 7 do
            local a = 7 - math.abs(dy)
            R(ORO, cx - a, cy + dy, a * 2 + 1, 1)
            if a > 1 then R(C.base, cx - a + 2, cy + dy, (a - 2) * 2 + 1, 1) end
        end
        R(p.amarillo, cx, cy - 7, 1, 1)
        texto("PROMO", 0, 25, ORO, "center", w)
        R(ORO, 3, 31, w - 6, 1)
        texto(codigo, 0, 34, p.blanco, "center", w)
    elseif origen == "correo" then
        -- sobre acolchado de papel (de pie, del tamaño de un sobre)
        local K, KO = { 0.80, 0.64, 0.42 }, { 0.62, 0.46, 0.28 }
        R(KO, 0, 1, w, h - 1)
        R(K, 1, 2, w - 2, h - 3)
        for y = 2, h - 2, 3 do for x = 1 + y % 2, w - 2, 4 do R(KO, x, y, 1, 1, 0.5) end end
        -- solapa de arriba y el sello
        R(KO, 1, 7, w - 2, 1)
        R(p.rojo, w - 15, 9, 13, 10) R(p.blanco, w - 14, 10, 11, 8)
        texto("OLP", w - 15, 12, p.rojo, "center", 13)
        estrella(7, 14)
        R(p.blanco, 3, 24, w - 6, 13) L(KO, 3, 24, w - 6, 13)
        texto("PARA", 3, 26, p.gris, "center", w - 6)
        texto("TI", 3, 32, p.negro, "center", w - 6)
    else
        -- torneo: sobre entero, azul con la copa
        dientes(p.grisclaro, 0, 0, w, h)
        R(p.azulosc, 0, 3, w, h - 6)
        for y = 3, h - 4 do for x = 0, w - 1 do if (x * 2 + y) % 9 == 0 then R(p.cian, x, y, 1, 1, 0.5) end end end
        R(p.cian, 0, 3, 1, h - 6) R(p.cian, w - 1, 3, 1, h - 6)
        R(p.amarillo, cx - 5, 9, 11, 6) R(p.amarillo, cx - 4, 15, 9, 1) R(p.amarillo, cx - 3, 16, 7, 1)
        R(p.amarillo, cx - 1, 17, 3, 3) R(p.amarillo, cx - 4, 20, 9, 2)
        R(p.amarillo, cx - 7, 10, 2, 3) R(p.amarillo, cx + 6, 10, 2, 3)
        R(p.blanco, cx - 3, 10, 1, 3)
        R(p.negro, 0, 24, w, 8)
        texto("TORNEO", 0, 26, p.cian, "center", w)
        R(p.negro, 0, 33, w, 7)
        texto(codigo, 0, 34, p.blanco, "center", w)
    end
end

-- la promo en pequeño (20x28) para enseñarla en el blister: su fondo, el
-- la promo del blister en pequeño (28x39), igual que la carta
local minis = {}
promo.MINI = { W = 28, H = 39 }
function promo.mini(def)
    if minis[def.id] then return minis[def.id] end
    local cv = lienzo(promo.MINI.W, promo.MINI.H, function() sinMarco(def, promo.MINI.W, promo.MINI.H) end)
    minis[def.id] = cv
    return cv
end

return promo
