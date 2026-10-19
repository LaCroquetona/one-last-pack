local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local elementos = require "datos.elementos"
local fuentes = require "src.fuentes"

local lg = love.graphics

local carta = { ANCHO = 72, ALTO = 100 }

local caras = {}
local dorso
local brillo

-- franja de arcoiris que recorre la carta en diagonal
local codigoBrillo = [[
extern number tiempo;
extern number fuerza;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * color;
    float banda = sin((uv.x * 1.5 + uv.y) * 9.0 - tiempo * 2.5) * 0.5 + 0.5;
    vec3 arcoiris = 0.5 + 0.5 * cos(6.2831 * (uv.x + uv.y * 0.5 + tiempo * 0.15) + vec3(0.0, 2.1, 4.2));
    c.rgb = mix(c.rgb, c.rgb + arcoiris * 0.6, banda * fuerza);
    return c;
}
]]

local function oscuro(color, f)
    return { color[1] * f, color[2] * f, color[3] * f }
end

local function dibujarForma(forma, cx, cy, r)
    if forma == "circulo" then
        lg.circle("fill", cx, cy, r)
    elseif forma == "cuadrado" then
        lg.rectangle("fill", cx - r * 0.85, cy - r * 0.85, r * 1.7, r * 1.7)
    elseif forma == "triangulo" then
        lg.polygon("fill", cx, cy - r, cx + r, cy + r * 0.8, cx - r, cy + r * 0.8)
    elseif forma == "rombo" then
        lg.polygon("fill", cx, cy - r, cx + r * 0.8, cy, cx, cy + r, cx - r * 0.8, cy)
    elseif forma == "anillo" then
        lg.setLineWidth(r * 0.35)
        lg.circle("line", cx, cy, r * 0.8)
        lg.setLineWidth(1)
    elseif forma == "estrella" then
        local puntos = {}
        for i = 0, 9 do
            local a = -math.pi / 2 + i * math.pi / 5
            local radio = i % 2 == 0 and r or r * 0.45
            table.insert(puntos, cx + math.cos(a) * radio)
            table.insert(puntos, cy + math.sin(a) * radio)
        end
        -- polygon solo rellena convexos, la estrella hay que trocearla
        for _, tri in ipairs(love.math.triangulate(puntos)) do
            lg.polygon("fill", tri)
        end
    end
end

local function dibujarArte(def, x, y, w, h, radio)
    local e = elementos[def.elemento]
    lg.setColor(e.fondo)
    lg.rectangle("fill", x, y, w, h)

    lg.setColor(oscuro(e.color, 0.35))
    for i = 0, w + h, 6 do
        lg.line(x + i, y, x + i - h, y + h)
    end

    local cx, cy = x + w / 2, y + h / 2
    if def.sprite then
        local img = lg.newImage("sprites/" .. def.sprite)
        local s = math.min(w / img:getWidth(), h / img:getHeight())
        lg.setColor(1, 1, 1)
        lg.draw(img, cx, cy, 0, s, s, img:getWidth() / 2, img:getHeight() / 2)
        return
    end

    lg.setColor(0, 0, 0, 0.4)
    dibujarForma(def.forma, cx + 2, cy + 2, radio)
    lg.setColor(e.color)
    dibujarForma(def.forma, cx, cy, radio)
    lg.setColor(1, 1, 1, 0.5)
    lg.rectangle("fill", cx - radio * 0.4, cy - radio * 0.4, 2, 2)
end

local function dibujarGemas(r, cy)
    lg.setColor(r.color)
    local ancho = r.nivel * 5 - 1
    local x0 = math.floor(carta.ANCHO / 2 - ancho / 2)
    for i = 0, r.nivel - 1 do
        local x = x0 + i * 5 + 2
        lg.polygon("fill", x, cy - 2, x + 2, cy, x, cy + 2, x - 2, cy)
    end
end

