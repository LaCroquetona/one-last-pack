-- Dibujo de los productos sellados (blister, tin y ETB) con la perspectiva de
-- la caja (src/muebles.lua). Los colores salen del set.
local p = require "datos.paleta"
local muebles = require "src.muebles"
local sobre = require "src.sobre"
local datosSobres = require "datos.sobres"
local fuentes = require "src.fuentes"

local lg = love.graphics
local rect, dz = muebles.rect, muebles.dz
local ORO = muebles.ORO

local productos = {}

productos.METAL = { 0.66, 0.70, 0.76 }
local METAL = productos.METAL

local function rombo(cx, cy, r, fuera, dentro)
    lg.setColor(fuera)
    lg.polygon("fill", cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy)
    if dentro and r >= 3 then
        lg.setColor(dentro)
        local q = math.floor(r / 2)
        lg.polygon("fill", cx, cy - q, cx + q, cy, cx, cy + q, cx - q, cy)
    end
end
productos.rombo = rombo

-- rayas en diagonal como las del sobre, dentro de un rectangulo
local function rayas(c, x, y, w, h, a, paso)
    paso = paso or 8
    lg.setColor(c[1], c[2], c[3], a or 1)
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            if (i + j) % paso < 2 then lg.rectangle("fill", x + i, y + j, 1, 1) end
        end
    end
end

-- rejilla de rombos pequeños
local function rombitos(c, x, y, w, h, a)
    lg.setColor(c[1], c[2], c[3], a or 1)
    for j = 0, h - 1 do
        for i = 0, w - 1 do
            local u, v = (i + (math.floor(j / 4) % 2) * 3) % 6, j % 4
            if (v == 1 or v == 2) and (u == 2 or (u == 1 and v == 2) or (u == 3 and v == 1)) then
                lg.rectangle("fill", x + i, y + j, 1, 1)
            end
        end
    end
end

----------------------------------------------------------------------------
-- Blister de 2: los dos sobres dentro a su tamaño real, uno al lado del otro
-- detras de la burbuja; carton del set con cabecera y pie.
productos.BLISTER = { W = 66, H = 64 }

-- la promo que se ve en el blister de ese tipo de sobre (la normal, no la ALT)
local promosBlister = {}
local function promoBlister(tipoId)
    if promosBlister[tipoId] == nil then
        promosBlister[tipoId] = false
        local tipo = datosSobres[tipoId]
        for _, def in ipairs(tipo and require("src.mercado").promosDe(tipo.set) or {}) do
            if def.promo == "blister" and not def.alt then promosBlister[tipoId] = def end
        end
    end
    return promosBlister[tipoId] or nil
end

