local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"

local generador = {}

local SOBRES_PIEDAD = 12   -- sin holo o mejor en tantos sobres -> el siguiente la trae
local PROB_GODPACK = 1 / 200

local porRareza = {}
for _, c in ipairs(cartas) do
    porRareza[c.rareza] = porRareza[c.rareza] or {}
    table.insert(porRareza[c.rareza], c)
end

local sequia = 0

local function alAzar(lista)
    return lista[love.math.random(#lista)]
end

local function tirarBuena(nivelMinimo)
    local total = 0
    for _, r in ipairs(rarezas.lista) do
        if r.nivel >= nivelMinimo then total = total + r.peso end
    end
    local tirada = love.math.random() * total
    for _, r in ipairs(rarezas.lista) do
        if r.nivel >= nivelMinimo and r.peso > 0 then
            tirada = tirada - r.peso
            if tirada <= 0 then return r.id end
        end
    end
    return "rara"
end

-- 3 comunes, 1 infrecuente y la buena al final, ordenadas de peor a mejor
function generador.sobre()
    local godpack = love.math.random() < PROB_GODPACK
    local ids = {}

    for i = 1, 3 do
        if godpack then
            ids[i] = tirarBuena(3)
        else
            ids[i] = love.math.random() < 0.12 and "infrecuente" or "comun"
        end
    end

    if godpack then
        ids[4] = tirarBuena(3)
    else
        ids[4] = love.math.random() < 0.15 and "rara" or "infrecuente"
    end

    ids[5] = tirarBuena(sequia >= SOBRES_PIEDAD and 4 or 3)

    local sobre = {}
    local mejorNivel = 0
    for i, id in ipairs(ids) do
        sobre[i] = alAzar(porRareza[id])
        mejorNivel = math.max(mejorNivel, rarezas[id].nivel)
    end
    sequia = mejorNivel >= 4 and 0 or sequia + 1

    table.sort(sobre, function(a, b)
        return rarezas[a.rareza].nivel < rarezas[b.rareza].nivel
    end)
    return sobre, godpack
end

return generador
