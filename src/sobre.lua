-- El dibujo del sobre, a 30x44 como las cartas, y los dos trozos al rasgarlo
local p = require "datos.paleta"
local fuentes = require "src.fuentes"

local lg = love.graphics

local sobre = { ANCHO = 30, ALTO = 44, CORTE = 7 }

local function px(x, y)
    lg.rectangle("fill", x, y, 1, 1)
end

local function pintar()
    local W, H = sobre.ANCHO, sobre.ALTO
    lg.setColor(p.grisclaro)
    for x = 0, W - 1 do
        local diente = x % 2
        lg.rectangle("fill", x, diente, 1, 3 - diente)
        lg.rectangle("fill", x, H - 3, 1, 3 - diente)
    end

    lg.setColor(p.rojo)
    lg.rectangle("fill", 0, 3, W, H - 6)
    lg.setColor(p.naranja)
    for y = 3, H - 4 do
        for x = 0, W - 1 do
            if (x + y) % 8 < 2 then px(x, y) end
        end
    end
    lg.setColor(p.morado)
    lg.rectangle("fill", 0, 3, 1, H - 6)
    lg.rectangle("fill", W - 1, 3, 1, H - 6)

    lg.setColor(p.negro)
    lg.rectangle("fill", 0, 13, W, 15)
    local cx, cy = W / 2, 20
    lg.setColor(p.amarillo)
    lg.polygon("fill", cx, cy - 6, cx + 6, cy, cx, cy + 6, cx - 6, cy)
    lg.setColor(p.rojo)
    lg.polygon("fill", cx, cy - 3, cx + 3, cy, cx, cy + 3, cx - 3, cy)

    lg.setColor(p.negro)
    lg.rectangle("fill", 0, 31, W, 7)
    fuentes.texto("SET 1", 0, 32, 1, p.amarillo, "center", W)

    lg.setColor(p.blanco)
    for x = 1, W - 2, 2 do px(x, sobre.CORTE) end
end

function sobre.preparar()
    sobre.img = lg.newCanvas(sobre.ANCHO, sobre.ALTO)
    sobre.img:setFilter("nearest", "nearest")
    lg.setCanvas(sobre.img)
    lg.clear(0, 0, 0, 0)
    pintar()
    lg.setCanvas()
    lg.setColor(1, 1, 1)
    sobre.arriba = lg.newQuad(0, 0, sobre.ANCHO, sobre.CORTE, sobre.ANCHO, sobre.ALTO)
    sobre.abajo = lg.newQuad(0, sobre.CORTE, sobre.ANCHO, sobre.ALTO - sobre.CORTE, sobre.ANCHO, sobre.ALTO)
end

function sobre.dibujar(x, y, escala, rot, kx, ky)
    local W, H = sobre.ANCHO, sobre.ALTO
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x - W / 2 * escala + 3, y - H / 2 * escala + 4, W * escala, H * escala)
    lg.setColor(1, 1, 1)
    lg.draw(sobre.img, x, y, rot or 0, escala, escala, W / 2, H / 2, kx or 0, ky or 0)
end

return sobre