-- vacio: ya abierto (la burbuja sin sobres y rota)
local function blisterUno(id, col, x, y, l, vacio)
    local W, H = productos.BLISTER.W, productos.BLISTER.H
    rect(p.negro, x - 1, y - 1, W + 2, H + 2)
    rect(col.base, x, y, W, H, 1, l)
    rayas(col.rayas, x, y, W, H, 0.5 * l)
    -- cabecera: franja del set con rayas, el agujero con su refuerzo y un filo
    rect(col.borde, x, y, W, 10, 1, l)
    rayas(col.base, x, y, W, 10, 0.6 * l, 6)
    rect(p.grisclaro, x + W / 2 - 6, y + 2, 12, 5, 1, l)
    rect(p.negro, x + W / 2 - 5, y + 3, 10, 3)
    rect(col.letras, x, y + 10, W, 1, 1, l)
    rombo(x + 6, y + 5, 2, col.letras)
    rombo(x + W - 7, y + 5, 2, col.letras)
    -- burbuja con los dos sobres a tamaño real
    local bx, by, bw, bh = x + 2, y + 12, W - 4, 46
    rect(p.negro, bx, by, bw, bh, 0.55)
    lg.setColor(l, l, l)
    if vacio then
        rect(p.negro, bx + 2, by + bh - 10, bw - 4, 8, 0.6)
        rect(p.blanco, bx + 4, by + bh - 4, 10, 1, 0.5)
        rect(p.blanco, bx + bw - 16, by + bh - 7, 12, 1, 0.5)
    else
        lg.draw(sobre.imagen(id), bx + 1, by + 1)
        lg.draw(sobre.imagen(id), bx + bw - 31, by + 1)
        -- su promo, delante de los sobres (se ve a traves del plastico)
        local def = promoBlister(id)
        if def then
            -- pequeña y en diagonal, delante de los sobres
            local pr = require "src.promo"
            local mini, ox, oy = pr.mini(def), pr.MINI.W / 2, pr.MINI.H / 2
            lg.setColor(0, 0, 0, 0.35)
            lg.draw(mini, x + W / 2 + 2, y + 37, -0.3, 1, 1, ox, oy)
            lg.setColor(l, l, l)
            lg.draw(mini, x + W / 2, y + 35, -0.3, 1, 1, ox, oy)
        end
    end
    rect(p.blanco, bx, by, bw, 1, 0.6)
    rect(p.blanco, bx, by, 1, bh, 0.45)
    rect(p.blanco, bx + 3, by + 4, 1, bh - 12, 0.5)
    rect(p.blanco, bx + bw - 3, by + 6, 1, 8, 0.4)
    rect(p.blanco, bx + bw - 1, by + 1, 1, bh - 1, 0.2)
    rect(p.blanco, bx, by, bw, bh, 0.08)
    -- pie: X2 y el nombre corto
    rect(p.negro, x, y + H - 6, W, 6)
    fuentes.texto(vacio and "2 SOBRES" or "2 SOBRES+PROMO", x, y + H - 5, 1, col.letras, "center", W)
end

-- colgados del agujero (hx, hy), en pila recta como los sobres
function productos.blister(id, col, hx, hy, n, giro, vacio)
    local W, H = productos.BLISTER.W, productos.BLISTER.H
    lg.push()
    lg.translate(hx, hy)
    lg.rotate(giro or 0)
    rect(p.negro, -W / 2 + 3, 1, W, H, 0.3)
    for k = (n or 1) - 1, 0, -1 do
        blisterUno(id, col, -W / 2, -3 - k * 2, 1 - k * 0.12, vacio)
    end
    lg.pop()
    lg.setColor(1, 1, 1)
end

----------------------------------------------------------------------------
-- Tin: lata de metal con la tapa algo mas ancha, una placa del set en la tapa
-- con el rombo en relieve y la banda del set por delante.
productos.TIN = { W = 30, H = 16, D = 12 }

local function placa(col, x, y, D, desdeX, ancho)
    -- placa en la tapa: 2 de margen detras, 3 delante y 4 a los lados
    for r = 3, D - 3 do rect(col.base, x + dz(r) + desdeX, y - 1 - r, ancho, 1) end
    rect(col.borde, x + dz(3) + desdeX, y - 4, ancho, 1)
    rect(col.borde, x + dz(D - 3) + desdeX, y - 1 - (D - 3), ancho, 1)
end

