local cartas = require "datos.cartas"
local sobres = require "datos.sobres"
local datosMercado = require "datos.mercado"
local mercado = require "src.mercado"

local partida = {}

local ARCHIVO = "partida.lua"
-- partidas de versiones anteriores no se cargan
local VERSION = 5
local ALMACEN = datosMercado.almacen

local porId = {}
for _, c in ipairs(cartas) do
    porId[c.id] = c
end

function partida.nueva()
    partida.dinero = sobres.inicio.dinero
    partida.abiertos = 0
    partida.coleccion = {}
    partida.primeras = {}
    partida.fundas = {}
    partida.guardados = {}
    partida.guardados1 = {}
    partida.anuncios = {}
    partida.orden = {}
    partida.mesa = {}
    partida.seguidas = {}
    partida.opciones = { autoFundas = true }
    partida.fundasLibres = 20
    partida.estanterias = ALMACEN.estanterias
    partida.cajas = ALMACEN.cajas
    for tipo, n in pairs(sobres.inicio.sobres) do
        partida.guardados[tipo] = n
    end
    mercado.nuevo()
    partida.cartera = { h0 = 1, h = { 0 } }
end

function partida.carta(id)
    return porId[id]
end

function partida.copias(id)
    return partida.coleccion[id] or 0
end

-- copias de 1ª edicion (primera = true), normales (false) o todas (nil)
function partida.deEdicion(id, primera)
    local p = math.min(partida.primeras[id] or 0, partida.copias(id))
    if primera == nil then return partida.copias(id) end
    if primera then return p end
    return partida.copias(id) - p
end

function partida.enfundadas(id)
    return math.min(partida.fundas[id] or 0, partida.copias(id))
end

function partida.publicadas(id, primera)
    local n = 0
    for _, a in ipairs(partida.anuncios) do
        if a.id == id and (primera == nil or (a.primera or false) == primera) then n = n + 1 end
    end
    return n
end

-- copias que estan en tu armario y no en un anuncio
function partida.libres(id, primera)
    return partida.deEdicion(id, primera) - partida.publicadas(id, primera)
end

-- set: "s1", "s2"... o nil para contar todos
function partida.distintas(set)
    local n = 0
    for _, c in ipairs(cartas) do
        if partida.coleccion[c.id] and (not set or c.set == set) then n = n + 1 end
    end
    return n
end

function partida.cartasDe(set)
    return mercado.cartasDe(set)
end

function partida.totalCartas()
    local n = 0
    for _, c in pairs(partida.coleccion) do n = n + c end
    return n
end

local function enOrden(id)
    for _, v in ipairs(partida.orden) do
        if v == id then return true end
    end
    return false
end

-- true si era la primera copia, para el aviso de NUEVA
function partida.anadir(id, primera)
    local antes = partida.copias(id)
    partida.coleccion[id] = antes + 1
    if primera then partida.primeras[id] = (partida.primeras[id] or 0) + 1 end
    if not enOrden(id) then table.insert(partida.orden, id) end
    local nivel = require("datos.rarezas")[porId[id].rareza].nivel
    -- solo se enfunda la copia que te quedas, las repes no gastan funda
    if partida.opciones.autoFundas and nivel >= 3 and partida.fundasLibres > 0 and partida.enfundadas(id) == 0 then
        partida.fundasLibres = partida.fundasLibres - 1
        partida.fundas[id] = (partida.fundas[id] or 0) + 1
    end
    return antes == 0
end

-- quita copias de una edicion (nil: primero las normales)
local function quitar(id, cantidad, primera)
    for _ = 1, cantidad do
        local p = partida.deEdicion(id, true)
        local quitarPrimera = primera == true or (primera == nil and partida.deEdicion(id, false) == 0)
        if quitarPrimera and p > 0 then partida.primeras[id] = p - 1 end
        if partida.primeras[id] == 0 then partida.primeras[id] = nil end
        partida.coleccion[id] = partida.copias(id) - 1
    end
    local n = partida.copias(id)
    if n <= 0 then partida.coleccion[id] = nil end
    -- la funda de una carta vendida se pierde con ella
    if (partida.fundas[id] or 0) > n then partida.fundas[id] = n > 0 and n or nil end
    if n <= 0 then
        for i, v in ipairs(partida.orden) do
            if v == id then table.remove(partida.orden, i) break end
        end
        partida.mesa[id] = nil
        partida.primeras[id] = nil
    end
