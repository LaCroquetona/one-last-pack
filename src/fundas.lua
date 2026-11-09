-- Dibujo de las fundas con diseno: el dorso de cada una en un lienzo de
-- 38x52 (el tamano de la funda) que se prepara la primera vez que hace falta.
-- Los nombres, colores y de donde sale cada una estan en datos/fundas.lua.
local p = require "datos.paleta"
local sobres = require "datos.sobres"
local cartas = require "datos.cartas"
local elementos = require "datos.elementos"
local datos = require "datos.fundas"
local muebles = require "src.muebles"
local fuentes = require "src.fuentes"
local carta = require "src.carta"
local bicho = require "src.bicho"

local lg = love.graphics
local ORO = muebles.ORO
local W, H = carta.ANCHO, carta.ALTO
local FW, FH = W + 2, H + 2
local porId = {}
for _, c in ipairs(cartas) do porId[c.id] = c end

local fundas = { W = FW, H = FH, filoBasica = 0.85 }

local function col(c, a) lg.setColor(c[1], c[2], c[3], a or 1) end
local function R(c, x, y, w, h, a) col(c, a) lg.rectangle("fill", x, y, w, h) end
local function L(c, x, y, w, h, a) col(c, a) lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1) end
local function texto(s, x, y, c, al, w, e)
    if al and not w then
        w = 400
        x = al == "center" and x - 200 or (al == "right" and x - 400 or x)
    end
    fuentes.texto(s, x, y, e or 1, c or p.blanco, al, w)
end
local function lienzo(w, h, f)
    local cv = lg.newCanvas(w, h)
    cv:setFilter("nearest", "nearest")
    lg.push("all") lg.origin() lg.setCanvas(cv) lg.clear(0, 0, 0, 0) f() lg.pop()
    return cv
end
local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }
local function bay(x, y, t2) return t2 * 16 > BAYER[y % 4 + 1][x % 4 + 1] + 0.5 end
-- pinta pixel a pixel: f(x, y) devuelve color (y alfa) o nil
local function pixeles(f)
    for y = 0, FH - 1 do for x = 0, FW - 1 do
        local c, a = f(x, y)
        if c then R(c, x, y, 1, 1, a) end
    end end
end
local function marco(borde, luz)
    R(borde, 0, 0, FW, 1) R(borde, 0, FH - 1, FW, 1) R(borde, 0, 0, 1, FH) R(borde, FW - 1, 0, 1, FH)
    if luz then R(luz, 2, 2, FW - 4, 1, 0.6) R(luz, 2, 2, 1, FH - 4, 0.6) end
end
local function circulo(cx, cy, r, c, solo)
    for y = -r, r do for x = -r, r do
        local d = math.sqrt(x * x + y * y)
        if (solo and d <= r + 0.5 and d > r - 0.7) or (not solo and d <= r + 0.3) then R(c, cx + x, cy + y, 1, 1) end
    end end
end
local function rombo(cx, cy, r, c, relleno)
    for dy = -r, r do
        local w = r - math.abs(dy)
        if relleno then R(relleno, cx - w, cy + dy, w * 2 + 1, 1) end
        R(c, cx - w, cy + dy, 1, 1) R(c, cx + w, cy + dy, 1, 1)
    end
end
local CX, CY = math.floor(FW / 2), math.floor(FH / 2)

-- dibujos por id (se pintan en su lienzo al pedirlos)
local D = {}
local function nuevo(id, _, _, _, f) D[id] = f end

