-- Zonas del tapete durante el directo: TU TACO (lo que no es hit, apilado con
-- grosor; al pasar el raton se abre en abanico), HITS (de holo para arriba, en
-- fila) y PEDIDOS (en la venta: el taquito de cada comprador con su post-it;
-- al completarse se mete en un sobre acolchado y sale volando).
-- Las cartas tuyas son entradas de partida.mesa con zona = "taco" o "hits":
-- ya estan en tu coleccion y vuelven al armario con RECOGER MESA.
local rarezas = require "datos.rarezas"
local productos = require "datos.productos"
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local carta = require "src.carta"
local directo = require "src.directo"
local apertura = require "src.apertura"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"

local lg = love.graphics

local zonas = {}

local CW, CH = carta.ANCHO, carta.ALTO
-- grosor del taco: la primera carta sola; desde la segunda, 1 px por cada
-- CARTAS_PX cartas (hasta MAX_CANTOS px: una caja deja ~240 cartas en el taco,
-- 60 px; el tope, 80 px). Si no cabe en su recuadro, el taco asoma por
-- arriba: el recuadro esta pintado en el tapete y no cambia
local CANTO = 1
local CARTAS_PX = 4
local MAX_CANTOS = 80
local MAX_CANTOS_PEDIDO = 10
-- la carta de arriba del taco, del tamano de los hits
local E_TACO = 1.25
-- el taco en la mano: del mismo tamano (las cartas no cambian al moverlas)
local E_MANO = E_TACO
-- lo que tarda en abrirse el abanico con el raton encima del taco
local ESPERA_ABANICO = 0.25
-- cartas que se ven en el abanico del taco (las ultimas)
local MAX_ABANICO = 40
local ESCALA_ABANICO = 1.5
local VUELO = 0.4
local ENVIO = 1.5

local T = { x = 116, y = 24, w = 386, h = 330 }
-- huecos de pedidos: { pe, cartas = {defs}, sobres, envio (nil, o el tiempo; negativo: espera) }
local huecos = {}
-- cartas de un comprador volando a su hueco
local vuelos = {}
-- abanico abierto con el dedo (en el PC se abre al pasar el raton)
local abiertoTactil = false
-- donde se pinto cada carta de las zonas (para cogerla): posZona[u] = { x, y, e }
local posZona = {}
-- donde esta la carta de arriba del taco (aparte: el abanico pisa posZona)
local posPila = nil
-- tiempo con el raton encima del taco (el abanico espera un poco)
local tEncima = 0
-- el taco volviendo a su sitio tras soltarlo fuera del armario
local pilaVuelve = nil
-- la mesa pone aqui la copia que llevas en la mano (no se pinta en su zona)
zonas.cogida = nil
-- y si llevas el taco entero
zonas.pilaCogida = false

-- px de grosor de un taco de n cartas
local function grosor(n, tope)
    return math.min(tope, math.ceil(math.max(0, n - 1) / CARTAS_PX))
end

function zonas.preparar(tapete)
    T = tapete
end

local function hayZona()
    for _, s in ipairs(partida.mesa) do
        if s.zona then return true end
    end
    return false
end

-- las zonas se ven en directo o si quedan cartas en ellas
function zonas.activas()
    return directo.activo() or hayZona()
end

-- la columna de pedidos: solo en la venta
function zonas.columna()
    return directo.activo() and directo.tipo() == "venta"
end

-- lo que ocupa la columna (la mesa aparta a la izquierda lo de la esquina)
function zonas.anchoColumna()
    return zonas.columna() and 54 or 0
end

local function geo()
    local col = { x = T.x + T.w - 54, y = T.y + 8, w = 48, h = T.h - 22 }
    local der = zonas.columna() and col.x - 4 or T.x + T.w - 8
    local y0 = T.y + 228
    local taco = { x = T.x + 8, y = y0, w = 62, h = 88 }
    local hits = { x = taco.x + taco.w + 6, y = y0, w = der - (taco.x + taco.w + 6), h = 88 }
    return taco, hits, col
end

-- la zona donde se abre: a la izquierda de la columna
function zonas.anchoApertura()
    return T.w - zonas.anchoColumna()
end

local function lista(zona)
    local l = {}
    for _, s in ipairs(partida.mesa) do
        if s.zona == zona and s.u ~= zonas.cogida then table.insert(l, s) end
    end
    return l
end

local function hits()
    local l = lista("hits")
    table.sort(l, function(a, b)
        local da, db = partida.carta(a.id), partida.carta(b.id)
        local ra, rb = da and rarezas.rango(da) or 0, db and rarezas.rango(db) or 0
        if ra ~= rb then return ra < rb end
        return a.u < b.u
    end)
    return l
end

