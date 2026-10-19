local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local elementos = require "datos.elementos"
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local bicho = require "src.bicho"

local lg = love.graphics

-- tamaño real de la carta en pixeles; en pantalla se dibuja a x1, x2 o x3
local carta = { ANCHO = 36, ALTO = 50 }

local caras = {}
local siluetas = {}
local dorso
local brillo

-- franja de arcoiris en diagonal; luz la mueve con el raton
local codigoBrillo = [[
extern number tiempo;
extern number fuerza;
extern vec2 luz;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * color;
    float fase = (uv.x * 1.5 + uv.y) * 9.0 - tiempo * 2.5 + luz.x * 3.0 + luz.y * 2.0;
    float banda = sin(fase) * 0.5 + 0.5;
    vec3 arcoiris = 0.5 + 0.5 * cos(6.2831 * (uv.x + uv.y * 0.5 + tiempo * 0.15) + vec3(0.0, 2.1, 4.2));
    c.rgb = mix(c.rgb, c.rgb + arcoiris * 0.6, banda * fuerza);
    return c;
}
]]

local patrones = {
    llamas = function(x, y) return (y + math.abs(x % 6 - 3)) % 4 == 0 end,
    olas   = function(x, y) return (y + math.floor(math.sin(x * 0.8) * 1.5 + 0.5)) % 5 == 0 end,
    hojas  = function(x, y) return (math.floor(x / 2) + math.floor(y / 2)) % 2 == 0 and (x + y) % 2 == 0 end,
    rayas  = function(x, y) return (x + y) % 6 < 2 end,
    puntos = function(x, y) return x % 4 == 0 and y % 4 == (math.floor(x / 4) % 2) * 2 end,
}

local function px(x, y)
    lg.rectangle("fill", x, y, 1, 1)
end

local function silueta(W, H, base)
    lg.setColor(p.negro)
    lg.rectangle("fill", 1, 0, W - 2, H)
    lg.rectangle("fill", 0, 1, W, H - 2)
    lg.setColor(base)
    lg.rectangle("fill", 1, 1, W - 2, H - 2)
end

local function esquinas(W, H)
    lg.setColor(p.negro)
    px(1, 1); px(W - 2, 1); px(1, H - 2); px(W - 2, H - 2)
end

local function imagenBicho(def, grande)
    if def.sprite then return lg.newImage("sprites/" .. def.sprite) end
    local e = elementos[def.elemento]
    local semilla = def.semilla or def.id * 7919 + 13
    if grande then return bicho.crear(semilla, 26, 26, e) end
    return bicho.crear(semilla, 20, 18, e)
end

local function recuadro(def, img, x, y, w, h)
    local e = elementos[def.elemento]
    local patron = patrones[e.dibujo]
    lg.setColor(e.fondo)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(e.patron)
    for py = 0, h - 1 do
        for pxx = 0, w - 1 do
            if patron(pxx, py) then px(x + pxx, y + py) end
        end
    end
    lg.setColor(1, 1, 1)
    lg.draw(img, x + math.floor((w - img:getWidth()) / 2), y + math.floor((h - img:getHeight()) / 2))
end

local function gemas(r, cy)
    local W = carta.ANCHO
    local x0 = math.floor(W / 2 - (r.nivel * 4 - 1) / 2) + 1
    for i = 0, r.nivel - 1 do
        local x = x0 + i * 4
        lg.setColor(p.negro)
        px(x, cy - 2); px(x - 2, cy); px(x + 2, cy); px(x, cy + 2)
        px(x - 1, cy - 1); px(x + 1, cy - 1); px(x - 1, cy + 1); px(x + 1, cy + 1)
        lg.setColor(r.color)
        px(x, cy - 1); px(x - 1, cy); px(x, cy); px(x + 1, cy); px(x, cy + 1)
    end
end

local function pintarCara(def)
    local r = rarezas[def.rareza]
    local W, H = carta.ANCHO, carta.ALTO
    local base = def.rareza == "secreta" and p.amarillo or p.blanco
    silueta(W, H, base)

    if r.nivel >= 3 then
        lg.setColor(r.color)
        lg.rectangle("line", 1.5, 1.5, W - 3, H - 3)
    end

    if r.nivel >= 5 then
        recuadro(def, imagenBicho(def, true), 2, 2, W - 4, 35)
        lg.setColor(p.negro)
        lg.rectangle("fill", 1, 37, W - 2, H - 38)
        fuentes.texto(def.nombre, 0, 39, 1, p.blanco, "center", W)
        gemas(r, 45)
        esquinas(W, H)
        return
    end

    lg.setColor(p.negro)
    lg.rectangle("line", 2.5, 7.5, W - 5, 28)
    recuadro(def, imagenBicho(def, false), 3, 8, W - 6, 27)

    fuentes.texto(string.format("#%02d", def.id), 3, 1, 1, p.negro)
    local e = elementos[def.elemento]
    lg.setColor(p.negro)
    lg.rectangle("fill", W - 8, 1, 5, 5)
    lg.setColor(e.cuerpo)
    lg.rectangle("fill", W - 7, 2, 3, 3)

    fuentes.texto(def.nombre, 0, 38, 1, p.negro, "center", W)
    gemas(r, 45)
    esquinas(W, H)
