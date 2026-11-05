local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local elementos = require "datos.elementos"
local p = require "datos.paleta"
local datosFundas = require "datos.fundas"
local fuentes = require "src.fuentes"
local bicho = require "src.bicho"

local lg = love.graphics

-- tamaño real de la carta en pixeles; en pantalla se dibuja a x1, x2 o x3
local carta = { ANCHO = 36, ALTO = 50 }
local W, H = carta.ANCHO, carta.ALTO

-- caras[id] = { normal, arriba, parpadeo }: las holo o mejores respiran y parpadean
local caras = {}
local siluetas = {}
local dorso, sello
local shader

local MODOS = { reflejo = 1, foil = 2, purpurina = 3, oro = 4, plata = 5, golden = 6 }

-- zona del foil: el recuadro del dibujo (en las ALT, toda la escena)
local ARTE_FOIL, ARTE_FOIL_ALT = { 3, 8, 32, 25 }, { 2, 2, 33, 34 }

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
extern vec4 arte;

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
        float dentro = step(arte.x, px.x) * step(px.x, arte.z) * step(arte.y, px.y) * step(px.y, arte.w);
        float rayas = step(0.5, fract((px.x - px.y) / 3.0));
        vec3 col = arcoiris((px.x * 0.5 + px.y) / tam.y + luz.x * 0.9 + luz.y * 0.5 + tiempo * 0.05);
        suma += col * (0.3 + 0.25 * rayas) * fuerza * dentro;
        suma += vec3(franja * 0.3 * fuerza);
    } else if (modo > 2.5 && modo < 3.5) {
        // purpurina: pixeles sueltos que destellan y una pelicula de color
        float g = pow(fract(azar(px) * 7.0 + tiempo * 0.7 + luz.x * 1.5 + luz.y), 14.0);
        float barra = step(35.0, px.y);
        suma += vec3(g) * fuerza * (1.0 - barra * 0.7);
        suma += arcoiris(px.y / tam.y + luz.x * 0.7 + luz.y * 0.4) * 0.16 * fuerza;
        suma += vec3(franja * 0.25 * fuerza);
    } else if (modo > 3.5 && modo < 4.5) {
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
    } else if (modo > 4.5) {
        // SILVER y GOLDEN: metal cepillado, cada fila de pixeles refleja distinto
        bool oro = modo > 5.5;
        float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        float fila = azar(vec2(3.0, px.y));
        float cep = 0.5 + 0.5 * sin(fila * 6.28 + luz.x * 5.0 + px.x * 0.12);
        vec3 tinte = oro ? vec3(1.1, 0.93, 0.6) : vec3(0.88, 0.97, 1.15);
        c.rgb = mix(c.rgb, c.rgb * tinte, 0.55 * fuerza);
        vec3 brillo = oro ? vec3(1.0, 0.85, 0.45) : vec3(0.82, 0.92, 1.0);
        suma += brillo * cep * 0.14 * fuerza * step(0.3, lum);
        // reflejo especular: uno ancho y un filo fino encima
        float o = (px.x * 0.7 + px.y) / tam.y - (0.55 - luz.x * 0.7 + luz.y * 0.4);
        suma += brillo * (exp(-o * o * 35.0) * 0.3 + exp(-o * o * 500.0) * 0.5) * fuerza;
        suma += arcoiris(o * 2.5 + tiempo * 0.05) * exp(-o * o * 10.0) * (oro ? 0.05 : 0.1) * fuerza;
        // destellos sueltos (muchos mas en la golden)
        float g = pow(fract(azar(px) * 7.0 + tiempo * 0.9 + luz.x * 1.5 + luz.y), oro ? 16.0 : 40.0);
        suma += brillo * g * (oro ? 1.0 : 0.7) * fuerza * step(0.35, lum);
        if (oro) {
            // aura que late alrededor del medallon
            float rr = length(px + 0.5 - vec2(18.0, 22.0));
            float aura = exp(-pow(rr - 13.0, 2.0) * 0.35) * (0.55 + 0.45 * sin(tiempo * 3.5));
            suma += vec3(1.0, 0.8, 0.35) * aura * 0.5 * fuerza;
        }
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
    burbujas = function(x, y) return (x % 5 == 2 and y % 4 == 1) or (x % 5 == 0 and y % 4 == 3) end,
    rafagas = function(x, y) return y % 3 == 1 and (x + y * 3) % 8 < 4 end,
    escamas = function(x, y) return (y % 2 == 0 and (x + y) % 4 == 0) or (y % 2 == 1 and (x + y) % 4 == 2) end,
    destellos = function(x, y) return (x * 7 + y * 3) % 9 == 0 end,
}