-- hits: de holo para arriba, y todas las promos
local function esHit(def)
    return def.promo or rarezas.de(def).nivel >= 4
end

-- las holo normales van a su taquito, al principio de HITS (las alt holo y
-- las promos, a la fila con lo gordo)
local function esHolo(def)
    return def and not def.promo and rarezas.de(def).nivel == 4
end

-- los hits de un tipo: holos = true, el taquito; false, la fila
local function hitsDe(holos)
    local l = {}
    for _, s in ipairs(hits()) do
        if (esHolo(partida.carta(s.id)) or false) == holos then table.insert(l, s) end
    end
    return l
end

-- marco fino del color del tapete con su nombre encima de la linea
local function marco(r, nombre)
    lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.45)
    lg.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    local w = fuentes.ancho(nombre) + 6
    lg.setColor(p.verdeosc)
    lg.rectangle("fill", r.x + 5, r.y - 2, w, 5)
    fuentes.texto(nombre, r.x + 8, r.y - 2, 1, { p.verde[1], p.verde[2], p.verde[3], 0.9 })
end

-- cantos de un taco: n px bajo una carta de ancho w cuyo borde de abajo esta
-- en y. Se cuentan desde abajo (j = 1 es el de abajo del todo): asi cada px
-- se queda como esta y el nuevo sale arriba, sin que se mueva lo de debajo.
-- enfundada(j) dice si el px j va en cian. Cada canto es del ancho de la
-- carta con su borde oscuro; cada 3 px el grupo se descuadra 1 px (como un
-- taco de verdad) y abajo, sombra. Con zonas.LADO se ve tambien el lado
-- derecho del taco, en perspectiva
zonas.LADO = true
local function cantos(cx, y, n, semilla, enfundada, w)
    if n <= 0 then return end
    w = math.floor(w or CW)
    local x0 = math.floor(cx - w / 2 + 0.5)
    y = math.floor(y + 0.5)
    local abajo = y + n * CANTO
    local function dx(j)
        local v = (semilla * 5 + math.floor((j - 1) / 3) * 7) % 5
        return (v == 0 and -1) or (v == 4 and 1) or 0
    end
    -- el lado: 1 px, 2 con el taco gordo
    local lado = zonas.LADO and (n > 40 and 2 or 1) or 0
    -- sombra, como la de las cartas
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x0 + 2, y + 1, w + lado, n * CANTO + 2)
    for j = 1, n do
        local d = dx(j)
        local cy = abajo - j * CANTO
        local f = enfundada and enfundada(j)
        local claro = j % 2 == 1
        lg.setColor(p.negro)
        lg.rectangle("fill", x0 + d, cy, w + lado, CANTO)
        if f then lg.setColor(claro and p.cian or p.celeste) else lg.setColor(claro and p.blanco or p.grisclaro) end
        lg.rectangle("fill", x0 + d + 1, cy, w - 2, CANTO)
        if lado > 0 then
            -- el lado, mas oscuro
            if f then lg.setColor(p.celeste) else lg.setColor(claro and p.grisclaro or p.gris) end
            lg.rectangle("fill", x0 + d + w - 1, cy, lado, CANTO)
        end
    end
    if lado > 0 then
        -- el lado sube por el borde de la carta de arriba
        lg.setColor(p.negro)
        lg.rectangle("fill", x0 + w - 1, y - CH * (w / CW) + lado, lado + 1, CH * (w / CW) - lado)
        lg.setColor(p.gris)
        lg.rectangle("fill", x0 + w - 1, y - CH * (w / CW) + lado + 1, lado, CH * (w / CW) - lado - 1)
    end
    -- el borde de abajo, un px mas estrecho (esquinas redondeadas)
    lg.setColor(p.negro)
    lg.rectangle("fill", x0 + dx(1) + 1, abajo, w - 2 + lado, 1)
end

local function copiaDe(s)
    return partida.copia(s.id, s.u)
end

local function dibujarCopia(s, x, y, e, rot, zid, hover)
    local def, c = partida.carta(s.id), copiaDe(s)
    if not (def and c) then return end
    local h = hover or (zid and ui.hoverCarta(zid, x, y, CW * e, CH * e))
    carta.dibujar(def, x, y, e, e, rot or 0, true, h, c.f, { primera = c.p, top = c.t, quieta = true })
end

local function tooltipCopia(s)
    local def, c = partida.carta(s.id), copiaDe(s)
    if not (def and c) then return end
    local r = rarezas.de(def)
    ui.tooltip(rarezas.nombre(def), r.color, {
        { r.nombre .. (c.p and "  -  1ª ED" or ""), r.color },
        { "Copias: " .. partida.copias(s.id) },
        { mercado.textoValor(s.id, c.p), p.amarillo },
        { c.f and "Enfundada" or "Sin funda", c.f and p.cian or p.gris },
        { "Tócala para más opciones", p.grisclaro },
    })
