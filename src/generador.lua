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

-- mejoras de suerte (las pone src/mejoras.lua):
-- segunda: probabilidad de tirar otra vez el ultimo hueco y quedarte la mejor;
-- extra: probabilidad de una carta mas (con las probabilidades del comodin);
-- godpack: multiplica la probabilidad de god pack
generador.suerte = { segunda = 0, extra = 0, godpack = 1 }

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

-- una carta de ese hueco que no este ya en el sobre
local function sacarDe(porRareza, pesos, minimo, usadas)
    local rareza = tirar(porRareza, pesos, minimo)
    -- si ya han salido todas las de esa rareza (god packs) se vuelve a tirar
    for _ = 1, 10 do
        if not agotada(porRareza, rareza, usadas) then break end
        rareza = tirar(porRareza, pesos, minimo)
    end
    return elegir(porRareza, rareza, usadas)
end

-- tipo: una entrada de datos/sobres.lua. Devuelve las cartas de peor a mejor
function generador.sobre(tipo)
    local S = generador.suerte
    local godpack = love.math.random() < tipo.godpack * S.godpack or generador.forzar == "godpack"
    local secreta = generador.forzar == "secreta"
    generador.forzar = nil
    local ultimo = tipo.huecos[#tipo.huecos]
    local porRareza = porSet[tipo.set]
    local seco = sequia[tipo.id] or 0
    local sobre, usadas = {}, {}
    local mejorNivel = 0

    -- god pack: todo holo o mejor (sin raras), con las proporciones del ultimo hueco
    local pesosGod = {}
    for r, peso in pairs(ultimo.rarezas) do
        if rarezas[r].nivel >= 4 then pesosGod[r] = peso end
    end
    for _, hueco in ipairs(tipo.huecos) do
        local pesos = godpack and pesosGod or hueco.rarezas
        if secreta and hueco == ultimo then pesos = { secreta = 1 } end
        local minimo = (hueco == ultimo and seco >= tipo.piedad) and 4 or 1
        for _ = 1, hueco.cantidad do
            local c = sacarDe(porRareza, pesos, minimo, usadas)
            -- segunda oportunidad: el ultimo hueco se tira otra vez y te quedas la mejor
            if hueco == ultimo and not secreta and love.math.random() < S.segunda then
                local otra = sacarDe(porRareza, pesos, minimo, usadas)
                if rarezas[otra.rareza].nivel > rarezas[c.rareza].nivel then
                    usadas[c.id] = nil
                    c = otra
                else
                    usadas[otra.id] = nil
                end
            end
            table.insert(sobre, c)
            mejorNivel = math.max(mejorNivel, rarezas[c.rareza].nivel)
        end
    end
    -- carta extra, con las probabilidades del comodin (el penultimo hueco)
    if love.math.random() < S.extra then
        local comodin = tipo.huecos[math.max(1, #tipo.huecos - 1)]
        local c = sacarDe(porRareza, godpack and pesosGod or comodin.rarezas, 1, usadas)
        table.insert(sobre, c)
        mejorNivel = math.max(mejorNivel, rarezas[c.rareza].nivel)
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
