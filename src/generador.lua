local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"

local generador = {}

-- porSet["s1"]["holo"] = lista de cartas
-- (sin las variantes: esas salen cambiando una carta normal, ver mejorar)
-- varDe[id]["alt"] = la ALT de esa carta (o la "silver" / "golden")
local porSet, varDe, todasVar = {}, {}, {}
for _, c in ipairs(cartas) do
    if c.variante then
        varDe[c.de] = varDe[c.de] or {}
        varDe[c.de][c.variante] = c
        todasVar[c.set] = todasVar[c.set] or {}
        todasVar[c.set][c.variante] = todasVar[c.set][c.variante] or {}
        table.insert(todasVar[c.set][c.variante], c)
    elseif not c.promo then
        porSet[c.set] = porSet[c.set] or {}
        local r = porSet[c.set]
        r[c.rareza] = r[c.rareza] or {}
        table.insert(r[c.rareza], c)
    end
end

-- probabilidad de que una carta de cada rareza se cambie por su variante, para
-- que salga de media una de cada tipo.variantes[clave] sobres
-- chances[tipo.id][rareza][variante] = probabilidad
local chances = {}
local function chancesDe(tipo)
    if chances[tipo.id] then return chances[tipo.id] end
    local esperadas = {}
    for _, h in ipairs(tipo.huecos) do
        local total = 0
        for _, peso in pairs(h.rarezas) do total = total + peso end
        for r, peso in pairs(h.rarezas) do
            esperadas[r] = (esperadas[r] or 0) + h.cantidad * peso / total
        end
    end
    local t = {}
    for r, lista in pairs(porSet[tipo.set]) do
        for _, nombre in ipairs({ "alt", "silver", "golden" }) do
            -- cuantas de esa rareza tienen esta variante y su clave (alt_holo...)
            local con, clave = 0, nil
            for _, c in ipairs(lista) do
                local v = varDe[c.id] and varDe[c.id][nombre]
                if v then con, clave = con + 1, rarezas.clave(v) end
            end
            local cada = clave and tipo.variantes and tipo.variantes[clave]
            if cada and (esperadas[r] or 0) > 0 then
                t[r] = t[r] or {}
                t[r][nombre] = math.min(1, (1 / cada) / (esperadas[r] * con / #lista))
            end
        end
    end
    chances[tipo.id] = t
    return t
end

-- la carta que ha salido, o su ALT / SILVER / GOLDEN si toca
local ORDEN_VAR = { "golden", "silver", "alt" }
local function mejorar(c, tipo)
    local suyas = varDe[c.id]
    if not suyas then return c end
    local t = chancesDe(tipo)[c.rareza] or {}
    local tirada = love.math.random()
    for _, nombre in ipairs(ORDEN_VAR) do
        if suyas[nombre] and t[nombre] then
            if tirada < t[nombre] then return suyas[nombre] end
            tirada = tirada - t[nombre]
        end
    end
    return c
end

-- sobres seguidos sin holo o mejor, uno por tipo de sobre (la piedad).
-- Es la tabla de la partida (partida.sequia), asi se guarda
generador.sequia = {}

-- herramientas de desarrollador: "godpack", "secreta", "alt", "silver" o
-- "golden" para el siguiente sobre
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
    local forzada = generador.forzar
    generador.forzar = nil
    local ultimo = tipo.huecos[#tipo.huecos]
    local porRareza = porSet[tipo.set]
    local seco = generador.sequia[tipo.id] or 0
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
            table.insert(sobre, mejorar(c, tipo))
            mejorNivel = math.max(mejorNivel, rarezas[c.rareza].nivel)
        end
    end
    -- carta extra, con las probabilidades del comodin (el penultimo hueco)
    if love.math.random() < S.extra then
        local comodin = tipo.huecos[math.max(1, #tipo.huecos - 1)]
        local c = sacarDe(porRareza, godpack and pesosGod or comodin.rarezas, 1, usadas)
        table.insert(sobre, mejorar(c, tipo))
        mejorNivel = math.max(mejorNivel, rarezas[c.rareza].nivel)
    end
    generador.sequia[tipo.id] = mejorNivel >= 4 and 0 or seco + 1

    -- forzada desde las herramientas: la ultima carta pasa a ser una variante
    local lista = forzada and todasVar[tipo.set] and todasVar[tipo.set][forzada]
    if lista then sobre[#sobre] = lista[love.math.random(#lista)] end

    table.sort(sobre, function(a, b)
        local na, nb = rarezas.rango(a), rarezas.rango(b)
        if na ~= nb then return na < nb end
        return a.id < b.id
    end)
    return sobre, godpack
end

-- probabilidad de cada variante por sobre (para la tienda y las pruebas)
function generador.chances(tipo)
    return chancesDe(tipo)
end

return generador