-- transparente: solo un brillo; detras se ve el dorso de la carta
nuevo("transparente", nil, nil, nil, function()
    lg.push() lg.translate(1, 1) carta.dibujar(porId[1], W / 2, H / 2, 1, 1, 0, false) lg.pop()
    lg.setShader()
    R(p.blanco, 0, 0, FW, FH, 0.05) R(p.blanco, FW - 7, 1, 2, FH - 2, 0.12) R(p.blanco, FW - 9, 1, 1, FH - 2, 0.08)
    -- el filo de la funda, como de frente
    L(p.cian, 0, 0, FW, FH, fundas.filoBasica)
end)
-- tienda del set: lisa (rombos) o rayas con su codigo
for i = 1, 8 do
    local C = sobres["set" .. i].colores
    nuevo("lisa" .. i, nil, nil, nil, function()
        R(C.base, 0, 0, FW, FH) rombo(CX, CY, 9, C.letras) rombo(CX, CY, 5, C.rayas, C.rayas) marco(C.borde, C.rayas)
    end)
    nuevo("rayas" .. i, nil, nil, nil, function()
        pixeles(function(x, y) return (x + y) % 8 < 2 and C.rayas or C.base end)
        R(C.borde, 6, 18, FW - 12, 15) R(C.letras, 7, 19, FW - 14, 1) R(C.letras, 7, 31, FW - 14, 1)
        texto("S" .. i, CX, 23, C.letras, "center") marco(C.borde)
    end)
end

-- motivos de la ETB, uno por set
nuevo("llamas", "LLAMAS", "ETB DEL SET 1", p.naranja, function()
    pixeles(function(x, y)
        local h = 22 + 9 * math.abs(math.sin(x * 0.42)) + 3 * math.sin(x * 1.3 + 1)
        local d = h - (FH - y)
        if d < -6 then return bay(x, y, y / FH) and p.rojo or p.morado end
        if d < 0 then return p.rojo end
        return nil
    end)
    pixeles(function(x, y)
        local h = 22 + 9 * math.abs(math.sin(x * 0.42)) + 3 * math.sin(x * 1.3 + 1)
        local d = h - (FH - y)
        if d >= 0 then return (d < 3 and p.naranja) or (d < 8 and p.amarillo) or (d < 14 and p.naranja) or p.rojo end
    end)
    pixeles(function(x, y) if (x * 7 + y * 13) % 31 == 0 and y < 18 then return p.amarillo end end)
    marco(p.morado, p.naranja)
end)
nuevo("olas", "OLAS", "ETB DEL SET 2", p.celeste, function()
    pixeles(function(x, y)
        for k = 0, 6 do
            local base = 6 + k * 7 + math.floor(2 * math.sin(x * 0.45 + k * 1.3) + 0.5)
            if y == base then return p.blanco end
            if y > base and y <= base + 2 then return k % 2 == 0 and p.cian or p.celeste end
            if y > base + 2 and y < base + 7 then return k % 2 == 0 and p.azul or p.azulosc end
        end
        return p.azulosc
    end)
    marco(p.negro, p.cian)
end)
nuevo("dunas", "DUNAS", "ETB DEL SET 3", p.amarillo, function()
    pixeles(function(x, y)
        local d1 = 30 + 4 * math.sin(x * 0.18 + 1)
        local d2 = 38 + 3 * math.sin(x * 0.25 + 3)
        local d3 = 45 + 2 * math.sin(x * 0.3)
        if y > d3 then return p.morado end
        if y > d2 then return bay(x, y, (y - d2) / 6) and p.morado or p.naranja end
        if y > d1 then return p.naranja end
        return bay(x, y, y / 30) and p.naranja or p.amarillo
    end)
    circulo(CX + 6, 14, 6, p.blanco) circulo(CX + 6, 14, 4, p.amarillo)
    marco(p.morado, p.amarillo)
end)
nuevo("galaxia", "GALAXIA", "ETB DEL SET 4", p.violeta, function()
    pixeles(function(x, y)
        local dx, dy = x - CX, (y - CY) * 0.7
        local r = math.sqrt(dx * dx + dy * dy)
        local a = math.atan2(dy, dx) + r * 0.22
        local brazo = math.abs(math.sin(a * 2))
        local t2 = brazo * math.max(0, 1 - r / 24)
        if r < 3 then return p.blanco end
        if bay(x, y, t2 * 1.4) then return t2 > 0.5 and p.violeta or p.morado end
        if bay(x, y, t2 * 2.2) then return p.azulosc end
        return p.negro
    end)
    pixeles(function(x, y) if (x * 5 + y * 11) % 23 == 0 then return (x + y) % 3 == 0 and p.blanco or p.cian end end)
    marco(p.azulosc, p.violeta)
end)
nuevo("burbujas", "BURBUJAS", "ETB DEL SET 5", p.lima, function()
    pixeles(function(x, y) return bay(x, y, y / FH) and p.verdeosc or p.morado end)
    local r = love.math.newRandomGenerator(5)
    for _ = 1, 11 do
        local cx, cy, rr = r:random(4, FW - 5), r:random(4, FH - 5), r:random(1, 5)
        circulo(cx, cy, rr, p.lima, true)
        R(p.blanco, cx - math.floor(rr / 2), cy - math.floor(rr / 2), 1, 1)
    end
    marco(p.negro, p.lima)
end)
nuevo("nubes", "NUBES", "ETB DEL SET 6", p.cian, function()
    R(p.celeste, 0, 0, FW, FH)
    local nubes = { { 8, 12, 6 }, { 15, 10, 7 }, { 24, 12, 5 }, { 26, 30, 6 }, { 32, 31, 5 }, { 18, 32, 4 }, { 6, 44, 5 }, { 13, 45, 6 } }
    for _, n in ipairs(nubes) do circulo(n[1], n[2] + 1, n[3], p.grisclaro) end
    for _, n in ipairs(nubes) do circulo(n[1], n[2], n[3], p.blanco) end
    for _, l in ipairs({ { 2, 21, 14 }, { 20, 22, 14 }, { 4, 38, 10 }, { 24, 40, 12 } }) do R(p.blanco, l[1], l[2], l[3], 1, 0.8) end
    marco(p.azul, p.blanco)
end)
nuevo("escamas", "ESCAMAS", "ETB DEL SET 7", p.verde, function()
    R(p.verdeosc, 0, 0, FW, FH)
    for fila = -1, 14 do
        for c = -1, 7 do
            local cx, cy = c * 6 + (fila % 2) * 3, fila * 4
            circulo(cx, cy, 3, p.negro)
            circulo(cx, cy, 2, p.verde)
            R(p.lima, cx - 1, cy + 1, 2, 1)
        end
    end
    marco(p.rojo, p.naranja)
end)
nuevo("sol", "SOL", "ETB DEL SET 8", p.amarillo, function()
    pixeles(function(x, y)
        local a = math.atan2(y - CY, x - CX)
        local k = math.floor((a + math.pi) / (2 * math.pi) * 20)
        return k % 2 == 0 and p.amarillo or p.blanco
    end)
    circulo(CX, CY, 10, p.naranja) circulo(CX, CY, 8, p.amarillo) circulo(CX, CY, 5, p.blanco)
    marco(p.naranja, p.blanco)
end)

