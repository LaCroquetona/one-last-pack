local cartas = require "datos.cartas"
local sets = require "datos.sets"
local sobres = require "datos.sobres"
local productos = require "datos.productos"
local datos = require "datos.mercado"
local rarezas = require "datos.rarezas"
local datosCalendario = require "datos.calendario"
local datosPromos = require "datos.promos"
local calendario = require "src.calendario"

local mercado = {}

-- dias de historial que se guardan de cada carta y sobre
local HISTORIAL = 120
local MAX_NOTICIAS = 40
-- version del estado del mercado: la 2 tiene rachas, golpes, tiradas y 1ª edicion aparte
local VERSION = 2

local porId = {}
for _, c in ipairs(cartas) do
    porId[c.id] = c
end

-- todas las del set, las que cuentan para el 100% y las de fuera de set
-- (las promos van aparte: promosDe, sin las colabs; colabs: todas en orden)
local delSet, baseDe, fueraDe, promosDe, colabs, canal = {}, {}, {}, {}, {}, {}
for _, c in ipairs(cartas) do
    if c.colab then
        table.insert(colabs, c)
    elseif c.promo == "canal" then
        table.insert(canal, c)
    elseif c.promo then
        promosDe[c.set] = promosDe[c.set] or {}
        table.insert(promosDe[c.set], c)
    else
        delSet[c.set] = delSet[c.set] or {}
        table.insert(delSet[c.set], c)
        local t = c.fuera and fueraDe or baseDe
        t[c.set] = t[c.set] or {}
        table.insert(t[c.set], c)
    end
end
-- las de fuera de set, por numero (las secretas primero)
for _, l in pairs(fueraDe) do
    table.sort(l, function(a, b) return a.num < b.num end)
end

-- cada carta tiene su "caracter" fijo: unas valen algo mas que otras de su rareza
local function variacion(id)
    local rng = love.math.newRandomGenerator(id * 104729 + 7)
    local a, b = datos.variacion[1], datos.variacion[2]
    return a + rng:random() * (b - a)
end

-- las ALT, SILVER y GOLDEN tienen su precio en sets.valores (alt_holo...)
local base = {}
for _, c in ipairs(cartas) do
    if c.promo then
        base[c.id] = c.valor * datos.valorCartas
    else
        base[c.id] = sets[c.set].valores[rarezas.clave(c) or c.rareza] * variacion(c.de or c.id) * datos.valorCartas
    end
end

-- todo lo que cambia y se guarda con la partida
mercado.estado = nil

local function normal()
    -- Box-Muller
    local u1, u2 = math.max(1e-9, love.math.random()), love.math.random()
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function azar(a, b)
    return a + love.math.random() * (b - a)
end

-- las tendencias van en logaritmo: nunca pasan de x max ni de 1/max
local function limitar(v, max)
    local l = math.log(max)
    return math.max(-l, math.min(l, v))
end

function mercado.dia()
    return mercado.estado.dia
end

function mercado.carta(id)
    return porId[id]
end

function mercado.cartasDe(setId)
    return delSet[setId] or {}
end

function mercado.baseDe(setId)
    return baseDe[setId] or {}
end

function mercado.fueraDe(setId)
    return fueraDe[setId] or {}
end

-- las promos de un set (P001...; sin colabs) y todas las colabs
function mercado.promosDe(setId)
    return promosDe[setId] or {}
end

function mercado.colabs()
    return colabs
end

-- las placas del canal (cartas que no se venden)
function mercado.placas()
    return canal
end

function mercado.base(id)
    return base[id]
end

function mercado.fase(setId, dia)
    return calendario.fase(setId, dia or mercado.estado.dia)
end

function mercado.salido(setId)
    return calendario.salido(setId, mercado.estado.dia)
end

function mercado.disponible(id)
    return mercado.estado.cartas[id] ~= nil
end

-- sets que ya han salido, en orden
function mercado.setsSalidos()
    local lista = {}
    for _, s in ipairs(sets.lista) do
        if calendario.salido(s.id, mercado.estado.dia) then table.insert(lista, s) end
    end
    return lista
end

-- si ya existen copias normales (ha habido reimpresion) ese dia (nil: hoy)
function mercado.hayNormales(setId, dia)
    local fase, i = calendario.fase(setId, dia or mercado.estado.dia)
    return fase == "reimpresion" or ((fase == "agotado" or fase == "rumor") and i.k > 0)
end

-- fases: lo que pesa el calendario en el precio

-- precio de la version normal respecto a su valor base, segun la fase de su set
local function multNormal(def, dia)
    local F = datos.fases
    local fase, i = calendario.fase(def.set, dia)
    local m
    if fase == "reimpresion" then
        m = F.reimpresion
    elseif (fase == "agotado" or fase == "rumor") and i.k > 0 then
        m = F.reimpresion + F.subidaTrasReimpresion * (1 - math.exp(-i.e / F.ritmoTrasReimpresion))
        if fase == "rumor" then m = m * (1 - F.caidaRumor) end
    else
        m = 1
    end
    if def.chase then m = 1 + (m - 1) * F.chase end
    return m
end

-- crecimiento vintage tras dias agotada: sin techo, cada vez mas despacio
local function vintage(dias, alfa)
    return (1 + math.max(0, dias) / datos.vintage.tau) ^ alfa
end

-- promos: sin reimpresion, suben solas con el tiempo desde que sale su set
-- (unos dias quietas; las doradas, mas deprisa)
local function crecePromo(def, dias)
    local S = datosPromos.subida
    local d = dias - S.quietas
    if d <= 0 then return 1 end
    local k = def.oro and S.oro or (def.plata and S.plata or S.normal)
    return (1 + d / S.ritmo) ^ k
end

local function salidaSet(set)
    local plan = calendario.plan[set]
    return plan and plan[1] and plan[1].desde or 1
end

-- colab: sube deprisa los primeros dias y luego sigue como una promo
local function multColab(def, dia)
    local C = datosPromos.colab
    local salida = mercado.estado.colabs and mercado.estado.colabs.dias[def.id] or dia
    local d = math.max(0, dia - salida)
    return (1 + C.sube * math.min(C.diasSube, d)) * crecePromo(def, d)
