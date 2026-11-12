-- Dibujo de las cajas selladas (booster box) y la animacion de abrirlas en la
-- mesa: cae, tiembla, la tapa se queda de pie como cartel, asoman los sobres
-- (de cara, en columnas) y se va a su esquina.
-- La caja es un sprite de pixel en vista 3/4 (tapa arriba, frente y lateral
-- derecho) que se pinta una vez por set en caja.preparar; asi gira y escala
-- entera sin romperse. Hay una version mini para la caja lateral.
local sobres = require "datos.sobres"
local sets = require "datos.sets"
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local fx = require "src.fx"
local encima = require "src.encima"
local muebles = require "src.muebles"

local lg = love.graphics

-- W ancho del frente, H alto del frente, T filas de la tapa, HEAD hueco de
-- arriba (para los sobres que asoman), LABIO filas que baja la tapa por
-- delante (por los lados baja en diagonal: LABIO delante y nada detras). El
-- corte de delante pasa por la mitad de la gema y la deja entera en la caja
local GRANDE = { W = 50, H = 24, T = 14, HEAD = 7, LABIO = 10 }
local MINI = { W = 28, H = 14, T = 10, HEAD = 0, LABIO = 7, mini = true }

local caja = {}
local sprites = {}

-- caja abierta de expositor: los sobres de cara en columnas, apilados de
-- delante a atras; la tapa (con su labio) se quita y queda de pie detras
-- como cartel, y la caja se queda con el cuerpo de debajo
-- sw, sh: tamaño del sobre; hueco: separacion entre columnas
local EXPO = { cols = 3, prof = 12, asoma = 6, cartel = 14, sw = 13, sh = 19, hueco = 1 }
caja.EXPO = EXPO

for _, g in ipairs({ GRANDE, MINI }) do
    g.FUGA = math.floor((g.T - 1) / 2)
    g.CW, g.CH = g.W + g.FUGA + 2, g.HEAD + g.T + g.H + 2
    -- centro de la caja cerrada (sin el hueco de arriba)
    g.ox, g.oy = math.floor(g.CW / 2), g.HEAD + 1 + math.floor((g.T + g.H) / 2)
end
-- de donde cuelga cuando la llevas en la mano: el borde de atras de la tapa
caja.COLGADO = GRANDE.oy - GRANDE.HEAD - 1

