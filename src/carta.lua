local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local elementos = require "datos.elementos"
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local bicho = require "src.bicho"

local lg = love.graphics

-- tamaño real de la carta en pixeles; en pantalla se dibuja a x1, x2 o x3
local carta = { ANCHO = 36, ALTO = 50 }

-- caras[id] = { normal, arriba, parpadeo }: las holo o mejores respiran y parpadean
local caras = {}
local siluetas = {}
local dorso, sello
local shader

local MODOS = { reflejo = 1, foil = 2, purpurina = 3, oro = 4 }

-- El vertice gira la carta en 3D alrededor de su centro y la pinta con
-- perspectiva (w distinto de 1, asi la textura no se deforma en diagonal).
-- LÖVE ya manda los vertices transformados a pantalla, asi que el centro
-- y la profundidad van en pixeles de pantalla.
-- El pixel pone el acabado de cada rareza, que se mueve con la inclinacion.
local CODIGO_SHADER = [[
extern vec2 giro;
extern vec2 centro;
extern number prof;
extern vec2 tam;
extern number tiempo;
extern number fuerza;
extern vec2 luz;
extern number modo;
extern number barrido;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vp) {
    vec2 q = vp.xy - centro;
    float cy = cos(giro.x), sy = sin(giro.x);
    float cx = cos(giro.y), sx = sin(giro.y);
    vec3 r = vec3(q.x * cy, q.y, -q.x * sy);
    r = vec3(r.x, r.y * cx - r.z * sx, r.y * sx + r.z * cx);
    float f = prof / (prof + r.z);
    vec4 sale = transform_projection * vec4(centro + r.xy * f, vp.z, 1.0);
    return sale / f;
}
#endif

#ifdef PIXEL
float azar(vec2 v) { return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 arcoiris(float t) { return 0.5 + 0.5 * cos(6.2831 * (t + vec3(0.0, 0.33, 0.67))); }

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * color;
    if (c.a < 0.01) return c;
    vec2 px = floor(uv * tam);
    vec3 suma = vec3(0.0);

    // franja de luz que cruza la carta al inclinarla
    float s = (px.x + px.y * 0.5) / tam.x - (0.75 - luz.x * 0.8 - luz.y * 0.3);
    float franja = exp(-s * s * 30.0);

    if (modo > 0.5 && modo < 1.5) {
        suma += vec3(franja * 0.35 * fuerza);
    } else if (modo > 1.5 && modo < 2.5) {
        // foil: arcoiris a rayas dentro del recuadro del dibujo
        float arte = step(3.0, px.x) * step(px.x, 32.0) * step(8.0, px.y) * step(px.y, 25.0);
        float rayas = step(0.5, fract((px.x - px.y) / 3.0));
        vec3 col = arcoiris((px.x * 0.5 + px.y) / tam.y + luz.x * 0.9 + luz.y * 0.5 + tiempo * 0.05);
        suma += col * (0.3 + 0.25 * rayas) * fuerza * arte;
        suma += vec3(franja * 0.3 * fuerza);
    } else if (modo > 2.5 && modo < 3.5) {
        // purpurina: pixeles sueltos que destellan y una pelicula de color
        float g = pow(fract(azar(px) * 7.0 + tiempo * 0.7 + luz.x * 1.5 + luz.y), 14.0);
        float barra = step(35.0, px.y);
        suma += vec3(g) * fuerza * (1.0 - barra * 0.7);
        suma += arcoiris(px.y / tam.y + luz.x * 0.7 + luz.y * 0.4) * 0.16 * fuerza;
        suma += vec3(franja * 0.25 * fuerza);
    } else if (modo > 3.5) {
        // oro: metal dorado, trama de prisma y estrellas que brillan
        float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        c.rgb = mix(c.rgb, c.rgb * vec3(1.08, 0.95, 0.65) + vec3(0.06, 0.04, 0.0), 0.35 * fuerza);
        float o = (px.x + px.y) / (tam.x + tam.y) - (0.5 - luz.x * 0.5 + luz.y * 0.3 + sin(tiempo * 0.6) * 0.15);
        suma += vec3(1.0, 0.85, 0.5) * exp(-o * o * 25.0) * 0.45 * fuerza;
        float trama = step(mod(px.x + px.y, 6.0), 0.5) * step(0.45, lum);
        suma += arcoiris(px.x / tam.x + luz.y * 0.6 + tiempo * 0.04) * trama * 0.12 * fuerza;
        vec2 celda = floor(px / 5.0);
        vec2 d = abs(px - (celda * 5.0 + 2.0));
        float estrella = (d.x + d.y < 0.5) ? 1.0 : ((d.x + d.y < 1.5) ? 0.5 : 0.0);
        float brilla = pow(max(0.0, sin(tiempo * 2.0 + azar(celda) * 6.28 + luz.x * 3.0)), 12.0) * step(0.55, azar(celda + 3.1));
        suma += vec3(estrella * brilla * fuerza);
    }

    // destello que cruza la carta una vez al revelarla
    if (barrido >= 0.0) {
        float b = (px.x + px.y * 0.5) / tam.x * 0.7 - (barrido * 2.0 - 0.5);
        suma += vec3(exp(-b * b * 60.0) * 0.9);
    }
    c.rgb += suma * c.a;
    return c;
}
#endif
]]

