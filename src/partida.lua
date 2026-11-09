local cartas = require "datos.cartas"
local sobres = require "datos.sobres"
local calendario = require "src.calendario"
local productos = require "datos.productos"
local datosFundas = require "datos.fundas"
local rarezas = require "datos.rarezas"
local datosMercado = require "datos.mercado"
local premios = require "datos.premios"
local sets = require "datos.sets"
local mercado = require "src.mercado"
local generador = require "src.generador"
local datosMejoras = require "datos.mejoras"
local datosEncargos = require "datos.encargos"

local partida = {}

-- varias partidas: la 1 es la de siempre (partida.lua), las demas partida2.lua, partida3.lua
partida.RANURAS = 3
partida.ranura = 1
local ARCHIVO = "partida.lua"
local function archivoDe(n) return n == 1 and "partida.lua" or ("partida" .. n .. ".lua") end
-- v6: cada copia se guarda por separado. Las partidas v5 se convierten al cargar
local VERSION = 6

local porId = {}
for _, c in ipairs(cartas) do
    porId[c.id] = c
end

-- Cada copia es una tabla { u = numero unico, p = 1ª edicion, f = en funda,
-- a = publicada en el movil, m = en la mesa }. partida.inv[id] = lista de copias.

-- sube cada vez que cambia algo del inventario o del dinero: lo que se calcula
-- caro (valor de la coleccion, ventas en lote) se guarda hasta que cambie
partida.rev = 0
local function tocar()
    partida.rev = partida.rev + 1
end
partida.tocar = tocar

local memo = {}
local enOrden = {}
-- f se recalcula solo si ha cambiado la partida o el dia
function partida.memo(clave, f)
    local m = memo[clave]
    local firma = partida.rev * 100000 + mercado.dia()
    if m and m.firma == firma then return m.v1, m.v2 end
    local v1, v2 = f()
    memo[clave] = { firma = firma, v1 = v1, v2 = v2 }
    return v1, v2
end

function partida.nueva()
    partida.dinero = sobres.inicio.dinero
    partida.abiertos = 0
    partida.inv = {}
    partida.uid = 0
    partida.guardados = {}
    partida.guardados1 = {}
    partida.anuncios = {}
    partida.orden = {}
    partida.mesa = {}
    partida.seguidas = {}
    -- fundaDesde / topDesde: nivel de rareza desde el que se protegen solas (0 = nunca)
    partida.opciones = { fundaDesde = 4, topDesde = 5 }
    partida.fundasLibres = 20
    partida.topsLibres = 0
    -- fundas y tops con diseno: cuantas tienes de cada id (las basicas, arriba)
    partida.fundasDiseno, partida.topsDiseno = {}, {}
    -- los disenos conseguidos alguna vez (fundario) y lo que ensena cada cajita
    partida.fundario = { f = {}, t = {} }
    partida.cajitas = {}
    -- funda del MIX que esta a la venta: { id, hasta } y las que ya han salido
    partida.temporada = nil
    partida.temporadas = {}
    -- carpetas propias: { id, nombre, tapa, b = { [bolsillo] = { id, u } } }; la copia lleva k = id de su carpeta
    partida.carpetas = {}
    partida.sigCarpeta = 1
    -- promos: sobrecitos sin abrir ("etb:set1", "caja:set1", "torneo:set1" = cuantos),
    -- placas del canal (nivel = dia en que llego), dia de la ultima preventa y
    -- copias compradas de cada colab
    partida.promoSobres = {}
    partida.promoMesa = {}      -- sobrecitos de la ETB o la caja que esperan en la mesa: { o, t }
    partida.correo = {}         -- placas del canal por abrir (nivel), en sobres de correo
    partida.placas = {}
    partida.preventaDia = nil
    partida.colabCompradas = {}
    partida.promosNuevas = {}  -- avisos para main.lua
    -- sobres y cajas apartados: no salen en la mesa ("s:set1:1" = sobres de 1ª ed del set 1)
    partida.apartados = {}
    partida.premios = {}
    partida.premiosNuevos = {}
    partida.encargosHechos = {}
    partida.encargosCaducados = {}
    -- canal de directos: nombre, idioma del chat ("es" o "en") y lo que se ha conseguido
    partida.canal = { nombre = "MI_CANAL", idioma = "es", seguidores = 0, directos = 0, propinas = 0, record = 0 }
    partida.mejoras = {}
    partida.cajas, partida.cajas1 = {}, {}
    -- productos sellados (blister, tin, ETB): "etb:set1" = cuantos; prods1 los de 1ª ed
    partida.prods, partida.prods1 = {}, {}
    -- fundas y tops de un producto, sueltos en la mesa (fundaId/topId: su diseno; nil la basica)
    partida.sueltos = { fundas = 0, tops = 0 }
    partida.huecosArmario = {}   -- armario SELLADO: { k = "etb:set1:1", n } por hueco (false: libre)
    partida.red = { racha = 0, dia = -99 }   -- red de rescate (partida.rescate)
    partida.cajaAbierta = nil    -- caja empezada en la mesa (tipo, quedan, primera, prod: si no es caja)
    partida.vendidos = nil      -- lo comprado hoy a los vendedores del movil
    partida.logros = {}         -- id del logro = dia en que se consiguio
    partida.encargos = {}        -- aceptados: { nombre, tipo, n, hechos, pago, dias, primera }
    partida.ofertasEncargo = {}  -- sin aceptar: lo mismo + espera
    partida.tutorial = 1         -- paso del tutorial (false: hecho o saltado)
    partida.desbloqueos = {}     -- lo que ya ha salido (src/desbloqueos.lua)
    partida.sequia = {}          -- sobres seguidos sin holo, por tipo (la piedad)
    partida.tiradas = {}         -- sobres que se guardaron sin abrir: ya tienen sus cartas
    partida.pistas = {}          -- bocadillos de la mesa que ya se han visto
    partida.guia = { visto = {} } -- explicaciones ya vistas (src/guia.lua)
    partida.buscadas = {}        -- cartas que buscas: id = true
    partida.encontradas = {}     -- buscadas que acaban de salir (main.lua avisa)
    for tipo, n in pairs(sobres.inicio.sobres) do
        partida.guardados[tipo] = n
        partida.guardados1[tipo] = n
    end
    mercado.nuevo()
    partida.cartera = { h0 = 1, h = { 0 } }
    generador.sequia = partida.sequia
    partida.aplicarSuerte()
    enOrden = {}
    tocar()
end

function partida.carta(id)
    return porId[id]
end

-- consultas de copias

local function lista(id)
    return partida.inv[id]
end

function partida.copias(id)
    local l = lista(id)
    return l and #l or 0
end

local function contar(id, condicion)
    local l = lista(id)
    if not l then return 0 end
    local n = 0
    for _, c in ipairs(l) do
        if condicion(c) then n = n + 1 end
    end
    return n
end

-- copias de 1ª edicion (primera = true), normales (false) o todas (nil)
function partida.deEdicion(id, primera)
    if primera == nil then return partida.copias(id) end
    return contar(id, function(c) return (c.p or false) == primera end)
end

function partida.enfundadas(id)
    return contar(id, function(c) return c.f end)
end

function partida.publicadas(id, primera)
    return contar(id, function(c) return c.a and (primera == nil or (c.p or false) == primera) end)
end

-- copias que estan en tu armario y no en un anuncio
function partida.libres(id, primera)
    return contar(id, function(c) return not c.a and not c.k and (primera == nil or (c.p or false) == primera) end)
end

-- las copias de una carta en el orden en que se enseñan:
-- primero las de 1ª edicion, luego las enfundadas, luego por antiguedad
local function ordenCopias(a, b)
    if (a.p or false) ~= (b.p or false) then return a.p == true end
    if (a.f or false) ~= (b.f or false) then return a.f == true end
    return a.u < b.u
end

function partida.lista(id)
    local l = lista(id)
    if not l then return {} end
    local copia = {}
    for i, c in ipairs(l) do copia[i] = c end
    table.sort(copia, ordenCopias)
    return copia
end

function partida.copia(id, u)
    local l = lista(id)
    if not l then return nil end
    for _, c in ipairs(l) do
        if c.u == u then return c end
    end
end

-- set: "s1", "s2"... o nil para contar todos. Con set solo cuenta las del
-- set (las de fuera de set van aparte, ver partida.fuera)
function partida.distintas(set)
    local n = 0
    for id in pairs(partida.inv) do
        local def = porId[id]
        if not set or (def.set == set and not def.fuera and not def.promo) then n = n + 1 end
    end
    return n
end

-- Red de rescate (no se avisa): si estas arruinado, cada sobre que abres
-- tiene mas opciones de traer una secreta normal para venderla. Como mucho
-- una vez cada RED.dias dias, para que sea una red y no un sueldo
local RED = { dinero = 500, anuncios = 500, dias = 7, prob = { 0.15, 0.35, 0.6, 1 } }

local function arruinado()
    if partida.dinero > RED.dinero or partida.sobresGuardados() > 0 then return false end
    for _, t in ipairs({ partida.cajas, partida.prods }) do
        for _, n in pairs(t) do
            if n > 0 then return false end
        end
    end
    local enVenta = 0
    for _, a in ipairs(partida.anuncios) do enVenta = enVenta + mercado.valor(a.id, a.primera) end
    if enVenta > RED.anuncios then return false end
    -- una full art o mejor repetida ya se puede vender
    for id, l in pairs(partida.inv) do
        if #l > 1 and rarezas[porId[id].rareza].nivel >= 5 then return false end
    end
    return true
end