-- degradado con trama ordenada (Bayer 4x4), el de la pixel art clasica
local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local totalSet = {}
for _, c in ipairs(cartas) do
    if not c.fuera then totalSet[c.set] = (totalSet[c.set] or 0) + 1 end
end

local function px(x, y)
    lg.rectangle("fill", x, y, 1, 1)
end

local function silueta(_, _, base)
    lg.setColor(p.negro)
    lg.rectangle("fill", 1, 0, W - 2, H)
    lg.rectangle("fill", 0, 1, W, H - 2)
    lg.setColor(base)
    lg.rectangle("fill", 1, 1, W - 2, H - 2)
end

local function esquinas()
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

-- cartas de fuera de set (datos/variantes.lua): ALT, SILVER y GOLDEN
local function trama(x, y, t) return t * 16 > BAYER[y % 4 + 1][x % 4 + 1] + 0.5 end

-- marco dorado: bisel de 2 px y adornos en las esquinas (joyas = secreta alt)
local function marcoOro(joyas)
    for x = 1, W - 2 do
        for y = 1, H - 2 do
            local b = math.min(x - 1, y - 1, W - 2 - x, H - 2 - y)
            if b == 0 then
                local luz = (x - 1 == b or y - 1 == b) and not (W - 2 - x == b or H - 2 - y == b)
                lg.setColor(luz and p.amarillo or p.naranja)
                if (x * 2 + y) % 7 == 0 then lg.setColor(p.blanco) end
                px(x, y)
            elseif b == 1 then
                lg.setColor((x + y) % 2 == 0 and p.naranja or p.morado)
                px(x, y)
            end
        end
    end
    for _, q in ipairs({ { 3, 3, 1, 1 }, { W - 4, 3, -1, 1 }, { 3, 33, 1, -1 }, { W - 4, 33, -1, -1 } }) do
        local x, y, dx, dy = q[1], q[2], q[3], q[4]
        lg.setColor(p.negro)
        px(x + dx * 2, y); px(x, y + dy * 2); px(x + dx, y + dy)
        lg.setColor(p.amarillo)
        px(x, y); px(x + dx, y); px(x, y + dy)
        if joyas then
            lg.setColor(p.negro); px(x + dx * 2, y + dy); px(x + dx, y + dy * 2)
            lg.setColor(p.cian); px(x + dx, y + dy)
        end
    end
    -- adorno arriba en el centro
    local c = math.floor(W / 2)
    lg.setColor(p.negro)
    px(c - 2, 2); px(c + 1, 2); px(c - 1, 3); px(c, 3)
    lg.setColor(p.amarillo)
    px(c - 1, 2); px(c, 2)
    lg.setColor(p.blanco)
    px(c - 1, 1); px(c, 1)
end

-- escena a sangre: cielo con sol detras del bicho, rayos y suelo
local function escena(d, img, x, y, w, h, dy, estrellas)
    local e = elementos[d.elemento]
    local cielo = h - 5
    local cx, cy = x + w / 2, y + cielo * 0.5
    for py = 0, h - 1 do
        for pxx = 0, w - 1 do
            local X, Y = x + pxx, y + py
            local col
            if py < cielo then
                col = trama(pxx, py, py / (cielo - 1)) and e.horizonte or e.cielo
                local ang = math.atan2(Y + 0.5 - cy, X + 0.5 - cx)
                if math.floor((ang + math.pi) / (math.pi / 8)) % 2 == 0 and (pxx + py) % 2 == 0 then col = e.horizonte end
                local dist = math.sqrt((X + 0.5 - cx) ^ 2 + (Y + 0.5 - cy) ^ 2)
                if dist < 9 then col = e.horizonte
                elseif dist < 10.2 then col = (pxx + py) % 2 == 0 and e.luz or e.horizonte end
                if estrellas and (pxx * 5 + py * 11) % 23 == 0 and dist > 11 then col = p.amarillo end
            else
                col = e.suelo
                if py == cielo or tramas[e.trama](pxx, py - cielo) then col = e.horizonte end
            end
            lg.setColor(col)
            px(X, Y)
        end
    end
    lg.setColor(1, 1, 1)
    lg.setScissor(x, y, w, h)
    lg.draw(img, x + math.floor((w - img:getWidth()) / 2), y + cielo - img:getHeight() + 2 - (dy or 0))
    lg.setScissor()