function productos.tin(col, x, y, e)
    e = e or 1
    x, y = math.floor(x), math.floor(y)
    local W, H, D = math.floor(30 * e), math.floor(16 * e), math.floor(12 * e)
    local tapa = math.max(3, math.floor(6 * e))
    muebles.bloque(x + 1, y + tapa, W - 2, H - tapa, D - 2, muebles.tonos(METAL, 0.9, 1.2, 0.6))
    muebles.bloque(x, y, W, tapa, D, muebles.tonos(METAL, 1.05, 1.3, 0.7))
    rect(p.blanco, x + 3, y + 1, 1, tapa - 2, 0.7)
    rect(p.blanco, x + 5, y + tapa + 1, 2, H - tapa - 2, 0.35)
    rect(p.negro, x, y + tapa, W, 1, 0.55)
    for _, c in ipairs({ { x - 1, y - 1 }, { x + W, y - 1 }, { x - 1, y + H - 1 }, { x + W - 1, y + H } }) do
        rect(p.negro, c[1], c[2], 1, 1)
    end
    local by = y + tapa + math.floor((H - tapa) / 2) - math.floor(3 * e)
    local bh = math.max(3, math.floor(6 * e))
    rect(col.base, x + 1, by, W - 2, bh)
    rayas(col.rayas, x + 1, by, W - 2, bh, 0.6)
    rect(col.borde, x + 1, by, W - 2, 1)
    rect(col.borde, x + 1, by + bh - 1, W - 2, 1)
    if e >= 0.8 then
        placa(col, x, y, D, 4, W - 8)
        local cx, cy = x + math.floor(W / 2) + dz(math.floor(D / 2)), y - math.floor(D / 2)
        lg.setColor(col.borde)
        lg.polygon("fill", cx, cy - 3, cx + 6, cy, cx, cy + 3, cx - 6, cy)
        lg.setColor(col.letras)
        lg.polygon("fill", cx, cy - 1, cx + 3, cy, cx, cy + 1, cx - 3, cy)
    end
    lg.setColor(1, 1, 1)
end

-- tin con dos sets: la placa y la banda partidas por la mitad
function productos.tinMix(c1, c2, x, y)
    productos.tin(c1, x, y, 1)
    local W, D, tapa = 30, 12, 6
    local by = y + tapa + 2
    rect(c2.base, x + W / 2, by, W / 2 - 1, 6)
    rayas(c2.rayas, x + W / 2, by, W / 2 - 1, 6, 0.6)
    rect(c2.borde, x + W / 2, by, W / 2 - 1, 1)
    rect(c2.borde, x + W / 2, by + 5, W / 2 - 1, 1)
    placa(c2, x, y, D, W / 2, W / 2 - 4)
    local cx, cy = x + W / 2 + dz(D / 2), y - D / 2
    lg.setColor(p.blanco)
    lg.polygon("fill", cx, cy - 4, cx + 7, cy, cx, cy + 4, cx - 7, cy)
    lg.setColor(c1.letras)
    lg.polygon("fill", cx - 3, cy, cx, cy - 2, cx, cy + 2)
    lg.setColor(c2.letras)
    lg.polygon("fill", cx + 3, cy, cx, cy - 2, cx, cy + 2)
    lg.setColor(1, 1, 1)
end

----------------------------------------------------------------------------
-- ETB: caja ancha del set. Tapa arriba con su borde en diagonal por el
-- lateral con rejilla de rombos y filos dorados, franja negra con ETB y el
-- rombo, y rayas abajo.
productos.ETB = { W = 40, H = 34, D = 10 }

function productos.etb(col, x, y, e, o)
    e, o = e or 1, o or {}
    if o.abierta then return productos.etbAbierta(col, x, y, e, o.dentro) end
    x, y = math.floor(x), math.floor(y)
    local W, H, D = math.floor(40 * e), math.floor(34 * e), math.max(4, math.floor(10 * e))
    local T = math.floor(14 * e)
    local base = muebles.tonos(col.base, 0.85, 1.2, 0.55)
    local tapaC = muebles.tonos(col.base, 1.05, 1.35, 0.7)
    muebles.bloque(x, y, W, H, D, base)
    rayas(col.rayas, x, y + T, W, H - T, 0.45)
    rect(col.borde, x, y + H - 4, W, 2)
    -- lateral: el borde de la tapa baja en diagonal
    for k = 1, math.floor(D / 2) do
        local cx = x + W - 1 + k
        local arriba = y - 2 * k + 1
        local corte = T + k
        rect(tapaC[3], cx, arriba, 1, corte)
        rect(p.negro, cx, arriba + corte, 1, 1, 0.6)
    end
    do
        for r = 0, D - 1 do rect(tapaC[2], x + dz(r), y - 1 - r, W, 1) end
        rect(tapaC[1], x, y, W, T)
        rombitos(col.borde, x, y + 1, W, T - 3, 0.6)
        rect(col.letras, x, y + T - 2, W, 1, 0.7)
        rect(p.negro, x, y + T, W, 1, 0.6)
        rect(p.blanco, x + 1, y + 1, 1, T - 3, 0.35)
        do
            rect(ORO.oro, x, y, W, 1)
            rect(ORO.oro, x, y + T - 2, W, 1)
            for _, sx in ipairs({ 0, W - 3 }) do
                rect(ORO.claro, x + sx, y + 1, 3, 1) rect(ORO.oro, x + sx + (sx == 0 and 0 or 2), y + 2, 1, 2)
            end
            for r = 0, D - 1 do rect(ORO.osc, x + dz(r), y - 1 - r, 1, 1) rect(ORO.osc, x + dz(r) + W - 1, y - 1 - r, 1, 1) end
        end
    end
    productos.etbFranja(col, x, y, e)
    lg.setColor(1, 1, 1)
