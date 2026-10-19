local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"

local generador = {}

local porRareza = {}
for _, c in ipairs(cartas) do
    porRareza[c.rareza] = porRareza[c.rareza] or {}
    table.insert(porRareza[c.rareza], c)
end

local sequia = 0

local function tirar(pesos, nivelMinimo)
    local candidatas, total = {}, 0
    for _, r in ipairs(rarezas.lista) do
        local peso = pesos[r.id]
        if peso and r.nivel >= nivelMinimo and porRareza[r.id] then
            table.insert(candidatas, { id = r.id, peso = peso })
            total = total + peso
        end
    end
    -- si el minimo deja el hueco vacio se ignora
    if #candidatas == 0 then return tirar(pesos, 1) end
    local tirada = love.math.random() * total
    for _, c in ipairs(candidatas) do
        tirada = tirada - c.peso
        if tirada <= 0 then return c.id end
    end
    return candidatas[#candidatas].id
end

-- dentro de un sobre no se repite carta mientras queden otras de esa rareza
local function elegir(rareza, usadas)
    local libres = {}
    for _, c in ipairs(porRareza[rareza]) do
        if not usadas[c.id] then table.insert(libres, c) end
    end
    if #libres == 0 then libres = porRareza[rareza] end
    local c = libres[love.math.random(#libres)]
    usadas[c.id] = true
    return c
end

-- tipo: una entrada de datos/sobres.lua. Devuelve las cartas de peor a mejor
function generador.sobre(tipo)
    local godpack = love.math.random() < tipo.godpack
    local ultimo = tipo.huecos[#tipo.huecos]
    local sobre, usadas = {}, {}
    local mejorNivel = 0

    for _, hueco in ipairs(tipo.huecos) do
        local pesos = godpack and ultimo.rarezas or hueco.rarezas
        local minimo = (hueco == ultimo and sequia >= tipo.piedad) and 4 or 1
        for _ = 1, hueco.cantidad do
            local rareza = tirar(pesos, minimo)
            table.insert(sobre, elegir(rareza, usadas))
            mejorNivel = math.max(mejorNivel, rarezas[rareza].nivel)
        end
    end
    sequia = mejorNivel >= 4 and 0 or sequia + 1

    table.sort(sobre, function(a, b)
        local na, nb = rarezas[a.rareza].nivel, rarezas[b.rareza].nivel
        if na ~= nb then return na < nb end
        return a.id < b.id
    end)
    return sobre, godpack
end

return generador
