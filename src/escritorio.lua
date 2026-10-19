-- La mesa de madera sobre la que se juega. Se genera por codigo; si existe
-- sprites/escritorio.png se usa esa imagen en su lugar (se ajusta tapando toda la ventana).
local lg = love.graphics

local escritorio = {}

local ARCHIVO = "sprites/escritorio.png"
local TABLA = 26   -- alto de cada tabla, en pixeles del juego

local MADERA = {
    { 0.30, 0.19, 0.13 },
    { 0.27, 0.17, 0.12 },
    { 0.33, 0.21, 0.14 },
}
local VETA = { 0.22, 0.13, 0.09 }
local LUZ = { 0.37, 0.24, 0.16 }
local JUNTA = { 0.13, 0.08, 0.06 }

local textura, imagen
local anchoHecho, altoHecho

-- w, h en pixeles del juego
local function generar(w, h)
    local datos = love.image.newImageData(w, h)
    local rng = love.math.newRandomGenerator(1234)
    local filas = math.ceil(h / TABLA)
    for f = 0, filas - 1 do
        local base = MADERA[f % #MADERA + 1]
        local fase = rng:random() * 10
        local onda = 0.03 + rng:random() * 0.04
        -- las tablas no empiezan todas en el mismo sitio: juntas verticales a destiempo
        local corte = rng:random(60, 200)
        local nudoX, nudoY = rng:random(0, w), f * TABLA + rng:random(6, TABLA - 6)
        for y = f * TABLA, math.min(h - 1, f * TABLA + TABLA - 1) do
            local fy = y - f * TABLA
            for x = 0, w - 1 do
                local c = base
                local veta = math.sin(x * onda + fase + fy * 0.9) + math.sin(x * onda * 2.7 + fy * 0.35 + fase * 2)
                if veta > 1.5 then
                    c = VETA
                elseif veta < -1.75 then
                    c = LUZ
                end
                local dx, dy = x - nudoX, (y - nudoY) * 2.2
                local d = dx * dx + dy * dy
                if d < 30 then
                    c = d < 8 and JUNTA or VETA
                end
                if fy == 0 or (x - corte) % 320 == 0 then
                    c = JUNTA
                elseif fy == 1 then
                    c = LUZ
                end
                datos:setPixel(x, y, c[1], c[2], c[3], 1)
            end
        end
    end
    local img = lg.newImage(datos)
    img:setFilter("nearest", "nearest")
    return img
end

function escritorio.preparar()
    if love.filesystem.getInfo(ARCHIVO) then
        imagen = lg.newImage(ARCHIVO)
    end
end

-- e, ox, oy: escala y desplazamiento del juego en la ventana, para que las
-- tablas se alineen con los pixeles del juego
function escritorio.dibujar(e, ox, oy, tinte)
    local w, h = lg.getDimensions()
    lg.setColor(1, 1, 1)
    if imagen then
        local s = math.max(w / imagen:getWidth(), h / imagen:getHeight())
        lg.draw(imagen, (w - imagen:getWidth() * s) / 2, (h - imagen:getHeight() * s) / 2, 0, s, s)
    else
        local gw, gh = math.ceil(w / e) + 2, math.ceil(h / e) + 2
        if gw ~= anchoHecho or gh ~= altoHecho then
            textura = generar(gw, gh)
            anchoHecho, altoHecho = gw, gh
        end
        -- la tabla de arriba del juego cae justo en y = 0 del juego
        local inicioY = oy - math.ceil(oy / e / TABLA) * TABLA * e
        lg.draw(textura, ox % e - e, inicioY, 0, e, e)
    end

    -- bordes un poco mas oscuros, como una lampara que ilumina el centro
    local pasos = 8
    for i = 1, pasos do
        lg.setColor(0, 0, 0, 0.045)
        local m = i * math.min(w, h) * 0.035
        lg.rectangle("fill", 0, 0, w, m)
        lg.rectangle("fill", 0, h - m, w, m)
        lg.rectangle("fill", 0, 0, m, h)
        lg.rectangle("fill", w - m, 0, m, h)
    end

    -- el color de las cartas buenas tiñe la mesa un momento
    if tinte then
        lg.setBlendMode("add")
        lg.setColor(tinte[1], tinte[2], tinte[3])
        lg.rectangle("fill", 0, 0, w, h)
        lg.setBlendMode("alpha")
    end
    lg.setColor(1, 1, 1)
end

return escritorio