end

-- abierta: sin tapa, el frente baja y los laterales suben en diagonal hacia
-- atras, como una ETB de verdad. dentro(): pinta lo de dentro (los sobres)
function productos.etbAbierta(col, x, y, e, dentro)
    e = e or 1
    x, y = math.floor(x), math.floor(y)
    local W, H, D = math.floor(40 * e), math.floor(34 * e), math.max(4, math.floor(10 * e))
    local C = math.floor(7 * e)
    local base = muebles.tonos(col.base, 0.85, 1.2, 0.55)
    local function borde(r) return y + C - r - math.floor(C * r / D) end
    muebles.bloque(x, y + C, W, H - C, D, base)
    -- hueco de dentro y pared de atras
    for r = 1, D - 1 do rect(p.negro, x + dz(r) + 1, y + C - 1 - r, W - 2, 1, 0.7) end
    rect(p.negro, x + dz(D) - 1, y - D - 1, W + 2, C + 1)
    rect(col.base, x + dz(D), y - D, W, C, 1, 0.45)
    rayas(col.rayas, x + dz(D), y - D, W, C, 0.2)
    -- pared de la izquierda por dentro y lateral de la derecha, en diagonal
    for r = 0, D do
        local t = borde(r)
        rect(col.base, x + dz(r), t, 1, y + C - r - t, 1, 0.6)
        rect(p.negro, x + dz(r), t - 1, 1, 1)
    end
    for k = 1, math.floor(D / 2) do
        local t = borde(2 * k)
        rect(base[3], x + W - 1 + k, t, 1, y + C - 2 * k + 1 - t)
        rect(p.negro, x + W - 1 + k, t - 1, 1, 1)
    end
    if dentro then dentro() end
    -- frente bajo, encima de lo de dentro
    rect(p.negro, x - 1, y + C - 1, W + 2, 1)
    rect(base[1], x, y + C, W, H - C)
    rayas(col.rayas, x, y + C, W, H - C, 0.45)
    rect(ORO.oro, x, y + C, W, 1)
    rect(col.borde, x, y + H - 4, W, 2)
    productos.etbFranja(col, x, y, e)
    lg.setColor(1, 1, 1)
end

-- franja negra con ETB y el rombo
function productos.etbFranja(col, x, y, e)
    e = e or 1
    local W, T = math.floor(40 * e), math.floor(14 * e)
    local fy = y + T + math.floor(3 * e)
    local fh = math.floor(11 * e)
    rect(p.negro, x, fy, W, fh)
    local rx = x + math.floor(W * 0.62)
    rombo(rx, fy + math.floor(fh / 2), math.floor(4 * e), ORO.oro, col.base)
    if e >= 1 then
        fuentes.texto("ETB", x + 2, fy + 3, 1, ORO.claro)
        rombo(x + W - 5, fy + math.floor(fh / 2), 1, col.borde)
    end
    rect(ORO.oro, x, fy, W, 1)
    rect(ORO.osc, x, fy + fh - 1, W, 1)