end

local function pintarSilueta(def)
    local W, H = carta.ANCHO, carta.ALTO
    lg.setColor(1, 1, 1)
    local img = imagenBicho(def, false)
    lg.draw(img, math.floor((W - img:getWidth()) / 2), 14)
end

local function pintarDorso()
    local W, H = carta.ANCHO, carta.ALTO
    silueta(W, H, p.azulosc)
    for y = 2, H - 3 do
        for x = 2, W - 3 do
            if (x + y) % 4 == 0 then
                lg.setColor(p.azul)
                px(x, y)
            elseif (x - y) % 4 == 0 then
                lg.setColor(p.rojo)
                px(x, y)
            end
        end
    end
    lg.setColor(p.amarillo)
    lg.rectangle("line", 2.5, 2.5, W - 5, H - 5)
    local cx, cy = W / 2, H / 2
    lg.setColor(p.negro)
    lg.polygon("fill", cx, cy - 13, cx + 11, cy, cx, cy + 13, cx - 11, cy)
    lg.setColor(p.amarillo)
    lg.polygon("line", cx, cy - 12, cx + 10, cy, cx, cy + 12, cx - 10, cy)
    fuentes.texto("OLP", 0, cy - 2, 1, p.amarillo, "center", W)
    esquinas(W, H)
end

local function lienzo(pintar, ...)
    local c = lg.newCanvas(carta.ANCHO, carta.ALTO)
    c:setFilter("nearest", "nearest")
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
        siluetas[def.id] = lienzo(pintarSilueta, def)
    end
end

-- h (opcional) viene del hover: kx, ky inclinan la carta y brillo/lx/ly mueven el reflejo
function carta.dibujar(def, x, y, sx, sy, rot, bocaArriba, h)
    local W, H = carta.ANCHO, carta.ALTO
    rot = rot or 0
    local kx, ky = 0, 0
    local alza = 0
    if h then
        kx, ky = h.kx, h.ky
        alza = h.brillo * 2
    end

    lg.push()
    lg.translate(x + 2 + alza, y + 3 + alza)
    lg.rotate(rot)
    lg.shear(kx, ky)
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", -W / 2 * math.abs(sx), -H / 2 * math.abs(sy), W * math.abs(sx), H * math.abs(sy))
    lg.pop()
    lg.setColor(1, 1, 1)

    if not bocaArriba then
        lg.draw(dorso, x, y - alza, rot, sx, sy, W / 2, H / 2, kx, ky)
        return
    end

    local r = rarezas[def.rareza]
    local fuerza = r.efecto or 0
    if h then fuerza = fuerza + h.brillo * 0.12 end
    if fuerza > 0 then
        lg.setShader(brillo)
        brillo:send("tiempo", love.timer.getTime())
        brillo:send("fuerza", fuerza)
        brillo:send("luz", { h and h.lx or 0, h and h.ly or 0 })
    end
    lg.draw(caras[def.id], x, y - alza, rot, sx, sy, W / 2, H / 2, kx, ky)
    lg.setShader()
end

-- carta que aun no tienes: hueco oscuro con la silueta del bicho
function carta.hueco(def, x, y, escala)
    local W, H = carta.ANCHO * escala, carta.ALTO * escala
    local x0, y0 = math.floor(x - W / 2), math.floor(y - H / 2)
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x0, y0, W, H)
    lg.setColor(p.grisosc)
    lg.rectangle("line", x0 + 0.5, y0 + 0.5, W - 1, H - 1)
    lg.setColor(p.negro[1], p.negro[2], p.negro[3], 0.9)
    lg.draw(siluetas[def.id], x0, y0, 0, escala, escala)
    fuentes.texto(string.format("#%02d", def.id), x0, y0 + H - 8 * escala, escala, p.grisosc, "center", W)
end

-- montón de cartas: defs[1] arriba del todo, total = cuantas hay en el monton
function carta.pila(defs, x, y, escala, total, h)
    local detras = math.min(total, 4) - 1
    for i = detras, 1, -1 do
        local def = defs[i + 1] or defs[1]
        carta.dibujar(def, x + i * escala, y - i * escala * 2, escala, escala, 0, true)
    end
    carta.dibujar(defs[1], x, y, escala, escala, 0, true, h)
    if total > 1 then
        carta.contador(total, x + carta.ANCHO * escala / 2, y + carta.ALTO * escala / 2)
    end
end

function carta.contador(n, xDer, yAbajo)
    local txt = "x" .. n
    local w = fuentes.ancho(txt) + 5
    local x0, y0 = math.floor(xDer - w + 2), math.floor(yAbajo - 6)
    lg.setColor(p.negro)
    lg.rectangle("fill", x0, y0, w, 9)
    lg.setColor(p.rojo)
    lg.rectangle("fill", x0 + 1, y0 + 1, w - 2, 7)
    fuentes.texto(txt, x0 + 3, y0 + 2, 1, p.blanco)
end

return carta