end

function partida.enfundar(id)
    if partida.enfundadas(id) >= partida.copias(id) or partida.fundasLibres <= 0 then return false end
    partida.fundasLibres = partida.fundasLibres - 1
    partida.fundas[id] = partida.enfundadas(id) + 1
    return true
end

function partida.desenfundar(id)
    if partida.enfundadas(id) <= 0 then return false end
    partida.fundasLibres = partida.fundasLibres + 1
    partida.fundas[id] = partida.enfundadas(id) - 1
    return true
end

-- venta rapida a la tienda, a la mitad del valor
function partida.vender(id, cantidad, primera)
    primera = primera or false
    cantidad = math.min(cantidad, partida.libres(id, primera))
    if cantidad <= 0 then return 0 end
    local ganado = 0
    for _ = 1, cantidad do
        ganado = ganado + mercado.ventaRapida(id, primera)
        mercado.vendida(id, 1)
    end
    quitar(id, cantidad, primera)
    partida.dinero = partida.dinero + ganado
    return ganado
end

-- lo que se vende en lote, por edicion, nunca las publicadas.
-- Repes (todas = false): deja una copia en el armario, ademas de las del movil
-- (mejor si es de 1ª edicion); las fundas de las repes vuelven a la caja.
-- Vender todo: nunca las enfundadas
local function sobrantes(id, todas)
    local libresN, libresP = partida.libres(id, false), partida.libres(id, true)
    local vendibles
    if todas then
        vendibles = libresN + libresP - partida.enfundadas(id)
    else
        vendibles = libresN + libresP - 1
    end
    vendibles = math.max(0, vendibles)
    local normales = math.min(libresN, vendibles)
    return normales, math.min(libresP, vendibles - normales)
end

-- lo que pagaria la tienda por varias copias: cada una baja un poco el precio
local function cobroRapido(id, normales, primeras)
    local antes = mercado.estado.saturacion[id]
    local total = 0
    for _ = 1, normales do
        total = total + mercado.ventaRapida(id, false)
        mercado.vendida(id, 1)
    end
    for _ = 1, primeras do
        total = total + mercado.ventaRapida(id, true)
        mercado.vendida(id, 1)
    end
    mercado.estado.saturacion[id] = antes
    return total
end

function partida.lote(todas)
    local n, valor = 0, 0
    for _, c in ipairs(cartas) do
        if partida.coleccion[c.id] then
            local a, b = sobrantes(c.id, todas)
            n = n + a + b
            if a + b > 0 then valor = valor + cobroRapido(c.id, a, b) end
        end
    end
    return n, valor
end

-- repes que no se venden porque estan en el movil
function partida.repesPublicadas()
    local n = 0
    for id, c in pairs(partida.coleccion) do
        local a, b = sobrantes(id, false)
        n = n + math.max(0, c - 1 - a - b)
    end
    return n
end

function partida.venderLote(todas)
    local total = 0
    for _, c in ipairs(cartas) do
        if partida.coleccion[c.id] then
            local a, b = sobrantes(c.id, todas)
            local fundas = partida.enfundadas(c.id)
            if a > 0 then total = total + partida.vender(c.id, a, false) end
            if b > 0 then total = total + partida.vender(c.id, b, true) end
            if not todas then
                partida.fundasLibres = partida.fundasLibres + fundas - partida.enfundadas(c.id)
            end
        end
    end
    return total
end

-- almacen

function partida.huecoSobres()
    return partida.estanterias * ALMACEN.sobresPorEstanteria
end

function partida.huecoCartas()
    return partida.cajas * ALMACEN.cartasPorCaja
end