end

----------------------------------------------------------------------------
-- Lo que hay en un hueco de la tienda o del armario (HUECO de ancho), con su
-- suelo en y: apilado como en la vida real, hasta lo que cabe
productos.HUECO = 70

local function colores(tipoId) return (datosSobres[tipoId] or datosSobres.lista[1]).colores end

function productos.enHueco(pid, tipoId, x, y, n, giro)
    local col = colores(tipoId)
    lg.setColor(1, 1, 1)
    if pid == "sobre" or pid:match("^pr") then
        local img = pid == "sobre" and sobre.imagen(tipoId) or sobre.imagen(sobre.clavePromo(pid:sub(3), tipoId))
        for i = math.min(3, n) - 1, 0, -1 do lg.draw(img, x + 18 + i * 2, y - 46 - i * 2) end
    elseif pid == "blister" then
        productos.blister(tipoId, col, x + 34, y - 72, math.min(2, n), giro or 0)
    elseif pid == "tin" then
        for i = 0, math.min(4, n) - 1 do
            productos.tin(col, x + 2 + (i % 2) * 34 + math.floor(i / 2), y - 19 - math.floor(i / 2) * 16)
        end
    elseif pid == "etb" then
        for i = 0, math.min(2, n) - 1 do productos.etb(col, x + 8 + i * 3, y - 37 - i * 34) end
    elseif pid == "caja" then
        local caja = require "src.caja"
        for i = 0, math.min(2, n) - 1 do caja.dibujar(tipoId, x + 32 + i, y - 19 - i * 26, 1, {}) end
    end
    lg.setColor(1, 1, 1)
end

-- uno solo, centrado en (x, y), al tamaño e (la mesa y lo que llevas en la mano)
function productos.uno(pid, tipoId, x, y, e, rot, vacio)
    local col = colores(tipoId)
    local W, H = 40, 34
    if pid == "tin" then W, H = 30, 16 end
    if pid == "blister" then W, H = productos.BLISTER.W, productos.BLISTER.H end
    lg.push()
    lg.translate(x, y)
    lg.rotate(rot or 0)
    lg.scale(e, e)
    if pid == "blister" then
        productos.blister(tipoId, col, 0, -H / 2 + 3, 1, 0, vacio)
    elseif pid == "tin" then
        productos.tin(col, -W / 2, -H / 2)
    else
        productos.etb(col, -W / 2, -H / 2)
    end
    lg.pop()
    lg.setColor(1, 1, 1)
end

-- en pequeño para la balda de la mesa, con el suelo en y y centrado en x
function productos.mini(pid, tipoId, x, y)
    local col = colores(tipoId)
    if pid == "etb" then productos.etb(col, x - 10, y - 17, 0.5)
    elseif pid == "tin" then productos.tin(col, x - 9, y - 9, 0.6) end
end

----------------------------------------------------------------------------
-- Animacion de abrir una ETB o un tin en la mesa, como la de la caja: cae,
-- tiembla, se abre y sus sobres salen volando al abanico de la esquina.
-- a = { prod, tipo, t, x0, y0, destinos = { { x, y, r }, ... } }
local CAE, TIEMBLA, ABRE, VA = 0.45, 0.9, 0.9, 0.4
local E = 3
productos.DURACION = CAE + TIEMBLA + ABRE + VA
productos.SALTO = CAE + TIEMBLA   -- cuando se abre y empiezan a salir los sobres

-- devuelve true en el frame en que se abre
function productos.avanzarAnim(a, dt, cx, cy)
    local fx = require "src.fx"
    local antes = a.t
    a.t = a.t + dt
    local salto = CAE + TIEMBLA
    if antes < CAE and a.t >= CAE then fx.sacudir(4) end
    if a.t > CAE and a.t < salto and math.floor(a.t * 12) ~= math.floor(antes * 12) then
        fx.chispa(cx + love.math.random(-40, 40), cy + love.math.random(-30, 20), colores(a.tipo).letras)
    end
    return antes < salto and a.t >= salto