end

-- donde acaba una carta: arriba del taco o su sitio en la fila de hits
local function sitioTaco(n)
    local taco = geo()
    local cantosN = grosor(n, MAX_CANTOS)
    local abajo = taco.y + taco.h - 5
    local y = abajo - cantosN * CANTO - CH * E_TACO / 2
    return taco.x + taco.w / 2 - 4, y, cantosN, abajo
end

-- un taco de las cartas l (la ultima, arriba) con el centro de la carta de
-- arriba en (0, 0): para pintarlo en su sitio o en la mano, girado
local function margenFunda(l, e)
    local top = l[#l] and copiaDe(l[#l])
    return top and top.f and math.ceil(e) or 0
end

local function pintarPila(l, e, semilla, hover)
    local n = #l
    local cantosN = grosor(n, MAX_CANTOS)
    -- el px k (de arriba abajo) son las CARTAS_PX cartas de debajo de la de
    -- arriba: cian si la mayoria van enfundadas
    -- el px j (de abajo arriba) son las cartas (j-1)*CARTAS_PX+1 .. j*CARTAS_PX
    -- (la de arriba del todo es la carta que se ve): cian si la mayoria van
    -- enfundadas
    -- la funda asoma 1 px (escalado) por fuera de la carta: los cantos, debajo
    local margen = margenFunda(l, e)
    cantos(0, CH * e / 2 + margen, cantosN, semilla, function(j)
        local si, total = 0, 0
        for i = (j - 1) * CARTAS_PX + 1, math.min(j * CARTAS_PX, n - 1) do
            local c = l[i] and copiaDe(l[i])
            total = total + 1
            if c and c.f then si = si + 1 end
        end
        return total > 0 and si * 2 > total
    end, CW * e)
    dibujarCopia(l[n], 0, 0, e, 0, nil, hover)
end

-- el taquito de holos, a la izquierda de HITS (como el taco, con grosor)
local function sitioHolo(n)
    local _, r = geo()
    local cantosN = grosor(n, MAX_CANTOS)
    local abajo = r.y + r.h - 5
    return r.x + 7 + CW * E_TACO / 2, abajo - cantosN * CANTO - CH * E_TACO / 2, cantosN
end

local function sitiosHits(n)
    local _, r = geo()
    local e = 1.25
    local w = CW * e
    -- con holos, la fila empieza despues de su taquito
    local hayHolos = #hitsDe(true) > 0
    local izq = r.x + 7 + (hayHolos and (w + 8) or 0)
    local ancho = r.x + r.w - 7 - izq
    local paso = n > 1 and math.min(w + 6, (ancho - w) / (n - 1)) or 0
    local total = w + paso * math.max(0, n - 1)
    local x0 = izq + w / 2 + math.max(0, (ancho - total) / 2)
    local y = r.y + r.h / 2 + 2
    return x0, paso, y, e
end

local function volando(s)
    return s.vuelo and s.vuelo.t < VUELO
end

-- lo que ocupa el taco: su recuadro y, si asoma por arriba, hasta la carta
local function marcoTaco(n)
    local taco = geo()
    local _, cy = sitioTaco(math.max(1, n))
    local arriba = math.min(taco.y, math.floor(cy - CH * E_TACO / 2 - 6))
    return { x = taco.x, y = arriba, w = taco.w, h = taco.y + taco.h - arriba }
end

local function dibujarTaco()
    local taco = geo()
    marco(taco, "TU TACO")
    posPila = nil
    if zonas.pilaCogida then
        -- lo llevas en la mano: su hueco, vacio
        lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.35)
        local cx, cy = sitioTaco(1)
        lg.rectangle("line", cx - CW * E_TACO / 2 + 0.5, cy - CH * E_TACO / 2 + 0.5, CW * E_TACO - 1, CH * E_TACO - 1)
        return
    end
    local l = {}
    for _, s in ipairs(lista("taco")) do
        if not volando(s) then table.insert(l, s) end
    end
    local n = #l
    if n == 0 then
        fuentes.texto("VACÍO", taco.x, taco.y + taco.h / 2 - 2, 1, { p.verde[1], p.verde[2], p.verde[3], 0.5 }, "center", taco.w)
        return
    end
    local cx, cy = sitioTaco(n)
    -- con la de arriba enfundada, sube un poco: lo de abajo no se mueve
    cy = cy - margenFunda(l, E_TACO)
    local e = E_TACO
    if pilaVuelve then
        -- vuelve volando de donde lo soltaste
        local q = fx.salidaSuave(math.min(1, pilaVuelve.t / VUELO))
        cx = fx.lerp(pilaVuelve.x, cx, q)
        cy = fx.lerp(pilaVuelve.y, cy, q) - math.sin(q * math.pi) * 12
        e = fx.lerp(pilaVuelve.e, E_TACO, q)
    end
    -- el brillo al pasar por encima, como en las demas cartas
    local h = not pilaVuelve and ui.hoverCarta("zt_pila", cx, cy, CW * e, CH * e) or nil
    lg.push()
    lg.translate(cx, cy)
    if pilaVuelve then lg.rotate(pilaVuelve.a * (1 - fx.salidaSuave(math.min(1, pilaVuelve.t / VUELO)))) end
    pintarPila(l, e, 1, h)
    lg.pop()
    if not pilaVuelve then posPila = { cx, cy, e } end
    posZona[l[n].u] = { cx, cy, e }
    local r = marcoTaco(n)
    ui.zona("zt_pila", r.x, r.y, r.w, r.h)
    -- contador
    local cad = "X" .. n
    local w = fuentes.ancho(cad) + 4
    lg.setColor(p.negro)
    lg.rectangle("fill", taco.x + taco.w - w - 2, taco.y + taco.h - 10, w + 2, 9)
    lg.setColor(p.rojo)
    lg.rectangle("fill", taco.x + taco.w - w - 1, taco.y + taco.h - 9, w, 7)
    fuentes.texto(cad, taco.x + taco.w - w + 1, taco.y + taco.h - 8, 1, p.blanco)