-- MIX: salen por temporadas
nuevo("cuadros", "AJEDREZ", "MIX, TEMPORADA", p.grisclaro, function()
    pixeles(function(x, y) return (math.floor(x / 5) + math.floor(y / 5)) % 2 == 0 and p.negro or p.grisclaro end)
    marco(p.negro, p.blanco)
end)
nuevo("lunares", "LUNARES", "MIX, TEMPORADA", p.rojo, function()
    R(p.rojo, 0, 0, FW, FH)
    for y = 0, 9 do for x = 0, 6 do
        circulo(x * 6 + (y % 2) * 3 + 1, y * 6 + 2, 1, p.blanco)
    end end
    marco(p.morado, p.naranja)
end)
nuevo("retro", "ATARDECER RETRO", "MIX, TEMPORADA", p.naranja, function()
    pixeles(function(x, y)
        if y < 30 then
            local t2 = y / 30
            if t2 < 0.5 then return bay(x, y, t2 * 2) and p.rojo or p.morado end
            return bay(x, y, (t2 - 0.5) * 2) and p.naranja or p.rojo
        end
        local f = y - 30
        local px0 = (x - CX) * 8 / (f + 4)
        if f % math.max(1, math.floor(f / 4) + 1) == 0 or math.abs(px0 - math.floor(px0 + 0.5)) < 0.12 then return p.violeta end
        return p.negro
    end)
    for y = 12, 29 do
        local w = math.floor(math.sqrt(math.max(0, 100 - (y - 22) ^ 2)) + 0.5)
        if y < 22 or y % 3 ~= 0 then R(y < 20 and p.amarillo or p.naranja, CX - w, y, w * 2 + 1, 1) end
    end
    marco(p.negro, p.violeta)
end)
nuevo("circuito", "CIRCUITO", "MIX, TEMPORADA", p.lima, function()
    R(p.verdeosc, 0, 0, FW, FH)
    local r = love.math.newRandomGenerator(11)
    for _ = 1, 14 do
        local x, y = r:random(2, FW - 3), r:random(2, FH - 3)
        local l1, l2 = r:random(3, 12), r:random(3, 12)
        local hx = r:random() < 0.5 and 1 or -1
        R(p.verde, math.min(x, x + hx * l1), y, l1, 1)
        local x2 = x + hx * l1
        R(p.verde, x2, math.min(y, y + l2), 1, l2)
        R(p.lima, x - 1, y - 1, 3, 3) R(p.verdeosc, x, y, 1, 1)
        R(p.amarillo, x2, y + l2, 1, 1)
    end
    R(p.negro, CX - 6, CY - 5, 12, 10) for i = 0, 4 do R(p.grisclaro, CX - 8, CY - 4 + i * 2, 2, 1) R(p.grisclaro, CX + 6, CY - 4 + i * 2, 2, 1) end
    marco(p.negro, p.lima)
end)
nuevo("camuflaje", "CAMUFLAJE", "MIX, TEMPORADA", p.verde, function()
    local n = love.math.noise
    pixeles(function(x, y)
        local v = n(x * 0.13, y * 0.13, 3.1)
        local w = n(x * 0.2 + 9, y * 0.2, 1.7)
        if w > 0.72 then return p.negro end
        if v > 0.62 then return p.verdeosc end
        if v > 0.38 then return p.verde end
        return { 0.45, 0.42, 0.24 }
    end)
    marco(p.negro)
end)
nuevo("tartan", "TARTÁN", "MIX, TEMPORADA", p.rojo, function()
    pixeles(function(x, y)
        local vx, vy = x % 12, y % 12
        if vx == 5 or vy == 5 then return p.amarillo end
        if (vx < 4) and (vy < 4) then return p.negro end
        if vx < 4 or vy < 4 then return (x + y) % 2 == 0 and p.negro or p.rojo end
        return p.rojo
    end)
    marco(p.negro)
end)
nuevo("clasico", "DORSO CLÁSICO", "MIX, TEMPORADA", p.rojo, function()
    R(p.blanco, 0, 0, FW, FH)
    pixeles(function(x, y)
        if x < 3 or y < 3 or x > FW - 4 or y > FH - 4 then return nil end
        if (x + y) % 4 == 0 or (x - y) % 4 == 0 then return p.rojo end
        return { 0.92, 0.85, 0.82 }
    end)
    L(p.rojo, 2, 2, FW - 4, FH - 4)
    marco(p.grisclaro)
end)
nuevo("noche", "NOCHE", "MIX, TEMPORADA", p.celeste, function()
    pixeles(function(x, y)
        local m1 = 38 + 6 * math.abs(((x + 4) % 18) - 9) / 9 * -1 + 3
        local m2 = 44 + 3 * math.sin(x * 0.4)
        if y > m2 then return p.negro end
        if y > m1 then return p.azulosc end
        return bay(x, y, y / 40) and p.azul or p.azulosc
    end)
    circulo(26, 12, 6, p.amarillo) circulo(29, 10, 5, p.azulosc)
    pixeles(function(x, y) if y < 30 and (x * 7 + y * 5) % 29 == 0 then return p.blanco end end)
    marco(p.negro, p.celeste)
end)