end

-- barra negra del nombre, como la de las full art
local function barraNombre(d)
    lg.setColor(p.negro)
    lg.rectangle("fill", 2, 35, W - 4, H - 37)
    fuentes.texto(d.nombre, 0, 37, 1, p.blanco, "center", W)
    gemas(rarezas[d.rareza], 44)
end

-- ALT: escena a sangre con marco dorado (joyas = la de una secreta)
local function pintarAlt(d, img, dy, joyas)
    silueta(W, H, p.amarillo)
    escena(d, img, 2, 2, W - 4, 33, 2 + dy, joyas)
    barraNombre(d)
    marcoOro(joyas)
    esquinas(W, H)
end

-- ALT de full art: fondo de rafaga y el bicho grande sobre el suelo, sin ventana
local function pintarAltFull(d, img, dy)
    local e = elementos[d.elemento]
    silueta(W, H, p.grisclaro)
    local cx, cy = 18, 16
    for y = 2, 34 do
        for x = 2, W - 3 do
            local ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
            local s = math.floor((ang + math.pi) / (math.pi / 10)) % 2 == 0
            lg.setColor(s and e.sombra or e.cielo)
            if not s and (x + y) % 2 == 0 then lg.setColor(e.horizonte) end
            px(x, y)
        end
    end
    lg.setColor(e.suelo)
    lg.rectangle("fill", 2, 30, W - 4, 5)
    lg.setColor(e.horizonte)
    lg.rectangle("fill", 2, 30, W - 4, 1)
    for py = 1, 4 do
        for x = 0, W - 5 do
            if tramas[e.trama](x, py) then px(2 + x, 30 + py) end
        end
    end
    lg.setColor(1, 1, 1)
    lg.draw(img, math.floor((W - img:getWidth()) / 2), 30 - img:getHeight() + 2 - dy)
    barraNombre(d)
    marcoOro(false)
    esquinas(W, H)
end

local RAMPAS = {
    plata = { p.azulosc, p.grisosc, p.gris, p.grisclaro, p.blanco },
    oro = { p.negro, p.morado, p.naranja, p.amarillo, p.blanco },
}

