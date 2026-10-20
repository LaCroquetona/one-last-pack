-- Emojis de pixel que suben por el chat del directo cuando sale algo bueno
-- (o muy malo). Cada uno es un dibujo de 7x7; los de texto se escriben.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"

local lg = love.graphics

local emojis = {}

local COLORES = { r = p.rojo, o = p.naranja, y = p.amarillo, w = p.blanco, k = p.negro, g = p.verde, l = p.lima, c = p.cian, v = p.violeta }

local DIBUJOS = {
    corazon = { ".rr.rr.", "rwrrrrr", "rrrrrrr", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..." },
    fuego = { "...o...", "..oo.o.", ".ooooo.", ".oyyoo.", "oyyyyro", "oyyyyro", ".orrro." },
    calavera = { ".wwwww.", "wwwwwww", "wkkwkkw", "wkkwkkw", "wwwkwww", ".wwwww.", ".w.w.w." },
    ojos = { ".......", "www.www", "wkw.wkw", "wkw.wkw", "www.www", ".......", "......." },
    estrella = { "...y...", "..yyy..", "yyyyyyy", ".yyyyy.", "..yyy..", ".yy.yy.", "y.....y" },
    moneda = { "..yyy..", ".yoooy.", "yoyyyoy", "yoyoyoy", "yoyyyoy", ".yoooy.", "..yyy.." },
    corona = { "y..y..y", "yy.y.yy", "yyyyyyy", "yrycyry", "yyyyyyy", ".......", "......." },
}
local TEXTOS = { ["67"] = p.lima, W = p.cian, GG = p.amarillo }

local imagenes = {}
local function imagen(k)
    if imagenes[k] then return imagenes[k] end
    local d = love.image.newImageData(7, 7)
    for y, fila in ipairs(DIBUJOS[k]) do
        for x = 1, 7 do
            local col = COLORES[fila:sub(x, x)]
            if col then d:setPixel(x - 1, y - 1, col[1], col[2], col[3], 1) end
        end
    end
    local img = lg.newImage(d)
    img:setFilter("nearest", "nearest")
    imagenes[k] = img
    return img
end

local vivos = {}
local VIDA = 2.4

-- tipos: lista de nombres; n: cuantos; durante: segundos en que van saliendo
function emojis.lanzar(tipos, n, durante)
    for _ = 1, math.min(n, 24 - #vivos) do
        table.insert(vivos, { k = tipos[love.math.random(#tipos)], t = -love.math.random() * (durante or 1),
                              x = 0.5 + love.math.random() * 0.36, fase = love.math.random() * 6 })
    end
end

function emojis.update(dt)
    for i = #vivos, 1, -1 do
        local e = vivos[i]
        e.t = e.t + dt
        if e.t > VIDA then table.remove(vivos, i) end
    end
end

function emojis.limpiar()
    vivos = {}
end

-- suben desde abajo a la derecha del chat (x, y, w, h)
function emojis.dibujar(x, y, w, h)
    for _, e in ipairs(vivos) do
        if e.t >= 0 then
            local q = e.t / VIDA
            local ex = math.floor(x + w * e.x + math.sin(e.t * 3 + e.fase) * 4)
            local ey = math.floor(y + h - 16 - q * (h - 40))
            local a = q > 0.75 and (1 - q) / 0.25 or 1
            if TEXTOS[e.k] then
                local c = TEXTOS[e.k]
                fuentes.texto(e.k, ex, ey + 2, 2, { c[1], c[2], c[3], a })
            else
                lg.setColor(1, 1, 1, a)
                lg.draw(imagen(e.k), ex, ey, 0, 2, 2)
            end
        end
    end
    lg.setColor(1, 1, 1)
end

return emojis
