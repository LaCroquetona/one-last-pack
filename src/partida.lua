local cartas = require "datos.cartas"
local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
local datosMercado = require "datos.mercado"
local premios = require "datos.premios"
local sets = require "datos.sets"
local mercado = require "src.mercado"

local partida = {}

local ARCHIVO = "partida.lua"
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
    partida.opciones = { autoFundas = true }
    partida.fundasLibres = 20
    partida.premios = {}
    partida.premiosNuevos = {}
    -- canal de directos: nombre, idioma del chat ("es" o "en") y lo que se ha conseguido
    partida.canal = { nombre = "MI_CANAL", idioma = "es", seguidores = 0, directos = 0, propinas = 0, record = 0 }
    for tipo, n in pairs(sobres.inicio.sobres) do
        partida.guardados[tipo] = n
        partida.guardados1[tipo] = n
    end
    mercado.nuevo()
    partida.cartera = { h0 = 1, h = { 0 } }
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
    return contar(id, function(c) return not c.a and (primera == nil or (c.p or false) == primera) end)
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

-- set: "s1", "s2"... o nil para contar todos
function partida.distintas(set)
    local n = 0
    for id in pairs(partida.inv) do
        if not set or porId[id].set == set then n = n + 1 end
    end
    return n
end

function partida.cartasDe(set)
    return mercado.cartasDe(set)
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
    local total, tienes, primeras = #mercado.cartasDe(set), 0, 0
    for _, def in ipairs(mercado.cartasDe(set)) do
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
    local function dar(clave, premio, texto)
        if partida.premios[clave] then return end
        partida.premios[clave] = true
        if avisar == false then return end
        local ed = not mercado.hayNormales(set)
        partida.meterSobres(tipo.id, premio.sobres, ed)
        if premio.dinero then partida.dinero = partida.dinero + premio.dinero * tipo.precio end
        table.insert(partida.premiosNuevos, { texto = texto, sobres = premio.sobres, dinero = premio.dinero and premio.dinero * tipo.precio, set = set })
    end
    for _, h in ipairs(premios.hitos) do
        if tienes >= math.ceil(total * h.parte) then
            dar(set .. "_" .. h.parte, h, h.parte >= 1 and ("¡" .. sets[set].nombre:upper() .. " COMPLETO!") or
                (math.floor(h.parte * 100) .. "% DEL " .. sets[set].nombre:upper()))
        end
    end
    if primeras >= total then
        dar(set .. "_primera", premios.primera, "¡" .. sets[set].nombre:upper() .. " COMPLETO EN 1ª EDICIÓN!")
    end
end

-- true si era la primera copia, para el aviso de NUEVA; y la copia
function partida.anadir(id, primera)
    local l = partida.inv[id]
    local nueva = l == nil
    if nueva then
        l = {}
        partida.inv[id] = l
    end
    partida.uid = partida.uid + 1
    local c = { u = partida.uid, p = primera or nil }
    -- solo se enfunda la copia que te quedas: las repes no gastan funda
    if partida.opciones.autoFundas and rarezas[porId[id].rareza].nivel >= 3 and partida.fundasLibres > 0
        and partida.enfundadas(id) == 0 then
        partida.fundasLibres = partida.fundasLibres - 1
        c.f = true
    end
    local primeraP = primera and partida.deEdicion(id, true) == 0
    table.insert(l, c)
    if not enOrden[id] then
        table.insert(partida.orden, id)
        enOrden[id] = true
    end
    -- solo una carta que no tenias (o tu primera 1ª edicion de ella) puede dar premio
    if nueva or primeraP then partida.revisarPremios(porId[id].set) end
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

function partida.enfundarCopia(c)
    if c.f or partida.fundasLibres <= 0 then return false end
    partida.fundasLibres = partida.fundasLibres - 1
    c.f = true
    tocar()
    return true
end