-- especiales
local HOLO = { p.violeta, p.celeste, p.cian, p.lima, p.amarillo, p.naranja }
nuevo("holo", "HOLO", "1 DE CADA 10 ETB", p.violeta, function()
    pixeles(function(x, y)
        local k = math.floor((x * 2 + y) / 5) % #HOLO + 1
        return HOLO[k], (x + y) % 2 == 0 and 0.85 or 0.45
    end)
    local r = love.math.newRandomGenerator(3)
    for _ = 1, 10 do
        local x, y = r:random(3, FW - 4), r:random(3, FH - 4)
        R(p.blanco, x - 1, y, 3, 1) R(p.blanco, x, y - 1, 1, 3)
    end
    marco(p.blanco)
end)
nuevo("plata", "PLATA", "1 DE CADA 10 ETB", p.grisclaro, function()
    pixeles(function(x, y)
        local k = math.floor((x - y * 0.6) / 4) % 4
        return ({ p.gris, p.grisclaro, p.blanco, p.grisclaro })[k + 1]
    end)
    L(p.grisosc, 3, 3, FW - 6, FH - 6) rombo(CX, CY, 8, p.grisosc, p.grisclaro) rombo(CX, CY, 4, p.blanco, p.blanco)
    marco(p.grisosc)
end)
nuevo("dorada", "DORADA", "LOGRO MASTER SET", ORO.claro, function()
    R(p.negro, 0, 0, FW, FH)
    pixeles(function(x, y)
        if x > 3 and y > 3 and x < FW - 4 and y < FH - 4 and ((x + y) % 6 == 0 or (x - y) % 6 == 0) then return ORO.osc end
    end)
    L(ORO.oro, 2, 2, FW - 4, FH - 4)
    rombo(CX, CY, 10, ORO.claro, p.negro) rombo(CX, CY, 6, ORO.oro, ORO.osc)
    R(ORO.brillo, CX, CY - 2, 1, 5) R(ORO.brillo, CX - 2, CY, 5, 1)
    marco(ORO.claro)
end)

