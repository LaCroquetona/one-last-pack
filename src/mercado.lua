local cartas = require "datos.cartas"
local sets = require "datos.sets"
local sobres = require "datos.sobres"
local datos = require "datos.mercado"
local rarezas = require "datos.rarezas"
local datosCalendario = require "datos.calendario"
local calendario = require "src.calendario"

local mercado = {}

-- dias de historial que se guardan de cada carta y sobre
local HISTORIAL = 120
local MAX_NOTICIAS = 40

local porId = {}
for _, c in ipairs(cartas) do
    porId[c.id] = c
end

local delSet = {}
for _, c in ipairs(cartas) do
    delSet[c.set] = delSet[c.set] or {}
    table.insert(delSet[c.set], c)
end

-- cada carta tiene su "caracter" fijo: unas valen algo mas que otras de su rareza
local function variacion(id)
    local rng = love.math.newRandomGenerator(id * 104729 + 7)
    local a, b = datos.variacion[1], datos.variacion[2]
    return a + rng:random() * (b - a)
end

local base = {}
for _, c in ipairs(cartas) do
    base[c.id] = sets[c.set].valores[c.rareza] * variacion(c.id)
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

function mercado.dia()
    return mercado.estado.dia
end

function mercado.carta(id)
    return porId[id]
end

function mercado.cartasDe(setId)
    return delSet[setId] or {}
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

-- precio de la version normal respecto a su valor base, segun la fase de su set
function mercado.multFase(def, dia)
    local F = datos.fases
    local fase, i = calendario.fase(def.set, dia)
    local m
    if fase == "impresion" then
        local hype = 1 + (def.chase and F.hype.chase or F.hype.normal) * math.exp(-i.d / F.hype.dias)
        return hype * (1 - F.caidaTirada * i.d / (i.d + i.quedan))
    elseif fase == "reimpresion" then
        m = F.reimpresion
    elseif fase == "agotado" or fase == "rumor" then
        if i.k == 0 then
            m = 1 - F.caidaTirada + F.subidaAgotado * (1 - math.exp(-i.e / F.ritmoAgotado))
        else
            m = F.reimpresion + F.subidaTrasReimpresion * (1 - math.exp(-i.e / F.ritmoTrasReimpresion))
        end
        if fase == "rumor" then m = m * (1 - F.caidaRumor) end
    else
        m = 1
    end
    if def.chase then m = 1 + (m - 1) * F.chase end
    return m
end

-- lo que vale una 1ª edicion respecto a la normal ese dia. Desde la primera
-- reimpresion la 1ª edicion va por su cuenta: sigue subiendo desde que se
-- agoto su tirada y las reimpresiones apenas le afectan
function mercado.prima(def, dia)
    local P = datos.primera
    local fase, i = calendario.fase(def.set, dia)
    local reimpresa = fase == "reimpresion" or ((fase == "agotado" or fase == "rumor") and i.k > 0)
    if not reimpresa then return 1 end
    local e1 = calendario.finPrimera(def.set, dia) or 0
    local m1 = 1 - datos.fases.caidaTirada + P.subida * (1 - math.exp(-e1 / P.ritmo))
    if fase == "reimpresion" and i.k > 0 then m1 = m1 * (1 - P.caidaReimpresion) end
    if def.chase then m1 = 1 + (m1 - 1) * datos.fases.chase end
    local prima = math.max(1, m1 / mercado.multFase(def, dia))
    -- los primeros dias de la primera reimpresion la diferencia va creciendo
    if fase == "reimpresion" and i.k == 0 then
        prima = 1 + (prima - 1) * math.min(1, (i.d + 1) / P.rampa)
    end
    return prima
end

-- si ya existen copias normales (ha habido reimpresion) ese dia (nil: hoy)
function mercado.hayNormales(setId, dia)
    local fase, i = calendario.fase(setId, dia or mercado.estado.dia)
    return fase == "reimpresion" or ((fase == "agotado" or fase == "rumor") and i.k > 0)
end

local function efectoNoticias(def, soloSet)
    local m = 1
    for _, ev in ipairs(mercado.estado.eventos) do
        if (ev.tipo == "carta" and ev.objetivo == def.id and not soloSet) or (ev.tipo == "set" and ev.objetivo == def.set) then
            m = m * ev.efecto
        end
    end
    return m
end

local function efectoBurbuja(id)
    local b = mercado.estado.burbujas[id]
    return b and b.m or 1
end

local function objetivo(def, dia)
    return base[def.id] * mercado.multFase(def, dia) * efectoNoticias(def) * efectoBurbuja(def.id)
end

-- valor de mercado en centimos (decimal; se redondea al cobrar)
function mercado.valorExacto(id, primera)
    local e = mercado.estado
    local c = e.cartas[id]
    local v = c and c.p or base[id]
    v = v / (1 + (e.saturacion[id] or 0) * datos.saturacion.golpe)
    if primera then v = v * mercado.prima(porId[id], e.dia) end
    return v
