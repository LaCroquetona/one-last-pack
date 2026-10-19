local cartas = require "datos.cartas"

local partida = { sobres = 0, coleccion = {} }
local ARCHIVO = "partida.txt"

function partida.anadir(id)
    local antes = partida.coleccion[id] or 0
    partida.coleccion[id] = antes + 1
    return antes == 0
end

function partida.sobreAbierto()
    partida.sobres = partida.sobres + 1
end

function partida.distintas()
    local n = 0
    for _, c in ipairs(cartas) do
        if partida.coleccion[c.id] then n = n + 1 end
    end
    return n
end

function partida.guardar()
    local lineas = { "sobres=" .. partida.sobres }
    for id, n in pairs(partida.coleccion) do
        table.insert(lineas, id .. "=" .. n)
    end
    love.filesystem.write(ARCHIVO, table.concat(lineas, "\n"))
end

function partida.cargar()
    if not love.filesystem.getInfo(ARCHIVO) then return end
    for linea in love.filesystem.lines(ARCHIVO) do
        local clave, valor = linea:match("^(%w+)=(%d+)$")
        if clave == "sobres" then
            partida.sobres = tonumber(valor)
        elseif clave then
            partida.coleccion[tonumber(clave)] = tonumber(valor)
        end
    end
end

return partida