local function chase(def, id)
    local e = elementos[def.elemento]
    nuevo(id, def.nombre:upper(), "PREMIO: SU SET AL 100%", e.luz, function()
        pixeles(function(x, y)
            local a = math.atan2(y - 22, x - CX)
            local k = math.floor((a + math.pi) / (2 * math.pi) * 16)
            local r = math.sqrt((x - CX) ^ 2 + (y - 22) ^ 2)
            if k % 2 == 0 then return bay(x, y, r / 30) and e.cielo or e.horizonte end
            return bay(x, y, r / 22) and e.cielo or e.sombra
        end)
        local img = bicho.crear(def.semilla or def.id * 7919 + 13, 30, 30, e)
        lg.setColor(0, 0, 0, 0.5) lg.draw(img, CX - 15 + 1, 8 + 1)
        lg.setColor(1, 1, 1) lg.draw(img, CX - 15, 8)
        R(p.negro, 3, FH - 13, FW - 6, 10)
        L(ORO.oro, 3, FH - 13, FW - 6, 10)
        texto(def.nombre:upper(), CX, FH - 10, ORO.claro, "center")
        L(ORO.oro, 1, 1, FW - 2, FH - 2)
        R(ORO.brillo, 1, 1, 2, 2) R(ORO.brillo, FW - 3, 1, 2, 2) R(ORO.brillo, 1, FH - 3, 2, 2) R(ORO.brillo, FW - 3, FH - 3, 2, 2)
        marco(ORO.osc)
    end)
end
for _, d in ipairs(datos.lista) do
    if d.carta then chase(porId[d.carta], d.id) end
end

local lienzos = {}
-- el lienzo del dorso de una funda (true o nil: la transparente)
function fundas.dorso(id)
    if id == true or id == nil or not D[id] then id = "transparente" end
    if not lienzos[id] then
        lg.push("all")
        lienzos[id] = lienzo(FW, FH, D[id])
        lg.pop()
    end
    return lienzos[id]
end

-- para las maquetas: vuelve a pintar los lienzos
function fundas.olvidar() lienzos = {} end

-- el dorso centrado en (x, y)
function fundas.dibujarDorso(id, x, y, sx, sy, rot)
    lg.setColor(1, 1, 1)
    lg.draw(fundas.dorso(id), x, y, rot or 0, sx, sy or sx, FW / 2, FH / 2)
end

-- color del filo de una funda o del plastico de un top
function fundas.color(id, esTop)
    if id == true or id == nil then return esTop and p.blanco or p.cian end
    local d = esTop and datos.top[id] or datos[id]
    return d and d.color or p.cian
end

return fundas