end

function mercado.valor(id, primera)
    return math.max(1, math.floor(mercado.valorExacto(id, primera) + 0.5))
end

function mercado.ventaRapida(id, primera)
    return math.max(1, math.floor(mercado.valorExacto(id, primera) * datos.ventaRapida + 0.5))
end

-- lo que te llega de una venta del movil despues de la comision
function mercado.trasComision(precio)
    return math.max(1, math.floor(precio * (1 - datos.comision) + 0.5))
end

-- historial de precios de la version normal: h0 = dia del primer valor
function mercado.historial(id)
    local c = mercado.estado.cartas[id]
    if not c then return nil end
    return c.h0, c.h, c.v
end

-- cuanto ha cambiado en los ultimos dias: 0.12 = +12%
function mercado.cambio(id, dias, primera)
    local c = mercado.estado.cartas[id]
    if not c or #c.h < 2 then return 0 end
    dias = dias or 7
    local k = math.max(1, #c.h - dias)
    local antes = c.h[k]
    local ahora = mercado.valorExacto(id)
    if primera then
        local def = porId[id]
        antes = antes * mercado.prima(def, c.h0 + k - 1)
        ahora = ahora * mercado.prima(def, mercado.estado.dia)
    end
    return ahora / math.max(1, antes) - 1
end

function mercado.vendida(id, cantidad)
    local e = mercado.estado
    e.saturacion[id] = (e.saturacion[id] or 0) + cantidad
end

-- tienda

-- precio en la tienda y edicion, o nil si no hay sobres en la tienda
function mercado.enTienda(tipo)
    local hay, primera = calendario.enTienda(tipo.set, mercado.estado.dia)
    if not hay then return nil end
    return tipo.precio, primera
end

function mercado.stock(tipo)
    return mercado.estado.stock[tipo.id] or 0
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
    local fase, i = calendario.fase(tipo.set, dia)
    local fin = calendario.finPrimera(tipo.set, dia)
    local m
    if primera then
        if fase == "impresion" then
            local hype = 1 + datos.fases.hype.normal * math.exp(-i.d / datos.fases.hype.dias)
            m = S.tirada * hype
        else
            m = 1 + S.subidaPrimera * (1 - math.exp(-(fin or 0) / S.ritmoPrimera))
        end
    else
        if fase == "reimpresion" then
            m = S.reimpresion
        elseif i and i.k and i.k > 0 then
            m = S.reimpresion + S.subidaReimpresion * (1 - math.exp(-(i.e or 0) / S.ritmoReimpresion))
        else
            return nil
        end
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

local function anadirNoticia(n)
    local e = mercado.estado
    n.dia = e.dia
    if n.clave and datos.explicaciones[n.clave] and not e.vistos[n.clave] then
        e.vistos[n.clave] = true
        n.explica = datos.explicaciones[n.clave]
    end
    table.insert(e.noticias, 1, n)
    while #e.noticias > MAX_NOTICIAS do table.remove(e.noticias) end
    return n
end

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

local function setsQue(filtro)
    local lista = {}
    for _, s in ipairs(sets.lista) do
        local fase = calendario.fase(s.id, mercado.estado.dia)
        if filtro(fase) then table.insert(lista, s) end
    end
    return lista
end

function mercado.noticia()
    local candidatas, total = {}, 0
    local agotados = setsQue(function(f) return f == "agotado" end)
    local enTienda = setsQue(function(f) return f == "impresion" or f == "reimpresion" end)
    local hayChase = false
    for id in pairs(mercado.estado.cartas) do
        if porId[id].chase then hayChase = true break end
    end
    for _, n in ipairs(datos.noticias) do
        local vale = true
        if n.soloAgotado and #agotados == 0 then vale = false end
        if n.soloTienda and #enTienda == 0 then vale = false end
        if n.soloChase and not hayChase then vale = false end
        if vale then
            table.insert(candidatas, n)
            total = total + n.peso
        end
    end
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
        n.texto = plantilla.texto:gsub("{carta}", def.nombre)
        n.carta = def.id
        n.set = def.set
        anadirEvento("carta", def.id, plantilla.efecto, plantilla.dias)
    else
        local lista = plantilla.soloAgotado and agotados or (plantilla.soloTienda and enTienda or mercado.setsSalidos())
        local s = lista[love.math.random(#lista)]
        n.texto = plantilla.texto:gsub("{set}", s.nombre)
        n.set = s.id
        anadirEvento("set", s.id, plantilla.efecto, plantilla.dias)
        if plantilla.clave == "escasez" then
            local tipo = sobres[s.sobre]
            mercado.estado.stock[tipo.id] = math.floor(mercado.stock(tipo) / 2)
        end
    end
    return anadirNoticia(n)
end

-- burbujas

function mercado.burbujaAhora(def)
    local B = datos.burbuja
    def = def or cartaAlAzar(true)
    if not def or mercado.estado.burbujas[def.id] then return end
    mercado.estado.burbujas[def.id] = { fase = "sube", d = 0, dur = love.math.random(B.dias[1], B.dias[2]), m = 1 }
    return anadirNoticia({ clave = "habla", tono = "sube", carta = def.id, set = def.set, texto = "Todo el mundo habla de " .. def.nombre })
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
                anadirNoticia({ clave = "burbuja", tono = "baja", carta = id, set = def.set, texto = "Se desinfla " .. def.nombre .. ": todo el mundo vende a la vez" })
            end
            if b.d >= 2 then b.fase, b.d = "vuelve", 0 end
        else
            b.m = b.m + (1 - b.m) * 0.3
            if math.abs(b.m - 1) < 0.03 then e.burbujas[id] = nil end
        end
    end
    if e.dia >= B.desdeDia and love.math.random() < B.prob then
        local def = cartaAlAzar(true)
        if def and not e.burbujas[def.id] then mercado.burbujaAhora(def) end
    end
end

-- dia a dia

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

local function apuntar(c, valor, volumen)
    table.insert(c.h, math.floor(valor + 0.5))
    table.insert(c.v, volumen)
    local q = recortar(c.h)
    recortar(c.v)
    c.h0 = c.h0 + q
end

-- las cartas y sobres de los sets que salen hoy entran en el mercado
local function abrirSets(dia)
    local e = mercado.estado
    for _, s in ipairs(sets.lista) do
        if calendario.salido(s.id, dia) then
            for _, def in ipairs(delSet[s.id]) do
                if not e.cartas[def.id] then
                    local c = { p = objetivo(def, dia), h = {}, v = {}, h0 = dia }
                    e.cartas[def.id] = c
                    apuntar(c, c.p, volumenDia(def, dia))
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

local function reponerStock(dia)
    for _, tipo in ipairs(sobres.lista) do
        mercado.estado.stock[tipo.id] = stockDelDia(tipo, dia)
    end
end

local function avisosCalendario(dia)
    for _, a in ipairs(calendario.avisos(dia)) do
        local t = (a.clave == "agotado" or a.clave == "ultimos") and "sube" or ((a.clave == "rumor" or a.clave == "reimpresion") and "baja" or "info")
        anadirNoticia({ clave = a.clave, tono = t, set = a.set.id, texto = a.texto, calendario = true })
    end
end

function mercado.nuevo(semilla)
    semilla = semilla or love.math.random(1, 2 ^ 30)
    calendario.plan = calendario.generar(semilla)
    mercado.estado = {
        dia = 1, semilla = semilla, cartas = {}, sellados = {}, saturacion = {},
        noticias = {}, eventos = {}, burbujas = {}, stock = {}, vistos = {},
    }
    abrirSets(1)
    reponerStock(1)
    avisosCalendario(1)
end

-- al cargar una partida el plan se vuelve a sacar de la semilla
function mercado.cargar(estado)
    mercado.estado = estado
    calendario.plan = calendario.generar(estado.semilla)
end

function mercado.pasarDia()
    local e = mercado.estado
    local antes = #e.noticias
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
    avanzarBurbujas()
    if love.math.random() < datos.probNoticia then mercado.noticia() end

    for id, c in pairs(e.cartas) do
        if c.h0 + #c.h - 1 < dia then
            local def = porId[id]
            local seguir = e.burbujas[id] and datos.seguimientoBurbuja or datos.seguimiento
            c.p = c.p + (objetivo(def, dia) - c.p) * seguir
            c.p = math.max(1, c.p * math.exp(normal() * datos.ruido))
            apuntar(c, mercado.valorExacto(id), volumenDia(def, dia))
        end
    end

    for _, tipo in ipairs(sobres.lista) do
        local s = e.sellados[tipo.id]
        if s and s.h0 + #s.h1 - 1 < dia then
            local o1 = objetivoSellado(tipo, dia, true)
            s.p1 = math.max(1, (s.p1 + (o1 - s.p1) * datos.seguimiento) * math.exp(normal() * datos.ruido))
            local o2 = objetivoSellado(tipo, dia, false)
            if o2 then
                if s.pr <= 0 then s.pr = o2 end
                s.pr = math.max(1, (s.pr + (o2 - s.pr) * datos.seguimiento) * math.exp(normal() * datos.ruido))
            end
            table.insert(s.h1, math.floor(s.p1 + 0.5))
            table.insert(s.hr, math.floor(s.pr + 0.5))
            local q = recortar(s.h1)
            recortar(s.hr)
            s.h0 = s.h0 + q
        end
    end

    local nuevas = {}
    for i = #e.noticias - antes, 1, -1 do
        table.insert(nuevas, e.noticias[i])
    end
    return nuevas
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