-- SILVER y GOLDEN: placa de metal grabada (guilloche), medallon y el bicho en relieve
local function pintarMetal(d, img, dy)
    local oro = d.variante == "golden"
    local R = oro and RAMPAS.oro or RAMPAS.plata
    lg.setColor(p.negro)
    lg.rectangle("fill", 1, 0, W - 2, H)
    lg.rectangle("fill", 0, 1, W, H - 2)
    local mx, my, mr = 18, 22, 13.5
    for y = 1, H - 2 do
        for x = 1, W - 2 do
            local col
            local borde = math.min(x - 1, y - 1, W - 2 - x, H - 2 - y)
            if borde == 0 then
                col = (x + y < (W + H) / 2) and R[5] or R[3]
                if (x * 3 + y) % 5 == 0 then col = R[4] end
            elseif borde == 1 then
                col = R[2]
            else
                -- guilloche: dos ondas cruzadas, como en los billetes
                local t = 0.25 + (1 - (x + y) / (W + H)) * 0.45
                col = trama(x, y, t) and R[3] or R[2]
                local a = math.sin(x * 0.6 + 2.4 * math.sin(y * 0.3))
                local b = math.sin(x * 0.6 - 2.4 * math.sin(y * 0.3) + 1.6)
                if math.abs(a) < 0.2 or math.abs(b) < 0.2 then col = R[4] end
                local dist = math.sqrt((x + 0.5 - mx) ^ 2 + (y + 0.5 - my) ^ 2)
                if dist < mr - 1.2 then
                    col = (math.floor(dist) % 3 == 0) and R[3] or R[2]
                    if dist < 4 then col = R[2] end
                elseif dist < mr then
                    col = (y < my) and R[5] or R[4]
                elseif dist < mr + 1 then
                    col = p.negro
                end
            end
            lg.setColor(col)
            px(x, y)
        end
    end
    -- remaches
    for _, q in ipairs({ { 3, 3 }, { W - 4, 3 }, { 3, H - 4 }, { W - 4, H - 4 } }) do
        lg.setColor(R[2]); px(q[1] + 1, q[2] + 1)
        lg.setColor(R[5]); px(q[1], q[2])
    end
    if oro then
        for k = 0, 7 do
            local a = k / 8 * math.pi * 2
            local sx, sy = math.floor(mx + math.cos(a) * mr), math.floor(my + math.sin(a) * mr)
            lg.setColor(p.blanco)
            px(sx, sy)
        end
    end
    -- placa de arriba y de abajo
    local txt = oro and "GOLDEN" or "SILVER"
    lg.setColor(p.negro)
    lg.rectangle("fill", 4, 2, W - 8, 8)
    lg.setColor(R[4])
    lg.rectangle("fill", 5, 3, W - 10, 6)
    lg.setColor(R[5])
    lg.rectangle("fill", 5, 3, W - 10, 1)
    fuentes.texto(txt, 0, 4, 1, R[1], "center", W)
    lg.setColor(p.negro)
    lg.rectangle("fill", 4, 37, W - 8, 9)
    lg.setColor(R[3])
    lg.rectangle("line", 4.5, 37.5, W - 9, 8)
    fuentes.texto(d.nombre, 0, 39, 1, R[5], "center", W)
    -- el bicho en relieve del mismo metal (img: imagenDe)
    lg.setColor(1, 1, 1)
    lg.draw(img, math.floor((W - img:getWidth()) / 2), my - 11 - dy)
    esquinas(W, H)
end

-- recuadro del dibujo en las cartas normales
local ARTE = { x = 3, y = 8, w = 30, h = 18 }

local function pintarCara(def, img, dy)
    if def.variante == "alt" then
        if def.rareza == "fullart" then return pintarAltFull(def, img, dy) end
        return pintarAlt(def, img, dy, def.rareza == "secreta")
    elseif def.variante then
        return pintarMetal(def, img, dy)
    end
    local r = rarezas[def.rareza]
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
    lg.setColor(1, 1, 1)
    local img = imagenBicho(def, false)
    lg.draw(img, math.floor((W - img:getWidth()) / 2), ARTE.y + ARTE.h - SUELO - img:getHeight() + 2)
end

-- linea de puntos (un pixel si, otro no) entre dos puntos
local function punteada(x1, y1, x2, y2)
    local n = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
    for i = 0, n, 2 do
        px(math.floor(x1 + (x2 - x1) * i / n + 0.5), math.floor(y1 + (y2 - y1) * i / n + 0.5))
    end
end

-- estrella en cruz: centro claro y brazos azules
local function estrellaCruz(x, y, brazo, centro)
    lg.setColor(p.celeste)
    for i = 1, brazo do
        px(x - i, y); px(x + i, y); px(x, y - i); px(x, y + i)
    end
    lg.setColor(centro)
    px(x, y)
end

-- dorso "constelacion rombo": fondo de noche con estrellas sueltas y dos
-- rombos unidos por sus puntas, igual para todas las cartas
local function pintarDorso()
    silueta(W, H, p.cian)
    lg.setColor(p.negro)
    lg.rectangle("fill", 2, 2, W - 4, H - 4)
    -- estrellitas tenues, siempre en el mismo sitio
    local r = love.math.newRandomGenerator(7)
    for i = 1, 26 do
        lg.setColor(i % 3 == 0 and p.gris or p.grisosc)
        px(r:random(3, W - 4), r:random(3, H - 4))
    end
    local cx, cy = math.floor(W / 2), math.floor(H / 2)
    local grande = { { cx, cy - 19 }, { cx + 13, cy }, { cx, cy + 19 }, { cx - 13, cy } }
    local chico = { { cx, cy - 8 }, { cx + 6, cy }, { cx, cy + 8 }, { cx - 6, cy } }
    lg.setColor(p.azul)
    for i = 1, 4 do
        local j = i % 4 + 1
        punteada(grande[i][1], grande[i][2], grande[j][1], grande[j][2])
        punteada(chico[i][1], chico[i][2], chico[j][1], chico[j][2])
        punteada(grande[i][1], grande[i][2], chico[i][1], chico[i][2])
    end
    for i = 1, 4 do
        estrellaCruz(grande[i][1], grande[i][2], 2, i % 2 == 1 and p.blanco or p.cian)
        estrellaCruz(chico[i][1], chico[i][2], 1, p.cian)
    end
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