local function mezcla(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end
local function oscuro(c, f) return { c[1] * f, c[2] * f, c[3] * f } end
local function claro(c, f) return mezcla(c, { 1, 1, 1 }, f) end

-- el texto pintado en un lienzo y leido pixel a pixel (para meterlo en el sprite)
local function mascara(texto, ancho)
    local c = lg.newCanvas(ancho, 8)
    lg.setCanvas(c)
    lg.clear(0, 0, 0, 0)
    fuentes.texto(texto, 0, 0, 1, { 1, 1, 1 }, "center", ancho)
    lg.setCanvas()
    local d = c:newImageData()
    return function(x, y)
        if x < 0 or y < 0 or x >= ancho or y >= 8 then return false end
        local _, _, _, a = d:getPixel(x, y)
        return a > 0.5
    end
end

-- que cara de la caja cae en el pixel (x, y): "top", "front" o "side" y sus
-- coordenadas en esa cara
local function cara(g, x, y)
    local ty = y - (g.HEAD + 1)
    if ty >= 0 and ty < g.T then
        local u = x - 1 - math.floor((g.T - 1 - ty) / 2)
        if u >= 0 and u < g.W then return "top", u, ty end
    end
    local fy = ty - g.T
    if fy >= 0 and fy < g.H and x >= 1 and x <= g.W then return "front", x - 1, fy end
    local k = x - g.W
    if k >= 1 and k <= g.FUGA then
        local sy = ty - (g.T - 2 * k)
        if sy >= 0 and sy < g.H then return "side", k, sy end
    end
end

-- filas que baja la tapa por el lateral en la columna k (1 delante, FUGA detras)
local function labio(g, k)
    return math.max(0, math.floor(g.LABIO * (1 - (2 * k - 1) / (g.T - 1)) + 0.5))
end

local function rombo(u, v, cu, cv)
    return math.floor(math.abs(u - cu)) + math.abs(v - cv)
end

-- la mitad de arriba de la gema del frente: se queda en la caja al abrirla
local function enGema(g, u, v)
    return not g.mini and v < g.LABIO and rombo(u, v, (g.W - 1) / 2, g.LABIO) <= 4
end

-- en que piezas va cada pixel: la caja cerrada, la tapa sola, y la abierta
-- en dos capas (fondo por detras de los sobres, frente por delante)
local function pieza(g, modo, f, a, b)
    if not f then return false end
    if modo == "cerrada" then return true end
    if modo == "tapa" then
        return f == "top" or (f == "front" and b < g.LABIO and not enGema(g, a, b)) or (f == "side" and b < labio(g, a))
    end
    -- el cuerpo de la abierta: lo que queda debajo de la tapa (con la gema entera)
    if modo == "cuerpo" then
        return (f == "front" and (b >= g.LABIO or enGema(g, a, b))) or (f == "side" and b >= labio(g, a))
    end
    if modo == "fondo" then return f == "top" and b < g.T - 1 end
    return f ~= "top" or b == g.T - 1
end


-- el dibujo de la tapa (u, v en una cara de w x h): rejilla de rombos a los
-- lados y el rombo grande en medio. Es el mismo con la caja cerrada y en el
-- cartel de la abierta (la tapa de pie)
local function dibujoTapa(c, u, v, w, h)
    local mx, my = (w - 1) / 2, (h - 1) / 2
    local lado = math.floor(w * 0.18)
    local k = h / 14
    local col = c.base
    local ax = math.abs(u - mx)
    if ax > lado + 1 and ((u + v) % 6 == 0 or (u - v) % 6 == 0) then col = c.rayas end
    if ax > lado and ax <= lado + 1 then col = p.negro end
    local dd = ax * 0.7 + math.abs(v - my)
    if dd <= 5.5 * k then col = dd <= 3.5 * k and (dd <= 1.5 * k and c.rayas or c.letras) or p.negro end
    if v == 0 or v == h - 1 or u == 0 or u == w - 1 then col = c.rayas end
    return col
end

local function colorPixel(g, t, modo, f, u, v, x, y)
    local c = t.colores
    local base = c.base
    local osc = (base[1] * 0.3 + base[2] * 0.59 + base[3] * 0.11) < 0.15
    local abierta = modo == "fondo" or modo == "frente"
    local col
    local brillo = true
    if f == "top" then
        if modo == "fondo" then
            brillo = false
            if u == 0 or u == g.W - 1 or v == 0 then
                col = claro(base, 0.3)
            elseif v <= g.T / 2 - 2 then
                col = osc and claro(base, 0.06) or oscuro(base, 0.5)
            else
                col = osc and oscuro(base, 0.7) or oscuro(base, 0.3)
            end
        elseif abierta then
            col = claro(base, 0.42)
        else
            col = dibujoTapa(c, u, v, g.W, g.T)
            if v == 0 then col = claro(base, 0.3) end
            if v == g.T - 1 then col = claro(base, 0.42) end
        end
    elseif f == "front" then
        local raya = (u + v) % 8 < 2
        col = raya and c.rayas or base
        if v == 0 then col = claro(base, 0.35) end
        if modo == "cuerpo" and v == g.LABIO then
            col = claro(base, 0.4)
        elseif not abierta and v == g.LABIO then
            col = osc and claro(base, 0.12) or oscuro(base, 0.45)
        end
        if g.mini then
            if v == 8 or v == 12 then col = c.letras end
            if v >= 9 and v <= 11 then col = (v == 10 and (u == 13 or u == 14)) and c.letras or p.negro end
        else
            local d = rombo(u, v, (g.W - 1) / 2, g.LABIO)
            if d <= 4 then col = d <= 1 and base or d <= 3 and c.letras or p.negro end
            if v == 15 or v == 23 then col = c.letras end
            if v >= 16 and v <= 22 then
                col = p.negro
                if g.letrasFrente(u, v - 17) then col = c.letras end
            end
        end
    else
        -- lateral: mas oscuro, con la banda negra dando la vuelta
        brillo = false
        local lado = osc and claro(base, 0.08) or oscuro(base, 0.62)
        col = ((u + v) % 8 < 2) and mezcla(lado, c.rayas, 0.35) or lado
        local b1, b2 = 15, 23
        if g.mini then b1, b2 = 8, 12 end
        if v == b1 or v == b2 then col = oscuro(c.letras, 0.7) end
        if v > b1 and v < b2 then col = p.negro end
        local l = labio(g, u)
        if modo == "cuerpo" and v == l then
            col = claro(base, 0.3)
        elseif v < l then
            col = osc and claro(base, 0.13) or oscuro(base, 0.72)
        elseif v == l then
            col = oscuro(lado, 0.6)
        end
    end
    -- el plastico: reflejos en diagonal por la tapa y el frente
    if brillo then
        local periodo = g.mini and 23 or 41
        local r = (x + y) % periodo
        if r <= 1 then col = claro(col, 0.35) elseif r == 4 then col = claro(col, 0.18) end
    end
    return col
end

local function pintar(g, t, modo)
    local d = love.image.newImageData(g.CW, g.CH)
    local dentro, suya = {}, {}
    local function idx(x, y) return y * g.CW + x end
    for y = 0, g.CH - 1 do
        for x = 0, g.CW - 1 do
            local f, u, v = cara(g, x, y)
            dentro[idx(x, y)] = f ~= nil
            if pieza(g, modo, f, u, v) then
                suya[idx(x, y)] = true
                local col = colorPixel(g, t, modo, f, u, v, x, y)
                d:setPixel(x, y, col[1], col[2], col[3], 1)
            end
        end
    end
    -- contorno negro de 1 pixel: el de la tapa es el suyo; el de las capas de
    -- la abierta es el de la caja entera, repartido segun a quien toca
    local propia = modo == "tapa" or modo == "cuerpo"
    local forma = propia and suya or dentro
    for y = 0, g.CH - 1 do
        for x = 0, g.CW - 1 do
            if not forma[idx(x, y)] then
                local toca, tocaSuya = false, false
                for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    local nx, ny = x + o[1], y + o[2]
                    if nx >= 0 and ny >= 0 and nx < g.CW and ny < g.CH then
                        if forma[idx(nx, ny)] then toca = true end
                        if suya[idx(nx, ny)] then tocaSuya = true end
                    end
                end
                local vale = toca and (modo == "cerrada" or propia or tocaSuya)
                -- en el fondo solo lo que no toca al frente
                if vale and modo == "fondo" then
                    for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local nx, ny = x + o[1], y + o[2]
                        local f, u, v = cara(g, nx, ny)
                        if pieza(g, "frente", f, u, v) then vale = false end
                    end
                end
                if vale then d:setPixel(x, y, p.negro[1], p.negro[2], p.negro[3], 1) end
            end
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    return img
end

-- un sobre de pie visto desde arriba, para dentro de la caja abierta
-- el sobre del juego (src/sobre.lua) en pequeño: dientes arriba y abajo,
-- rayas en diagonal, bordes, banda negra con el rombo, banda del nombre y
-- la linea de corte
local function pintarSobreMini(t)
    local SW, SH = EXPO.sw, EXPO.sh
    local c = t.colores
    local d = love.image.newImageData(SW, SH)
    local mx, my = (SW - 1) / 2, 8
    for y = 0, SH - 1 do
        for x = 0, SW - 1 do
            local col = (x + y) % 4 == 0 and c.rayas or c.base
            if x == 0 or x == SW - 1 then col = c.borde end
            if y >= 5 and y <= 11 then
                col = p.negro
                local dd = math.abs(x - mx) + math.abs(y - my)
                if dd <= 2.5 then col = dd <= 1 and c.base or c.letras end
            end
            if y >= 13 and y <= 15 then
                col = p.negro
                if y == 14 and x >= 3 and x <= SW - 4 and x % 2 == 1 then col = c.letras end
            end
            if y == 3 and x % 2 == 1 then col = p.blanco end
            -- el cierre: dientes plateados y una fila clara (en la pila se ve el color)
            if y == 1 or y == SH - 2 then col = claro(c.base, 0.25) end
            if (y == 0 or y == SH - 1) and x % 2 == 0 then col = p.grisclaro end
            if not ((y == 0 or y == SH - 1) and x % 2 == 1) then d:setPixel(x, y, col[1], col[2], col[3], 1) end
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    return img
end

-- el frente del cartel: el mismo dibujo que la tapa de la caja cerrada
local function pintarCartel(t, w, h)
    local d = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local col = dibujoTapa(t.colores, x, y, w, h)
            d:setPixel(x, y, col[1], col[2], col[3], 1)
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    return img
end

function caja.preparar()
    for _, t in ipairs(sobres.lista) do
        local nombre = sets[t.set].nombre:upper()
        GRANDE.letrasFrente = mascara(nombre, GRANDE.W)
        sprites[t.id] = {
            cerrada = pintar(GRANDE, t, "cerrada"),
            tapa = pintar(GRANDE, t, "tapa"),
            mini = pintar(MINI, t, "cerrada"),
            mini1 = pintarSobreMini(t),
            cartel = pintarCartel(t, GRANDE.W, EXPO.cartel),
            cuerpo = pintar(GRANDE, t, "cuerpo"),
        }
    end
    lg.setColor(1, 1, 1)
end

local function spritesDe(tipoId)
    return sprites[tipoId] or sprites[sobres.lista[1].id]
end

-- la caja abierta de expositor en las coordenadas del sprite. o.quedan:
-- sobres que quedan; o.asoman (0 a 1): lo que han salido los sobres y el cartel
local function dibujarExpositor(tipoId, s, g, o)
    local t = sobres[tipoId] or sobres.lista[1]
    local c = t.colores
    local dz, rect = muebles.dz, muebles.rect
    local X, Y, W, H, D = 1, g.HEAD + 1 + g.T, g.W, g.H, g.T
    local B = g.LABIO
    local asoman = o.asoman or 1
    local tonos = muebles.tonos(c.base)
    local hondo = { c.base[1] * 0.3, c.base[2] * 0.3, c.base[3] * 0.3 }
    local hondo2 = { c.base[1] * 0.2, c.base[2] * 0.2, c.base[3] * 0.2 }
    -- la tapa, de pie detras como cartel (sube al abrirla)
    local ch = math.floor(EXPO.cartel * math.min(1, asoman * 1.4) + 0.5)
    if ch > 2 then
        local cx, cy = X + dz(D), Y - D - ch
        muebles.bloque(cx, cy, W, ch, 2, tonos)
        lg.setColor(1, 1, 1)
        lg.draw(s.cartel, cx, cy, 0, 1, ch / EXPO.cartel)
    end
    -- la pared de atras por dentro
    rect(p.negro, X + dz(D) - 1, Y - D - 1, W + 2, H + 1)
    rect(hondo2, X + dz(D), Y - D, W, H)
    rect(tonos[2], X + dz(D), Y - D, W, 1)
    -- la pared de la izquierda por dentro, cortada en diagonal
    for k = 0, math.floor(D / 2) do
        local top = Y - 2 * k + labio(g, math.max(1, k))
        rect(p.negro, X - 1 + k, top - 1, 1, 1)
        rect(hondo, X + k, top, 1, Y + H - top)
        rect(tonos[2], X + k, top, 1, 1)
    end
    -- los sobres: cada columna es una pila; se gastan de delante a atras
    local img = s.mini1
    local SW, SH = img:getWidth(), img:getHeight()
    local total = EXPO.cols * EXPO.prof
    local quedan = math.max(0, math.min(total, o.quedan or total))
    local hueco = EXPO.hueco
    local x0 = X + math.floor((W - EXPO.cols * SW - (EXPO.cols - 1) * hueco) / 2)
    local sube = math.floor(EXPO.asoma * asoman + 0.5)
    for z = EXPO.prof - 1, 0, -1 do
        local zz = math.floor(z * (D - 2) / EXPO.prof) + 1
        local l = 1 - z * 0.025
        lg.setColor(l, l, l)
        for col = 0, EXPO.cols - 1 do
            local enCol = math.max(0, math.min(EXPO.prof, quedan - col * EXPO.prof))
            if EXPO.prof - z <= enCol then
                lg.draw(img, x0 + col * (SW + hueco) + dz(zz), Y + B - zz - SH + sube)
            end
        end
    end
    -- el cuerpo de la caja (frente y lateral de debajo de la tapa) por delante
    lg.setColor(1, 1, 1)
    lg.draw(s.cuerpo, 0, 0)
end

-- la caja con su centro en (x, y). o.rot giro, o.mini la pequeña,
-- o.colgada: (x, y) es el borde de atras de la tapa (cuelga de ahi),
-- o.sombra { dx, dy } en pixeles del juego, o.abierta: sin tapa con los
-- sobres de pie dentro (o.quedan cuantos, o.asoman de 0 a 1 lo que salen)
function caja.dibujar(tipoId, x, y, e, o)
    o = o or {}
    local s = spritesDe(tipoId)
    local g = o.mini and MINI or GRANDE
    local rot = o.rot or 0
    local oy = o.colgada and g.HEAD + 1 or g.oy
    if rot == 0 then x, y = math.floor(x + 0.5), math.floor(y + 0.5) end
    local sd = o.sombra or { math.max(1, math.floor(e * 2)), math.max(1, math.floor(e * 2)) }
    local silueta = o.mini and s.mini or s.cerrada
    lg.setColor(0, 0, 0, 0.3)
    lg.draw(silueta, x + sd[1], y + sd[2], rot, e, e, g.ox, oy)
    lg.setColor(1, 1, 1)
    if not o.abierta or o.mini then
        lg.draw(silueta, x, y, rot, e, e, g.ox, oy)
        return
    end
    lg.push()
    lg.translate(x, y)
    lg.rotate(rot)
    lg.scale(e, e)
    lg.translate(-g.ox, -oy)
    dibujarExpositor(tipoId, s, g, o)
    lg.pop()
    lg.setColor(1, 1, 1)
end

-- la tapa sola, centrada en (x, y)
local TAPA_X, TAPA_Y = GRANDE.CW / 2, GRANDE.HEAD + 1 + (GRANDE.T + GRANDE.LABIO) / 2
function caja.tapa(tipoId, x, y, e, rot)
    lg.setColor(1, 1, 1)
    lg.draw(spritesDe(tipoId).tapa, x, y, rot or 0, e, e, TAPA_X, TAPA_Y)
end

-- animacion de abrir: a = { tipo, t, x0, y0, x1, y1 (esquina), e1 }
local CAE, TIEMBLA, TAPA, ASOMA, VA = 0.45, 0.9, 0.05, 0.75, 0.6
local E = 3
caja.DURACION = CAE + TIEMBLA + TAPA + ASOMA + VA

-- devuelve true en el frame en que salta la tapa
function caja.avanzar(a, dt, cx, cy)
    local antes = a.t
    a.t = a.t + dt
    local salto = CAE + TIEMBLA
    if antes < CAE and a.t >= CAE then
        fx.sacudir(4)
    end
    if a.t > CAE and a.t < salto and math.floor(a.t * 12) ~= math.floor(antes * 12) then
        fx.chispa(cx + love.math.random(-40, 40), cy + love.math.random(-30, 20), sobres[a.tipo].colores.letras)
    end
    return antes < salto and a.t >= salto
end

function caja.dibujarAnim(a, cx, cy)
    local t = a.t
    local col = sobres[a.tipo].colores
    local x, y, e, rot, abierta, asoman = cx, cy, E, 0, false, 0
    if t < CAE then
        local q = fx.salidaRebote(t / CAE)
        x, y = fx.lerp(a.x0, cx, q), fx.lerp(a.y0, cy, q)
        e = fx.lerp(1.5, E, q)
        rot = (1 - q) * 0.4
    elseif t < CAE + TIEMBLA then
        -- tiembla a saltos de pixel, cada vez mas fuerte
        local f = (t - CAE) / TIEMBLA
        local paso = math.floor(t * 30)
        local r = love.math.newRandomGenerator(paso)
        x = cx + r:random(-1, 1) * math.floor(f * 3 + 0.5)
        y = cy + r:random(-1, 1) * math.floor(f * 2 + 0.5)
        rot = (r:random() * 2 - 1) * 0.04 * f
        e = E + f * 0.25
        fx.aura(cx, cy, col.letras, 60 + f * 50, f * 0.7)
    else
        abierta = true
        local t2 = t - CAE - TIEMBLA
        asoman = math.min(1, t2 / (TAPA + ASOMA))
        if t2 < TAPA + ASOMA then
            fx.aura(cx, cy, col.letras, 110, (1 - asoman) * 0.8)
            fx.rayos(cx, cy - 30, col.letras, 160, 0.25 * (1 - asoman), t)
        else
            -- se encoge y se va a su esquina
            local q = fx.salidaSuave(math.min(1, (t2 - TAPA - ASOMA) / VA))
            x, y = fx.lerp(cx, a.x1, q), fx.lerp(cy, a.y1, q)
            e = fx.lerp(E, a.e1 or 1, q)
        end
        -- la tapa no sale volando: se queda de pie detras como cartel
    end
    local o = { abierta = abierta, asoman = asoman, quedan = a.quedan, rot = rot }
    encima.anotar(function()
        caja.dibujar(a.tipo, x, y, e, o)
    end)
end

return caja