end

-- el taquito de holos: la de arriba se coge sola; encima, su abanico
local posHolo = nil
local function dibujarHolos()
    posHolo = nil
    local l = {}
    for _, s in ipairs(hitsDe(true)) do
        if not volando(s) then table.insert(l, s) end
    end
    local n = #l
    if n == 0 then return end
    local cx, cy = sitioHolo(n)
    cy = cy - margenFunda(l, E_TACO)
    local h = ui.hoverCarta("zt_holo", cx, cy, CW * E_TACO, CH * E_TACO)
    lg.push()
    lg.translate(cx, cy)
    pintarPila(l, E_TACO, 2, h)
    lg.pop()
    posHolo = { cx, cy, E_TACO }
    posZona[l[n].u] = { cx, cy, E_TACO }
    local w, alto = CW * E_TACO, CH * E_TACO
    local _, r = geo()
    local arriba = math.min(cy - alto / 2, r.y)
    ui.zona("zt_holo", cx - w / 2 - 2, arriba, w + 4, r.y + r.h - arriba)
    -- contador, en violeta como la rareza
    local cad = "X" .. n
    local wc = fuentes.ancho(cad) + 4
    local bx, by = cx + w / 2 - wc + 3, r.y + r.h - 10
    lg.setColor(p.negro)
    lg.rectangle("fill", bx - 1, by, wc + 2, 9)
    lg.setColor(p.violeta)
    lg.rectangle("fill", bx, by + 1, wc, 7)
    fuentes.texto(cad, bx + 2, by + 2, 1, p.blanco)
end