-- tramas del suelo de cada elemento
local tramas = {
    llamas    = function(x, y) return (y + math.abs(x % 6 - 3)) % 4 == 0 end,
    olas      = function(x, y) return (y + math.floor(math.sin(x * 0.8) * 1.5 + 0.5)) % 3 == 0 end,
    hojas     = function(x, y) return (math.floor(x / 2) + y) % 3 == 0 end,
    rayas     = function(x, y) return (x + y) % 4 < 1 end,
    puntos    = function(x, y) return (x + y * 3) % 5 == 0 end,
    cristales = function(x, y) return (x % 4 == 0 and y % 2 == 0) or (x % 4 == 2 and y % 2 == 1) end,
    rejilla   = function(x, y) return x % 3 == 0 or y % 3 == 0 end,
    rocas     = function(x, y) return (x * 7 + y * 3) % 5 == 0 or (x + y * 2) % 7 == 0 end,
    estrellas = function(x, y) return (x * 5 + y * 11) % 13 == 0 end,
}

-- degradado con trama ordenada (Bayer 4x4), el de la pixel art clasica
local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local totalSet = {}
for _, c in ipairs(cartas) do
    totalSet[c.set] = (totalSet[c.set] or 0) + 1
end

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

local function imagenBicho(def, grande, cerrados)
    if def.sprite then return lg.newImage("sprites/" .. def.sprite) end
    local e = elementos[def.elemento]
    local semilla = def.semilla or def.id * 7919 + 13
    if grande then return bicho.crear(semilla, 22, 22, e, cerrados) end
    return bicho.crear(semilla, 16, 13, e, cerrados)
end

-- paisaje plano: cielo en degradado hacia el horizonte, suelo con la trama
-- del elemento y el bicho de pie encima (dy: lo sube unos pixeles)
local SUELO = 4

local function recuadro(def, img, x, y, w, h, dy)
    local e = elementos[def.elemento]
    local trama = tramas[e.trama]
    local cielo = h - SUELO
    for py = 0, cielo - 1 do
        local t = py / (cielo - 1) * 16
        for pxx = 0, w - 1 do
            local umbral = BAYER[py % 4 + 1][pxx % 4 + 1]
            lg.setColor(t > umbral + 0.5 and e.horizonte or e.cielo)
            px(x + pxx, y + py)
        end
    end
    lg.setColor(e.suelo)
    lg.rectangle("fill", x, y + cielo, w, SUELO)
    lg.setColor(e.horizonte)
    lg.rectangle("fill", x, y + cielo, w, 1)
    for py = 1, SUELO - 1 do
        for pxx = 0, w - 1 do
            if trama(pxx, py) then px(x + pxx, y + cielo + py) end
        end
    end
    lg.setColor(1, 1, 1)
    lg.setScissor(x, y, w, h)
    lg.draw(img, x + math.floor((w - img:getWidth()) / 2), y + cielo - img:getHeight() + 2 - (dy or 0))
    lg.setScissor()
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

-- recuadro del dibujo en las cartas normales
local ARTE = { x = 3, y = 8, w = 30, h = 18 }

