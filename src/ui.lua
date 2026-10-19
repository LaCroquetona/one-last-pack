-- Interfaz de modo inmediato: cada frame las pantallas pintan sus botones y
-- zonas, y el click se resuelve con lo pintado en el frame anterior.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"

local lg = love.graphics

local ui = { mx = 0, my = 0 }

local zonas = {}
local anims = {}
local anterior
local tip

local function dentro(z, x, y)
    return x >= z.x and x < z.x + z.w and y >= z.y and y < z.y + z.h
end

local function buscar(x, y)
    for i = #zonas, 1, -1 do
        if dentro(zonas[i], x, y) then return zonas[i].id end
    end
end

function ui.empezar(mx, my)
    ui.mx, ui.my = mx, my
    ui.encima = buscar(mx, my)
    if ui.encima and ui.encima ~= anterior then sonido.tocar("encima") end
    anterior = ui.encima
    zonas = {}
    tip = nil
end

function ui.zona(id, x, y, w, h)
    table.insert(zonas, { id = id, x = x, y = y, w = w, h = h })
end

function ui.click(mx, my)
    return buscar(mx, my)
end

-- valor que va suave hacia el objetivo, uno por id
function ui.anim(id, objetivo, velocidad)
    local v = anims[id] or 0
    v = v + (objetivo - v) * math.min(1, love.timer.getDelta() * (velocidad or 14))
    anims[id] = v
    return v
end

local function oscuro(c)
    return { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55 }
end

function ui.boton(id, texto, x, y, w, h, color, activo)
    if activo == nil then activo = true end
    local alza = ui.anim(id, (activo and ui.encima == id) and 1 or 0)
    local dy = -math.floor(alza * 2 + 0.5)
    local c = activo and color or p.grisosc

    lg.setColor(p.negro)
    lg.rectangle("fill", x, y + 1, w, h + 1)
    lg.setColor(oscuro(c))
    lg.rectangle("fill", x, y + dy, w, h)
    lg.setColor(c)
    lg.rectangle("fill", x + 1, y + dy + 1, w - 2, h - 3)
    fuentes.texto(texto, x, y + dy + math.floor((h - 5) / 2), 1, activo and p.blanco or p.gris, "center", w)

    if activo then ui.zona(id, x, y, w, h) end
end

-- caja oscura con borde, la de los paneles
function ui.caja(x, y, w, h, relleno)
    lg.setColor(p.negro)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(relleno or p.grisosc)
    lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    lg.setColor(1, 1, 1)
end

-- inclinacion de una carta segun donde este el raton, para carta.dibujar
function ui.hoverCarta(id, x, y, ancho, alto)
    local a = ui.anim(id, ui.encima == id and 1 or 0)
    if a < 0.01 then return nil end
    local dx = math.max(-1, math.min(1, (ui.mx - x) / (ancho / 2)))
    local dy = math.max(-1, math.min(1, (ui.my - y) / (alto / 2)))
    return { kx = -dx * dy * 0.12 * a, ky = dx * 0.06 * a, brillo = a, lx = dx, ly = dy }
end

-- se pide durante el frame y se pinta al final, por encima de todo
function ui.tooltip(titulo, color, lineas)
    tip = { titulo = titulo, color = color, lineas = lineas }
end

function ui.dibujarTooltip(anchoPantalla, altoPantalla)
    if not tip then return end
    local w = fuentes.ancho(tip.titulo) + 10
    for _, l in ipairs(tip.lineas) do
        w = math.max(w, fuentes.ancho(l[1]) + 10)
    end
    local h = 14 + #tip.lineas * 8
    local x = math.min(ui.mx + 10, anchoPantalla - w - 4)
    local y = ui.my + 12
    if y + h > altoPantalla - 4 then y = ui.my - h - 6 end

    ui.caja(x, y, w, h, p.negro)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 2, y + 11, w - 4, h - 13)
    fuentes.texto(tip.titulo, x + 5, y + 3, 1, tip.color)
    for i, l in ipairs(tip.lineas) do
        fuentes.texto(l[1], x + 5, y + 6 + i * 8, 1, l[2] or p.blanco)
    end
end

function ui.dinero(n)
    local s = tostring(math.floor(n + 0.5))
    local con = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    return "$" .. con:gsub("^%.", "")
end

return ui