local function dibujarHits()
    local _, r = geo()
    marco(r, "HITS")
    dibujarHolos()
    local l = {}
    for _, s in ipairs(hitsDe(false)) do
        if not volando(s) then table.insert(l, s) end
    end
    if #l == 0 then
        if not posHolo then
            fuentes.texto("DE HOLO PARA ARRIBA", r.x, r.y + r.h / 2 - 2, 1, { p.verde[1], p.verde[2], p.verde[3], 0.5 }, "center", r.w)
        end
        return
    end
    local x0, paso, y, e = sitiosHits(#l)
    -- la mejor, delante (la ultima)
    for i, s in ipairs(l) do
        local zid = "zh_" .. s.u
        local x = x0 + (i - 1) * paso
        dibujarCopia(s, x, y, e, 0, zid)
        posZona[s.u] = { x, y, e }
        local w = (i < #l) and math.max(4, paso) or CW * e
        ui.zona(zid, x - CW * e / 2, y - CH * e / 2, w, CH * e)
        if ui.encima == zid then tooltipCopia(s) end
    end
end

-- huecos de pedidos

local function sitioHueco(i)
    local _, _, col = geo()
    local alto = math.floor((col.h - 10) / 3)
    return { x = col.x + 2, y = col.y + 10 + (i - 1) * alto, w = col.w - 4, h = alto - 2 }
end

local function huecoDe(pe)
    for i = 1, 3 do
        if huecos[i] and huecos[i].pe == pe then return huecos[i], i end
    end
end

local function libre()
    for i = 1, 3 do
        if not huecos[i] then return i end
    end
end

local function totalSobres(pe)
    if pe.prod then return productos[pe.prod].sobres end
    return pe.n or 1
end

local CODIGOS = { blister = "BL", tin = "TIN", etb = "ETB", caja = "CAJA" }

local function postit(r, h)
    local pe = h.pe
    local x, y, w = r.x, r.y, r.w
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 1, y - 1, w + 2, 18)
    lg.setColor(p.amarillo)
    lg.rectangle("fill", x, y, w, 16)
    lg.setColor(p.naranja)
    lg.rectangle("fill", x, y + 15, w, 1)
    local nombre = pe.nombre:upper()
    while #nombre > 1 and fuentes.ancho(nombre) > w - 4 do nombre = nombre:sub(1, -2) end
    fuentes.texto(nombre, x, y + 2, 1, p.negro, "center", w)
    local cod = pe.prod and (CODIGOS[pe.prod] or pe.prod:upper()) or pe.codigo
    fuentes.texto(cod .. " " .. h.sobres .. "/" .. totalSobres(pe), x, y + 9, 1, p.rojo, "center", w)
end

-- sobre acolchado: crece tapando el taquito, se cierra con el nombre y sale volando
local function dibujarEnvio(r, h)
    local t = h.envio
    local cx = r.x + r.w / 2
    local w, alto = r.w - 2, r.h - 22
    local q = math.min(1, t / 0.35)
    local vuelo = math.max(0, t - 0.75)
    local x = cx + vuelo * vuelo * 900
    local yb = r.y + 20 + alto - vuelo * vuelo * 260
    local a = alto * fx.salidaSuave(q)
    lg.push()
    lg.translate(x, yb - alto / 2)
    lg.rotate(vuelo * 1.5)
    local top = alto / 2 - a
    lg.setColor(p.negro)
    lg.rectangle("fill", -w / 2 - 1, top - 1, w + 2, a + 2)
    lg.setColor(0.80, 0.64, 0.42)
    lg.rectangle("fill", -w / 2, top, w, a)
    lg.setColor(0.62, 0.46, 0.28)
    for yy = top + 2, alto / 2 - 2, 3 do
        for xx = -w / 2 + 1 + (math.floor(yy) % 2), w / 2 - 2, 4 do lg.rectangle("fill", xx, yy, 1, 1) end
    end
    if q >= 1 then
        lg.rectangle("fill", -w / 2, top + 6, w, 1)
        ui.caja(-w / 2 + 3, -4, w - 6, 15, p.blanco)
        local nombre = h.pe.nombre:upper()
        while #nombre > 1 and fuentes.ancho(nombre) > w - 8 do nombre = nombre:sub(1, -2) end
        fuentes.texto("PARA", -w / 2, -2, 1, p.gris, "center", w)
        fuentes.texto(nombre, -w / 2, 4, 1, p.negro, "center", w)
        if t > 0.5 then
            lg.setColor(p.rojo)
            lg.rectangle("fill", w / 2 - 12, top + 2, 9, 7)
            lg.setColor(p.blanco)
            lg.rectangle("fill", w / 2 - 11, top + 3, 7, 5)
        end
    end
    lg.pop()
end

local function dibujarHueco(i)
    local r = sitioHueco(i)
    local h = huecos[i]
    lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.3)
    lg.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
    if not h then
        fuentes.texto("LIBRE", r.x, r.y + r.h / 2 - 2, 1, { p.verde[1], p.verde[2], p.verde[3], 0.6 }, "center", r.w)
        return
    end
    if h.envio and h.envio > 0 then return end
    postit(r, h)
    local n = #h.cartas
    local cx = r.x + r.w / 2
    if n == 0 then
        lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.5)
        lg.rectangle("line", cx - CW / 2 + 0.5, r.y + 22.5, CW - 1, CH - 1)
        fuentes.texto(h.pe.empezado and "ABRIENDO" or "ESPERA", r.x, r.y + 22 + CH / 2 - 2, 1,
            { p.verde[1], p.verde[2], p.verde[3], 0.7 }, "center", r.w)
        return
    end
    local cantosN = grosor(n, MAX_CANTOS_PEDIDO)
    local y = r.y + 22 + CH / 2
    cantos(cx, y + CH / 2, cantosN, i, nil, CW)
    carta.dibujar(h.cartas[n], cx, y, 1, 1, 0, true, nil, false, { quieta = true })
end

function zonas.dibujar()
    if not zonas.activas() then return end
    dibujarTaco()
    dibujarHits()
    if zonas.columna() then
        local _, _, col = geo()
        marco(col, "PEDIDOS")
        for i = 1, 3 do dibujarHueco(i) end
    end
end

-- lo que va por encima de todo: el abanico, lo que vuela y los envios
-- la mesa lo pone mientras llevas algo en la mano (no se abre el abanico)
zonas.ocupado = false

