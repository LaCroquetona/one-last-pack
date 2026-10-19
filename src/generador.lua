local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"

local generador = {}

-- porSet["s1"]["holo"] = lista de cartas
local porSet = {}
for _, c in ipairs(cartas) do
    porSet[c.set] = porSet[c.set] or {}
    local r = porSet[c.set]
    r[c.rareza] = r[c.rareza] or {}
    table.insert(r[c.rareza], c)
end

-- sobres seguidos sin holo o mejor, uno por tipo de sobre
local sequia = {}

-- herramientas de desarrollador: "godpack" o "secreta" para el siguiente sobre
generador.forzar = nil

local function tirar(porRareza, pesos, nivelMinimo)
    local candidatas, total = {}, 0
    for _, r in ipairs(rarezas.lista) do
        local peso = pesos[r.id]
        if peso and r.nivel >= nivelMinimo and porRareza[r.id] then
            table.insert(candidatas, { id = r.id, peso = peso })
            total = total + peso
        end
    end
    -- si el minimo deja el hueco vacio se ignora
    if #candidatas == 0 then return tirar(porRareza, pesos, 1) end
    local tirada = love.math.random() * total
    for _, c in ipairs(candidatas) do
        tirada = tirada - c.peso
        if tirada <= 0 then return c.id end
    end
    return candidatas[#candidatas].id
end

local function agotada(porRareza, rareza, usadas)
    for _, c in ipairs(porRareza[rareza]) do
        if not usadas[c.id] then return false end
    end
    return true
end

-- dentro de un sobre no se repite carta mientras queden otras de esa rareza
local function elegir(porRareza, rareza, usadas)
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
    local godpack = love.math.random() < tipo.godpack or generador.forzar == "godpack"
    local secreta = generador.forzar == "secreta"
    generador.forzar = nil
    local ultimo = tipo.huecos[#tipo.huecos]
    local porRareza = porSet[tipo.set]
    local seco = sequia[tipo.id] or 0
    local sobre, usadas = {}, {}
    local mejorNivel = 0

    for _, hueco in ipairs(tipo.huecos) do
        local pesos = godpack and ultimo.rarezas or hueco.rarezas
        if secreta and hueco == ultimo then pesos = { secreta = 1 } end
        local minimo = (hueco == ultimo and seco >= tipo.piedad) and 4 or 1
        for _ = 1, hueco.cantidad do
            local rareza = tirar(porRareza, pesos, minimo)
            -- si ya han salido todas las de esa rareza (god packs) se vuelve a tirar
            for _ = 1, 10 do
                if not agotada(porRareza, rareza, usadas) then break end
                rareza = tirar(porRareza, pesos, minimo)
            end
            table.insert(sobre, elegir(porRareza, rareza, usadas))
            mejorNivel = math.max(mejorNivel, rarezas[rareza].nivel)
        end
    end
    sequia[tipo.id] = mejorNivel >= 4 and 0 or seco + 1

    table.sort(sobre, function(a, b)
        local na, nb = rarezas[a.rareza].nivel, rarezas[b.rareza].nivel
        if na ~= nb then return na < nb end
        return a.id < b.id
    end)
    return sobre, godpack
end

return generador