function partida.precioEstanteria()
    return math.floor(ALMACEN.precioEstanteria * ALMACEN.subidaEstanteria ^ (partida.estanterias - ALMACEN.estanterias) + 0.5)
end

function partida.precioCaja()
    return math.floor(ALMACEN.precioCaja * ALMACEN.subidaCaja ^ (partida.cajas - ALMACEN.cajas) + 0.5)
end

function partida.comprarEstanteria()
    local precio = partida.precioEstanteria()
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.estanterias = partida.estanterias + 1
    return precio
end

function partida.comprarCaja()
    local precio = partida.precioCaja()
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.cajas = partida.cajas + 1
    return precio
end

-- por que no se pueden meter n sobres mas (nil si se puede)
function partida.sinSitio(n)
    if partida.sobresGuardados() + n > partida.huecoSobres() then return "estanteria" end
    if partida.totalCartas() >= partida.huecoCartas() then return "cajas" end
end

-- sobres

-- cuantos se pueden comprar ahora en la tienda (por stock, dinero y sitio)
function partida.maxCompra(tipo)
    local precio = mercado.enTienda(tipo)
    if not precio then return 0 end
    local n = math.min(mercado.stock(tipo), math.floor(partida.dinero / precio))
    n = math.min(n, partida.huecoSobres() - partida.sobresGuardados())
    if partida.totalCartas() >= partida.huecoCartas() then n = 0 end
    return math.max(0, n)
end

function partida.comprar(tipo, cantidad)
    local precio, primera = mercado.enTienda(tipo)
    if not precio or cantidad > partida.maxCompra(tipo) or cantidad <= 0 then return false end
    local coste = precio * cantidad
    partida.dinero = partida.dinero - coste
    mercado.gastarStock(tipo, cantidad)
    partida.meterSobres(tipo.id, cantidad, primera)
    return coste
end

function partida.comprarReventa(tipo, primera)
    local precio = mercado.compraReventa(tipo, primera)
    if not precio or partida.dinero < precio or partida.sinSitio(1) then return false end
    partida.dinero = partida.dinero - precio
    partida.meterSobres(tipo.id, 1, primera)
    return precio
end

function partida.meterSobres(tipoId, n, primera)
    partida.guardados[tipoId] = (partida.guardados[tipoId] or 0) + n
    if primera then partida.guardados1[tipoId] = (partida.guardados1[tipoId] or 0) + n end
end

function partida.comprarFundas(cantidad, precio)
    if partida.dinero < precio then return false end
    partida.dinero = partida.dinero - precio
    partida.fundasLibres = partida.fundasLibres + cantidad
    return true
end

-- sobres guardados de una edicion (nil: todos)
function partida.sobres(tipoId, primera)
    local total = partida.guardados[tipoId] or 0
    local p = math.min(partida.guardados1[tipoId] or 0, total)
    if primera == nil then return total end
    if primera then return p end
    return total - p
end

local function sacar(tipoId, primera)
    if primera then partida.guardados1[tipoId] = partida.sobres(tipoId, true) - 1 end
    partida.guardados[tipoId] = partida.guardados[tipoId] - 1
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

-- anuncios del movil

function partida.publicar(id, primera)
    primera = primera or false
    if #partida.anuncios >= datosMercado.anuncios.maximo or partida.libres(id, primera) <= 0 then return false end
    table.insert(partida.anuncios, { id = id, primera = primera, ofertas = {}, dia = mercado.dia() })
    return true
end

function partida.retirar(i)
    table.remove(partida.anuncios, i)
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

function partida.generarOfertas()
    local d = datosMercado.anuncios
    for _, a in ipairs(partida.anuncios) do
        if #a.ofertas < d.ofertasMax and love.math.random() < d.probOferta then
            nuevaOferta(a)
            if #a.ofertas < d.ofertasMax and love.math.random() < d.probSegunda then nuevaOferta(a) end
        end
        table.sort(a.ofertas, function(x, y) return x.precio > y.precio end)
    end
end