-- de que taco es el abanico: "taco" o "holo"
local grupoAbanico = "taco"

local function abanicoAbierto()
    if apertura.bloqueada() or zonas.ocupado or zonas.pilaCogida or pilaVuelve then return false end
    if ui.tactil then return abiertoTactil end
    return ui.encima ~= nil and ui.encima:sub(1, 3) == "zt_" and tEncima >= ESPERA_ABANICO
end

local function sitiosAbanico(n)
    local taco, hitsR = geo()
    -- que la primera y la ultima (giradas) no se salgan del tapete
    local media = CW * ESCALA_ABANICO / 2
    local x1, x2 = taco.x + media + 2, hitsR.x + hitsR.w - media - 4
    local paso = n > 1 and math.min(CW * ESCALA_ABANICO + 4, (x2 - x1) / (n - 1)) or 0
    local total = paso * (n - 1)
    local x0 = x1 + math.max(0, ((x2 - x1) - total) / 2)
    return x0, paso, taco.y - 24
end

local function dibujarAbanico()
    local l = grupoAbanico == "holo" and hitsDe(true) or lista("taco")
    local desde = math.max(1, #l - MAX_ABANICO + 1)
    local n = #l - desde + 1
    if n <= 0 then return end
    local taco, hitsR = geo()
    local x0, paso, base = sitiosAbanico(n)
    local w, h = CW * ESCALA_ABANICO, CH * ESCALA_ABANICO
    -- fondo para que se lea y para que no se cierre al pasar entre cartas
    local fx1, fy1 = taco.x, base - h / 2 - 14
    lg.setColor(p.negro[1], p.negro[2], p.negro[3], 0.55)
    lg.rectangle("fill", fx1, fy1, hitsR.x + hitsR.w - fx1, base + h / 2 + 10 - fy1)
    -- solo encima del taco: el taco sigue a mano para arrastrarlo
    ui.zona("zt_fondo", fx1, fy1, hitsR.x + hitsR.w - fx1, taco.y - fy1)
    local mid = (n - 1) / 2
    local sobreCarta
    for k = 1, n do
        local s = l[desde + k - 1]
        local x = x0 + (k - 1) * paso
        local d = mid > 0 and (k - 1 - mid) / mid or 0
        local y = base + d * d * 8
        local zid = "zt_" .. s.u
        local alza = ui.encima == zid and -8 or 0
        dibujarCopia(s, x, y + alza, ESCALA_ABANICO, d * 0.12, zid)
        posZona[s.u] = { x, y + alza, ESCALA_ABANICO }
        local ancho = (k < n) and math.max(4, paso) or w
        ui.zona(zid, x - w / 2, y - h / 2, ancho, h)
        if ui.encima == zid then sobreCarta = s end
    end
    fuentes.texto((grupoAbanico == "holo" and "HOLOS: " or "TU TACO: ") .. #l .. (#l > n and ("  (LAS ÚLTIMAS " .. n .. ")") or ""), fx1 + 4, fy1 + 3, 1, p.grisclaro)
    if sobreCarta then tooltipCopia(sobreCarta) end
end

local function dibujarVuelos()
    -- las tuyas, al taco o a su sitio en hits
    local listaHits = hitsDe(false)
    local nHolos = 0
    for _, s in ipairs(hitsDe(true)) do
        if not volando(s) then nHolos = nHolos + 1 end
    end
    local nTaco = 0
    for _, s in ipairs(lista("taco")) do
        if not volando(s) then nTaco = nTaco + 1 end
    end
    for _, s in ipairs(partida.mesa) do
        if volando(s) and s.vuelo.t >= 0 and s.u ~= zonas.cogida then
            local v = s.vuelo
            local x1, y1, e1
            if s.zona == "taco" then
                x1, y1 = sitioTaco(nTaco + 1)
                e1 = E_TACO
            elseif esHolo(partida.carta(s.id)) then
                x1, y1 = sitioHolo(nHolos + 1)
                e1 = E_TACO
            else
                local pos = 1
                for i, o in ipairs(listaHits) do if o == s then pos = i end end
                local x0, paso, y, e = sitiosHits(#listaHits)
                x1, y1, e1 = x0 + (pos - 1) * paso, y, e
            end
            local q = fx.salidaSuave(v.t / VUELO)
            dibujarCopia(s, fx.lerp(v.x, x1, q), fx.lerp(v.y, y1, q) - math.sin(q * math.pi) * 20, fx.lerp(v.e, e1, q), 0)
        end
    end
    -- las del comprador, a su hueco
    for _, v in ipairs(vuelos) do
        local _, i = huecoDe(v.pe)
        if i then
            local r = sitioHueco(i)
            local q = fx.salidaSuave(math.min(1, v.t / VUELO))
            local x1, y1 = r.x + r.w / 2, r.y + 22 + CH / 2
            carta.dibujar(v.def, fx.lerp(v.x, x1, q), fx.lerp(v.y, y1, q) - math.sin(q * math.pi) * 20, fx.lerp(v.e, 1, q), fx.lerp(v.e, 1, q),
                0, true, nil, false, { quieta = true })
        end
    end
end

function zonas.dibujarEncima()
    if not zonas.activas() and #vuelos == 0 then return end
    dibujarVuelos()
    for i = 1, 3 do
        local h = huecos[i]
        if h and h.envio and h.envio > 0 then dibujarEnvio(sitioHueco(i), h) end
    end
    if abanicoAbierto() and #lista("taco") > 0 then dibujarAbanico() end
end

-- donde va el boton RECOGER MESA con las zonas a la vista
function zonas.sitioRecoger()
    local _, r = geo()
    return r.x + r.w - 76, r.y - 7, 72, 12
end

-- logica

-- cartas tuyas del ultimo sobre: al taco o a hits, volando desde el resumen
function zonas.recibir(cartas)
    for _, c in ipairs(cartas) do
        local s = c.copia and partida.aLaMesa(c.def.id, c.copia, true)
        if s then
            s.zona = esHit(c.def) and "hits" or "taco"
            s.vuelo = { x = c.x, y = c.y, e = c.escala, t = 0 }
        end
    end
end

-- cartas de un comprador: a su hueco; si ya esta completo, se envia
function zonas.recibirComprador(pe, cartas)
    local h = huecoDe(pe)
    if not h then
        local i = libre()
        if not i then
            fx.texto(T.x + T.w / 2, T.y + 100, "ENVIADO A " .. pe.nombre:upper(), p.lima)
            return
        end
        h = { pe = pe, cartas = {}, sobres = 0 }
        huecos[i] = h
    end
    h.sobres = h.sobres + 1
    for _, c in ipairs(cartas) do
        table.insert(vuelos, { pe = pe, def = c.def, x = c.x, y = c.y, e = c.escala, t = 0 })
    end
    if pe.acabado then h.envio = -VUELO - 0.35 end
end

local function enPedidos(pe)
    for _, o in ipairs(directo.pedidos()) do
        if o == pe then return true end
    end
    return false
end

function zonas.update(dt)
    for _, s in ipairs(partida.mesa) do
        if s.vuelo then
            s.vuelo.t = s.vuelo.t + dt
            if s.vuelo.t >= VUELO then
                s.vuelo = nil
                sonido.tocar("encima", 0.9)
            end
        end
    end
    for k = #vuelos, 1, -1 do
        local v = vuelos[k]
        v.t = v.t + dt
        if v.t >= VUELO then
            local h = huecoDe(v.pe)
            if h then table.insert(h.cartas, v.def) end
            table.remove(vuelos, k)
        end
    end
    -- los compradores nuevos cogen hueco
    if zonas.columna() then
        for _, pe in ipairs(directo.pedidos()) do
            if not huecoDe(pe) then
                local i = libre()
                if i then huecos[i] = { pe = pe, cartas = {}, sobres = 0 } end
            end
        end
    end
    for i = 1, 3 do
        local h = huecos[i]
        if h and h.envio then
            local antes = h.envio
            h.envio = h.envio + dt
            if antes <= 0 and h.envio > 0 then
                sonido.tocar("giro")
            end
            if antes < 0.75 and h.envio >= 0.75 then
                local r = sitioHueco(i)
                local cobrado = h.pe.cobrado or 0
                if cobrado > 0 then fx.texto(r.x + r.w / 2, r.y + 10, "+" .. ui.dinero(cobrado), p.amarillo) end
                sonido.tocar("moneda")
                directo.enviado(h.pe)
            end
            if h.envio >= ENVIO then huecos[i] = nil end
        elseif h and not enPedidos(h.pe) and (not h.pe.empezado or not directo.activo()) then
            -- caducado, rechazado o el directo se acabo a medias
            huecos[i] = nil
        end
    end
    if not ui.tactil then abiertoTactil = false end
    -- el abanico se abre si te quedas encima del taco (no al pasar de largo);
    -- ya abierto, sigue mientras estes en sus cartas
    if ui.encima == "zt_pila" or ui.encima == "zt_holo" then
        local g = ui.encima == "zt_holo" and "holo" or "taco"
        if g ~= grupoAbanico then grupoAbanico, tEncima = g, 0 end
    end
    if ui.encima == "zt_pila" or ui.encima == "zt_holo" or (tEncima >= ESPERA_ABANICO and ui.encima and ui.encima:sub(1, 3) == "zt_") then
        tEncima = tEncima + dt
    else
        tEncima = 0
    end
    if pilaVuelve then
        pilaVuelve.t = pilaVuelve.t + dt
        if pilaVuelve.t >= VUELO then
            pilaVuelve = nil
            sonido.tocar("encima", 0.9)
        end
    end
end

-- devuelve true si se ha encargado del click (las cartas las coge la mesa
-- con zonas.coger: arrastradas van al tapete o a tu caja; tocadas, INSPECCIONAR)
function zonas.presionar(id)
    if not id or id:sub(1, 3) ~= "zt_" and id:sub(1, 3) ~= "zh_" then
        abiertoTactil = false
        return false
    end
    if id == "zt_fondo" then
        if ui.tactil then abiertoTactil = false end
        return true
    end
    return false
end

-- con el dedo, tocar el taco sin arrastrarlo abre o cierra el abanico
function zonas.alternarAbanico(grupo)
    grupo = grupo or "taco"
    if abiertoTactil and grupo ~= grupoAbanico then
        grupoAbanico = grupo
        return
    end
    grupoAbanico = grupo
    abiertoTactil = not abiertoTactil
end

-- la copia de las zonas en (x, y) (un hit, una del abanico o la de arriba del taco)
function zonas.copiaEn(x, y)
    if not zonas.activas() then return nil end
    local id = ui.zonaEn(x, y, "zh_") or ui.zonaEn(x, y, "zt_")
    if not id or id == "zt_fondo" then return nil end
    local s
    if id == "zt_pila" then
        local l = lista("taco")
        s = l[#l]
    elseif id == "zt_holo" then
        local l = hitsDe(true)
        s = l[#l]
    else
        local u = tonumber(id:sub(4))
        for _, e in ipairs(partida.mesa) do
            if e.u == u and e.zona then s = e end
        end
    end
    return s and copiaDe(s)
end

-- una carta suelta en la mesa (la promo del blister o del tin) va a su zona;
-- espera: segundos antes de salir volando (mientras se abre el producto)
function zonas.recibirSuelta(s, x, y, e, espera)
    s.zona = esHit(partida.carta(s.id)) and "hits" or "taco"
    s.vuelo = { x = x, y = y, e = e, t = -(espera or 0) }
end

-- la carta de una zona para arrastrarla: entrada, centro y escala (o nil)
function zonas.coger(id)
    if not id or (id:sub(1, 3) ~= "zt_" and id:sub(1, 3) ~= "zh_") or id == "zt_fondo" then return nil end
    local s
    if id == "zt_pila" then
        local l = lista("taco")
        s = l[#l]
    elseif id == "zt_holo" then
        local l = hitsDe(true)
        s = l[#l]
    else
        local u = tonumber(id:sub(4))
        for _, e in ipairs(partida.mesa) do
            if e.u == u and e.zona then s = e end
        end
    end
    local pos = s and (id == "zt_pila" and posPila or id == "zt_holo" and posHolo or posZona[s.u])
    if not pos then return nil end
    return s, pos[1], pos[2], pos[3]
end

-- el taco entero en la mano, en (x, y) y girado a
function zonas.dibujarPilaEn(x, y, a)
    local l = lista("taco")
    if #l == 0 then return end
    lg.push()
    lg.translate(x, y)
    lg.rotate(a or 0)
    pintarPila(l, E_MANO, 1)
    lg.pop()
end

-- el taco soltado fuera del armario vuelve volando a su sitio
function zonas.soltarPila(x, y, a)
    pilaVuelve = { x = x, y = y, e = E_MANO, a = a or 0, t = 0 }
end

-- cuanto mide el taco en la mano (para el cartel de encima)
function zonas.altoPila()
    return CH * E_MANO
end

-- (x, y) cae dentro del taco o de los hits
function zonas.enZona(x, y)
    if not zonas.activas() then return false end
    local _, hitsR = geo()
    -- el taco: su recuadro, y lo que asome por arriba
    local taco = marcoTaco(#lista("taco"))
    for _, r in ipairs({ taco, hitsR }) do
        if x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h then return true end
    end
    return false
end

-- todas las cartas de un grupo ("taco" o "hits"), tambien las sacadas al tapete
function zonas.grupo(nombre)
    local l = {}
    for _, s in ipairs(partida.mesa) do
        if s.zona == nombre or s.vuelve == nombre then table.insert(l, s) end
    end
    return l
end

-- para las pruebas
function zonas.huecos() return huecos end

function zonas.reiniciar()
    huecos, vuelos = {}, {}
    abiertoTactil = false
    pilaVuelve, posPila, tEncima = nil, nil, 0
    zonas.pilaCogida = false
end

return zonas