-- defs: el sobre que se va a abrir (se cambia la ultima carta si toca)
function partida.rescate(defs, tipo)
    local red = partida.red
    if mercado.dia() - red.dia < RED.dias or not arruinado() then
        red.racha = 0
        return
    end
    red.racha = red.racha + 1
    if love.math.random() >= RED.prob[math.min(red.racha, #RED.prob)] then return end
    local secretas = {}
    for _, def in ipairs(mercado.fueraDe(tipo.set)) do
        if def.rareza == "secreta" and not def.variante and not def.chase then table.insert(secretas, def) end
    end
    if #secretas == 0 then return end
    defs[#defs] = secretas[love.math.random(#secretas)]
    red.racha, red.dia = 0, mercado.dia()
end

-- las que cuentan para el 100% del set
function partida.cartasDe(set)
    return mercado.baseDe(set)
end

-- las de fuera de set que tienes y cuantas hay
function partida.fuera(set)
    local n, fuera = 0, mercado.fueraDe(set)
    for _, def in ipairs(fuera) do
        if partida.copias(def.id) > 0 then n = n + 1 end
    end
    return n, #fuera
end

-- lo que llevas del set en %: llega al 100 con las del set y, ya completo,
-- pasa del 100 con las de fuera de set
function partida.porcentaje(set)
    local total, tiene = #mercado.baseDe(set), partida.distintas(set)
    if tiene < total then return math.floor(tiene / total * 100) end
    return math.floor((total + partida.fuera(set)) / total * 100)
end

-- master set: el set entero y todas las de fuera de set
function partida.master(set)
    local tiene, total = partida.fuera(set)
    return tiene >= total and partida.distintas(set) >= #mercado.baseDe(set)
end

function partida.totalCartas()
    local n = 0
    for _, l in pairs(partida.inv) do n = n + #l end
    return n
end

-- anadir y quitar

local function rehacerOrden()
    enOrden = {}
    for _, id in ipairs(partida.orden) do enOrden[id] = true end
end

-- premios por completar sets

-- lo que llevas de cada hito de un set: distintas, de 1ª edicion y total
function partida.progreso(set)
    local total, tienes, primeras = #mercado.baseDe(set), 0, 0
    for _, def in ipairs(mercado.baseDe(set)) do
        local l = partida.inv[def.id]
        if l then
            tienes = tienes + 1
            for _, c in ipairs(l) do
                if c.p then primeras = primeras + 1 break end
            end
        end
    end
    return tienes, primeras, total
end

-- da los premios conseguidos de un set; con avisar = false se marcan sin darlos
-- (partidas de antes de que hubiera premios)
function partida.revisarPremios(set, avisar)
    local tienes, primeras, total = partida.progreso(set)
    local tipo = sobres[sets[set].sobre]
    local function dar(clave, premio, texto, funda)
        if partida.premios[clave] then return end
        partida.premios[clave] = true
        if avisar == false then return end
        local ed = not mercado.hayNormales(set)
        if premio.sobres then partida.meterSobres(tipo.id, premio.sobres, ed) end
        if premio.dinero then partida.dinero = partida.dinero + premio.dinero * tipo.precio end
        if funda then partida.sumarFundas(funda[1], funda[2]) end
        table.insert(partida.premiosNuevos, { texto = texto, sobres = premio.sobres, dinero = premio.dinero and premio.dinero * tipo.precio, set = set,
                                              funda = funda })
    end
    local chase = datosFundas["chase" .. (tipo.id:match("%d+") or "")]
    for _, h in ipairs(premios.hitos) do
        if tienes >= math.ceil(total * h.parte) then
            dar(set .. "_" .. h.parte, h, h.parte >= 1 and ("¡" .. sets[set].nombre:upper() .. " COMPLETO!") or
                (math.floor(h.parte * 100) .. "% DEL " .. sets[set].nombre:upper()),
                (h.parte >= 1 and chase) and { chase.id, datosFundas.premioChase } or nil)
        end
    end
    -- la funda dorada, por el MASTER SET (una vez por set)
    if tienes >= total and partida.master(set) then
        dar(set .. "_master", {}, "¡MASTER SET DEL " .. sets[set].nombre:upper() .. "!", { "dorada", datosFundas.premioDorada })
    end
    if premios.primera and primeras >= total then
        dar(set .. "_primera", premios.primera, "¡" .. sets[set].nombre:upper() .. " COMPLETO EN 1ª EDICIÓN!")
    end
end

-- cartas que buscas (se marcan en el album o en la ficha del movil)
partida.MAX_BUSCADAS = 5

function partida.buscada(id)
    return partida.buscadas[id] == true
end

-- las buscadas, en orden fijo
function partida.listaBuscadas()
    local ids = {}
    for id in pairs(partida.buscadas) do table.insert(ids, id) end
    table.sort(ids)
    return ids
end

-- marca o desmarca; devuelve como queda, o nil si ya buscas el maximo
function partida.buscar(id)
    if partida.buscadas[id] then
        partida.buscadas[id] = nil
        return false
    end
    if #partida.listaBuscadas() >= partida.MAX_BUSCADAS then return nil end
    partida.buscadas[id] = true
    return true
end

-- true si era la primera copia, para el aviso de NUEVA; y la copia
-- deSobre: sale de un sobre tuyo (cuenta para los encargos de rareza)
function partida.anadir(id, primera, deSobre)
    -- la que buscabas: se quita de la lista y se avisa
    if partida.buscadas[id] then
        partida.buscadas[id] = nil
        table.insert(partida.encontradas, id)
    end
    local l = partida.inv[id]
    local nueva = l == nil
    if nueva then
        l = {}
        partida.inv[id] = l
    end
    partida.uid = partida.uid + 1
    local c = { u = partida.uid, p = primera or nil }
    -- funda y top loader solos segun la rareza (opciones.fundaDesde / topDesde)
    local nivel = rarezas[porId[id].rareza].nivel
    local o = partida.opciones
    -- solo con la mejora SERVICIO DE FUNDAS (1: fundas, 2: tambien tops)
    local auto = partida.efecto("autofundas")
    if auto >= 1 and (o.fundaDesde or 0) > 0 and nivel >= o.fundaDesde and partida.fundasLibres > 0 then
        partida.fundasLibres = partida.fundasLibres - 1
        c.f = true
    end
    if auto >= 2 and c.f and (o.topDesde or 0) > 0 and nivel >= o.topDesde and partida.topsLibres > 0 then
        partida.topsLibres = partida.topsLibres - 1
        c.t = true
    end
    local primeraP = primera and partida.deEdicion(id, true) == 0
    table.insert(l, c)
    if not enOrden[id] then
        table.insert(partida.orden, id)
        enOrden[id] = true
    end
    -- solo una carta que no tenias (o tu primera 1ª edicion de ella) puede dar premio
    if nueva or primeraP then partida.revisarPremios(porId[id].set) end
    if deSobre then partida.avanzarEncargo("rareza", porId[id].rareza) end
    tocar()
    return nueva, c
end

-- saca una copia concreta del inventario (vendida o enviada)
local function quitarCopia(id, u)
    local l = partida.inv[id]
    if not l then return nil end
    for i, c in ipairs(l) do
        if c.u == u then
            table.remove(l, i)
            if c.k then partida.sacarCopiaDeCarpeta(c) end
            if c.m then
                for j, s in ipairs(partida.mesa) do
                    if s.u == u then table.remove(partida.mesa, j) break end
                end
            end
            if #l == 0 then
                partida.inv[id] = nil
                for j, v in ipairs(partida.orden) do
                    if v == id then table.remove(partida.orden, j) break end
                end
                enOrden[id] = nil
            end
            tocar()
            return c
        end
    end
end

-- fundas

-- id: true (basica, la colgada) o el id de un diseno de datos/fundas.lua
function partida.fundasDe(id)
    if id == true or id == nil then return partida.fundasLibres end
    return partida.fundasDiseno[id] or 0
end

function partida.topsDe(id)
    if id == true or id == nil then return partida.topsLibres end
    return partida.topsDiseno[id] or 0
end

-- suma (o resta) fundas o tops de un diseno
function partida.sumarFundas(id, n, esTop)
    if id == true or id == nil then
        if esTop then partida.topsLibres = partida.topsLibres + n else partida.fundasLibres = partida.fundasLibres + n end
        return
    end
    local t = esTop and partida.topsDiseno or partida.fundasDiseno
    local v = (t[id] or 0) + n
    t[id] = v > 0 and v or nil
    if n > 0 then partida.fundario[esTop and "t" or "f"][id] = true end
end

-- disenos que tienes ahora (con alguna libre), en el orden de datos/fundas.lua
function partida.disenosLibres(esTop)
    local l = {}
    for _, d in ipairs(esTop and datosFundas.tops or datosFundas.lista) do
        if partida[esTop and "topsDe" or "fundasDe"](d.id) > 0 then table.insert(l, d.id) end
    end
    return l
end

function partida.enfundarCopia(c, id)
    id = id or true
    if c.f or partida.fundasDe(id) <= 0 then return false end
    partida.sumarFundas(id, -1)
    c.f = id
    partida.avanzarEncargo("enfundar", nil, c.u)
    tocar()
    return true
end

function partida.desenfundarCopia(c)
    if not c.f then return false end
    partida.quitarTop(c)
    partida.sumarFundas(c.f, 1)
    c.f = nil
    tocar()
    return true
end

-- cambia la funda de una copia por otra (la que tenia vuelve a su caja)
function partida.cambiarFunda(c, id)
    if c.f == id then return false end
    if not c.f then return partida.enfundarCopia(c, id) end
    if partida.fundasDe(id) <= 0 then return false end
    partida.sumarFundas(c.f, 1)
    partida.sumarFundas(id, -1)
    c.f = id
    tocar()
    return true
end

function partida.cambiarTop(c, id)
    if c.t == id then return false end
    if not c.t then return partida.ponerTop(c, id) end
    if partida.topsDe(id) <= 0 then return false end
    partida.sumarFundas(c.t, 1, true)
    partida.sumarFundas(id, -1, true)
    c.t = id
    tocar()
    return true
end

-- compra un pack de fundas o tops con diseno
function partida.comprarDiseno(id, n, precio, esTop)
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.sumarFundas(id, n, esTop)
    tocar()
    return true
end

-- la funda del MIX de ahora (nil si aun no hay)
function partida.fundaTemporada()
    local t = partida.temporada
    if t and t.hasta >= mercado.dia() then return t.id, t.hasta - mercado.dia() + 1 end
end

-- cada 3-4 dias sale una funda nueva en el MIX: primero las que no han salido
-- y, cuando ya han salido todas, alguna vuelve de vez en cuando
function partida.revisarTemporada()
    local dia = mercado.dia()
    local t = partida.temporada
    if t and t.hasta >= dia then return nil end
    local nuevas = {}
    for _, id in ipairs(datosFundas.mix) do
        if not partida.temporadas[id] then table.insert(nuevas, id) end
    end
    local id = nuevas[1]
    if not id then
        repeat id = datosFundas.mix[love.math.random(#datosFundas.mix)] until #datosFundas.mix < 2 or not t or id ~= t.id
    end
    local T = datosFundas.temporada
    partida.temporada = { id = id, hasta = dia + love.math.random(T[1], T[2]) - 1 }
    partida.temporadas[id] = true
    return id
end

-- top loader: va encima de la funda. Sin funda tambien se puede, pero la
-- carta se puede rayar (quien lo pone avisa)
function partida.ponerTop(c, id)
    id = id or true
    if c.t or partida.topsDe(id) <= 0 then return false end
    partida.sumarFundas(id, -1, true)
    c.t = id
    partida.avanzarEncargo("top", nil, c.u)
    tocar()
    return true
end

function partida.quitarTop(c)
    if not c.t then return false end
    partida.sumarFundas(c.t, 1, true)
    c.t = nil
    tocar()
    return true
end

-- al vender o enviar una copia vuelven su funda y su top loader
local function devolverProteccion(c)
    if c.f then partida.sumarFundas(c.f, 1) end
    if c.t then partida.sumarFundas(c.t, 1, true) end
end

function partida.comprarTops(cantidad, precio)
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.topsLibres = partida.topsLibres + cantidad
    tocar()
    return true
end

-- enfunda la mejor copia sin funda (para soltar un monton en la caja de fundas)
function partida.enfundar(id)
    for _, c in ipairs(partida.lista(id)) do
        if not c.f and not c.a then return partida.enfundarCopia(c) end
    end
    return false
end

-- venta rapida a la tienda, al valor de mercado (datos/mercado.lua, ventaRapida)

-- vende copias concretas (uids); las del movil no se venden.
-- La funda de una carta vendida vuelve a la caja
function partida.venderCopias(id, uids)
    local ganado = 0
    for _, u in ipairs(uids) do
        local c = partida.copia(id, u)
        if c and not c.a and not c.k and not porId[id].noVende then
            ganado = ganado + mercado.ventaRapida(id, c.p)
            mercado.vendida(id, 1)
            devolverProteccion(c)
            quitarCopia(id, u)
        end
    end
    partida.dinero = partida.dinero + ganado
    tocar()
    return ganado
end

-- Venta en lote. o.todo: tambien la ultima copia (si no, se deja la mejor de
-- cada carta); o.primeras: tambien las de 1ª edicion; o.fundas: tambien las
-- enfundadas; o.set: solo ese set. Nunca las del movil ni las de la mesa.
-- Devuelve los uids que se venderian de cada carta
local function plan(o)
    local res = {}
    for id in pairs(partida.inv) do
        if (not o.set or porId[id].set == o.set) and not porId[id].noVende then
            local ordenadas = partida.lista(id)
            -- la que se queda en el armario: la mejor (1ª edicion, enfundada)
            -- de las que no estan en el movil
            local guardar
            if not o.todo then
                for _, c in ipairs(ordenadas) do
                    if not c.a and not c.k then guardar = c break end
                end
            end
            local vender = {}
            -- se venden antes las normales
            for k = #ordenadas, 1, -1 do
                local c = ordenadas[k]
                -- proteccion: "sin" solo sin funda, "funda" solo con funda (sin top),
                -- "top" solo con top loader, "todo" todas
                local pr = o.proteccion or "sin"
                local tipoP = c.t and "top" or (c.f and "funda" or "sin")
                if c ~= guardar and not c.a and not c.m and not c.k and (o.primeras or not c.p) and (pr == "todo" or pr == tipoP) then
                    table.insert(vender, c.u)
                end
            end
            if #vender > 0 then res[id] = vender end
        end
    end
    return res
end

-- lo que pagaria la tienda por varias copias: cada una baja un poco el precio
local function cobroRapido(id, uids)
    local antes = mercado.estado.saturacion[id]
    local total = 0
    for _, u in ipairs(uids) do
        total = total + mercado.ventaRapida(id, partida.copia(id, u).p)
        mercado.vendida(id, 1)
    end
    mercado.estado.saturacion[id] = antes
    return total
end

local function claveLote(o)
    return "lote" .. (o.todo and 1 or 0) .. (o.primeras and 1 or 0) .. (o.proteccion or "sin") .. (o.set or "")
end

-- cuantas, por cuanto y cuantas son la ultima copia de su carta
function partida.lote(o)
    return partida.memo(claveLote(o), function()
        local n, valor, ultimas = 0, 0, 0
        for id, uids in pairs(plan(o)) do
            n = n + #uids
            valor = valor + cobroRapido(id, uids)
            if #uids == partida.copias(id) then ultimas = ultimas + 1 end
        end
        return { n = n, valor = valor, ultimas = ultimas }
    end)
end

function partida.venderLote(o)
    local total = 0
    for id, uids in pairs(plan(o)) do
        total = total + partida.venderCopias(id, uids)
    end
    return total
end

-- sobres

-- cuantos se pueden comprar ahora en la tienda (por stock y dinero)
function partida.maxCompra(tipo)
    local precio = mercado.enTienda(tipo)
    if not precio then return 0 end
    return math.max(0, math.min(mercado.stock(tipo), math.floor(partida.dinero / precio)))
end

function partida.comprar(tipo, cantidad)
    local precio, primera = mercado.enTienda(tipo)
    if not precio or cantidad > partida.maxCompra(tipo) or cantidad <= 0 then return false end
    local coste = precio * cantidad
    partida.dinero = partida.dinero - coste
    mercado.gastarStock(tipo, cantidad)
    if primera then mercado.comprados(tipo.set, cantidad) end
    partida.meterSobres(tipo.id, cantidad, primera)
    return coste
end

function partida.comprarReventa(tipo, primera)
    local precio = mercado.compraReventa(tipo, primera)
    if not precio or partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.meterSobres(tipo.id, 1, primera)
    return precio
end

-- cajas selladas: se guardan cerradas, se venden o se abren (dan sus sobres)
function partida.cajasDe(tipoId, primera)
    local n = (partida.cajas[tipoId] or 0)
    if primera == nil then return n end
    local p1 = partida.cajas1[tipoId] or 0
    return primera and p1 or n - p1
end

function partida.comprarCaja(tipo)
    local precio = mercado.precioCaja(tipo)
    if not precio or mercado.stockCajas(tipo) <= 0 or partida.dinero < precio then return false end
    local _, primera = mercado.enTienda(tipo)
    partida.dinero = partida.dinero - precio
    mercado.estado.cajas[tipo.id] = mercado.stockCajas(tipo) - 1
    if primera then mercado.comprados(tipo.set, sobres.caja.sobres) end
    partida.cajas[tipo.id] = partida.cajasDe(tipo.id) + 1
    if primera then partida.cajas1[tipo.id] = partida.cajasDe(tipo.id, true) + 1 end
    tocar()
    return precio
end

-- saca una caja (antes las de reimpresion, como los sobres); devuelve si era de 1ª ed
local function sacarCaja(tipo, respetar)
    if (respetar and partida.cajasDisponibles(tipo.id) or partida.cajasDe(tipo.id)) <= 0 then return nil end
    local primera
    if respetar then primera = partida.sinApartar("c", tipo.id, false) == 0 else primera = partida.cajasDe(tipo.id, false) == 0 end
    partida.cajas[tipo.id] = partida.cajasDe(tipo.id) - 1
    if primera then partida.cajas1[tipo.id] = partida.cajasDe(tipo.id, true) - 1 end
    tocar()
    return primera
end

-- se abre en la mesa: se queda en su esquina y los sobres se sacan de ella.
-- Si ya habia una abierta, sus sobres pasan a los guardados
function partida.abrirCaja(tipo)
    return partida.abrirProd("caja", tipo)
end

-- lo ultimo que se vacio en la mesa (si vuelve un sobre, vuelve a eso)
local ultimoProd

-- saca un sobre de la caja abierta
function partida.sacarDeCaja()
    local c = partida.cajaAbierta
    if not c or c.quedan <= 0 then return nil end
    c.quedan = c.quedan - 1
    partida.abiertos = partida.abiertos + 1
    if c.quedan <= 0 then
        partida.cajaAbierta = nil
        ultimoProd = c.prod
    end
    tocar()
    return sobres[c.tipo], c.primera or false
end

-- se vende por el movil, a lo que vale cerrada menos la comision
function partida.venderCaja(tipo, primera)
    if partida.cajasDe(tipo.id, primera) <= 0 then return false end
    local valor = mercado.trasComision(mercado.valorCaja(tipo, primera))
    partida.cajas[tipo.id] = partida.cajasDe(tipo.id) - 1
    if primera then partida.cajas1[tipo.id] = partida.cajasDe(tipo.id, true) - 1 end
    partida.dinero = partida.dinero + valor
    tocar()
    return valor
end

-- una caja cerrada comprada a un vendedor
function partida.meterCaja(tipoId, primera)
    partida.cajas[tipoId] = partida.cajasDe(tipoId) + 1
    if primera then partida.cajas1[tipoId] = partida.cajasDe(tipoId, true) + 1 end
    tocar()
end

-- productos sellados (datos/productos.lua). La caja usa sus tablas de siempre
local function claveProd(pid, tipoId) return pid .. ":" .. tipoId end

function partida.prodDe(pid, tipoId, primera)
    if pid == "caja" then return partida.cajasDe(tipoId, primera) end
    local k = claveProd(pid, tipoId)
    local n = partida.prods[k] or 0
    if primera == nil then return n end
    local p1 = math.min(n, partida.prods1[k] or 0)
    return primera and p1 or n - p1
end

-- suma (o resta) d de una edicion
local function moverProd(pid, tipoId, primera, d)
    if pid == "caja" then
        partida.cajas[tipoId] = partida.cajasDe(tipoId) + d
        if primera then partida.cajas1[tipoId] = partida.cajasDe(tipoId, true) + d end
    else
        local k = claveProd(pid, tipoId)
        -- la de 1ª se mira antes de cambiar el total (prodDe la recorta al total)
        local p1 = partida.prodDe(pid, tipoId, true)
        partida.prods[k] = partida.prodDe(pid, tipoId) + d
        if primera then partida.prods1[k] = p1 + d end
        if partida.prods[k] <= 0 then partida.prods[k], partida.prods1[k] = nil, nil end
    end
    tocar()
end

function partida.meterProd(pid, tipoId, primera, n)
    moverProd(pid, tipoId, primera, n or 1)
end

function partida.comprarProd(prod, tipo)
    if prod.id == "caja" then return partida.comprarCaja(tipo) end
    local precio = mercado.precioProd(prod, tipo)
    if not precio or mercado.stockProd(prod, tipo) <= 0 or partida.dinero < precio then return false end
    local _, primera = mercado.enTienda(tipo)
    partida.dinero = partida.dinero - precio
    mercado.gastarProd(prod, tipo)
    if primera then mercado.comprados(tipo.set, prod.sobres) end
    moverProd(prod.id, tipo.id, primera, 1)
    return precio
end

function partida.venderProd(prod, tipo, primera)
    if prod.id == "caja" then return partida.venderCaja(tipo, primera) end
    if partida.prodDe(prod.id, tipo.id, primera) <= 0 then return false end
    local valor = mercado.trasComision(mercado.valorProd(prod, tipo, primera))
    moverProd(prod.id, tipo.id, primera, -1)
    partida.dinero = partida.dinero + valor
    return valor
end

-- saca uno sin apartar (antes los de reimpresion); devuelve si era de 1ª ed
local function sacarProd(pid, tipoId, primera)
    if primera == nil then
        if partida.sinApartar(pid, tipoId, false) > 0 then primera = false
        elseif partida.sinApartar(pid, tipoId, true) > 0 then primera = true
        else return nil end
    elseif partida.prodDe(pid, tipoId, primera) <= 0 then
        return nil
    end
    moverProd(pid, tipoId, primera, -1)
    return primera
end

-- el diseno de las fundas y los tops que trae un producto de un set: la ETB
-- el motivo de su set (1 de cada 10, holo o plata) y el tin tops de su color
local function disenosDe(prod, tipoId)
    local i = tonumber(tipoId:match("%d+")) or 1
    local f, t
    if prod.fundas and prod.id == "etb" then
        for _, d in ipairs(datosFundas.lista) do
            if d.familia == "etb" and d.set == "s" .. i then f = d.id end
        end
        if love.math.random() < datosFundas.etbEspecial then f = love.math.random() < 0.5 and "holo" or "plata" end
    end
    if prod.tops and prod.id == "tin" then t = "color" .. i end
    return f, t
end

-- Promos (datos/promos.lua)
local datosPromos = require "datos.promos"

-- una promo al azar de ese origen y set (por su peso)
function partida.tiradaPromo(origen, set)
    local cands, total = {}, 0
    for _, def in ipairs(mercado.promosDe(set)) do
        if def.promo == origen then
            table.insert(cands, def)
            total = total + def.peso
        end
    end
    local r = love.math.random() * total
    for _, def in ipairs(cands) do
        r = r - def.peso
        if r <= 0 then return def end
    end
    return cands[#cands]
end

function partida.promoSobresDe(origen, tipoId)
    return partida.promoSobres[origen .. ":" .. tipoId] or 0
end

function partida.sumarPromoSobre(origen, tipoId, n)
    local k = origen .. ":" .. tipoId
    partida.promoSobres[k] = math.max(0, (partida.promoSobres[k] or 0) + n)
    if partida.promoSobres[k] == 0 then partida.promoSobres[k] = nil end
    tocar()
end

-- lo que trae un sobrecito: una promo (el de correo, la placa que toca)
local function cartasSobrecito(origen, tipoId)
    if origen == "correo" then
        local nivel = table.remove(partida.correo, 1)
        local def = nivel and mercado.placas()[nivel]
        return def and { def } or nil
    end
    return { partida.tiradaPromo(origen, sobres[tipoId].set) }
end

-- saca un sobrecito guardado para abrirlo: sus cartas
function partida.sacarPromoSobre(origen, tipoId)
    if partida.promoSobresDe(origen, tipoId) <= 0 then return nil end
    partida.sumarPromoSobre(origen, tipoId, -1)
    return cartasSobrecito(origen, tipoId)
end

-- el sobrecito i de la mesa: abrirlo (sus cartas) o guardarlo
function partida.abrirPromoMesa(i)
    local m = table.remove(partida.promoMesa, i)
    if not m then return nil end
    tocar()
    return cartasSobrecito(m.o, m.t)
end

function partida.guardarPromoMesa(i)
    local desde, hasta = i or 1, i or #partida.promoMesa
    for k = hasta, desde, -1 do
        local m = table.remove(partida.promoMesa, k)
        if m then partida.sumarPromoSobre(m.o, m.t, 1) end
    end
    tocar()
end

-- lo que vale un sobrecito cerrado: la media de lo que trae, a precio de hoy
function partida.valorPromoSobre(origen, tipo)
    if origen == "torneo" then
        local precio = mercado.sobreTorneo(tipo)
        return precio and math.floor(precio / datosPromos.torneo.margen) or 0
    end
    local v, pesos = 0, 0
    for _, def in ipairs(mercado.promosDe(tipo.set)) do
        if def.promo == origen then
            v = v + mercado.valor(def.id, true) * def.peso
            pesos = pesos + def.peso
        end
    end
    return pesos > 0 and math.floor(v / pesos) or 0
end

function partida.venderPromoSobre(origen, tipo)
    if origen == "correo" or partida.promoSobresDe(origen, tipo.id) <= 0 then return nil end
    local cobro = mercado.trasComision(partida.valorPromoSobre(origen, tipo))
    partida.sumarPromoSobre(origen, tipo.id, -1)
    partida.dinero = partida.dinero + cobro
    return cobro
end

local function avisoPromo(texto)
    table.insert(partida.promosNuevas, texto)
end

-- lo que trae un producto ademas de sus sobres: la ETB y la caja, un
-- sobrecito promo; el blister y el tin, su promo (o su ALT). Devuelve la copia
-- enMesa: se abre en la mesa (el sobrecito se queda en el tapete y la promo
-- del blister o del tin la coloca la mesa, partida.promoReciente)
local function promoProducto(pid, tipo, enMesa)
    if pid == "etb" or pid == "caja" then
        if enMesa then
            table.insert(partida.promoMesa, { o = pid, t = tipo.id })
        else
            partida.sumarPromoSobre(pid, tipo.id, 1)
            avisoPromo("+1 SOBRECITO PROMO (" .. (pid == "etb" and "ETB" or "CAJA") .. "): EN LOS GANCHOS DE LA MESA")
        end
    elseif pid == "blister" or pid == "tin" then
        local def = partida.tiradaPromo(pid, tipo.set)
        if def then
            local _, c = partida.anadir(def.id, false)
            if enMesa then partida.promoReciente = { id = def.id, c = c } end
            avisoPromo((def.alt and "¡SU ALT! " or "PROMO DEL " .. (pid == "tin" and "TIN" or "BLÍSTER") .. ": ") .. def.nombre:upper())
            return def, c
        end
    end
end
partida.promoProducto = promoProducto

-- preventa: una compra grande de una vez mientras un set esta anunciado
-- y aun no se vende te da su promo (una al dia como mucho)
function partida.preventa(gastado)
    if gastado < datosPromos.preventa or partida.preventaDia == mercado.dia() then return nil end
    for _, s in ipairs(require("datos.sets").lista) do
        if calendario.conocido(s.id, mercado.dia()) and not mercado.salido(s.id) then
            for _, def in ipairs(mercado.promosDe(s.id)) do
                if def.promo == "preventa" then
                    partida.preventaDia = mercado.dia()
                    partida.anadir(def.id, false)
                    avisoPromo("PREVENTA DEL " .. s.nombre:upper() .. ": TE REGALAN SU PROMO " .. def.nombre:upper())
                    return def
                end
            end
        end
    end
end

-- el set anunciado que esta en preventa (o nil)
function partida.setEnPreventa()
    for _, s in ipairs(require("datos.sets").lista) do
        if calendario.conocido(s.id, mercado.dia()) and not mercado.salido(s.id) then return s end
    end
end

-- un sobre de torneo del mercado
function partida.comprarTorneo(tipo)
    local precio, stock = mercado.sobreTorneo(tipo)
    if not precio or stock <= 0 or partida.dinero < precio then return nil end
    partida.dinero = partida.dinero - precio
    mercado.gastarTorneo(tipo)
    partida.sumarPromoSobre("torneo", tipo.id, 1)
    return precio
end

function partida.venderTorneo(tipo)
    local precio = mercado.sobreTorneo(tipo)
    if not precio or partida.promoSobresDe("torneo", tipo.id) <= 0 then return nil end
    partida.sumarPromoSobre("torneo", tipo.id, -1)
    local cobro = mercado.trasComision(math.floor(precio / datosPromos.torneo.margen))
    partida.dinero = partida.dinero + cobro
    return cobro
end

-- colabs: solo en el mercado y como mucho unas pocas copias
function partida.puedeColab(id)
    return (partida.colabCompradas[id] or 0) < datosPromos.colab.maximo and mercado.stockColab(id) > 0
end

function partida.comprarColab(id)
    local precio = mercado.valor(id, true)
    if not partida.puedeColab(id) or partida.dinero < precio then return nil end
    partida.dinero = partida.dinero - precio
    mercado.comprarColab(id)
    partida.colabCompradas[id] = (partida.colabCompradas[id] or 0) + 1
    partida.anadir(id, false)
    return precio
end

-- placas del canal: al pasar de ciertos seguidores llega un sobre de correo
-- (cuelga en los ganchos de la mesa); dentro va la placa, que va al album
function partida.revisarPlacas()
    local seg = partida.canal and partida.canal.seguidores or 0
    for i, d in ipairs(datosPromos.canal) do
        if seg >= d.seguidores and not partida.placas[i] then
            partida.placas[i] = mercado.dia()
            table.insert(partida.correo, i)
            partida.sumarPromoSobre("correo", sobres.lista[1].id, 1)
            avisoPromo("CORREO DE ONE LAST PACK: TE MANDAN LA PLACA " .. d.nombre .. " (EN LOS GANCHOS DE LA MESA)")
            tocar()
        end
    end
end

-- las cartas que no se venden (placas del canal)
function partida.vendible(id)
    return not porId[id].noVende
end

local function lleva(prod, tipoId)
    local f, t = disenosDe(prod, tipoId)
    local s = partida.sueltos
    -- si quedaban sueltas de otro diseno, esas se guardan antes
    if prod.fundas then
        if s.fundas > 0 and s.fundaId ~= f then partida.guardarSueltos("fundas") end
        s.fundas, s.fundaId = s.fundas + prod.fundas, f
    end
    if prod.tops then
        if s.tops > 0 and s.topId ~= t then partida.guardarSueltos("tops") end
        s.tops, s.topId = s.tops + prod.tops, t
    end
end

-- se abre en la mesa: sus sobres se quedan en la esquina y se sacan de ahi;
-- las fundas y los tops se quedan sueltos en la mesa. Si ya habia algo
-- abierto, sus sobres pasan a los guardados
function partida.abrirProd(pid, tipo, primera)
    local prod = productos[pid]
    primera = sacarProd(pid, tipo.id, primera)
    if primera == nil then return false end
    local vieja = partida.cajaAbierta
    if vieja and vieja.quedan > 0 then partida.meterSobres(vieja.tipo, vieja.quedan, vieja.primera) end
    partida.cajaAbierta = { tipo = tipo.id, quedan = prod.sobres, primera = primera or nil, prod = pid ~= "caja" and pid or nil }
    lleva(prod, tipo.id)
    promoProducto(pid, tipo, true)
    tocar()
    return true
end

-- un blister se rasga y deja sus sobres con los guardados
function partida.rasgarBlister(tipoId, primera)
    primera = sacarProd("blister", tipoId, primera)
    if primera == nil then return nil end
    partida.meterSobres(tipoId, productos.blister.sobres, primera)
    promoProducto("blister", sobres[tipoId])
    return primera
end

-- vacia un producto cerrado en los sobres guardados, sin abrirlo (lo que
-- trae ademas va directo a tus fundas y tops)
function partida.vaciarProd(pid, tipo, primera)
    if pid == "caja" then return partida.vaciarCaja(tipo, primera) end
    local prod = productos[pid]
    primera = sacarProd(pid, tipo.id, primera)
    if primera == nil then return nil end
    partida.meterSobres(tipo.id, prod.sobres, primera)
    promoProducto(pid, tipo)
    local f, t = disenosDe(prod, tipo.id)
    if prod.fundas then partida.sumarFundas(f or true, prod.fundas) end
    if prod.tops then partida.sumarFundas(t or true, prod.tops, true) end
    return prod.sobres
end

-- las fundas o los tops sueltos de la mesa pasan a tu caja
function partida.guardarSueltos(que)
    local n = partida.sueltos[que] or 0
    if n <= 0 then return 0 end
    partida.sueltos[que] = 0
    if que == "fundas" then
        partida.sumarFundas(partida.sueltos.fundaId or true, n)
        partida.sueltos.fundaId = nil
    else
        partida.sumarFundas(partida.sueltos.topId or true, n, true)
        partida.sueltos.topId = nil
    end
    tocar()
    return n
end

-- Armario SELLADO: lo que tienes cerrado, repartido en huecos como en la vida
-- real. Cada hueco guarda una clave "pid:tipoId:ed" (pid "sobre" para los
-- sueltos) y cuantos; lo nuevo se junta con un hueco de lo mismo con sitio o va
-- al primer hueco libre. Los huecos solo recuerdan el orden: lo que tienes de
-- verdad son los contadores de siempre, y aqui se cuadran
function partida.capacidadHueco(pid)
    if pid:match("^pr") then return productos.sobresPorHueco end
    return pid == "sobre" and productos.sobresPorHueco or productos[pid].cabe
end

local function totalesSellado()
    local t = {}
    for _, tipo in ipairs(sobres.lista) do
        for _, ed in ipairs({ true, false }) do
            local e = ed and "1" or "n"
            local n = partida.sobres(tipo.id, ed)
            if n > 0 then t["sobre:" .. tipo.id .. ":" .. e] = n end
            for _, prod in ipairs(productos.lista) do
                local m = partida.prodDe(prod.id, tipo.id, ed)
                if m > 0 then t[prod.id .. ":" .. tipo.id .. ":" .. e] = m end
            end
        end
        -- sobrecitos promo y de torneo (sin edicion)
        for _, o in ipairs({ "etb", "caja", "torneo" }) do
            local m = partida.promoSobresDe(o, tipo.id)
            if m > 0 then t["pr" .. o .. ":" .. tipo.id .. ":n"] = m end
        end
    end
    return t
end

function partida.huecos()
    local H = partida.huecosArmario
    local t = totalesSellado()
    local en = {}
    for _, h in ipairs(H) do
        if h then en[h.k] = (en[h.k] or 0) + h.n end
    end
    -- lo que ya no esta sale de los ultimos huecos de lo mismo
    for i = #H, 1, -1 do
        local h = H[i]
        local sobra = h and (en[h.k] or 0) - (t[h.k] or 0) or 0
        if sobra > 0 then
            local q = math.min(sobra, h.n)
            h.n, en[h.k] = h.n - q, en[h.k] - q
            if h.n <= 0 then H[i] = false end
        end
    end
    local claves = {}
    for k in pairs(t) do table.insert(claves, k) end
    table.sort(claves)
    for _, k in ipairs(claves) do
        local falta = t[k] - (en[k] or 0)
        if falta > 0 then
            local cap = partida.capacidadHueco(k:match("^[^:]+"))
            for _, h in ipairs(H) do
                if falta > 0 and h and h.k == k and h.n < cap then
                    local q = math.min(falta, cap - h.n)
                    h.n, falta = h.n + q, falta - q
                end
            end
            local i = 1
            while falta > 0 do
                if not H[i] then
                    local q = math.min(falta, cap)
                    H[i], falta = { k = k, n = q }, falta - q
                end
                i = i + 1
            end
        end
    end
    while #H > 0 and H[#H] == false do table.remove(H) end
    return H
end

-- recolocar a mano: lo del hueco "de" pasa al hueco "a" (si habia algo, se cambian)
function partida.moverHueco(de, a)
    local H = partida.huecos()
    if de == a or not H[de] then return false end
    for i = #H + 1, a do H[i] = false end
    H[de], H[a] = H[a], H[de]
    while #H > 0 and H[#H] == false do table.remove(H) end
    tocar()
    return true
end

-- ordena el armario una vez (por set o por tipo); luego se sigue llenando como venga
local ORDEN_TIPO = { sobre = 1 }
for i, x in ipairs(productos.lista) do ORDEN_TIPO[x.id] = i + 1 end
local ORDEN_SET = {}
for i, x in ipairs(sobres.lista) do ORDEN_SET[x.id] = i end

function partida.ordenarArmario(por)
    local t = totalesSellado()
    local claves = {}
    for k in pairs(t) do table.insert(claves, k) end
    local function partes(k)
        local pid, tipoId, ed = k:match("^([^:]+):([^:]+):(.+)$")
        return ORDEN_TIPO[pid] or 99, ORDEN_SET[tipoId] or 99, ed == "1" and 0 or 1
    end
    table.sort(claves, function(a, b)
        local ta, sa, ea = partes(a)
        local tb, sb, eb = partes(b)
        if por == "set" then
            if sa ~= sb then return sa < sb end
            if ta ~= tb then return ta < tb end
        else
            if ta ~= tb then return ta < tb end
            if sa ~= sb then return sa < sb end
        end
        return ea < eb
    end)
    local H = {}
    for _, k in ipairs(claves) do
        local cap, n = partida.capacidadHueco(k:match("^[^:]+")), t[k]
        while n > 0 do
            table.insert(H, { k = k, n = math.min(cap, n) })
            n = n - cap
        end
    end
    partida.huecosArmario = H
    tocar()
end

-- un sobre sacado y guardado sin abrir ya tiene sus cartas: se guardan y
-- salen en el siguiente de ese tipo y edicion (asi guardarlo no cambia nada)
local function claveTirada(tipoId, primera)
    return tipoId .. ":" .. (primera and "1" or "n")
end

function partida.guardarTirada(tipoId, primera, defs, godpack)
    local k = claveTirada(tipoId, primera)
    local ids = {}
    for i, def in ipairs(defs) do ids[i] = def.id end
    partida.tiradas[k] = partida.tiradas[k] or {}
    table.insert(partida.tiradas[k], { c = ids, g = godpack or nil })
    tocar()
end

function partida.sacarTirada(tipoId, primera)
    local k = claveTirada(tipoId, primera)
    local l = partida.tiradas[k]
    if not l or #l == 0 then return nil end
    local t = table.remove(l, 1)
    if #l == 0 then partida.tiradas[k] = nil end
    local defs = {}
    for i, id in ipairs(t.c) do
        defs[i] = porId[id]
        if not defs[i] then return nil end
    end
    return defs, t.g or false
end

-- vacia una caja cerrada en los sobres guardados, sin abrirla. primera: la
-- edicion (nil: la que saldria en la mesa). Devuelve los sobres que salen
function partida.vaciarCaja(tipo, primera)
    if primera == nil then
        primera = sacarCaja(tipo, true)
        if primera == nil then return nil end
    else
        if partida.cajasDe(tipo.id, primera) <= 0 then return nil end
        partida.cajas[tipo.id] = partida.cajasDe(tipo.id) - 1
        if primera then partida.cajas1[tipo.id] = partida.cajasDe(tipo.id, true) - 1 end
    end
    partida.meterSobres(tipo.id, sobres.caja.sobres, primera)
    promoProducto("caja", tipo)
    return sobres.caja.sobres
end

-- la caja abierta de la mesa se cierra: lo que le quede pasa a los guardados
function partida.cerrarCajaAbierta()
    local c = partida.cajaAbierta
    if not c then return 0 end
    partida.cajaAbierta = nil
    if c.quedan > 0 then partida.meterSobres(c.tipo, c.quedan, c.primera) end
    tocar()
    return c.quedan
end

-- un sobre que se saco y no se abrio vuelve a donde estaba
function partida.devolverSobre(tipoId, primera, aCaja)
    partida.abiertos = math.max(0, partida.abiertos - 1)
    local c = partida.cajaAbierta
    if aCaja and c and c.tipo == tipoId and (c.primera or false) == (primera or false) then
        c.quedan = c.quedan + 1
    elseif aCaja and not c then
        partida.cajaAbierta = { tipo = tipoId, quedan = 1, primera = primera or nil, prod = ultimoProd }
    else
        partida.meterSobres(tipoId, 1, primera)
    end
    tocar()
end

function partida.meterSobres(tipoId, n, primera)
    partida.guardados[tipoId] = (partida.guardados[tipoId] or 0) + n
    if primera then partida.guardados1[tipoId] = (partida.guardados1[tipoId] or 0) + n end
    tocar()
end

function partida.comprarFundas(cantidad, precio)
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.fundasLibres = partida.fundasLibres + cantidad
    tocar()
    return true
end

-- sobres guardados de una edicion (nil: todos)
function partida.sobres(tipoId, primera)
    local total = partida.guardados[tipoId] or 0
    if primera == nil then return total end
    local p = math.min(partida.guardados1[tipoId] or 0, total)
    if primera then return p end
    return total - p
end

local function sacar(tipoId, primera)
    if primera then partida.guardados1[tipoId] = partida.sobres(tipoId, true) - 1 end
    partida.guardados[tipoId] = partida.guardados[tipoId] - 1
    tocar()
end

-- vende sobres cerrados de una edicion a precio de mercado, menos la comision
function partida.venderSobres(tipo, cantidad, primera)
    cantidad = math.min(cantidad, partida.sobres(tipo.id, primera))
    local precio = mercado.sellado(tipo, primera)
    if not precio or cantidad <= 0 then return 0 end
    local total = mercado.trasComision(precio) * cantidad
    for _ = 1, cantidad do sacar(tipo.id, primera) end
    partida.dinero = partida.dinero + total
    return total
end

function partida.regalar(tipoId, n, primera)
    partida.meterSobres(tipoId, n or 1, primera)
end

function partida.sobresGuardados()
    local n = 0
    for _, c in pairs(partida.guardados) do n = n + c end
    return n
end

-- los que se ven como "sin abrir": los guardados y los de la caja abierta
function partida.sobresSinAbrir()
    return partida.sobresGuardados() + (partida.cajaAbierta and partida.cajaAbierta.quedan or 0)
end

-- tipoId: el sobre que se quiere abrir; sin el, el primero que quede.
-- Se abren antes los de reimpresion: los de 1ª edicion cerrados valen mas
-- apartados: no salen en la mesa. Clase "s" sobres, "c" cajas o el id del
-- producto; se guarda cuantos ("s:set1:1" = sobres de 1ª ed del set 1)
local function claveApartado(clase, tipoId, primera)
    return clase .. ":" .. tipoId .. ":" .. (primera and 1 or "n")
end

-- cuantos hay de una clase y edicion
function partida.cuantos(clase, tipoId, primera)
    if clase == "s" then return partida.sobres(tipoId, primera) end
    if clase == "c" then return partida.cajasDe(tipoId, primera) end
    return partida.prodDe(clase, tipoId, primera)
end

function partida.apartadosDe(clase, tipoId, primera)
    local n = partida.apartados[claveApartado(clase, tipoId, primera)]
    if type(n) ~= "number" then return 0 end
    return math.max(0, math.min(n, partida.cuantos(clase, tipoId, primera)))
end

function partida.apartado(clase, tipoId, primera)
    return partida.apartadosDe(clase, tipoId, primera) > 0
end

function partida.sinApartar(clase, tipoId, primera)
    return partida.cuantos(clase, tipoId, primera) - partida.apartadosDe(clase, tipoId, primera)
end

-- n: cuantos se apartan (negativo: vuelven a la mesa). Sin n, todos o ninguno
function partida.apartar(clase, tipoId, primera, n)
    local k = claveApartado(clase, tipoId, primera)
    local total, ya = partida.cuantos(clase, tipoId, primera), partida.apartadosDe(clase, tipoId, primera)
    local nuevo
    if n then nuevo = math.max(0, math.min(total, ya + n)) else nuevo = ya > 0 and 0 or total end
    partida.apartados[k] = nuevo > 0 and nuevo or nil
    tocar()
end

-- sobres que se pueden abrir en la mesa (sin los apartados)
function partida.disponibles(tipoId)
    return partida.sinApartar("s", tipoId, false) + partida.sinApartar("s", tipoId, true)
end

function partida.cajasDisponibles(tipoId)
    return partida.sinApartar("c", tipoId, false) + partida.sinApartar("c", tipoId, true)
end

function partida.prodDisponibles(pid, tipoId)
    if pid == "caja" then return partida.cajasDisponibles(tipoId) end
    return partida.sinApartar(pid, tipoId, false) + partida.sinApartar(pid, tipoId, true)
end

-- respetar: no saca los apartados (la mesa). primera: de esa edicion
function partida.sacarSobre(tipoId, respetar, primeraPedida)
    for _, s in ipairs(sobres.lista) do
        local hay = respetar and partida.disponibles(s.id) or partida.sobres(s.id)
        if primeraPedida ~= nil then
            hay = respetar and partida.sinApartar("s", s.id, primeraPedida) or partida.sobres(s.id, primeraPedida)
        end
        if (not tipoId or s.id == tipoId) and hay > 0 then
            local normales = (respetar and partida.sinApartar("s", s.id, false) or partida.sobres(s.id, false)) > 0
            local primera = not normales
            if primeraPedida ~= nil then primera = primeraPedida end
            sacar(s.id, primera)
            partida.abiertos = partida.abiertos + 1
            return s, primera
        end
    end
end

-- mesa: las copias que sacas para mirarlas (como mucho MAX_MESA) y las
-- cartas del ultimo sobre abierto (sobre = true, no cuentan para el maximo)

partida.MAX_MESA = 10

-- copias sacadas del armario que hay en la mesa
function partida.propiasEnMesa()
    local n = 0
    for _, s in ipairs(partida.mesa) do
        if not s.sobre then n = n + 1 end
    end
    return n
end

function partida.mesaLlena()
    return partida.propiasEnMesa() >= partida.MAX_MESA
end

-- deSobre: carta recien abierta que se queda en la mesa
function partida.aLaMesa(id, c, deSobre)
    if c.m or c.a or c.k or (not deSobre and partida.mesaLlena()) then return nil end
    c.m = true
    local s = { u = c.u, id = id, sobre = deSobre or nil }
    table.insert(partida.mesa, s)
    tocar()
    return s
end

-- se recoge la mesa entera: todo vuelve al armario
function partida.recogerMesa()
    for _, s in ipairs(partida.mesa) do
        local c = partida.copia(s.id, s.u)
        if c then c.m = nil end
    end
    partida.mesa = {}
    tocar()
end

function partida.guardarDeMesa(u)
    for i, s in ipairs(partida.mesa) do
        if s.u == u then
            table.remove(partida.mesa, i)
            local c = partida.copia(s.id, u)
            if c then c.m = nil end
            tocar()
            return true
        end
    end
    return false
end

-- mejoras del movil (datos/mejoras.lua): suerte, venta y directo

function partida.nivelMejora(id)
    return partida.mejoras[id] or 0
end

function partida.costeMejora(m)
    local n = partida.nivelMejora(m.id)
    if n >= #m.valores then return nil end
    return math.floor(m.coste * m.multiplica ^ n / 10 + 0.5) * 10
end

local mejoraPorId = {}
for _, m in ipairs(datosMejoras) do mejoraPorId[m.id] = m end

-- lo que da ahora una mejora (o lo que hay sin ella)
function partida.efecto(id)
    local m = mejoraPorId[id]
    return m.valores[partida.nivelMejora(id)] or m.nada
end

-- velocidades de apertura que puedes elegir en la mesa (la mejora MANOS RAPIDAS)
function partida.velocidades()
    local vs = { 0.75, 1 }
    local m = mejoraPorId.velocidad
    for k = 1, partida.nivelMejora("velocidad") do table.insert(vs, m.valores[k]) end
    return vs
end

-- la velocidad elegida, sin pasar de la que da la mejora
function partida.velocidad()
    local v = partida.opciones.velocidad or 1
    return math.min(v, partida.efecto("velocidad"))
end

function partida.maxAnuncios()
    return datosMercado.anuncios.maximo + partida.efecto("anuncios")
end

function partida.aplicarSuerte()
    generador.suerte = { segunda = partida.efecto("segunda"), extra = partida.efecto("extra"), godpack = partida.efecto("godpack") }
    mercado.rebajaComision = partida.efecto("comision")
    mercado.rebajaTienda = partida.efecto("mayorista")
    mercado.extraStock = partida.efecto("proveedor")
end

function partida.comprarMejora(m)
    local coste = partida.costeMejora(m)
    if not coste or partida.dinero < coste then return false end
    partida.dinero = partida.dinero - coste
    partida.mejoras[m.id] = partida.nivelMejora(m.id) + 1
    -- la velocidad nueva se pone sola (en la mesa se puede bajar)
    if m.id == "velocidad" then partida.opciones.velocidad = partida.efecto("velocidad") end
    partida.aplicarSuerte()
    tocar()
    return coste
end

-- encargos del movil (datos/encargos.lua)

local function entre(r)
    return r[1] + love.math.random() * (r[2] - r[1])
end

local function alAzar(pesos)
    local total = 0
    for _, w in pairs(pesos) do total = total + (type(w) == "table" and w.peso or w) end
    local r = love.math.random() * total
    local ultimo
    for k, w in pairs(pesos) do
        r = r - (type(w) == "table" and w.peso or w)
        ultimo = k
        if r <= 0 then return k end
    end
    return ultimo
end

-- cartas de una rareza que trae de media un sobre
local function mediaRareza(tipo, rareza)
    local media = 0
    for _, h in ipairs(tipo.huecos) do
        local tot = 0
        for _, w in pairs(h.rarezas) do tot = tot + w end
        media = media + (h.rarezas[rareza] or 0) / tot * h.cantidad
    end
    return media
end

-- enfundar, poner tops o sacar cartas de una rareza
local function encargoEspecial(clase, tipos)
    local E = datosEncargos.movil
    local nombres = datosMercado.compradores
    local e = { nombre = nombres[love.math.random(#nombres)], clase = clase, hechos = 0, espera = E.diasOferta }
    if clase == "rareza" then
        local r = alAzar(E.rareza)
        local d = E.rareza[r]
        e.rareza = r
        e.n = love.math.random(d.n[1], d.n[2])
        e.dias = love.math.random(d.dias[1], d.dias[2])
        -- sobres que hacen falta de media, al precio medio de los sets que hay
        local media, precio = 0, 0
        for _, t in ipairs(tipos) do
            media = media + mediaRareza(t, r) / #tipos
            precio = precio + t.precio / #tipos
        end
        e.pago = e.n / math.max(media, 0.001) * precio * entre(E.pago)
    else
        local d = E[clase]
        e.n = love.math.random(d.n[1], d.n[2])
        e.dias = love.math.random(E.dias[1], E.dias[2])
        e.pago = e.n * d.pagoPor
        e.vistas = {}
    end
    e.pago = math.max(50, math.floor(e.pago / 10 + 0.5) * 10)
    table.insert(partida.ofertasEncargo, e)
end

local function nuevoEncargo()
    local E = datosEncargos.movil
    local tipos = {}
    for _, t in ipairs(sobres.lista) do
        if mercado.salido(t.set) then table.insert(tipos, t) end
    end
    if #tipos == 0 then return end
    local clase = alAzar(E.clases)
    if clase ~= "abrir" then return encargoEspecial(clase, tipos) end
    local t = tipos[love.math.random(#tipos)]
    local n = love.math.random(E.sobres[1], E.sobres[2])
    local primera = love.math.random() < E.primera
    local pago = t.precio * n * entre(E.pago) * (primera and 1.5 or 1)
    local nombres = datosMercado.compradores
    table.insert(partida.ofertasEncargo, {
        nombre = nombres[love.math.random(#nombres)], tipo = t.id, n = n, hechos = 0, primera = primera or nil,
        pago = math.floor(pago / 10 + 0.5) * 10, dias = love.math.random(E.dias[1], E.dias[2]), espera = E.diasOferta,
    })
end

function partida.diaEncargos()
    local E = datosEncargos.movil
    for i = #partida.ofertasEncargo, 1, -1 do
        local o = partida.ofertasEncargo[i]
        o.espera = o.espera - 1
        if o.espera <= 0 then table.remove(partida.ofertasEncargo, i) end
    end
    partida.encargosCaducados = {}
    for i = #partida.encargos, 1, -1 do
        local e = partida.encargos[i]
        e.dias = e.dias - 1
        if e.dias <= 0 then
            table.remove(partida.encargos, i)
            table.insert(partida.encargosCaducados, e)
        end
    end
    local prob = math.min(E.probMax, E.prob + partida.canal.seguidores * E.probPorSeguidor)
    if #partida.ofertasEncargo < E.ofertasMax and love.math.random() < prob then nuevoEncargo() end
    tocar()
end

function partida.generarEncargo()
    nuevoEncargo()
    tocar()
end

function partida.aceptarEncargo(i)
    local o = partida.ofertasEncargo[i]
    if not o or #partida.encargos >= datosEncargos.movil.activosMax then return false end
    table.remove(partida.ofertasEncargo, i)
    o.espera = nil
    table.insert(partida.encargos, o)
    tocar()
    return true
end

function partida.rechazarEncargo(i)
    table.remove(partida.ofertasEncargo, i)
    tocar()
end

-- al abrir un sobre: avanza los encargos de ese tipo; devuelve los terminados
function partida.encargoSobre(tipoId, primera)
    local hechos = {}
    for i = #partida.encargos, 1, -1 do
        local e = partida.encargos[i]
        if (e.clase or "abrir") == "abrir" and e.tipo == tipoId and (primera or not e.primera) then
            e.hechos = e.hechos + 1
            if e.hechos >= e.n then
                table.remove(partida.encargos, i)
                partida.dinero = partida.dinero + e.pago
                table.insert(hechos, e)
                table.insert(partida.encargosHechos, e)
            end
            break
        end
    end
    if #hechos > 0 then tocar() end
    return hechos
end

-- enfundar, poner un top o sacar una carta de una rareza: avanza el primer
-- encargo que lo pide (u: la copia, para no contar dos veces la misma)
function partida.avanzarEncargo(clase, rareza, u)
    for i, e in ipairs(partida.encargos) do
        if e.clase == clase and (not e.rareza or e.rareza == rareza) then
            if u and e.vistas then
                if e.vistas[u] then return end
                e.vistas[u] = true
            end
            e.hechos = e.hechos + 1
            if e.hechos >= e.n then
                table.remove(partida.encargos, i)
                partida.dinero = partida.dinero + e.pago
                table.insert(partida.encargosHechos, e)
            end
            return
        end
    end
end

-- anuncios del movil

function partida.huecosAnuncios()
    return partida.maxAnuncios() - #partida.anuncios
end

-- publica una copia concreta
function partida.publicarCopia(id, c)
    if partida.huecosAnuncios() <= 0 or c.a or c.k or porId[id].noVende then return false end
    if c.m then partida.guardarDeMesa(c.u) end
    c.a = true
    table.insert(partida.anuncios, { id = id, u = c.u, primera = c.p or false, ofertas = {}, dia = mercado.dia() })
    tocar()
    return true
end

-- Carpetas propias: bolsillos con la copia que quieras. Las copias de una
-- carpeta no se venden, ni se publican, ni van a la mesa.
partida.MAX_CARPETAS = 12
partida.MAX_PAGINAS = 20
partida.NOMBRE_CARPETA = 14

function partida.carpeta(cid)
    for i, k in ipairs(partida.carpetas) do
        if k.id == cid then return k, i end
    end
end

function partida.nuevaCarpeta(nombre)
    if #partida.carpetas >= partida.MAX_CARPETAS then return nil end
    local k = { id = partida.sigCarpeta, nombre = nombre or "FAVORITAS", tapa = (#partida.carpetas % 8) + 1, b = {} }
    partida.sigCarpeta = partida.sigCarpeta + 1
    table.insert(partida.carpetas, k)
    tocar()
    return k
end

-- vacia y quita una carpeta: sus copias vuelven al armario
function partida.borrarCarpeta(cid)
    local k, i = partida.carpeta(cid)
    if not k then return end
    for _, b in pairs(k.b) do
        local c = partida.copia(b.id, b.u)
        if c then c.k = nil end
    end
    table.remove(partida.carpetas, i)
    tocar()
end

-- cuantas cartas lleva y el ultimo bolsillo usado
function partida.cuentaCarpeta(k)
    local n, ultimo = 0, 0
    for slot in pairs(k.b) do
        n = n + 1
        ultimo = math.max(ultimo, slot)
    end
    return n, ultimo
end

-- paginas que se enseñan: siempre en pares y con alguna libre al final
function partida.paginasCarpeta(k)
    local _, ultimo = partida.cuentaCarpeta(k)
    local paginas = math.ceil(ultimo / 9) + 1
    paginas = paginas + paginas % 2
    return math.max(2, math.min(partida.MAX_PAGINAS, paginas))
end

-- la mejor copia que se puede meter en una carpeta (1ª ed, con funda...)
function partida.mejorLibre(id)
    for _, c in ipairs(partida.lista(id)) do
        if not c.a and not c.m and not c.k then return c end
    end
end

-- copias que se pueden meter (sin las del movil, la mesa y otras carpetas)
function partida.libresCarpeta(id)
    return contar(id, function(c) return not c.a and not c.m and not c.k end)
end

function partida.sacarCopiaDeCarpeta(c)
    for _, k in ipairs(partida.carpetas) do
        if k.id == c.k then
            for slot, b in pairs(k.b) do
                if b.u == c.u then k.b[slot] = nil end
            end
        end
    end
    c.k = nil
    tocar()
end

-- mete una copia (u, o la mejor libre) en un bolsillo; lo que habia vuelve al armario
function partida.meterEnCarpeta(cid, slot, id, u)
    local k = partida.carpeta(cid)
    if not k or slot < 1 or slot > partida.MAX_PAGINAS * 9 then return false end
    local c = u and partida.copia(id, u) or partida.mejorLibre(id)
    if not c or c.a then return false end
    if c.m then partida.guardarDeMesa(c.u) end
    if c.k then partida.sacarCopiaDeCarpeta(c) end
    local antes = k.b[slot]
    if antes then
        local ca = partida.copia(antes.id, antes.u)
        if ca then ca.k = nil end
    end
    k.b[slot] = { id = id, u = c.u }
    c.k = cid
    tocar()
    return true
end

-- mueve lo de un bolsillo a otro (si el otro tiene algo, se cambian)
function partida.moverEnCarpeta(cid, de, a)
    local k = partida.carpeta(cid)
    if not k or not k.b[de] or de == a or a < 1 or a > partida.MAX_PAGINAS * 9 then return false end
    k.b[de], k.b[a] = k.b[a], k.b[de]
    tocar()
    return true
end

function partida.sacarDeCarpeta(cid, slot)
    local k = partida.carpeta(cid)
    local b = k and k.b[slot]
    if not b then return false end
    k.b[slot] = nil
    local c = partida.copia(b.id, b.u)
    if c then c.k = nil end
    tocar()
    return true
end

-- en la carpeta, cambia la copia de un bolsillo por otra de la misma carta
function partida.cambiarCopiaCarpeta(cid, slot, u)
    local k = partida.carpeta(cid)
    local b = k and k.b[slot]
    if not b or b.u == u then return false end
    return partida.meterEnCarpeta(cid, slot, b.id, u)
end

-- publica la copia libre que menos se echa de menos de esa edicion
function partida.publicar(id, primera)
    primera = primera or false
    local l = partida.lista(id)
    for k = #l, 1, -1 do
        local c = l[k]
        if not c.a and not c.k and (c.p or false) == primera then return partida.publicarCopia(id, c) end
    end
    return false
end

function partida.retirar(i)
    local a = table.remove(partida.anuncios, i)
    local c = a and partida.copia(a.id, a.u)
    if c then c.a = nil end
    tocar()
end

local function valorAnuncio(a)
    return mercado.valorExacto(a.id, a.primera)
end

-- un comprador al azar que no haya pasado ya por este anuncio
local function nuevaOferta(a)
    local d = datosMercado.anuncios
    a.vistos = a.vistos or {}
    local libres = {}
    for _, nombre in ipairs(datosMercado.compradores) do
        if not a.vistos[nombre] then table.insert(libres, nombre) end
    end
    if #libres == 0 then return end
    local nombre = libres[love.math.random(#libres)]
    a.vistos[nombre] = true
    -- casi todas cerca del valor; las muy altas salen poco (curva)
    local f = d.rango[1] + love.math.random() ^ partida.efecto("regateo") * (d.rango[2] - d.rango[1])
    table.insert(a.ofertas, {
        nombre = nombre,
        precio = math.max(1, math.floor(valorAnuncio(a) * f + 0.5)),
        dias = d.dias,
    })
end

local function porPrecio(x, y) return x.precio > y.precio end

function partida.generarOfertas()
    local d = datosMercado.anuncios
    for _, a in ipairs(partida.anuncios) do
        if #a.ofertas < d.ofertasMax and love.math.random() < d.probOferta then
            nuevaOferta(a)
            if #a.ofertas < d.ofertasMax and love.math.random() < d.probSegunda then nuevaOferta(a) end
            table.sort(a.ofertas, porPrecio)
        end
    end
    tocar()
end

function partida.ofertasTotales()
    local n = 0
    for _, a in ipairs(partida.anuncios) do n = n + #a.ofertas end
    return n
end

-- valor de toda la coleccion (a precio de mercado)
function partida.valorColeccion()
    return (partida.memo("valor", function()
        local total = 0
        for id, l in pairs(partida.inv) do
            local vn, v1
            for _, c in ipairs(l) do
                if c.p then
                    v1 = v1 or mercado.valorExacto(id, true)
                    total = total + v1
                else
                    vn = vn or mercado.valorExacto(id, false)
                    total = total + vn
                end
            end
        end
        return math.floor(total + 0.5)
    end))
end

function partida.apuntarCartera()
    local c = partida.cartera
    local h = c.h
    local valor = partida.valorColeccion()
    if c.h0 + #h - 1 >= mercado.dia() then
        h[#h] = valor
    else
        table.insert(h, valor)
    end
    while #h > 120 do
        table.remove(h, 1)
        c.h0 = c.h0 + 1
    end
end

-- las noticias que salen ese dia, para avisar en el movil
function partida.pasarDia()
    partida.apuntarCartera()
    partida.diaEncargos()
    for _, a in ipairs(partida.anuncios) do
        for j = #a.ofertas, 1, -1 do
            local o = a.ofertas[j]
            o.dias = o.dias - 1
            if o.dias <= 0 then
                table.remove(a.ofertas, j)
                -- si la oferta caduca sin respuesta, ese comprador puede volver otro dia
                if a.vistos then a.vistos[o.nombre] = nil end
            end
        end
    end
    local noticias = mercado.pasarDia()
    local d = partida.desbloqueos
    local nueva = (d == nil or d.todo or d.fundas == true) and partida.revisarTemporada()
    if nueva then
        local _, dias = partida.fundaTemporada()
        mercado.anadirNoticia({ texto = "NUEVA FUNDA EN EL MIX: " .. datosFundas[nueva].nombre .. ". SOLO " .. dias .. " DÍAS", tono = "info" })
    end
    partida.generarOfertas()
    partida.apuntarCartera()
    return noticias
end

-- devuelve la carta, lo que pagaba el comprador y lo que te llega tras la comision
function partida.aceptar(i, j)
    local a = partida.anuncios[i]
    local o = a.ofertas[j]
    table.remove(partida.anuncios, i)
    local c = quitarCopia(a.id, a.u)
    if c then devolverProteccion(c) end
    mercado.vendida(a.id, 0.5)
    local cobrado = mercado.trasComision(o.precio)
    partida.dinero = partida.dinero + cobrado
    tocar()
    return porId[a.id], o.precio, cobrado
end

function partida.rechazar(i, j)
    table.remove(partida.anuncios[i].ofertas, j)
    tocar()
end

-- pedir mas: o acepta la subida o se va. Cuanto mas baja era la oferta, mas facil
function partida.pedirMas(i, j)
    local a = partida.anuncios[i]
    local o = a.ofertas[j]
    local relacion = o.precio / valorAnuncio(a)
    local prob = math.max(0.2, math.min(0.85, 1.45 - relacion))
    tocar()
    if love.math.random() < prob then
        o.precio = math.floor(o.precio * (1 + datosMercado.anuncios.subida) + 0.5)
        o.subida = true
        return true
    end
    table.remove(a.ofertas, j)
    return false
end

function partida.seguir(id)
    partida.seguidas[id] = not partida.seguidas[id] or nil
end

-- guardar

-- las listas de numeros van en una linea: los historiales ocupan mucho
local function serializar(v, sangria)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) then return string.format("%d", v) end
        return string.format("%.4f", v)
    end
    if t == "boolean" then return tostring(v) end
    if t == "string" then return string.format("%q", v) end
    sangria = sangria or ""
    local n, todosNumeros = 0, true
    for k, x in pairs(v) do
        n = n + 1
        if type(x) ~= "number" or type(k) ~= "number" then todosNumeros = false end
    end
    if n == 0 then return "{}" end
    -- solo es lista si las claves son exactamente 1..n (# no vale con huecos)
    if todosNumeros then
        for i = 1, n do
            if v[i] == nil then
                todosNumeros = false
                break
            end
        end
    end
    if todosNumeros then
        local partes = {}
        for i = 1, n do partes[i] = serializar(v[i]) end
        return "{" .. table.concat(partes, ",") .. "}"
    end
    local dentro = sangria .. "  "
    local partes = {}
    local claves = {}
    for k in pairs(v) do table.insert(claves, k) end
    table.sort(claves, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) == "number"
    end)
    -- las tablas pequeñas sin tablas dentro (una copia, una oferta) van en una linea
    local corta = #claves <= 6
    for _, k in ipairs(claves) do
        if type(v[k]) == "table" then corta = false break end
    end
    for _, k in ipairs(claves) do
        local clave = type(k) == "number" and ("[" .. k .. "]") or string.format("[%q]", k)
        table.insert(partes, (corta and "" or dentro) .. clave .. " = " .. serializar(v[k], dentro))
    end
    if corta then return "{ " .. table.concat(partes, ", ") .. " }" end
    return "{\n" .. table.concat(partes, ",\n") .. "\n" .. sangria .. "}"
end
partida.serializar = serializar

local pendiente = false
-- el menu pregunta cada frame si hay partida: el archivo se lee solo la primera vez
local existe

-- se apunta y se escribe como mucho una vez por segundo (main.lua llama a partida.update)
function partida.guardar()
    pendiente = true
end

local CAMPOS = { "dinero", "abiertos", "inv", "uid", "guardados", "guardados1", "anuncios",
    "orden", "mesa", "seguidas", "opciones", "fundasLibres", "cartera", "premios", "canal", "mejoras", "encargos", "ofertasEncargo", "cajas", "cajas1", "prods", "prods1", "sueltos", "huecosArmario", "cajaAbierta", "topsLibres", "apartados", "vendidos", "logros", "tutorial", "desbloqueos", "sequia", "tiradas", "pistas", "guia", "buscadas", "red", "fundasDiseno", "topsDiseno", "fundario", "cajitas", "temporada", "temporadas", "carpetas", "sigCarpeta",
    "promoSobres", "placas", "preventaDia", "colabCompradas", "promoMesa", "correo" }

-- la partida como se guarda (tambien para los reportes de bugs)
function partida.texto()
    local datos = { version = VERSION, mercado = mercado.estado }
    for _, k in ipairs(CAMPOS) do datos[k] = partida[k] end
    return "return " .. serializar(datos) .. "\n"
end

-- el archivo guardado tal cual (nil si no hay)
function partida.archivo()
    return love.filesystem.read(ARCHIVO)
end

function partida.guardarYa()
    pendiente = false
    love.filesystem.write(ARCHIVO, partida.texto())
    existe = true
end

local reloj = 0
function partida.update(dt)
    reloj = reloj + dt
    if pendiente and reloj > 1 then
        reloj = 0
        partida.guardarYa()
    end
end

-- v5 guardaba cuantas copias tenias de cada carta, cuantas de 1ª edicion y
-- cuantas enfundadas. Se reparten: las fundas primero en las de 1ª edicion
local function desdeV5(datos)
    local inv, uid = {}, 0
    for id, n in pairs(datos.coleccion or {}) do
        if porId[id] and n > 0 then
            local p1 = math.min(n, (datos.primeras or {})[id] or 0)
            local f = math.min(n, (datos.fundas or {})[id] or 0)
            local l = {}
            for k = 1, n do
                uid = uid + 1
                l[k] = { u = uid, p = k <= p1 or nil, f = k <= f or nil }
            end
            inv[id] = l
        end
    end
    -- cada anuncio se queda con una copia libre de su edicion
    local anuncios = {}
    for _, a in ipairs(datos.anuncios or {}) do
        local l = inv[a.id]
        for k = l and #l or 0, 1, -1 do
            local c = l[k]
            if not c.a and (c.p or false) == (a.primera or false) then
                c.a = true
                a.u = c.u
                table.insert(anuncios, a)
                break
            end
        end
    end
    datos.inv, datos.uid, datos.anuncios = inv, uid, anuncios
    datos.mesa = {}
    datos.version = VERSION
    return datos
end

local function leer(archivo)
    archivo = archivo or ARCHIVO
    if not love.filesystem.getInfo(archivo) then return nil end
    local ok, trozo = pcall(love.filesystem.load, archivo)
    if not ok or not trozo then return nil end
    local bien, datos = pcall(trozo)
    if not bien or type(datos) ~= "table" or not datos.mercado then return nil end
    if datos.version == 5 then return desdeV5(datos) end
    if datos.version ~= VERSION then return nil end
    return datos
end

function partida.existe()
    if existe == nil then existe = leer() ~= nil end
    return existe
end

-- cambia de partida (no carga: eso lo hace partida.cargar)
function partida.elegirRanura(n)
    if pendiente then partida.guardarYa() end
    partida.ranura = n
    ARCHIVO = archivoDe(n)
    existe = nil
    love.filesystem.write("ranura.txt", tostring(n))
end

function partida.ranuraGuardada()
    local n = tonumber(love.filesystem.read("ranura.txt") or "")
    return (n and n >= 1 and n <= partida.RANURAS) and math.floor(n) or 1
end

-- dia y dinero de una partida guardada, sin cargarla (nil si esta vacia)
function partida.resumen(n)
    local datos = leer(archivoDe(n))
    if not datos then return nil end
    if datos.version == VERSION then
        return { dia = datos.mercado.dia or 1, dinero = datos.dinero or 0 }
    end
    return { dia = 1, dinero = 0 }
end

-- copia tal cual otra partida en la actual
function partida.copiarDe(n)
    local texto = love.filesystem.read(archivoDe(n))
    if not texto then return false end
    love.filesystem.write(ARCHIVO, texto)
    existe = nil
    return partida.cargar()
end

-- deja el inventario coherente: marca de anuncio y de mesa solo en las que lo estan
local function repasar()
    for id, l in pairs(partida.inv) do
        if not porId[id] or #l == 0 then partida.inv[id] = nil end
    end
    local anunciadas, enMesa = {}, {}
    local anuncios = {}
    for _, a in ipairs(partida.anuncios) do
        if a.u and partida.copia(a.id, a.u) then
            anunciadas[a.u] = true
            table.insert(anuncios, a)
        end
    end
    partida.anuncios = anuncios
    local mesa = {}
    for _, s in ipairs(partida.mesa) do
        if partida.copia(s.id, s.u) and not anunciadas[s.u] then
            enMesa[s.u] = true
            table.insert(mesa, s)
        end
    end
    partida.mesa = mesa
    local orden, visto = {}, {}
    for _, id in ipairs(partida.orden) do
        if partida.inv[id] and not visto[id] then
            table.insert(orden, id)
            visto[id] = true
        end
    end
    for id in pairs(partida.inv) do
        if not visto[id] then table.insert(orden, id) end
    end
    partida.orden = orden
    -- carpetas: solo los bolsillos con copias que siguen ahi (y no en el movil)
    local enCarpeta = {}
    for _, k in ipairs(partida.carpetas) do
        for slot, b in pairs(k.b) do
            if partida.copia(b.id, b.u) and not anunciadas[b.u] and not enCarpeta[b.u] then
                enCarpeta[b.u] = k.id
            else
                k.b[slot] = nil
            end
        end
    end
    for _, l in pairs(partida.inv) do
        for _, c in ipairs(l) do
            c.a = anunciadas[c.u]
            c.m = enMesa[c.u]
            c.k = enCarpeta[c.u]
            partida.uid = math.max(partida.uid, c.u)
        end
    end
    rehacerOrden()
end

function partida.cargar()
    local datos = leer()
    partida.nueva()
    if not datos then return false end
    for _, k in ipairs(CAMPOS) do
        if datos[k] ~= nil then partida[k] = datos[k] end
    end
    mercado.cargar(datos.mercado)
    repasar()
    -- partidas de antes de los logros: lo que ya tenias se marca sin avisar
    partida.logrosSinAviso = datos.logros == nil
    -- partidas de antes de los premios: lo que ya tenias cuenta como cobrado
    if datos.premios == nil then
        for _, s in ipairs(sets.lista) do partida.revisarPremios(s.id, false) end
    end
    -- partidas de antes de las fundas con diseno: los sets ya completos dan su
    -- funda de la chase (y la dorada si es MASTER SET), una sola vez
    if datos.fundasDiseno == nil then
        for i, s in ipairs(sets.lista) do
            local ch = datosFundas["chase" .. i]
            if ch and partida.premios[s.id .. "_1"] then partida.sumarFundas(ch.id, datosFundas.premioChase) end
            if partida.premios[s.id .. "_1"] and partida.master(s.id) then
                partida.premios[s.id .. "_master"] = true
                partida.sumarFundas("dorada", datosFundas.premioDorada)
            end
        end
    end
    partida.encargosHechos, partida.encargosCaducados = {}, {}
    partida.encontradas = {}
    -- partidas de antes de la guia (v0.9.1 o antes): con todo abierto ya saben
    -- jugar; si no, se les explica lo que tengan al entrar en cada sitio
    if datos.guia == nil and (datos.desbloqueos == nil or datos.desbloqueos.todo) then partida.guia = { todo = true } end
    -- partidas de antes del tutorial: ya saben jugar
    if datos.tutorial == nil then partida.tutorial = false end
    -- partidas de antes de los desbloqueos (v0.8.2 o antes): todo abierto, y
    -- las mejoras tienen el doble de niveles (5 de antes = 10 de ahora)
    if datos.desbloqueos == nil then
        partida.desbloqueos = { todo = true }
        for id, n in pairs(partida.mejoras) do
            local m = mejoraPorId[id]
            partida.mejoras[id] = m and math.min(n * 2, #m.valores) or nil
        end
        partida.mejoras.autofundas = 2
    end
    -- partidas de antes de elegir rarezas: holo o mejor con funda, full art o mejor con top
    if partida.opciones.fundaDesde == nil then
        partida.opciones.fundaDesde = partida.opciones.autoFundas == false and 0 or 4
        partida.opciones.topDesde = 5
        partida.opciones.autoFundas = nil
    end
    -- partidas de antes de apartar por cantidad (v0.9.5 o antes): se apartan los que hay
    for k, v in pairs(partida.apartados) do
        if v == true then
            local clase, tipoId, ed = k:match("^([^:]+):([^:]+):(.+)$")
            local n = clase and partida.cuantos(clase, tipoId, ed == "1") or 0
            partida.apartados[k] = n > 0 and n or nil
        end
    end
    -- placas del canal que ya habian llegado sin ser cartas: llegan por correo
    for i in pairs(partida.placas or {}) do
        local def = mercado.placas()[i]
        local enCola = false
        for _, n in ipairs(partida.correo) do if n == i then enCola = true end end
        if def and partida.copias(def.id) == 0 and not enCola then
            table.insert(partida.correo, i)
            partida.sumarPromoSobre("correo", sobres.lista[1].id, 1)
        end
    end
    partida.premiosNuevos = {}
    generador.sequia = partida.sequia
    partida.aplicarSuerte()
    tocar()
    return true
end

function partida.borrar()
    love.filesystem.remove(ARCHIVO)
    existe = nil
    partida.nueva()
    partida.guardarYa()
end

partida.nueva()

return partida