-- valor de toda la coleccion
function partida.valorColeccion()
    local total = 0
    for id, n in pairs(partida.coleccion) do
        local p = partida.deEdicion(id, true)
        total = total + (n - p) * mercado.valorExacto(id, false) + p * mercado.valorExacto(id, true)
    end
    return math.floor(total + 0.5)
end

local function apuntarCartera()
    local c = partida.cartera
    local h = c.h
    local dia = mercado.dia()
    local valor = partida.valorColeccion()
    if c.h0 + #h - 1 >= dia then
        h[#h] = valor
    else
        table.insert(h, valor)
    end
    while #h > 120 do
        table.remove(h, 1)
        c.h0 = c.h0 + 1
    end
end
partida.apuntarCartera = apuntarCartera

-- las noticias que salen ese dia, para avisar en el movil
function partida.pasarDia()
    apuntarCartera()
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
    apuntarCartera()
    return noticias
end

-- devuelve la carta, lo que pagaba el comprador y lo que te llega tras la comision
function partida.aceptar(i, j)
    local a = partida.anuncios[i]
    local o = a.ofertas[j]
    table.remove(partida.anuncios, i)
    quitar(a.id, 1, a.primera or false)
    mercado.vendida(a.id, 0.5)
    local cobrado = mercado.trasComision(o.precio)
    partida.dinero = partida.dinero + cobrado
    return porId[a.id], o.precio, cobrado
end

function partida.rechazar(i, j)
    table.remove(partida.anuncios[i].ofertas, j)
end

-- pedir mas: o acepta la subida o se va. Cuanto mas baja era la oferta, mas facil
function partida.pedirMas(i, j)
    local a = partida.anuncios[i]
    local o = a.ofertas[j]
    local relacion = o.precio / valorAnuncio(a)
    local prob = math.max(0.2, math.min(0.85, 1.45 - relacion))
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
    for _, k in ipairs(claves) do
        local clave = type(k) == "number" and ("[" .. k .. "]") or string.format("[%q]", k)
        table.insert(partes, dentro .. clave .. " = " .. serializar(v[k], dentro))
    end
    return "{\n" .. table.concat(partes, ",\n") .. "\n" .. sangria .. "}"
end

local pendiente = false
-- el menu pregunta cada frame si hay partida: el archivo se lee solo la primera vez
local existe

-- se apunta y se escribe como mucho una vez por segundo (main.lua llama a partida.update)
function partida.guardar()
    pendiente = true
end

function partida.guardarYa()
    pendiente = false
    local datos = {
        version = VERSION,
        dinero = partida.dinero,
        abiertos = partida.abiertos,
        coleccion = partida.coleccion,
        primeras = partida.primeras,
        fundas = partida.fundas,
        guardados = partida.guardados,
        guardados1 = partida.guardados1,
        anuncios = partida.anuncios,
        orden = partida.orden,
        fundasLibres = partida.fundasLibres,
        mesa = partida.mesa,
        seguidas = partida.seguidas,
        opciones = partida.opciones,
        estanterias = partida.estanterias,
        cajas = partida.cajas,
        cartera = partida.cartera,
        mercado = mercado.estado,
    }
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

local function leer()
    if not love.filesystem.getInfo(ARCHIVO) then return nil end
    local ok, trozo = pcall(love.filesystem.load, ARCHIVO)
    if not ok or not trozo then return nil end
    local bien, datos = pcall(trozo)
    if not bien or type(datos) ~= "table" or datos.version ~= VERSION or not datos.mercado then return nil end
    return datos
end

function partida.existe()
    if existe == nil then existe = leer() ~= nil end
    return existe
end

function partida.cargar()
    local datos = leer()
    if not datos then
        partida.nueva()
        return false
    end
    partida.nueva()
    local campos = { "dinero", "abiertos", "coleccion", "primeras", "fundas", "guardados", "guardados1", "anuncios",
        "orden", "mesa", "seguidas", "opciones", "fundasLibres", "estanterias", "cajas", "cartera" }
    for _, k in ipairs(campos) do
        if datos[k] ~= nil then partida[k] = datos[k] end
    end
    mercado.cargar(datos.mercado)
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
