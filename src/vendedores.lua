-- Vendedores de segunda mano del movil: ofertas de sobres, cajas y cartas.
-- Las ofertas de cada dia salen de una semilla (dia + producto), asi no hay
-- que guardarlas: solo se guarda cuanto les has comprado hoy.
local datos = require "datos.vendedores"
local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
local mercado = require "src.mercado"
local partida = require "src.partida"
local logros = require "src.logros"

local vendedores = {}

-- los vendedores son siempre los mismos: nombre, estrellas y ventas de base
local gente = {}
do
    local r = love.math.newRandomGenerator(4242)
    for i = 1, datos.cuantos do
        local nombre = datos.nombres[(i - 1) % #datos.nombres + 1]
        local estrellas = math.max(2.4, 5 - math.abs(r:randomNormal(0.45, 0)))
        gente[i] = {
            nombre = nombre,
            estrellas = math.floor(estrellas * 10 + 0.5) / 10,
            ventas = math.floor(math.exp(r:random() * 7.5)),
            ritmo = r:random() * 3,
        }
    end
end

local function hash(cad)
    local h = 5381
    for i = 1, #cad do h = (h * 33 + cad:byte(i)) % 2147483647 end
    return h
end

-- lo comprado hoy a cada oferta (se olvida al cambiar de dia)
local function comprado()
    local v = partida.vendidos
    if not v or v.dia ~= mercado.dia() then
        v = { dia = mercado.dia(), n = {} }
        partida.vendidos = v
    end
    return v.n
end

-- ventas que lleva un vendedor (suben con los dias)
function vendedores.ventas(g)
    return g.ventas + math.floor(mercado.dia() * g.ritmo)
end

-- clave: el producto; ref: precio de referencia; clase: tienda/sellado/carta
local function ofertas(clave, ref, clase, cantidad, stock, cosa)
    if not ref or ref <= 0 then return {} end
    local r = love.math.newRandomGenerator(mercado.dia() * 7919 + hash(clave))
    local n = r:random(cantidad[1], cantidad[2])
    local P, hechas, usados = datos.precio[clase], comprado(), {}
    local lista = {}
    for i = 1, n do
        local k
        repeat k = r:random(#gente) until not usados[k]
        usados[k] = true
        local g = gente[k]
        local media = P.media + (g.estrellas - 4) * datos.precio.porEstrella
        local f = math.max(P.min, math.min(P.max, r:randomNormal(P.desv, media)))
        local unidades = r:random(stock[1], stock[2])
        -- los chollos de verdad duran poco: como mucho dos
        if f < 0.9 then unidades = math.min(unidades, 2) end
        local id = clave .. ":" .. i
        local quedan = unidades - (hechas[id] or 0)
        if quedan > 0 then
            table.insert(lista, { id = id, vendedor = g, precio = math.max(1, math.floor(ref * f + 0.5)),
                                  quedan = quedan, ref = ref, cosa = cosa })
        end
    end
    table.sort(lista, function(a, b) return a.precio < b.precio end)
    return lista
end

-- la referencia de un sobre o una caja y su clase de precio
local function referencia(tipo, primera, caja)
    if not mercado.salido(tipo.set) then return nil end
    local precio, primeraTienda = mercado.enTienda(tipo)
    if precio and (primeraTienda or false) == (primera or false) then
        return caja and mercado.precioCaja(tipo) or precio, "tienda"
    end
    local s = mercado.sellado(tipo, primera)
    if not s then return nil end
    if caja then return s * sobres.caja.sobres * datos.cajaReventa, "sellado" end
    return s, "sellado"
end

function vendedores.deSobre(tipo, primera)
    local ref, clase = referencia(tipo, primera, false)
    return ofertas("s" .. tipo.id .. (primera and 1 or 0), ref, clase, datos.ofertas.sobre, datos.stock.sobre,
        { que = "sobre", tipo = tipo.id, primera = primera })
end

function vendedores.deCaja(tipo, primera)
    local ref, clase = referencia(tipo, primera, true)
    return ofertas("c" .. tipo.id .. (primera and 1 or 0), ref, clase, datos.ofertas.caja, datos.stock.caja,
        { que = "caja", tipo = tipo.id, primera = primera })
end

function vendedores.deCarta(id, primera)
    local def = mercado.carta(id)
    if not def or not mercado.salido(def.set) then return {} end
    if not primera and not mercado.hayNormales(def.set) then return {} end
    local nivel = rarezas[def.rareza].nivel
    return ofertas("k" .. id .. (primera and 1 or 0), mercado.valorExacto(id, primera), "carta",
        datos.cartas[nivel] or { 0, 1 }, datos.stock.carta, { que = "carta", id = id, primera = primera })
end

-- compra una unidad de la oferta; devuelve lo pagado
function vendedores.comprar(o)
    if not o or o.quedan <= 0 or partida.dinero < o.precio then return false end
    local hechas = comprado()
    hechas[o.id] = (hechas[o.id] or 0) + 1
    o.quedan = o.quedan - 1
    partida.dinero = partida.dinero - o.precio
    local c = o.cosa
    if c.que == "sobre" then
        partida.meterSobres(c.tipo, 1, c.primera)
    elseif c.que == "caja" then
        partida.meterCaja(c.tipo, c.primera)
    else
        partida.anadir(c.id, c.primera)
    end
    logros.marcar("vendedor")
    partida.guardar()
    return o.precio
end

return vendedores
