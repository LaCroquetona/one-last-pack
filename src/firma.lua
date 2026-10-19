local utf8 = require "utf8"
local firma = require "datos.firma"
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"

local lg = love.graphics

local intro = {}

local ESCALA_NOMBRE = 3
local ALTO_LOGO = 100

-- el logo aparece pixel a pixel en orden aleatorio
local codigoDisolver = [[
extern number progreso;
extern vec2 tam;

float azar(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 c = Texel(tex, uv) * color;
    if (azar(floor(uv * tam)) > progreso) discard;
    return c;
}
]]

local logo, escalaLogo, disolver
local largo = utf8.len(firma.nombre)
local t = 0
local letras = 0
local listo = false
local alSalir

function intro.empezar(siguiente)
    alSalir = siguiente
    if love.filesystem.getInfo(firma.logo) then
        logo = lg.newImage(firma.logo)
        logo:setFilter("nearest", "nearest")
        -- escala entera para que no se deformen los pixeles
        escalaLogo = math.max(1, math.floor(ALTO_LOGO / logo:getHeight()))
        if logo:getHeight() > ALTO_LOGO then escalaLogo = ALTO_LOGO / logo:getHeight() end
        disolver = lg.newShader(codigoDisolver)
        disolver:send("tam", { logo:getWidth(), logo:getHeight() })
    end
end

local function terminar()
    if listo then return end
    listo = true
    alSalir()
end

function intro.saltar()
    if t > 0.3 then terminar() end
end

function intro.update(dt)
    t = t + dt
    local antes = letras
    letras = math.max(0, math.floor((t - 0.9) / 0.05))
    if letras > antes and letras <= largo then sonido.tocar("encima", 0.8 + letras * 0.04) end
    if t >= firma.duracion then terminar() end
end

local function alfa()
    local fin = firma.duracion
    if t > fin - 0.4 then return math.max(0, (fin - t) / 0.4) end
    return 1
end

function intro.dibujar(ancho, alto)
    lg.clear(p.negro)
    local a = alfa()
    local yNombre = alto / 2 + 4

    if logo then
        local w, h = logo:getWidth() * escalaLogo, logo:getHeight() * escalaLogo
        yNombre = alto / 2 + h / 2 + 4
        local y = alto / 2 - h / 2 - 12
        disolver:send("progreso", math.min(1, math.max(0, (t - 0.2) / 0.6)))
        lg.setShader(disolver)
        lg.setColor(1, 1, 1, a)
        lg.draw(logo, math.floor(ancho / 2 - w / 2), math.floor(y), 0, escalaLogo, escalaLogo)
        lg.setShader()
    end

    -- se cuentan letras, no bytes, por la ñ
    local n = math.min(letras, largo)
    local visible = n > 0 and firma.nombre:sub(1, (utf8.offset(firma.nombre, n + 1) or 0) - 1) or ""
    local w = fuentes.ancho(firma.nombre, ESCALA_NOMBRE)
    fuentes.texto(visible, math.floor(ancho / 2 - w / 2), yNombre, ESCALA_NOMBRE, { p.blanco[1], p.blanco[2], p.blanco[3], a })
end

return intro