local function pintarCara(def, img, dy)
    local r = rarezas[def.rareza]
    local W, H = carta.ANCHO, carta.ALTO
    local base = def.rareza == "secreta" and p.amarillo or p.blanco
    silueta(W, H, base)

    if r.nivel >= 3 then
        lg.setColor(r.color)
        lg.rectangle("line", 1.5, 1.5, W - 3, H - 3)
    end

    if r.nivel >= 5 then
        recuadro(def, img, 2, 2, W - 4, 33, dy)
        lg.setColor(p.negro)
        lg.rectangle("fill", 1, 35, W - 2, H - 36)
        fuentes.texto(def.nombre, 0, 37, 1, p.blanco, "center", W)
        gemas(r, 45)
        esquinas(W, H)
        return
    end

    lg.setColor(p.negro)
    lg.rectangle("line", ARTE.x - 0.5, ARTE.y - 0.5, ARTE.w + 1, ARTE.h + 1)
    recuadro(def, img, ARTE.x, ARTE.y, ARTE.w, ARTE.h, dy)

    fuentes.texto(def.set:upper(), 3, 1, 1, p.negro)
    local e = elementos[def.elemento]
    lg.setColor(p.negro)
    lg.rectangle("fill", W - 8, 1, 5, 5)
    lg.setColor(e.cuerpo)
    lg.rectangle("fill", W - 7, 2, 3, 3)

    fuentes.texto(def.nombre, 0, 28, 1, p.negro, "center", W)
    lg.setColor(p.grisclaro)
    lg.rectangle("fill", 5, 34, W - 10, 1)
    local codigo = "#" .. def.num .. "/" .. totalSet[def.set]
    fuentes.texto(codigo, 0, 37, 1, p.gris, "center", W)
    gemas(r, 46)
    esquinas(W, H)
end

local function pintarSilueta(def)
    local W = carta.ANCHO
    lg.setColor(1, 1, 1)
    local img = imagenBicho(def, false)
    lg.draw(img, math.floor((W - img:getWidth()) / 2), ARTE.y + ARTE.h - SUELO - img:getHeight() + 2)
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

-- sello de 1ª edicion: chapita dorada con un 1
local SELLO = { x = 20, y = 1, w = 6, h = 6 }
local function pintarSello()
    lg.setColor(p.negro)
    lg.rectangle("fill", 1, 0, 4, 6)
    lg.rectangle("fill", 0, 1, 6, 4)
    lg.setColor(p.amarillo)
    lg.rectangle("fill", 1, 1, 4, 4)
    lg.setColor(p.negro)
    lg.rectangle("fill", 3, 1, 1, 4)
    px(2, 2)
end

local function lienzo(w, h, pintar, ...)
    local c = lg.newCanvas(w, h)
    c:setFilter("nearest", "nearest")
    lg.setCanvas(c)
    lg.clear(0, 0, 0, 0)
    pintar(...)
    lg.setCanvas()
    lg.setColor(1, 1, 1)
    return c
end

function carta.preparar()
    shader = lg.newShader(CODIGO_SHADER)
    dorso = lienzo(carta.ANCHO, carta.ALTO, pintarDorso)
    sello = lienzo(SELLO.w, SELLO.h, pintarSello)
    local W, H = carta.ANCHO, carta.ALTO
    for _, def in ipairs(cartas) do
        local r = rarezas[def.rareza]
        local grande = r.nivel >= 5
        local img = imagenBicho(def, grande)
        local frames = { lienzo(W, H, pintarCara, def, img, 0) }
        if r.nivel >= 4 and not def.sprite then
            frames[2] = lienzo(W, H, pintarCara, def, img, 1)
            frames[3] = lienzo(W, H, pintarCara, def, imagenBicho(def, grande, true), 0)
        end
        caras[def.id] = frames
        siluetas[def.id] = lienzo(W, H, pintarSilueta, def)
    end
end

-- el bicho de las buenas respira (sube un pixel) y parpadea cada pocos segundos
local function cara(def)
    local frames = caras[def.id]
    if #frames == 1 then return frames[1] end
    local t = love.timer.getTime() + def.id * 1.37
    if t % 3.7 < 0.13 then return frames[3] end
    if math.floor(t * 1.4) % 2 == 0 then return frames[2] end
    return frames[1]
end

