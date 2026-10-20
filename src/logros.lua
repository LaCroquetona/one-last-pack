-- Logros: se miran cada segundo y los que dependen de un momento (god pack,
-- abrir una caja...) se marcan desde donde pasan. Los nuevos esperan en una
-- cola para avisar.
local lista = require "datos.logros"
local partida = require "src.partida"
local mercado = require "src.mercado"

local logros = { lista = lista }
local porId = {}
for _, l in ipairs(lista) do porId[l.id] = l end
local nuevos = {}
local reloj = 0

function logros.hecho(id)
    return partida.logros[id]
end

-- sinAviso: se marca sin avisar (partidas de antes de los logros)
function logros.marcar(id, sinAviso)
    if not porId[id] or partida.logros[id] then return end
    partida.logros[id] = mercado.dia()
    if not sinAviso then table.insert(nuevos, porId[id]) end
    partida.guardar()
end

function logros.revisar(dt, sinAviso)
    reloj = reloj + (dt or 1)
    if reloj < 1 then return end
    reloj = 0
    for _, l in ipairs(lista) do
        if l.si and not partida.logros[l.id] and l.si(partida, mercado) then logros.marcar(l.id, sinAviso) end
    end
end

function logros.siguiente()
    return table.remove(nuevos, 1)
end

function logros.cuantos()
    local n = 0
    for _, l in ipairs(lista) do
        if partida.logros[l.id] then n = n + 1 end
    end
    return n, #lista
end

return logros