end

-- precio de la 1ª edicion respecto a su valor base, segun la fase de su set
local function multPrimera(def, dia)
    if def.colab then return multColab(def, dia) end
    if def.promo then return crecePromo(def, dia - salidaSet(def.set)) end
    local F = datos.fases
    local fase, i = calendario.fase(def.set, dia)
    if fase == "impresion" then
        local hype = 1 + (def.chase and F.hype.chase or F.hype.normal) * math.exp(-i.d / F.hype.dias)
        return hype * (1 - F.caidaTirada * i.d / (i.d + i.quedan))
    end
    local fin = calendario.finPrimera(def.set, dia) or 0
    local m = (1 - F.caidaTirada) * vintage(fin, def.chase and datos.vintage.alfaChase or datos.vintage.alfa)
    if fase == "rumor" then m = m * (1 - datos.vintage.caidaRumor) end
    return m
end

-- tirada de 1ª edicion: cuanto mas grande, mas baratas sus copias
local function efectoTirada(setId)
    local s = mercado.estado.sets[setId]
    return (s.tirada / datos.tirada.minima) ^ (-datos.tirada.efecto)
end

local function efectoBurbuja(id)
    local b = mercado.estado.burbujas[id]
    return b and b.m or 1
end

-- tendencia (en logaritmo) de una carta en una edicion: la suya y la de su set
local function tendencia(id, primera)
    local e = mercado.estado
    local c, s = e.cartas[id], e.sets[porId[id].set]
    local t = c.t + c.g + s.t + s.g
    if primera then return t + s.t1 + s.g1 end
    return t + c.gn
end

local function objetivo(def, dia, primera)
    local m = primera and multPrimera(def, dia) * (def.promo and 1 or efectoTirada(def.set)) or multNormal(def, dia)
    return base[def.id] * m * math.exp(tendencia(def.id, primera)) * efectoBurbuja(def.id)
end

-- valor de mercado en centimos (decimal; se redondea al cobrar).
-- Antes de la primera reimpresion no hay normales: vale lo de la 1ª edicion
function mercado.valorExacto(id, primera)
    local e = mercado.estado
    local c = e.cartas[id]
    local v
    if not c then
        v = base[id]
    elseif primera or not c.pn then
        v = c.p1
    else
        v = c.pn
    end
    return v / (1 + (e.saturacion[id] or 0) * datos.saturacion.golpe)
end

function mercado.valor(id, primera)
    return math.max(1, math.floor(mercado.valorExacto(id, primera) + 0.5))
end

-- linea de los tooltips: lo que vale o, si no se vende (placas), eso
function mercado.textoValor(id, primera)
    if porId[id] and porId[id].noVende then return "No se vende" end
    return "Valor " .. require("src.ui").dinero(mercado.valor(id, primera))
end

function mercado.ventaRapida(id, primera)
    return math.max(1, math.floor(mercado.valorExacto(id, primera) * datos.ventaRapida + 0.5))
end

-- lo que te llega de una venta del movil despues de la comision
-- la mejora CUENTA PRO la rebaja (la pone partida.aplicarSuerte)
mercado.rebajaComision = 0
function mercado.comision()
    return datos.comision - mercado.rebajaComision
end

function mercado.trasComision(precio)
    return math.max(1, math.floor(precio * (1 - mercado.comision()) + 0.5))
end

-- historial de precios de una edicion (nil: la normal si ya hay, si no la 1ª):
-- h0 = dia del primer valor, h = precios (0 = ese dia no existia), v = ventas
function mercado.historial(id, primera)
    local c = mercado.estado.cartas[id]
    if not c then return nil end
    -- sin reimpresiones todas son de 1ª edicion
    if not c.pn then primera = true end
    return c.h0, primera and c.h1 or c.hn, c.v
end