local function enviar(nombre, valor)
    if shader:hasUniform(nombre) then shader:send(nombre, valor) end
end

-- cx, cy: centro de la carta en pantalla; alto: lo que mide en pantalla
local function preparar3D(gx, gy, cx, cy, alto, modo, fuerza, lx, ly, barrido)
    lg.setShader(shader)
    enviar("giro", { gx, gy })
    enviar("tam", { carta.ANCHO, carta.ALTO })
    enviar("centro", { cx, cy })
    enviar("prof", math.max(1, alto * 2.2))
    enviar("tiempo", love.timer.getTime())
    enviar("fuerza", fuerza)
    enviar("luz", { lx, ly })
    enviar("modo", modo)
    enviar("barrido", barrido or -1)
end

-- top loader: plastico rigido por encima de la funda, mas grueso y brillante
-- lo que mide h en pantalla desde (x, y), con la escala que haya puesta
local function altoEn(x, y, h)
    local ax, ay = lg.transformPoint(x, y)
    local bx, by = lg.transformPoint(x, y + h)
    return math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
end

local function toploader(x, y, sx, sy, rot, gx, gy)
    local W, H = carta.ANCHO, carta.ALTO
    local cx, cy = lg.transformPoint(x, y)
    preparar3D(gx, gy, cx, cy, altoEn(x, y, H * math.abs(sy)), 0, 0, 0, 0)
    lg.push()
    lg.translate(x, y)
    lg.rotate(rot)
    lg.scale(sx, sy)
    lg.setColor(1, 1, 1, 0.1)
    lg.rectangle("fill", -W / 2 - 3, -H / 2 - 4, W + 6, H + 7)
    lg.setColor(1, 1, 1, 0.3)
    lg.rectangle("fill", -W / 2 - 3, -H / 2 - 4, W + 6, 2)
    lg.rectangle("fill", W / 2 - 1, -H / 2 - 2, 2, H + 3)
    lg.setColor(p.blanco[1], p.blanco[2], p.blanco[3], 0.75)
    lg.setLineWidth(1 / math.max(math.abs(sx), 0.01))
    lg.rectangle("line", -W / 2 - 3, -H / 2 - 4, W + 6, H + 7)
    lg.setLineWidth(1)
    lg.pop()
    lg.setShader()
    lg.setColor(1, 1, 1)
end

local function funda(x, y, sx, sy, rot, gx, gy)
    local W, H = carta.ANCHO, carta.ALTO
    local cx, cy = lg.transformPoint(x, y)
    preparar3D(gx, gy, cx, cy, altoEn(x, y, H * math.abs(sy)), 0, 0, 0, 0)
    lg.push()
    lg.translate(x, y)
    lg.rotate(rot)
    lg.scale(sx, sy)
    lg.setColor(1, 1, 1, 0.07)
    lg.rectangle("fill", -W / 2 - 1, -H / 2 - 1, W + 2, H + 2)
    lg.setColor(1, 1, 1, 0.22)
    lg.polygon("fill", -W / 2 + 4, -H / 2, -W / 2 + 10, -H / 2, -W / 2 + 2, H / 2, -W / 2 - 1, H / 2, -W / 2 - 1, -H / 2 + 10)
    lg.setColor(p.cian[1], p.cian[2], p.cian[3], 0.85)
    lg.setLineWidth(1 / math.max(math.abs(sx), 0.01))
    lg.rectangle("line", -W / 2 - 1, -H / 2 - 1, W + 2, H + 2)
    lg.setLineWidth(1)
    lg.pop()
    lg.setShader()
    lg.setColor(1, 1, 1)
end

