-- Bichos de pixel sacados de una semilla, simetricos como los space invaders.
-- Son el dibujo provisional de cada carta hasta que haya sprites hechos a mano.
-- Cada semilla elige proporciones, cuernos, patas, ojos y panza.
local p = require "datos.paleta"

local bicho = {}

local function vecinos(lleno, x, y)
    local n = 0
    for dy = -1, 1 do
        for dx = -1, 1 do
            if (dx ~= 0 or dy ~= 0) and lleno[y + dy] and lleno[y + dy][x + dx] then n = n + 1 end
        end
    end
    return n
end

local function rejilla(alto)
    local g = {}
    for y = -1, alto do g[y] = {} end
    return g
end

-- ancho par; e = elemento (cuerpo, luz, sombra)
function bicho.crear(semilla, ancho, alto, e)
    local rng = love.math.newRandomGenerator(semilla)
    local mitad = ancho / 2

    local densidad = 0.75 + rng:random() * 0.35
    local estrecho = 0.45 + rng:random() * 0.6
    local redondo = 0.3 + rng:random() * 0.7
    -- donde cae el centro del cuerpo: arriba (cabezon) o abajo (panzudo)
    local centro = (alto - 1) * (0.4 + rng:random() * 0.25)

    local lleno = rejilla(alto)
    for y = 2, alto - 3 do
        for x = 1, mitad - 1 do
            local dx = (mitad - 1 - x) / (mitad - 1)
            local dy = math.abs(y - centro) / (alto / 2)
            if rng:random() < densidad - dx * estrecho - dy * dy * redondo then
                lleno[y][x] = true
                lleno[y][ancho - 1 - x] = true
            end
        end
    end

    -- dos pasadas de suavizado: rellena huecos y quita pixeles sueltos
    for _ = 1, 2 do
        local nuevo = rejilla(alto)
        for y = 0, alto - 1 do
            for x = 0, ancho - 1 do
                local n = vecinos(lleno, x, y)
                if lleno[y][x] then
                    nuevo[y][x] = n >= 2
                else
                    nuevo[y][x] = n >= 5 and y > 0 and y < alto - 1 and x > 0 and x < ancho - 1
                end
            end
        end
        lleno = nuevo
    end

    local arriba, abajo = alto, 0
    for y = 0, alto - 1 do
        for x = 0, ancho - 1 do
            if lleno[y][x] then
                arriba = math.min(arriba, y)
                abajo = math.max(abajo, y)
            end
        end
    end
    if arriba > abajo then
        arriba, abajo = math.floor(alto / 3), math.floor(alto * 2 / 3)
        for y = arriba, abajo do
            lleno[y][mitad - 1], lleno[y][mitad] = true, true
        end
    end

    -- cuernos u orejas que salen de la parte de arriba
    if rng:random() < 0.55 then
        local x = rng:random(math.max(1, mitad - 5), mitad - 2)
        local largo = rng:random(2, 3)
        for i = 1, largo do
            local y = arriba - i + 1
            local cx = x - (i - 1)
            if y >= 1 and cx >= 1 then
                lleno[y][cx] = true
                lleno[y][ancho - 1 - cx] = true
            end
        end
    end

    -- patas que salen de abajo
    if rng:random() < 0.6 then
        local x = rng:random(math.max(1, mitad - 6), mitad - 2)
        for i = 1, 2 do
            local y = abajo + i
            if y <= alto - 2 then
                lleno[y][x] = true
                lleno[y][ancho - 1 - x] = true
            end
        end
    end

    local panza = rng:random() < 0.5
    local ciclope = rng:random() < 0.25
    local ojoY = math.floor(arriba + (abajo - arriba) * (0.2 + rng:random() * 0.2))
    local ojoX = ciclope and mitad - 1 or rng:random(math.max(1, mitad - 4), mitad - 2)
    lleno[ojoY][ojoX], lleno[ojoY + 1][ojoX] = true, true
    lleno[ojoY][ancho - 1 - ojoX], lleno[ojoY + 1][ancho - 1 - ojoX] = true, true

    local datos = love.image.newImageData(ancho, alto)
    local function pintar(x, y, c)
        datos:setPixel(x, y, c[1], c[2], c[3], 1)
        datos:setPixel(ancho - 1 - x, y, c[1], c[2], c[3], 1)
    end

    local medio = (arriba + abajo) / 2
    for y = 0, alto - 1 do
        for x = 0, mitad - 1 do
            if lleno[y][x] then
                local c = e.cuerpo
                if not lleno[y - 1][x] then
                    c = e.luz
                elseif not lleno[y + 1][x] or not lleno[y][x - 1] then
                    c = e.sombra
                elseif panza and y > medio and x >= mitad - 2 then
                    c = e.luz
                elseif rng:random() < 0.06 then
                    c = e.sombra
                end
                pintar(x, y, c)
            elseif lleno[y - 1][x] or lleno[y + 1][x] or lleno[y][x - 1] or lleno[y][x + 1] then
                pintar(x, y, p.negro)
            end
        end
    end

    pintar(ojoX, ojoY, p.blanco)
    pintar(ojoX, ojoY + 1, p.negro)

    local img = love.graphics.newImage(datos)
    img:setFilter("nearest", "nearest")
    return img
end

return bicho