function partida.desenfundarCopia(c)
    if not c.f then return false end
    partida.fundasLibres = partida.fundasLibres + 1
    c.f = nil
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
        if c and not c.a then
            ganado = ganado + mercado.ventaRapida(id, c.p)
            mercado.vendida(id, 1)
            if c.f then partida.fundasLibres = partida.fundasLibres + 1 end
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
        if not o.set or porId[id].set == o.set then
            local ordenadas = partida.lista(id)
            -- la que se queda en el armario: la mejor (1ª edicion, enfundada)
            -- de las que no estan en el movil
            local guardar
            if not o.todo then
                for _, c in ipairs(ordenadas) do
                    if not c.a then guardar = c break end
                end
            end
            local vender = {}
            -- se venden antes las normales
            for k = #ordenadas, 1, -1 do
                local c = ordenadas[k]
                if c ~= guardar and not c.a and not c.m and (o.primeras or not c.p) and (o.fundas or not c.f) then
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
    return "lote" .. (o.todo and 1 or 0) .. (o.primeras and 1 or 0) .. (o.fundas and 1 or 0) .. (o.set or "")
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

-- una caja de sobres: muchos sobres mas baratos (no gasta los sobres sueltos)
function partida.comprarCaja(tipo)
    local precio = mercado.precioCaja(tipo)
    if not precio or mercado.stockCajas(tipo) <= 0 or partida.dinero < precio then return false end
    local _, primera = mercado.enTienda(tipo)
    local n = sobres.caja.sobres
    partida.dinero = partida.dinero - precio
    mercado.estado.cajas[tipo.id] = mercado.stockCajas(tipo) - 1
    if primera then mercado.comprados(tipo.set, n) end
    partida.meterSobres(tipo.id, n, primera)
    return precio
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

-- tipoId: el sobre que se quiere abrir; sin el, el primero que quede.
-- Se abren antes los de reimpresion: los de 1ª edicion cerrados valen mas
function partida.sacarSobre(tipoId)
    for _, s in ipairs(sobres.lista) do
        if (not tipoId or s.id == tipoId) and partida.sobres(s.id) > 0 then
            local primera = partida.sobres(s.id, false) == 0
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
    if c.m or c.a or (not deSobre and partida.mesaLlena()) then return nil end
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

-- anuncios del movil

function partida.huecosAnuncios()
    return datosMercado.anuncios.maximo - #partida.anuncios
end

-- publica una copia concreta
function partida.publicarCopia(id, c)
    if partida.huecosAnuncios() <= 0 or c.a then return false end
    if c.m then partida.guardarDeMesa(c.u) end
    c.a = true
    table.insert(partida.anuncios, { id = id, u = c.u, primera = c.p or false, ofertas = {}, dia = mercado.dia() })
    tocar()
    return true
end

-- publica la copia libre que menos se echa de menos de esa edicion
function partida.publicar(id, primera)
    primera = primera or false
    local l = partida.lista(id)
    for k = #l, 1, -1 do
        local c = l[k]
        if not c.a and (c.p or false) == primera then return partida.publicarCopia(id, c) end
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
    local f = d.rango[1] + love.math.random() * (d.rango[2] - d.rango[1])
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
    if c and c.f then partida.fundasLibres = partida.fundasLibres + 1 end
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
    "orden", "mesa", "seguidas", "opciones", "fundasLibres", "cartera", "premios", "canal" }

function partida.guardarYa()
    pendiente = false
    local datos = { version = VERSION, mercado = mercado.estado }
    for _, k in ipairs(CAMPOS) do datos[k] = partida[k] end
    love.filesystem.write(ARCHIVO, "return " .. serializar(datos) .. "\n")
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

local function leer()
    if not love.filesystem.getInfo(ARCHIVO) then return nil end
    local ok, trozo = pcall(love.filesystem.load, ARCHIVO)
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
    for _, l in pairs(partida.inv) do
        for _, c in ipairs(l) do
            c.a = anunciadas[c.u]
            c.m = enMesa[c.u]
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
    -- partidas de antes de los premios: lo que ya tenias cuenta como cobrado
    if datos.premios == nil then
        for _, s in ipairs(sets.lista) do partida.revisarPremios(s.id, false) end
    end
    partida.premiosNuevos = {}
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