-- el bicho de cada carta: el de su carta normal (misma semilla y tamaño) o,
-- en SILVER y GOLDEN, en relieve del mismo metal
local function imagenDe(def, cerrados)
    if def.variante == "silver" or def.variante == "golden" then
        local R = def.variante == "golden" and RAMPAS.oro or RAMPAS.plata
        return bicho.crear(def.semilla, 22, 22, { cuerpo = R[4], luz = R[5], sombra = R[3] }, cerrados)
    end
    return imagenBicho(def, rarezas[def.rareza].nivel >= 5, cerrados)
end

function carta.preparar()
    shader = lg.newShader(CODIGO_SHADER)
    dorso = lienzo(carta.ANCHO, carta.ALTO, pintarDorso)
    sello = lienzo(SELLO.w, SELLO.h, pintarSello)
    for _, def in ipairs(cartas) do
        local r = rarezas[def.rareza]
        local img = imagenDe(def)
        local frames = { lienzo(W, H, pintarCara, def, img, 0) }
        if r.nivel >= 4 and not def.sprite then
            frames[2] = lienzo(W, H, pintarCara, def, img, 1)
            frames[3] = lienzo(W, H, pintarCara, def, imagenDe(def, true), 0)
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

local ORO = { osc = { 0.50, 0.32, 0.10 }, oro = { 0.84, 0.62, 0.16 } }
local function caja(c, a, x, y, w, h)
    lg.setColor(c[1], c[2], c[3], a)
    lg.rectangle("fill", x, y, w, h)
end

-- id: true (transparente) o un top de datos/fundas.lua (color, pegatina o magnetico)
local function toploader(x, y, sx, sy, rot, gx, gy, id)
    local cx, cy = lg.transformPoint(x, y)
    preparar3D(gx, gy, cx, cy, altoEn(x, y, H * math.abs(sy)), 0, 0, 0, 0)
    lg.push()
    lg.translate(x, y)
    lg.rotate(rot)
    lg.scale(sx, sy)
    local d = id ~= true and datosFundas.top[id]
    local tw, th = W + 6, H + 7
    local x0, y0 = -W / 2 - 3, -H / 2 - 4
    if d and d.estilo == "magnetico" then
        caja(p.negro, 1, x0 - 1, y0 - 1, tw + 2, 2) caja(p.negro, 1, x0 - 1, y0 + th - 1, tw + 2, 3)
        caja(p.negro, 1, x0 - 1, y0, 2, th) caja(p.negro, 1, x0 + tw - 1, y0, 2, th)
        lg.setColor(ORO.oro)
        lg.setLineWidth(1 / math.max(math.abs(sx), 0.01))
        lg.rectangle("line", x0 + 0.5, y0 + 0.5, tw - 1, th - 1)
        lg.setLineWidth(1)
        caja(p.blanco, 0.08, x0 + 1, y0 + 1, tw - 2, th - 2)
        caja(p.blanco, 0.2, x0 + 3, y0 + 2, 2, th - 4)
        lg.pop()
        lg.setShader()
        lg.setColor(1, 1, 1)
        return
    end
    if d then
        local c = d.color
        local a = d.estilo == "color" and 0.55 or 0.3
        caja(c, a + 0.2, x0, y0, tw, 2) caja(c, a, x0, y0 + th - 4, tw, 4)
        caja(c, a, x0, y0, 2, th) caja(c, a, x0 + tw - 2, y0, 2, th)
        if d.pegatina then
            local C = d.pegatina
            caja(C.base, 1, -8, y0 + th - 6, 16, 5)
            for k = -8, 7, 3 do caja(C.rayas, 1, k, y0 + th - 6, 1, 5) end
            caja(C.borde, 1, -8, y0 + th - 6, 16, 1)
        end
    end
    lg.setColor(1, 1, 1, 0.1)
    lg.rectangle("fill", -W / 2 - 3, -H / 2 - 4, W + 6, H + 7)
    lg.setColor(1, 1, 1, 0.3)
    lg.rectangle("fill", -W / 2 - 3, -H / 2 - 4, W + 6, 2)
    lg.rectangle("fill", W / 2 - 1, -H / 2 - 2, 2, H + 3)
    local lc = (d and d.color) or p.blanco
    lg.setColor(lc[1], lc[2], lc[3], 0.75)
    lg.setLineWidth(1 / math.max(math.abs(sx), 0.01))
    lg.rectangle("line", -W / 2 - 3, -H / 2 - 4, W + 6, H + 7)
    lg.setLineWidth(1)
    lg.pop()
    lg.setShader()
    lg.setColor(1, 1, 1)
