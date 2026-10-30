-- Desbloqueos por hitos (datos/desbloqueos.lua): las cosas van saliendo al
-- jugar para no saturar al empezar. Cada uno deja un aviso en la cola, que
-- pinta src/tutorial.lua cuando acaba la intro.
-- partida.desbloqueos: id = true; { todo = true } en las partidas de antes
local partida = require "src.partida"
local mercado = require "src.mercado"
local calendario = require "src.calendario"
local sobres = require "datos.sobres"
local sets = require "datos.sets"
local rarezas = require "datos.rarezas"
local cartas = require "datos.cartas"
local datos = require "datos.desbloqueos"
local datosDirecto = require "datos.directo"

local desbloqueos = {}

-- avisos por enseñar (no se guardan: lo desbloqueado si)
desbloqueos.avisos = {}
-- avisos cortos (toasts) que main.lua manda al movil
desbloqueos.toasts = {}

local porId = {}
for _, c in ipairs(cartas.lista or cartas) do porId[c.id] = c end

function desbloqueos.hay(id)
    local d = partida.desbloqueos
    return d == nil or d.todo or d[id] == true
end

-- las apps del movil que ya tienes
local deApp = {}
for id, d in pairs(datos) do
    if type(d) == "table" and d.apps then
        for _, a in ipairs(d.apps) do deApp[a] = id end
    end
end

function desbloqueos.app(appId)
    return not deApp[appId] or desbloqueos.hay(deApp[appId])
end

-- el sobre mas barato que hay hoy en la tienda (o nil)
local function masBarato()
    local precio
    for _, t in ipairs(sobres.lista) do
        local pr = mercado.enTienda(t)
        if pr and mercado.stock(t) > 0 and (not precio or pr < precio) then precio = pr end
    end
    return precio
end

local function nadaQueAbrir()
    if partida.sobresGuardados() > 0 or partida.cajaAbierta then return false end
    for _, n in pairs(partida.cajas) do
        if n > 0 then return false end
    end
    return true
end

local function mejorRareza()
    local mejor = 0
    for id in pairs(partida.inv) do
        local c = porId[id]
        local r = c and rarezas[c.rareza]
        if r and r.nivel > mejor then mejor = r.nivel end
    end
    return mejor
end

local function hayRepetidas()
    for _, l in pairs(partida.inv) do
        if #l >= 2 then return true end
    end
    return false
end

local function sinDinero()
    local precio = masBarato()
    return precio and partida.dinero < precio and nadaQueAbrir()
end

local function tiendaVacia()
    for _, t in ipairs(sobres.lista) do
        if mercado.enTienda(t) and mercado.stock(t) > 0 then return false end
    end
    return true
end

local set2 = sets.lista[2] and sets.lista[2].id

-- cuando se cumple cada hito
local CUANDO = {
    fundas = function() return mejorRareza() >= 3 end,
    tops = function() return mejorRareza() >= 5 end,
    mercado = function() return (partida.abiertos >= datos.mercado.abiertos and hayRepetidas()) or sinDinero() end,
    encargos = function() return partida.canal.directos >= datos.encargos.directos end,
    mejoras = function() return partida.dinero >= datos.mejoras.dinero end,
    venta = function() return partida.canal.seguidores >= datosDirecto.venta.desbloqueo end,
    noticias = function() return set2 and calendario.conocido(set2, mercado.dia()) end,
    cajas = function() return partida.abiertos >= datos.cajas.abiertos end,
    tienda = function() return partida.abiertos > 0 and nadaQueAbrir() and not sinDinero() and not tiendaVacia() end,
    -- cuando ya no te queda nada que abrir y has acabado con la tienda
    -- (vacia o sin dinero para el sobre mas barato)
    dia = function()
        return partida.abiertos >= datos.dia.abiertos and nadaQueAbrir() and (tiendaVacia() or sinDinero())
    end,
}

-- los avisos que dependen de como estas ahora: si ya no es asi al ir a
-- enseñarlos (has comprado, te queda algo por abrir...), no salen
local function sinSobresEnTienda()
    return partida.abiertos > 0 and nadaQueAbrir() and tiendaVacia() and desbloqueos.app("mercado")