-- cuanto ha cambiado en los ultimos dias: 0.12 = +12%
function mercado.cambio(id, dias, primera)
    local c = mercado.estado.cartas[id]
    if not c then return 0 end
    if not c.pn then primera = true end
    local h = primera and c.h1 or c.hn
    if #h < 2 then return 0 end
    local k = math.max(1, #h - (dias or 7))
    -- el primer dia del rango en que ya existia esa edicion
    while k < #h and h[k] <= 0 do k = k + 1 end
    if h[k] <= 0 then return 0 end
    return mercado.valorExacto(id, primera) / math.max(1, h[k]) - 1
end

function mercado.vendida(id, cantidad)
    local e = mercado.estado
    e.saturacion[id] = (e.saturacion[id] or 0) + cantidad
end

-- tirada de 1ª edicion

-- tu compra de sobres de 1ª edicion: si pasa de tu cuota, se imprimen mas
function mercado.comprados(setId, n)
    local s = mercado.estado.sets[setId]
    s.comprados = s.comprados + n
    s.tirada = math.max(s.tirada, math.ceil(s.comprados / s.cuota))
end

-- tirada de 1ª edicion de un set y la parte que has comprado tu (0-1)
function mercado.tirada(setId)
    local s = mercado.estado.sets[setId]
    return s.tirada, s.comprados / s.tirada
end

-- tienda

-- precio en la tienda y edicion, o nil si no hay sobres en la tienda
-- mejoras MAYORISTA (rebaja) y PROVEEDOR (sobres de mas al dia); las pone
-- partida.aplicarSuerte
mercado.rebajaTienda, mercado.extraStock = 0, 0

function mercado.enTienda(tipo)
    local hay, primera = calendario.enTienda(tipo.set, mercado.estado.dia)
    if not hay then return nil end
    if mercado.rebajaTienda > 0 then
        return math.max(10, math.floor(tipo.precio * (1 - mercado.rebajaTienda) / 10 + 0.5) * 10), primera
    end
    return tipo.precio, primera
end

function mercado.stock(tipo)
    return mercado.estado.stock[tipo.id] or 0
end

-- cajas de sobres que quedan hoy en la tienda
function mercado.stockCajas(tipo)
    return (mercado.estado.cajas or {})[tipo.id] or 0
end

-- precio de una caja en la tienda (nil si hoy no se vende)
function mercado.precioCaja(tipo)
    local precio = mercado.enTienda(tipo)
    if not precio then return nil end
    local C = sobres.caja
    return math.floor(precio * C.sobres * (1 - C.descuento) / 10 + 0.5) * 10
end

-- lo que vale una caja cerrada: sus sobres cerrados a precio de mercado
function mercado.valorCaja(tipo, primera)
    return mercado.valorProd(productos.caja, tipo, primera)
end

-- productos de un set que se venden (sin la caja si sinCaja)
function mercado.productosDe(tipo, sinCaja)
    local lista = {}
    for _, x in ipairs(productos.lista) do
        if x.sale ~= false and not x.mix and (not x.sets or x.sets[tipo.set]) and not (sinCaja and x.id == "caja") then
            table.insert(lista, x)
        end
    end
    return lista
end

local function claveProd(prod, tipo) return prod.id .. ":" .. tipo.id end

-- precio en la tienda (nil si hoy no se vende)
function mercado.precioProd(prod, tipo)
    if prod.id == "caja" then return mercado.precioCaja(tipo) end
    local precio = mercado.enTienda(tipo)
    if not precio then return nil end
    return math.floor((precio * prod.sobres * prod.precio + (prod.extra or 0)) / 10 + 0.5) * 10
end

function mercado.stockProd(prod, tipo)
    if prod.id == "caja" then return mercado.stockCajas(tipo) end
    return (mercado.estado.prods or {})[claveProd(prod, tipo)] or 0
end

function mercado.gastarProd(prod, tipo)
    if prod.id == "caja" then
        mercado.estado.cajas[tipo.id] = math.max(0, mercado.stockCajas(tipo) - 1)
        return
    end
    local k = claveProd(prod, tipo)
    mercado.estado.prods[k] = math.max(0, (mercado.estado.prods[k] or 0) - 1)
end

-- Mercado propio de cada producto sellado: su valor sale del set (lo que valen
-- sus sobres cerrados y lo que trae) y encima lleva su propia tendencia, que
-- sube y baja sola de un dia a otro (nunca por lo que haga el jugador)
local function tendenciaProd(prod, tipo)
    local t = (mercado.estado.prodMerc or {})[claveProd(prod, tipo)]
    return t and math.exp(t.f) or 1
end

-- lo que vale cerrado segun el set, sin su tendencia
local function baseProd(prod, tipo, primera)
    if prod.id == "caja" then
        local v = mercado.sellado(tipo, primera) or mercado.sellado(tipo, not primera) or tipo.precio
        return v * sobres.caja.sobres * sobres.caja.valor
    end
    local v = mercado.sellado(tipo, primera) or mercado.sellado(tipo, not primera) or tipo.precio
    return v * prod.sobres * sobres.caja.valor + (prod.fundas or 0) * productos.valorFunda + (prod.tops or 0) * productos.valorTop
end

-- lo que vale cerrado hoy
function mercado.valorProd(prod, tipo, primera)
    local v = baseProd(prod, tipo, primera) * tendenciaProd(prod, tipo)
    -- mientras la tienda lo vende, venderlo nunca da mas de lo que cuesta nuevo
    local nuevo = mercado.precioProd(prod, tipo)
    if nuevo then v = math.min(v, nuevo * 0.9) end
    return math.floor(v / 10 + 0.5) * 10
end

-- historial de un producto (dia del primero, 1ª edicion, reimpresion)
function mercado.historialProd(prod, tipo)
    local t = (mercado.estado.prodMerc or {})[claveProd(prod, tipo)]
    if not t then return nil end
    return t.h0, t.h1, t.hr
end

-- cuanto ha cambiado en los ultimos dias (0,1 = +10%), o nil sin historial
function mercado.cambioProd(prod, tipo, primera, dias)
    local _, h1, hr = mercado.historialProd(prod, tipo)
    local h = primera and h1 or hr
    if not h or #h < 2 then return nil end
    local antes = h[math.max(1, #h - (dias or 7))]
    if not antes or antes <= 0 or h[#h] <= 0 then return nil end
    return h[#h] / antes - 1
end


function mercado.gastarStock(tipo, n)
    local s = mercado.estado.stock
    s[tipo.id] = math.max(0, (s[tipo.id] or 0) - n)
end

local function stockDelDia(tipo, dia)
    local fase, i = calendario.fase(tipo.set, dia)
    local S = datos.stock
    if fase == "impresion" then
        return i.d < datosCalendario.lanzamiento and S.lanzamiento or S.impresion
    elseif fase == "reimpresion" then
        return S.reimpresion
    end
    return 0
end

-- sobres cerrados de reventa

local function objetivoSellado(tipo, dia, primera)
    local S = datos.sellados
    local st = mercado.estado.sets[tipo.set]
    local fase, i = calendario.fase(tipo.set, dia)
    local m
    if primera then
        if fase == "impresion" then
            m = S.tirada * (1 + S.hype * math.exp(-i.d / datos.fases.hype.dias))
        else
            m = S.tirada * vintage(calendario.finPrimera(tipo.set, dia) or 0, datos.vintage.alfaSellado)
        end
        m = m * efectoTirada(tipo.set) * math.exp(st.t + st.g + st.t1 + st.g1)
    else
        if fase == "reimpresion" then
            m = S.reimpresion
        elseif i and i.k and i.k > 0 then
            m = S.reimpresion + S.subidaReimpresion * (1 - math.exp(-(i.e or 0) / S.ritmoReimpresion))
        else
            return nil
        end
        m = m * math.exp(st.t + st.g)
    end
    if fase == "rumor" then m = m * (1 - S.caidaRumor) end
    return tipo.precio * m
end

-- precio de mercado de un sobre cerrado, o nil si esa edicion no existe aun
function mercado.sellado(tipo, primera)
    local s = mercado.estado.sellados[tipo.id]
    if not s then return nil end
    local v = primera and s.p1 or s.pr
    if not v or v <= 0 then return nil end
    return math.max(1, math.floor(v + 0.5))
end

function mercado.compraReventa(tipo, primera)
    local v = mercado.sellado(tipo, primera)
    if not v then return nil end
    return math.floor(v * (1 + datos.recargoReventa) + 0.5)
end

function mercado.historialSellado(tipo)
    local s = mercado.estado.sellados[tipo.id]
    if not s then return nil end
    return s.h0, s.h1, s.hr
end

local function recortar(lista)
    local quitar = #lista - HISTORIAL
    if quitar <= 0 then return 0 end
    for _ = 1, quitar do table.remove(lista, 1) end
    return quitar
end

-- noticias

-- las de hoy, para avisar en el movil (la lista de noticias tiene tope y no
-- se puede contar por su largo)
local deHoy = {}

local function anadirNoticia(n)
    local e = mercado.estado
    table.insert(deHoy, n)
    n.dia = e.dia
    if n.clave and datos.explicaciones[n.clave] and not e.vistos[n.clave] then
        e.vistos[n.clave] = true
        n.explica = datos.explicaciones[n.clave]
    end
    table.insert(e.noticias, 1, n)
    while #e.noticias > MAX_NOTICIAS do table.remove(e.noticias) end
    return n
end
mercado.anadirNoticia = anadirNoticia

-- eventos: los dias que una noticia hace que se venda mas (barras de volumen)
local function anadirEvento(tipo, meta, efecto, dias)
    table.insert(mercado.estado.eventos, { tipo = tipo, objetivo = meta, efecto = efecto, dias = dias })
end

local function tono(efecto)
    if efecto > 1 then return "sube" end
    if efecto < 1 then return "baja" end
    return "info"
end

-- carta al azar de los sets salidos; las chase salen mas
local function cartaAlAzar(soloChase)
    local lista, total = {}, 0
    for id in pairs(mercado.estado.cartas) do
        local def = porId[id]
        if not soloChase or def.chase then
            local peso = def.chase and 6 or (1 + rarezas[def.rareza].nivel * 0.5)
            table.insert(lista, { def = def, peso = peso })
            total = total + peso
        end
    end
    table.sort(lista, function(a, b) return a.def.id < b.def.id end)
    local t = love.math.random() * total
    for _, x in ipairs(lista) do
        t = t - x.peso
        if t <= 0 then return x.def end
    end
    return lista[#lista] and lista[#lista].def
end

local FILTROS_SET = {
    soloAgotado = function(id) return calendario.fase(id, mercado.estado.dia) == "agotado" end,
    soloTienda = function(id)
        local f = calendario.fase(id, mercado.estado.dia)
        return f == "impresion" or f == "reimpresion"
    end,
    soloReimpreso = function(id) return mercado.hayNormales(id) end,
}

-- sets a los que puede tocarles una noticia
local function setsPara(plantilla)
    local lista = {}
    for _, s in ipairs(mercado.setsSalidos()) do
        local vale = true
        for clave, filtro in pairs(FILTROS_SET) do
            if plantilla[clave] and not filtro(s.id) then vale = false end
        end
        if vale then table.insert(lista, s) end
    end
    return lista
end

-- golpe de una noticia a una carta o a un set (en logaritmo); se va deshaciendo
local function golpear(plantilla, cartaId, setId)
    local g = math.log(plantilla.efecto)
    local e = mercado.estado
    if cartaId then
        local c = e.cartas[cartaId]
        if plantilla.soloNormal then c.gn = c.gn + g else c.g = c.g + g end
        return
    end
    local s = e.sets[setId]
    if plantilla.solo1 then
        s.g1 = s.g1 + g
    elseif plantilla.soloNormal then
        for _, def in ipairs(delSet[setId]) do
            local c = e.cartas[def.id]
            if c then c.gn = c.gn + g end
        end
    else
        s.g = s.g + g
    end
end

-- clave (opcional, herramientas de desarrollador): fuerza ese tipo de noticia
function mercado.noticia(clave)
    local e = mercado.estado
    local candidatas, total = {}, 0
    local hayChase = false
    for id in pairs(e.cartas) do
        if porId[id].chase then hayChase = true break end
    end
    for _, n in ipairs(datos.noticias) do
        local vale = (clave == nil and e.dia >= (n.desde or 0) or n.clave == clave) and not (n.soloChase and not hayChase)
        if vale and n.tipo == "set" then vale = #setsPara(n) > 0 end
        if vale then
            table.insert(candidatas, n)
            total = total + n.peso
        end
    end
    if #candidatas == 0 then return nil end
    local t = love.math.random() * total
    local plantilla = candidatas[#candidatas]
    for _, n in ipairs(candidatas) do
        t = t - n.peso
        if t <= 0 then plantilla = n break end
    end

    local n = { clave = plantilla.clave, tono = plantilla.clave == "escasez" and "info" or tono(plantilla.efecto) }
    if plantilla.tipo == "carta" then
        local def = cartaAlAzar(plantilla.soloChase)
        if not def then return nil end
        n.texto = plantilla.texto:gsub("{carta}", rarezas.nombre(def))
        n.carta = def.id
        n.set = def.set
        golpear(plantilla, def.id)
        anadirEvento("carta", def.id, plantilla.efecto, plantilla.dias)
    else
        local lista = setsPara(plantilla)
        local s = lista[love.math.random(#lista)]
        n.texto = plantilla.texto:gsub("{set}", s.nombre)
        n.set = s.id
        golpear(plantilla, nil, s.id)
        anadirEvento("set", s.id, plantilla.efecto, plantilla.dias)
        if plantilla.tirada then
            local st = e.sets[s.id]
            local tope = math.max(st.tirada, datos.tirada.minima * datos.tirada.maxNoticias)
            st.tirada = math.min(tope, math.floor(st.tirada * azar(plantilla.tirada[1], plantilla.tirada[2])))
        end
        if plantilla.clave == "escasez" then
            local tipo = sobres[s.sobre]
            e.stock[tipo.id] = math.floor(mercado.stock(tipo) / 2)
        end
    end
    return anadirNoticia(n)
end

-- torneo nacional: aviso unos dias antes y luego el mazo campeon

-- ya: (herramientas de desarrollador) lo anuncia o lo resuelve ahora
function mercado.torneo(ya)
    local e = mercado.estado
    local T = datos.torneo
    local t = e.torneo
    if t then
        if e.dia < t.dia and not ya then return end
        e.torneo = nil
        local lista = {}
        for _, def in ipairs(delSet[t.set] or {}) do
            if e.cartas[def.id] then table.insert(lista, def) end
        end
        if #lista == 0 then return end
        local mazo = {}
        for _ = 1, math.min(T.cartas, #lista) do
            local def = table.remove(lista, love.math.random(#lista))
            local plantilla = { efecto = azar(T.efecto[1], T.efecto[2]) }
            golpear(plantilla, def.id)
            anadirEvento("carta", def.id, plantilla.efecto, T.dias)
            table.insert(mazo, def)
        end
        local nombres = {}
        for _, def in ipairs(mazo) do table.insert(nombres, rarezas.nombre(def)) end
        local texto = #nombres > 1 and (table.concat(nombres, ", ", 1, #nombres - 1) .. " y " .. nombres[#nombres]) or nombres[1]
        return anadirNoticia({ clave = "torneoNacional", tono = "sube", carta = mazo[1].id, set = t.set,
                               texto = "Torneo nacional: el mazo campeón lleva " .. texto })
    end
    if not ya and (e.dia < T.desde or love.math.random() >= T.prob) then return end
    local salidos = mercado.setsSalidos()
    if #salidos == 0 then return end
    local s = salidos[love.math.random(#salidos)]
    local dias = ya and 1 or love.math.random(T.aviso[1], T.aviso[2])
    e.torneo = { dia = e.dia + dias, set = s.id }
    return anadirNoticia({ clave = "torneoAviso", tono = "info", set = s.id,
                           texto = "Torneo nacional en " .. dias .. (dias == 1 and " día" or " días") .. ": se espera mucho del " .. s.nombre })
end

-- burbujas

function mercado.burbujaAhora(def)
    local B = datos.burbuja
    def = def or cartaAlAzar(true)
    if not def or mercado.estado.burbujas[def.id] then return end
    mercado.estado.burbujas[def.id] = { fase = "sube", d = 0, dur = love.math.random(B.dias[1], B.dias[2]), m = 1 }
    return anadirNoticia({ clave = "habla", tono = "sube", carta = def.id, set = def.set, texto = "Todo el mundo habla de " .. rarezas.nombre(def) })
end

local function avanzarBurbujas()
    local B = datos.burbuja
    local e = mercado.estado
    for id, b in pairs(e.burbujas) do
        b.d = b.d + 1
        if b.fase == "sube" then
            b.m = b.m * azar(B.subida[1], B.subida[2])
            if b.d >= b.dur then b.fase, b.d = "pincha", 0 end
        elseif b.fase == "pincha" then
            b.m = b.m * B.pinchazo
            if b.d == 1 then
                local def = porId[id]
                anadirNoticia({ clave = "burbuja", tono = "baja", carta = id, set = def.set, texto = "Se desinfla " .. rarezas.nombre(def) .. ": todo el mundo vende a la vez" })
            end
            if b.d >= B.diasPinchazo then b.fase, b.d = "vuelve", 0 end
        else
            b.m = b.m + (1 - b.m) * 0.15
            if math.abs(b.m - 1) < 0.03 then e.burbujas[id] = nil end
        end
    end
    if e.dia >= B.desdeDia and love.math.random() < B.prob then
        local def = cartaAlAzar(true)
        if def and not e.burbujas[def.id] then mercado.burbujaAhora(def) end
    end
end

-- rachas: cada carta y cada set van un tiempo subiendo, bajando o quietos

local TIPOS_RACHA = { "quieta", "sube", "baja" }

local function nuevaRacha(R, fuerza)
    local total = 0
    for _, w in pairs(R.pesos) do total = total + w end
    local t = love.math.random() * total
    local tipo = "quieta"
    for _, k in ipairs(TIPOS_RACHA) do
        t = t - R.pesos[k]
        if t <= 0 then tipo = k break end
    end
    local d = 0
    if tipo ~= "quieta" then d = azar(R.deriva[1], R.deriva[2]) * (fuerza or 1) * (tipo == "sube" and 1 or -1) end
    return { d = d, dias = love.math.random(R.dias[1], R.dias[2]) }
end

-- un dia de una tendencia (x.t) y su golpe (x.g): sigue su racha, vuelve un
-- poco hacia cero y el golpe se deshace dejando su memoria.
-- Devuelve cuanto ha cambiado en total y si ha empezado una racha nueva
local function avanzarTendencia(x, R, fuerza)
    local G = datos.golpes
    local antes = x.t + x.g
    x.r.dias = x.r.dias - 1
    local nueva = x.r.dias <= 0
    if nueva then x.r = nuevaRacha(R, fuerza) end
    local suelta = x.g * G.baja
    x.g = x.g - suelta
    x.t = limitar(x.t * (1 - R.vuelta) + x.r.d + suelta * G.memoria, R.max)
    return x.t + x.g - antes, nueva
end

local function avanzarRachas()
    local e = mercado.estado
    local R = datos.rachas
    local G = datos.golpes
    local cambiosChase = {}
    for id, c in pairs(e.cartas) do
        local def = porId[id]
        local cambio = avanzarTendencia(c, R.carta, def.chase and R.chase or 1)
        c.gn = c.gn * (1 - G.baja)
        if def.chase then
            local suma = cambiosChase[def.set] or { 0, 0 }
            suma[1], suma[2] = suma[1] + cambio, suma[2] + 1
            cambiosChase[def.set] = suma
        end
    end
    for _, s in ipairs(mercado.setsSalidos()) do
        local st = e.sets[s.id]
        local _, nueva = avanzarTendencia(st, R.set)
        -- la 1ª edicion del set tiene su propio golpe (almacenes) con su memoria
        local suelta = st.g1 * G.baja
        st.g1 = st.g1 - suelta
        st.t1 = limitar(st.t1 * (1 - R.set.vuelta) + suelta * G.memoria, R.set.max)
        -- las chase arrastran al set
        local suma = cambiosChase[s.id]
        if suma then st.t = limitar(st.t + datos.contagio * suma[1] / suma[2], R.set.max) end
        if nueva and math.abs(st.r.d) >= R.noticiaModa and love.math.random() < 0.6 then
            if st.r.d > 0 then
                anadirNoticia({ clave = "moda", tono = "sube", set = s.id, texto = "El " .. s.nombre .. " se pone de moda: todo el mundo lo busca" })
            else
                anadirNoticia({ clave = "caida", tono = "baja", set = s.id, texto = "El " .. s.nombre .. " pierde interés entre los coleccionistas" })
            end
        end
    end
end

-- dia a dia

local function efectoNoticias(def)
    local m = 1
    for _, ev in ipairs(mercado.estado.eventos) do
        if (ev.tipo == "carta" and ev.objetivo == def.id) or (ev.tipo == "set" and ev.objetivo == def.set) then
            -- tanto si sube como si baja, se vende mas
            m = m * math.max(ev.efecto, 1 / ev.efecto)
        end
    end
    return m
end

local function volumenDia(def, dia)
    local fase = calendario.fase(def.set, dia)
    local actividad = 1
    if calendario.lanzando(def.set, dia) then
        actividad = 3
    elseif fase == "impresion" or fase == "reimpresion" then
        actividad = 1.5
    elseif fase == "agotado" then
        actividad = 0.6
    end
    local v = datos.volumen[def.rareza] * actividad * efectoNoticias(def)
    local b = mercado.estado.burbujas[def.id]
    if b and b.fase ~= "vuelve" then v = v * datos.burbuja.volumen * (b.fase == "pincha" and 1.5 or 1) end
    return math.max(0, math.floor(v * azar(0.5, 1.5) + 0.5))
end

local function apuntar(c, dia)
    table.insert(c.h1, math.floor(c.p1 + 0.5))
    table.insert(c.hn, c.pn and math.floor(c.pn + 0.5) or 0)
    table.insert(c.v, volumenDia(porId[c.id], dia))
    local q = recortar(c.h1)
    recortar(c.hn)
    recortar(c.v)
    c.h0 = c.h0 + q
end

local function nuevoSet()
    local T = datos.tirada
    return {
        t = 0, g = 0, t1 = 0, g1 = 0, r = { d = 0, dias = 0 },
        tirada = T.minima, comprados = 0, cuota = azar(T.cuota[1], T.cuota[2]),
    }
end

local function nuevaCarta(id)
    return { id = id, t = 0, g = 0, gn = 0, r = { d = 0, dias = love.math.random(1, 10) }, h1 = {}, hn = {}, v = {} }
end

-- las cartas y sobres de los sets que salen hoy entran en el mercado
local function abrirSets(dia)
    local e = mercado.estado
    for _, s in ipairs(sets.lista) do
        e.sets[s.id] = e.sets[s.id] or nuevoSet()
        if calendario.salido(s.id, dia) then
            for _, l in ipairs({ delSet[s.id], promosDe[s.id] or {} }) do
                for _, def in ipairs(l) do
                    if not e.cartas[def.id] then
                        local c = nuevaCarta(def.id)
                        c.h0 = dia
                        e.cartas[def.id] = c
                        c.p1 = objetivo(def, dia, true)
                        if mercado.hayNormales(def.set, dia) and not def.promo then c.pn = objetivo(def, dia, false) end
                        apuntar(c, dia)
                    end
                end
            end
            local tipo = sobres[s.sobre]
            if not e.sellados[tipo.id] then
                local p1 = objetivoSellado(tipo, dia, true)
                e.sellados[tipo.id] = { p1 = p1, pr = 0, h0 = dia, h1 = { math.floor(p1 + 0.5) }, hr = { 0 } }
            end
        end
    end
end

local function reponerProds(dia)
    mercado.estado.prods = {}
    for _, tipo in ipairs(sobres.lista) do
        local n = stockDelDia(tipo, dia)
        for _, prod in ipairs(mercado.productosDe(tipo, true)) do
            mercado.estado.prods[claveProd(prod, tipo)] = n > 0 and prod.porDia or 0
        end
    end
end

local function reponerStock(dia)
    mercado.estado.cajas = mercado.estado.cajas or {}
    for _, tipo in ipairs(sobres.lista) do
        local n = stockDelDia(tipo, dia)
        mercado.estado.stock[tipo.id] = n > 0 and n + mercado.extraStock or 0
        mercado.estado.cajas[tipo.id] = n > 0 and sobres.caja.porDia or 0
    end
    reponerProds(dia)
end

local function avisosCalendario(dia)
    for _, a in ipairs(calendario.avisos(dia)) do
        local t = (a.clave == "agotado" or a.clave == "ultimos") and "sube" or ((a.clave == "rumor" or a.clave == "reimpresion") and "baja" or "info")
        anadirNoticia({ clave = a.clave, tono = t, set = a.set.id, texto = a.texto, calendario = true })
    end
end

-- Colabs: ONE LAST PACK X MARCA. Salen cada 15-20 dias con unas pocas copias
-- que solo se compran en el mercado; la gente las compra deprisa y suben.
-- estado.colabs = { sig = dia de la siguiente, n = cuantas han salido, salidas = ids,
--   dias = { [id] = dia en que salio }, stock = { [id] = copias que quedan } }
local function estadoColabs()
    local e = mercado.estado
    if not e.colabs then
        local C = datosPromos.colab
        e.colabs = { sig = C.primera + love.math.random(0, 3), n = 0, salidas = {}, dias = {}, stock = {} }
    end
    return e.colabs
end

function mercado.avanzarColabs(dia)
    local e = mercado.estado
    local k = estadoColabs()
    local C = datosPromos.colab
    -- la gente compra las que quedan
    for id, n in pairs(k.stock) do
        if n > 0 and k.dias[id] < dia then
            k.stock[id] = math.max(0, n - math.max(1, math.floor(n * (C.venden[1] + love.math.random() * (C.venden[2] - C.venden[1])) + 0.5)))
        end
    end
    if dia < k.sig then return end
    -- la siguiente que no ha salido y cuyo set ya esta en las tiendas
    local def
    for _, c in ipairs(colabs) do
        if not k.dias[c.id] and calendario.salido(c.set, dia) then
            def = c
            break
        end
    end
    k.sig = dia + love.math.random(C.cada[1], C.cada[2])
    if not def then return end
    k.n = k.n + 1
    k.salidas = k.salidas or {}
    table.insert(k.salidas, def.id)
    k.dias[def.id] = dia
    k.stock[def.id] = love.math.random(C.stock[1], C.stock[2])
    local c = nuevaCarta(def.id)
    c.h0 = dia
    e.cartas[def.id] = c
    c.p1 = objetivo(def, dia, true)
    apuntar(c, dia)
    anadirNoticia({ clave = "colab", tono = "sube", set = def.set, carta = def.id,
        texto = "ONE LAST PACK X " .. def.marca .. ": sale la carta colab. Pocas copias, solo en el mercado" })
end

-- colabs a la venta ahora (salidas y con stock), la ultima primero
function mercado.colabsALaVenta()
    local k = estadoColabs()
    local lista = {}
    local salidas = k.salidas or {}
    for i = #salidas, 1, -1 do
        local def = porId[salidas[i]]
        if def and (k.stock[def.id] or 0) > 0 then table.insert(lista, def) end
    end
    return lista
end

function mercado.stockColab(id)
    return estadoColabs().stock[id] or 0
end

function mercado.comprarColab(id)
    local k = estadoColabs()
    if (k.stock[id] or 0) <= 0 then return false end
    k.stock[id] = k.stock[id] - 1
    return true
end

-- sobres de torneo de un set: lo que cuestan hoy y cuantos quedan (nil si no hay)
function mercado.sobreTorneo(tipo)
    if not calendario.salido(tipo.set, mercado.estado.dia) then return nil end
    local T = datosPromos.torneo
    local media, pesos = 0, 0
    for _, def in ipairs(promosDe[tipo.set] or {}) do
        if def.promo == "torneo" then
            media = media + mercado.valorExacto(def.id, true) * def.peso
            pesos = pesos + def.peso
        end
    end
    if pesos == 0 then return nil end
    local plan = calendario.plan[tipo.set]
    local desde = plan and plan[1] and plan[1].desde or 1
    local dias = math.max(0, mercado.estado.dia - desde)
    local precio = math.floor(media / pesos * T.margen * (1 + dias / T.subida) / 10 + 0.5) * 10
    local hoy = (mercado.estado.torneoHoy or {})[tipo.id] or 0
    local stock = math.max(1, T.stock - math.floor(dias / T.menosCada)) - hoy
    return precio, math.max(0, stock)
end

function mercado.gastarTorneo(tipo)
    mercado.estado.torneoHoy = mercado.estado.torneoHoy or {}
    mercado.estado.torneoHoy[tipo.id] = (mercado.estado.torneoHoy[tipo.id] or 0) + 1
end

function mercado.nuevo(semilla)
    semilla = semilla or love.math.random(1, 2 ^ 30)
    calendario.plan = calendario.generar(semilla)
    mercado.estado = {
        version = VERSION, dia = 1, semilla = semilla, cartas = {}, sets = {}, sellados = {}, saturacion = {},
        noticias = {}, eventos = {}, burbujas = {}, stock = {}, vistos = {},
    }
    abrirSets(1)
    reponerStock(1)
    avisosCalendario(1)
end

-- Partidas de antes (mercado v1): cada carta tenia un solo precio e historial.
-- Se ponen las tendencias de forma que el precio de hoy no salte
local function desdeV1(e)
    e.version = VERSION
    e.sets = {}
    for _, s in ipairs(sets.lista) do e.sets[s.id] = nuevoSet() end
    local viejas = e.cartas
    e.cartas = {}
    for id, vieja in pairs(viejas) do
        local def = porId[id]
        if def then
            local c = nuevaCarta(id)
            c.h0, c.v = vieja.h0, vieja.v or {}
            e.cartas[id] = c
            local normales = mercado.hayNormales(def.set, e.dia)
            -- el precio que habia se respeta: es el de la normal si ya habia, si no el de la 1ª edicion
            local hoy = vieja.p or base[id]
            c.p1 = objetivo(def, e.dia, true)
            if normales then
                c.pn = hoy
                c.gn = math.log(hoy / objetivo(def, e.dia, false))
            else
                c.t = limitar(math.log(hoy / c.p1), datos.rachas.carta.max)
                c.p1 = hoy
            end
            for i, valor in ipairs(vieja.h or {}) do
                if normales and mercado.hayNormales(def.set, c.h0 + i - 1) then
                    c.hn[i] = valor
                    c.h1[i] = math.floor(valor * c.p1 / hoy + 0.5)
                else
                    c.hn[i] = 0
                    c.h1[i] = valor
                end
            end
            while #c.v < #c.h1 do table.insert(c.v, 0) end
        end
    end
end

-- al cargar una partida el plan se vuelve a sacar de la semilla
function mercado.cargar(estado)
    calendario.plan = calendario.generar(estado.semilla)
    mercado.estado = estado
    if (estado.version or 1) < VERSION then desdeV1(estado) end
    for _, s in ipairs(sets.lista) do
        estado.sets[s.id] = estado.sets[s.id] or nuevoSet()
    end
    -- ids que ya no estan en la lista de cartas (promos de una version anterior)
    for _, t in ipairs({ estado.cartas, estado.burbujas or {}, estado.saturacion or {} }) do
        for id in pairs(t) do
            if not porId[id] then t[id] = nil end
        end
    end
    -- cartas nuevas de un set que ya habia salido (el set 1 paso de 40 a 80)
    abrirSets(estado.dia)
    -- partidas de antes de las cajas: hoy llegan las de siempre
    if not estado.cajas then
        estado.cajas = {}
        for _, tipo in ipairs(sobres.lista) do
            estado.cajas[tipo.id] = stockDelDia(tipo, estado.dia) > 0 and sobres.caja.porDia or 0
        end
    end
    -- partidas de antes de los productos (v0.9.5 o antes): hoy llegan los de siempre
    if not estado.prods then reponerProds(estado.dia) end
end

-- se persigue el objetivo en logaritmo: subir x2 y bajar a la mitad pesan igual
local function hacia(actual, meta, seguir)
    local l = math.log(actual) + (math.log(meta) - math.log(actual)) * seguir + normal() * datos.ruido
    return math.max(1, math.exp(l))
end

-- un dia mas en el mercado de cada producto: la tendencia tiene inercia (rachas)
-- y vuelve poco a poco a 0
local function avanzarProds(dia)
    local e = mercado.estado
    e.prodMerc = e.prodMerc or {}
    local R = datos.productos
    for _, tipo in ipairs(sobres.lista) do
        if e.sellados[tipo.id] then
            for _, prod in ipairs(mercado.productosDe(tipo)) do
                local k = claveProd(prod, tipo)
                local t = e.prodMerc[k]
                if not t then
                    t = { f = 0, v = 0, h0 = dia, h1 = {}, hr = {} }
                    e.prodMerc[k] = t
                else
                    t.v = t.v * R.inercia + normal() * R.ruido
                    local f = t.f * R.vuelta + t.v
                    t.f = limitar(f, R.max)
                    -- en el tope la racha se acaba
                    if t.f ~= f then t.v = -t.v * 0.5 end
                end
                table.insert(t.h1, mercado.valorProd(prod, tipo, true))
                table.insert(t.hr, mercado.sellado(tipo, false) and mercado.valorProd(prod, tipo, false) or 0)
                local q = recortar(t.h1)
                recortar(t.hr)
                t.h0 = t.h0 + q
            end
        end
    end
end

function mercado.pasarDia()
    local e = mercado.estado
    deHoy = {}
    e.dia = e.dia + 1
    local dia = e.dia

    for id, s in pairs(e.saturacion) do
        s = s * datos.saturacion.recuperacion
        e.saturacion[id] = s > 0.05 and s or nil
    end
    for i = #e.eventos, 1, -1 do
        local ev = e.eventos[i]
        ev.dias = ev.dias - 1
        if ev.dias <= 0 then table.remove(e.eventos, i) end
    end

    abrirSets(dia)
    reponerStock(dia)
    avisosCalendario(dia)
    mercado.avanzarColabs(dia)
    e.torneoHoy = {}
    avanzarBurbujas()
    if love.math.random() < datos.probNoticia then mercado.noticia() end
    mercado.torneo()
    avanzarRachas()

    for id, c in pairs(e.cartas) do
        if c.h0 + #c.h1 - 1 < dia then
            local def = porId[id]
            local seguir = e.burbujas[id] and datos.seguimientoBurbuja or datos.seguimiento
            c.p1 = hacia(c.p1, objetivo(def, dia, true), seguir)
            if mercado.hayNormales(def.set, dia) and not def.promo then
                local meta = objetivo(def, dia, false)
                c.pn = hacia(c.pn or meta, meta, seguir)
            end
            apuntar(c, dia)
        end
    end

    for _, tipo in ipairs(sobres.lista) do
        local s = e.sellados[tipo.id]
        if s and s.h0 + #s.h1 - 1 < dia then
            s.p1 = hacia(s.p1, objetivoSellado(tipo, dia, true), datos.seguimiento)
            local o2 = objetivoSellado(tipo, dia, false)
            if o2 then s.pr = hacia(s.pr > 0 and s.pr or o2, o2, datos.seguimiento) end
            table.insert(s.h1, math.floor(s.p1 + 0.5))
            table.insert(s.hr, math.floor(s.pr + 0.5))
            local q = recortar(s.h1)
            recortar(s.hr)
            s.h0 = s.h0 + q
        end
    end
    avanzarProds(dia)

    return deHoy
end

-- herramientas de desarrollador: un set al azar se pone de moda (o pierde interes)
function mercado.forzarRacha(sube)
    local lista = mercado.setsSalidos()
    local s = lista[love.math.random(#lista)]
    local st = mercado.estado.sets[s.id]
    local R = datos.rachas.set
    st.r = { d = (sube and 1 or -1) * R.deriva[2] * 1.5, dias = R.dias[2] }
    return anadirNoticia(sube and { clave = "moda", tono = "sube", set = s.id, texto = "El " .. s.nombre .. " se pone de moda: todo el mundo lo busca" }
        or { clave = "caida", tono = "baja", set = s.id, texto = "El " .. s.nombre .. " pierde interés entre los coleccionistas" })
end

-- dias con noticias de esta carta o de su set (para marcarlos en la grafica)
function mercado.diasNoticia(id)
    local def = porId[id]
    local dias = {}
    for _, n in ipairs(mercado.estado.noticias) do
        if n.carta == id or (n.set == def.set and not n.carta) then dias[n.dia] = n end
    end
    return dias
end

-- las cartas que mas suben (signo 1) o bajan (signo -1) en dias; filtro opcional
function mercado.movimientos(signo, cuantas, dias, filtro)
    local lista = {}
    for id in pairs(mercado.estado.cartas) do
        if not filtro or filtro(id) then
            table.insert(lista, { def = porId[id], cambio = mercado.cambio(id, dias) })
        end
    end
    table.sort(lista, function(a, b)
        if a.cambio ~= b.cambio then return a.cambio * signo > b.cambio * signo end
        return a.def.id < b.def.id
    end)
    local res = {}
    for i = 1, cuantas do
        if lista[i] and lista[i].cambio * signo > 0.005 then table.insert(res, lista[i]) end
    end
    return res
end

return mercado