end

-- id: true (transparente) o una funda de datos/fundas.lua: de frente solo se
-- nota en el filo, con el color de su diseno
local function funda(x, y, sx, sy, rot, gx, gy, id)
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
    local d = id ~= true and datosFundas[id]
    local fc = d and d.color or p.cian
    lg.setColor(fc[1], fc[2], fc[3], d and 1 or 0.85)
    lg.setLineWidth(1 / math.max(math.abs(sx), 0.01))
    lg.rectangle("line", -W / 2 - 1, -H / 2 - 1, W + 2, H + 2)
    if d then
        -- doble filo: se nota mas que la transparente
        lg.setColor(fc[1], fc[2], fc[3], 0.45)
        lg.rectangle("line", -W / 2, -H / 2, W, H)
    end
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
    rot = rot or 0
    extra = extra or {}
    local a, lx, ly = 0, 0, 0
    if h then a, lx, ly = h.brillo or 0, h.lx or 0, h.ly or 0 end
    local alza = a * 2

    local gx, gy = -lx * 0.32 * a, ly * 0.32 * a
    local r = def and rarezas.de(def)
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
    enviar("arte", def.variante == "alt" and ARTE_FOIL_ALT or ARTE_FOIL)
    lg.draw(cara(def), x, y - alza, rot, sx, sy, W / 2, H / 2)
    if extra.primera then
        preparar3D(gx, gy, cx, cy, alto, 0, 0, 0, 0)
        -- en SILVER y GOLDEN va abajo, para no tapar la placa de arriba
        local metal = def.variante == "silver" or def.variante == "golden"
        lg.draw(sello, x, y - alza, rot, sx, sy, W / 2 - (metal and 28 or SELLO.x), H / 2 - (metal and 31 or SELLO.y))
    end
    lg.setShader()
    if enFunda then funda(x, y - alza, sx, sy, rot, gx, gy, enFunda) end
    if extra.top then toploader(x, y - alza, sx, sy, rot, gx, gy, extra.top) end
end

-- carta que aun no tienes: hueco oscuro con la silueta del bicho
-- (las de fuera de set no dicen cual es: solo un ? grande)
function carta.hueco(def, x, y, escala)
    local w, h = W * escala, H * escala
    local x0, y0 = math.floor(x - w / 2), math.floor(y - h / 2)
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x0, y0, w, h)
    lg.setColor(p.grisosc)
    lg.rectangle("line", x0 + 0.5, y0 + 0.5, w - 1, h - 1)
    if def.fuera then
        local t = math.max(1, math.floor(escala * 1.5))
        fuentes.texto("?", x0, y0 + math.floor((h - 5 * t) / 2), t, p.gris, "center", w)
        return
    end
    lg.setColor(p.negro[1], p.negro[2], p.negro[3], 0.9)
    lg.draw(siluetas[def.id], x0, y0, 0, escala, escala)
    fuentes.texto(string.format("#%02d", def.num), x0, y0 + h - 8 * escala, escala, p.grisosc, "center", w)
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
        extra = { primera = ediciones[1], top = extra.top }
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