end

function productos.dibujarAnim(a, cx, cy)
    local fx = require "src.fx"
    local encima = require "src.encima"
    local col = colores(a.tipo)
    local t = a.t
    -- el blister ya es grande: se queda a 2
    local EE = a.prod == "blister" and 2 or E
    local x, y, e, rot, abierta, alfa = cx, cy, EE, 0, false, 1
    if t < CAE then
        local q = fx.salidaRebote(t / CAE)
        x, y = fx.lerp(a.x0, cx, q), fx.lerp(a.y0, cy, q)
        e = fx.lerp(1.5, EE, q)
        rot = (1 - q) * 0.4
    elseif t < CAE + TIEMBLA then
        local f = (t - CAE) / TIEMBLA
        local r = love.math.newRandomGenerator(math.floor(t * 30))
        x = cx + r:random(-1, 1) * math.floor(f * 3 + 0.5)
        y = cy + r:random(-1, 1) * math.floor(f * 2 + 0.5)
        rot = (r:random() * 2 - 1) * 0.04 * f
        e = EE + f * 0.25
        fx.aura(cx, cy, col.letras, 60 + f * 50, f * 0.7)
    else
        abierta = true
        local t2 = t - CAE - TIEMBLA
        if t2 < ABRE then
            fx.aura(cx, cy, col.letras, 110, (1 - t2 / ABRE) * 0.8)
            fx.rayos(cx, cy - 30, col.letras, 160, 0.25 * (1 - t2 / ABRE), t)
        else
            local q = math.min(1, (t2 - ABRE) / VA)
            e, alfa = EE * (1 - 0.3 * q), 1 - q
        end
    end
    local t2 = t - CAE - TIEMBLA
    encima.anotar(function()
        lg.setColor(1, 1, 1, alfa)
        if a.prod == "etb" then
            local W, H = productos.ETB.W, productos.ETB.H
            lg.push()
            lg.translate(x, y)
            lg.rotate(rot)
            lg.scale(e, e)
            productos.etb(col, -W / 2, -H / 2, 1, { abierta = abierta })
            lg.pop()
        elseif alfa > 0 then
            productos.uno(a.prod, a.tipo, x, y, e, rot, abierta and a.prod == "blister")
        end
        -- los sobres salen de uno en uno hacia el abanico
        if abierta then
            local img = sobre.imagen(a.tipo)
            for i, d in ipairs(a.destinos or {}) do
                local q = math.max(0, math.min(1, (t2 - 0.1 - (i - 1) * 0.05) / 0.45))
                if q > 0 then
                    local qq = fx.salidaSuave(q)
                    local sx = fx.lerp(cx, d[1], qq)
                    local sy = fx.lerp(cy - 30, d[2], qq) - math.sin(q * math.pi) * 40
                    lg.setColor(1, 1, 1)
                    lg.draw(img, sx, sy, fx.lerp(0, d[3], qq), fx.lerp(2, 0.8, qq), fx.lerp(2, 0.8, qq), 15, 0)
                end
            end
        end
        lg.setColor(1, 1, 1)
    end)
end

-- hueco libre: borde de rayas y su texto
function productos.hueco(x, y, w, h, texto)
    lg.setColor(1, 1, 1, 0.18)
    for i = 0, w - 1, 4 do lg.rectangle("fill", x + i, y, 2, 1) lg.rectangle("fill", x + i, y + h - 1, 2, 1) end
    for i = 0, h - 1, 4 do lg.rectangle("fill", x, y + i, 1, 2) lg.rectangle("fill", x + w - 1, y + i, 1, 2) end
    fuentes.texto(texto, x, y + h / 2 - 2, 1, { 1, 1, 1, 0.35 }, "center", w)
    lg.setColor(1, 1, 1)
end

return productos