-- h (opcional) viene del hover: brillo (0-1) y lx, ly (-1 a 1, donde esta el raton)
-- enFunda: se pinta la funda transparente por encima
-- extra (opcional): primera (sello de 1ª edicion), barrido (0-1, destello al
-- revelar), quieta (sin balanceo), giro = { x, y } para forzar la inclinacion
function carta.dibujar(def, x, y, sx, sy, rot, bocaArriba, h, enFunda, extra)
    local W, H = carta.ANCHO, carta.ALTO
    rot = rot or 0
    extra = extra or {}
    local a, lx, ly = 0, 0, 0
    if h then a, lx, ly = h.brillo or 0, h.lx or 0, h.ly or 0 end
    local alza = a * 2

    local gx, gy = -lx * 0.32 * a, ly * 0.32 * a
    local r = def and rarezas[def.rareza]
    if bocaArriba and def and not extra.quieta then
        -- balanceo en reposo, como si la tuvieras en la mano
        local t = love.timer.getTime() + def.id * 0.77
        local amp = (r.nivel >= 4 and 0.12 or 0.05) * (1 - a)
        gx = gx + math.sin(t * 1.3) * amp
        gy = gy + math.cos(t * 1.1) * amp * 0.6
    end
    if extra.giro then gx, gy = extra.giro[1], extra.giro[2] end

    lg.push()
    lg.translate(x + 2 + alza + gx * 4, y + 3 + alza)
    lg.rotate(rot)
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", -W / 2 * math.abs(sx), -H / 2 * math.abs(sy), W * math.abs(sx), H * math.abs(sy))
    lg.pop()
    lg.setColor(1, 1, 1)

    local cx, cy = lg.transformPoint(x, y - alza)
    -- lo que mide de verdad en pantalla (tambien si se pinta encima, ya escalada)
    local alto = altoEn(x, y - alza, H * math.abs(sy))
    if not bocaArriba then
        preparar3D(gx, gy, cx, cy, alto, 0, 0, 0, 0)
        lg.draw(dorso, x, y - alza, rot, sx, sy, W / 2, H / 2)
        lg.setShader()
        return
    end

    local modo = MODOS[r.brillo] or 0
    local fuerza = (r.efecto or 0) * (0.7 + a * 0.5)
    -- la luz sigue a la inclinacion, tambien la del balanceo
    preparar3D(gx, gy, cx, cy, alto, modo, fuerza, lx * a - gx * 1.5, ly * a + gy * 1.5, extra.barrido)
    lg.draw(cara(def), x, y - alza, rot, sx, sy, W / 2, H / 2)
    if extra.primera then
        preparar3D(gx, gy, cx, cy, alto, 0, 0, 0, 0)
        lg.draw(sello, x, y - alza, rot, sx, sy, W / 2 - SELLO.x, H / 2 - SELLO.y)
    end
    lg.setShader()
    if enFunda then funda(x, y - alza, sx, sy, rot, gx, gy) end
    if extra.top then toploader(x, y - alza, sx, sy, rot, gx, gy) end
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
    fuentes.texto(string.format("#%02d", def.num), x0, y0 + H - 8 * escala, escala, p.grisosc, "center", W)
end

-- montón de cartas: defs[1] arriba del todo, total = cuantas hay en el monton.
-- Al pasar el raton las de detras se abren en abanico para verlas.
-- extra.ediciones (opcional): si cada copia es de 1ª edicion, la de arriba primero
function carta.pila(defs, x, y, escala, total, h, enFunda, extra)
    local detras = math.min(total, 4) - 1
    local a = h and h.brillo or 0
    local ediciones = extra and extra.ediciones
    local mitad = carta.ALTO * escala / 2
    for i = detras, 1, -1 do
        local def = defs[i + 1] or defs[1]
        -- girando sobre la esquina de abajo, como una mano de cartas
        local giro = -0.12 * i * a
        local cx = x + i * escala * (1 - a) - i * 8 * escala * a + math.sin(giro) * mitad
        local cy = y - i * escala * 2 * (1 - a) + mitad - math.cos(giro) * mitad
        carta.dibujar(def, cx, cy, escala, escala, giro, true, nil, false, { quieta = true, primera = ediciones and ediciones[i + 1] })
    end
    if ediciones then
        extra = { primera = ediciones[1] }
    end
    carta.dibujar(defs[1], x, y, escala, escala, 0, true, h, enFunda, extra)
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

-- gema de color de una rareza, para las listas del movil
function carta.gema(rareza, x, y)
    local r = rarezas[rareza]
    lg.setColor(p.negro)
    lg.polygon("fill", x, y - 4, x + 4, y, x, y + 4, x - 4, y)
    lg.setColor(r.color)
    lg.polygon("fill", x, y - 3, x + 3, y, x, y + 3, x - 3, y)
    lg.setColor(1, 1, 1)
end

return carta