local function pintarCara(def)
    local r = rarezas[def.rareza]
    local e = elementos[def.elemento]
    local W, H = carta.ANCHO, carta.ALTO

    lg.setColor(r.color)
    lg.rectangle("fill", 0, 0, W, H)
    lg.setColor(oscuro(e.fondo, 0.6))
    lg.rectangle("fill", 3, 3, W - 6, H - 6)
    lg.setFont(fuentes.mini)

    -- las rayas del fondo se salen del recuadro, por eso el scissor
    if def.rareza == "fullart" or def.rareza == "secreta" then
        lg.setScissor(3, 3, W - 6, H - 6)
        dibujarArte(def, 3, 3, W - 6, H - 6, 24)
        lg.setScissor()
        lg.setColor(0, 0, 0, 0.6)
        lg.rectangle("fill", 3, H - 22, W - 6, 19)
        lg.setColor(1, 1, 1)
        lg.printf(def.nombre, 0, H - 21, W, "center")
        dibujarGemas(r, H - 7)
        return
    end

    lg.setColor(1, 1, 1, 0.8)
    lg.print(string.format("#%02d", def.id), 6, 3)
    lg.printf(e.nombre, 0, 3, W - 6, "right")

    lg.setScissor(6, 13, W - 12, 50)
    dibujarArte(def, 6, 13, W - 12, 50, 15)
    lg.setScissor()

    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", 6, 66, W - 12, 22)
    lg.setColor(1, 1, 1)
    lg.printf(def.nombre, 0, 70, W, "center")
    dibujarGemas(r, H - 7)
end

local function pintarDorso()
    local W, H = carta.ANCHO, carta.ALTO
    lg.setColor(0.85, 0.75, 0.45)
    lg.rectangle("fill", 0, 0, W, H)
    lg.setColor(0.12, 0.13, 0.28)
    lg.rectangle("fill", 3, 3, W - 6, H - 6)
    lg.setColor(0.18, 0.20, 0.40)
    for y = 6, H - 8, 8 do
        for x = 6 + (y / 8 % 2) * 4, W - 8, 8 do
            lg.rectangle("fill", x, y, 2, 2)
        end
    end
    local cx, cy = W / 2, H / 2
    lg.setColor(0.85, 0.75, 0.45)
    lg.polygon("fill", cx, cy - 22, cx + 16, cy, cx, cy + 22, cx - 16, cy)
    lg.setColor(0.12, 0.13, 0.28)
    lg.polygon("fill", cx, cy - 17, cx + 12, cy, cx, cy + 17, cx - 12, cy)
    lg.setColor(0.85, 0.75, 0.45)
    lg.setFont(fuentes.mini)
    lg.printf("OLP", 0, cy - 5, W, "center")
end

local function lienzo(pintar, ...)
    local c = lg.newCanvas(carta.ANCHO, carta.ALTO)
    lg.setCanvas(c)
    lg.clear(0, 0, 0, 0)
    pintar(...)
    lg.setCanvas()
    lg.setColor(1, 1, 1)
    return c
end

function carta.preparar()
    brillo = lg.newShader(codigoBrillo)
    dorso = lienzo(pintarDorso)
    for _, def in ipairs(cartas) do
        caras[def.id] = lienzo(pintarCara, def)
    end
end

-- sx distinto de sy sirve para el giro (sx se encoge a 0 y vuelve)
function carta.dibujar(def, x, y, sx, sy, rot, bocaArriba)
    local W, H = carta.ANCHO, carta.ALTO
    rot = rot or 0

    lg.push()
    lg.translate(x + 3, y + 4)
    lg.rotate(rot)
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", -W / 2 * sx, -H / 2 * sy, W * sx, H * sy)
    lg.pop()
    lg.setColor(1, 1, 1)

    if not bocaArriba then
        lg.draw(dorso, x, y, rot, sx, sy, W / 2, H / 2)
        return
    end

    local r = rarezas[def.rareza]
    if r.efecto then
        lg.setShader(brillo)
        brillo:send("tiempo", love.timer.getTime())
        brillo:send("fuerza", r.efecto)
    end
    lg.draw(caras[def.id], x, y, rot, sx, sy, W / 2, H / 2)
    lg.setShader()
end

return carta
