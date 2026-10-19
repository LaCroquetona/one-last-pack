local fuentes = require "src.fuentes"

local fx = {}

local BASE = {0.06, 0.06, 0.10}

local particulas = {}
local textos = {}
local temblor = 0
local destello = { a = 0, color = {1, 1, 1} }
local lenta = { t = 0, escala = 1 }
local tinte = {BASE[1], BASE[2], BASE[3]}

fx.fondo = {BASE[1], BASE[2], BASE[3]}

function fx.salidaSuave(t)
    return 1 - (1 - t) ^ 3
end

function fx.salidaRebote(t)
    local c = 1.70158
    return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

function fx.lerp(a, b, t)
    return a + (b - a) * t
end

function fx.explosion(x, y, color, cantidad, fuerza)
    for _ = 1, cantidad do
        local ang = love.math.random() * math.pi * 2
        local vel = fuerza * (0.3 + love.math.random() * 0.7)
        local vida = 0.5 + love.math.random() * 0.8
        table.insert(particulas, {
            x = x, y = y,
            vx = math.cos(ang) * vel,
            vy = math.sin(ang) * vel - fuerza * 0.4,
            vida = vida, vidaMax = vida,
            tam = love.math.random(1, 3),
            color = color,
        })
    end
end

-- texto que sube y se desvanece (+$20, -$120...)
function fx.texto(x, y, cad, color)
    table.insert(textos, { x = x, y = y, cad = cad, color = color, vida = 1.2 })
end

function fx.sacudir(fuerza)
    temblor = math.max(temblor, fuerza)
end

function fx.destello(color, fuerza)
    destello.color = color
    destello.a = math.max(destello.a, fuerza)
end

function fx.camaraLenta(duracion, escala)
    lenta.t = duracion
    lenta.escala = escala
end

function fx.tintar(color)
    for i = 1, 3 do
        tinte[i] = BASE[i] + color[i] * 0.15
    end
end

function fx.escalaTiempo()
    if lenta.t > 0 then return lenta.escala end
    return 1
end

-- dt real, sin camara lenta: los efectos de pantalla no se ralentizan
function fx.update(dt)
    for i = #particulas, 1, -1 do
        local q = particulas[i]
        q.vy = q.vy + 260 * dt
        q.vx = q.vx * (1 - dt * 1.5)
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        q.vida = q.vida - dt
        if q.vida <= 0 then table.remove(particulas, i) end
    end
    for i = #textos, 1, -1 do
        local t = textos[i]
        t.y = t.y - 18 * dt
        t.vida = t.vida - dt
        if t.vida <= 0 then table.remove(textos, i) end
    end
    temblor = temblor * math.exp(-dt * 9)
    destello.a = destello.a * math.exp(-dt * 7)
    lenta.t = math.max(0, lenta.t - dt)
    for i = 1, 3 do
        tinte[i] = fx.lerp(tinte[i], BASE[i], dt * 0.6)
        fx.fondo[i] = fx.lerp(fx.fondo[i], tinte[i], dt * 6)
    end
end

function fx.desplazamiento()
    if temblor < 0.3 then return 0, 0 end
    return math.floor((love.math.random() * 2 - 1) * temblor + 0.5),
           math.floor((love.math.random() * 2 - 1) * temblor + 0.5)
end

function fx.dibujarParticulas()
    for _, q in ipairs(particulas) do
        local c = q.color
        love.graphics.setColor(c[1], c[2], c[3], q.vida / q.vidaMax)
        love.graphics.rectangle("fill", math.floor(q.x), math.floor(q.y), q.tam, q.tam)
    end
    for _, t in ipairs(textos) do
        local c = t.color
        local a = math.min(1, t.vida * 2)
        local w = fuentes.ancho(t.cad, 2)
        fuentes.texto(t.cad, t.x - w / 2 + 1, t.y + 1, 2, {0, 0, 0, a * 0.6})
        fuentes.texto(t.cad, t.x - w / 2, t.y, 2, {c[1], c[2], c[3], a})
    end
    love.graphics.setColor(1, 1, 1)
end

function fx.dibujarDestello(ancho, alto)
    if destello.a < 0.01 then return end
    local c = destello.color
    love.graphics.setColor(c[1], c[2], c[3], destello.a)
    love.graphics.rectangle("fill", 0, 0, ancho, alto)
    love.graphics.setColor(1, 1, 1)
end

function fx.aura(x, y, color, radio, alfa)
    love.graphics.setBlendMode("add")
    for i = 5, 1, -1 do
        love.graphics.setColor(color[1], color[2], color[3], alfa * 0.18)
        love.graphics.circle("fill", x, y, radio * i / 5)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1)
end

function fx.rayos(x, y, color, radio, alfa, giro)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], alfa)
    local n = 12
    for i = 0, n - 1 do
        local a = giro + i * math.pi * 2 / n
        local ancho = 0.12
        love.graphics.polygon("fill", x, y,
            x + math.cos(a - ancho) * radio, y + math.sin(a - ancho) * radio,
            x + math.cos(a + ancho) * radio, y + math.sin(a + ancho) * radio)
    end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1)
end

return fx
