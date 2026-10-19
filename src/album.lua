local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local partida = require "src.partida"
local carta = require "src.carta"
local fuentes = require "src.fuentes"

local lg = love.graphics

local album = {}

local COLUMNAS = 10
local ESCALA = 0.5
local HUECO = 5
local X0, Y0 = 20, 46
local CW = carta.ANCHO * ESCALA
local CH = carta.ALTO * ESCALA

local function posicion(i)
    local col = (i - 1) % COLUMNAS
    local fila = math.floor((i - 1) / COLUMNAS)
    return X0 + col * (CW + HUECO), Y0 + fila * (CH + HUECO)
end

local function bajoRaton(mx, my)
    for i = 1, #cartas do
        local x, y = posicion(i)
        if mx >= x and mx < x + CW and my >= y and my < y + CH then return i end
    end
end

function album.dibujar(mx, my)
    lg.setFont(fuentes.grande)
    lg.setColor(1, 1, 1)
    lg.print("Álbum - Set 1", X0, 14)

    for i, def in ipairs(cartas) do
        local x, y = posicion(i)
        local copias = partida.coleccion[def.id]
        if copias then
            carta.dibujar(def, x + CW / 2, y + CH / 2, ESCALA, ESCALA, 0, true)
            if copias > 1 then
                lg.setFont(fuentes.mini)
                lg.setColor(0, 0, 0, 0.7)
                lg.rectangle("fill", x + CW - 14, y + CH - 9, 14, 9)
                lg.setColor(1, 1, 1)
                lg.print("x" .. copias, x + CW - 13, y + CH - 9)
            end
        else
            lg.setColor(1, 1, 1, 0.06)
            lg.rectangle("fill", x, y, CW, CH)
            lg.setColor(1, 1, 1, 0.25)
            lg.setFont(fuentes.mini)
            lg.printf(string.format("#%02d", def.id), x, y + CH / 2 - 4, CW, "center")
        end
    end

    local y = Y0 + 4 * (CH + HUECO) + 10
    local x = X0
    lg.setFont(fuentes.mini)
    for _, r in ipairs(rarezas.lista) do
        local tengo, total = 0, 0
        for _, def in ipairs(cartas) do
            if def.rareza == r.id then
                total = total + 1
                if partida.coleccion[def.id] then tengo = tengo + 1 end
            end
        end
        lg.setColor(r.color)
        local linea = r.nombre .. " " .. tengo .. "/" .. total
        lg.print(linea, x, y)
        x = x + fuentes.mini:getWidth(linea) + 14
    end

    local i = bajoRaton(mx, my)
    if i then
        local def = cartas[i]
        if partida.coleccion[def.id] then
            carta.dibujar(def, 530, 160, 1.6, 1.6, 0, true)
        else
            carta.dibujar(nil, 530, 160, 1.6, 1.6, 0, false)
            lg.setFont(fuentes.grande)
            lg.setColor(1, 1, 1)
            lg.printf("???", 430, 250, 200, "center")
        end
    end
    lg.setColor(1, 1, 1)
end

return album
