local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local sobres = require "datos.sobres"

local partida = {
    dinero = sobres.inicio.dinero,
    abiertos = 0,
    coleccion = {},
    guardados = {},
}
local ARCHIVO = "partida.txt"

local porId = {}
for _, c in ipairs(cartas) do
    porId[c.id] = c
end

for tipo, n in pairs(sobres.inicio.sobres) do
    partida.guardados[tipo] = n
end

function partida.carta(id)
    return porId[id]
end

function partida.copias(id)
    return partida.coleccion[id] or 0
end

-- true si era la primera copia, para el aviso de NUEVA
function partida.anadir(id)
    local antes = partida.copias(id)
    partida.coleccion[id] = antes + 1
    return antes == 0
end

function partida.distintas()
    local n = 0
    for _, c in ipairs(cartas) do
        if partida.coleccion[c.id] then n = n + 1 end
    end
    return n
end

function partida.precio(id)
    return rarezas[porId[id].rareza].precio
end

-- copias que sobran (siempre se queda una) y lo que valen
function partida.repetidas()
    local n, valor = 0, 0
    for _, c in ipairs(cartas) do
        local extra = partida.copias(c.id) - 1
        if extra > 0 then
            n = n + extra
            valor = valor + extra * partida.precio(c.id)
        end
    end
    return n, valor
end

-- solo se venden repetidas: la ultima copia no se toca
function partida.vender(id, cantidad)
    cantidad = math.min(cantidad, partida.copias(id) - 1)
    if cantidad <= 0 then return 0 end
    partida.coleccion[id] = partida.coleccion[id] - cantidad
    local ganado = cantidad * partida.precio(id)
    partida.dinero = partida.dinero + ganado
    return ganado
end

function partida.venderRepes()
    local total = 0
    for _, c in ipairs(cartas) do
        total = total + partida.vender(c.id, math.huge)
    end
    return total
end

function partida.comprar(tipo, cantidad)
    local coste = sobres[tipo].precio * cantidad
    if partida.dinero < coste then return false end
    partida.dinero = partida.dinero - coste
    partida.guardados[tipo] = (partida.guardados[tipo] or 0) + cantidad
    return true
end

function partida.regalar(tipo)
    partida.guardados[tipo] = (partida.guardados[tipo] or 0) + 1
end

function partida.sobresGuardados()
    local n = 0
    for _, c in pairs(partida.guardados) do n = n + c end
    return n
end

-- el primer tipo que quede por abrir, o nil
function partida.sacarSobre()
    for _, s in ipairs(sobres.lista) do
        if (partida.guardados[s.id] or 0) > 0 then
            partida.guardados[s.id] = partida.guardados[s.id] - 1
            partida.abiertos = partida.abiertos + 1
            return s
        end
    end
end

function partida.guardar()
    local lineas = { "dinero=" .. partida.dinero, "abiertos=" .. partida.abiertos }
    for tipo, n in pairs(partida.guardados) do
        table.insert(lineas, "sobre_" .. tipo .. "=" .. n)
    end
    for id, n in pairs(partida.coleccion) do
        table.insert(lineas, id .. "=" .. n)
    end
    love.filesystem.write(ARCHIVO, table.concat(lineas, "\n"))
end

function partida.cargar()
    if not love.filesystem.getInfo(ARCHIVO) then return end
    partida.guardados = {}
    for linea in love.filesystem.lines(ARCHIVO) do
        local clave, valor = linea:match("^([%w_]+)=(%d+)$")
        valor = tonumber(valor)
        if clave == "dinero" then
            partida.dinero = valor
        elseif clave == "abiertos" or clave == "sobres" then
            -- "sobres" era el nombre en la v0.1
            partida.abiertos = valor
        elseif clave and clave:match("^sobre_") then
            partida.guardados[clave:sub(7)] = valor
        elseif clave and tonumber(clave) then
            partida.coleccion[tonumber(clave)] = valor
        end
    end
end

return partida