end

local VIGENTE = {
    sinDinero = sinDinero,
    tienda = function() return nadaQueAbrir() and not sinDinero() end,
    mercadoSobres = function() return nadaQueAbrir() end,
    dia = function() return nadaQueAbrir() and (tiendaVacia() or sinDinero()) end,
}

local function avisar(id)
    local d = datos[id]
    if d.toast then
        table.insert(desbloqueos.toasts, d.toast)
        return
    end
    table.insert(desbloqueos.avisos, { id = id, texto = d.texto, apunta = d.apunta, pose = d.pose,
        inmediato = d.inmediato, vigente = VIGENTE[id] })
end

-- el siguiente toast (o nil)
function desbloqueos.toast()
    return table.remove(desbloqueos.toasts, 1)
end

-- abriendo un sobre (o con uno en el tapete) no se mira nada: el ultimo
-- sobre en la mesa no es quedarse sin sobres
local function ocupado()
    return require("src.apertura").bloqueada()
end

-- segundos de juego que faltan para enseñar el siguiente aviso: de uno en uno
-- y con aire entre ellos (datos.espera)
local pausa = 0

-- avisos inmediatos ya vistos de la serie de ahora (para el 1/2, 2/2)
local serie = 0

-- el aviso que toca enseñar ahora (o nil). Los inmediatos (lo que acaba de
-- desbloquear un sobre) salen al acabar el sobre, sin esperar
function desbloqueos.siguiente()
    if ocupado() then return nil end
    while desbloqueos.avisos[1] do
        local a = desbloqueos.avisos[1]
        if not a.vigente or a.vigente() then
            if a.inmediato or pausa <= 0 then return a end
            return nil
        end
        table.remove(desbloqueos.avisos, 1)
    end
    return nil
end

-- posicion del aviso de ahora en su serie de inmediatos: n, total (total 1 si va solo)
function desbloqueos.posicion()
    local a = desbloqueos.avisos[1]
    if not a or not a.inmediato then return 1, 1 end
    local quedan = 0
    for _, b in ipairs(desbloqueos.avisos) do
        if not b.inmediato then break end
        quedan = quedan + 1
    end
    return serie + 1, serie + quedan
end

-- se ha cerrado un aviso (o el tutorial): el siguiente espera un poco
function desbloqueos.vale(segundos)
    if segundos == nil then
        local a = table.remove(desbloqueos.avisos, 1)
        serie = (a and a.inmediato and desbloqueos.avisos[1] and desbloqueos.avisos[1].inmediato) and serie + 1 or 0
    end
    pausa = segundos or datos.espera
end

local reloj, vista = 0, nil
function desbloqueos.update(dt)
    local d = partida.desbloqueos
    -- otra partida (nueva o cargada): los avisos de antes no valen
    if d ~= vista then
        vista = d
        desbloqueos.avisos = {}
        desbloqueos.toasts = {}
        pausa, serie = 0, 0
    end
    if d == nil or d.todo then return end
    if not ocupado() then pausa = math.max(0, pausa - dt) end
    reloj = reloj + dt
    if reloj < 0.5 or ocupado() then return end
    reloj = 0
    for _, id in ipairs(datos.orden) do
        if id == "sinDinero" or id == "mercadoSobres" then
            -- una vez al dia como mucho
            local toca = id == "sinDinero" and sinDinero() or id == "mercadoSobres" and sinSobresEnTienda()
            if toca and d[id] ~= mercado.dia() then
                d[id] = mercado.dia()
                avisar(id)
                partida.guardar()
            end
        elseif id == "fundas" and not d.fundas and not d.tops and CUANDO.tops() then
            -- full art antes que ninguna rara: un aviso para las dos cosas
            d.fundas, d.tops = true, true
            partida.topsLibres = partida.topsLibres + datos.tops.tops
            avisar("fundasTops")
            partida.guardar()
        elseif not d[id] and CUANDO[id]() then
            d[id] = true
            if datos[id].tops then partida.topsLibres = partida.topsLibres + datos[id].tops end
            avisar(id)
            partida.guardar()
        end
    end
end

return desbloqueos
