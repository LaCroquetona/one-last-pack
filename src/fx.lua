local fuentes = require "src.fuentes"

local fx = {}

local BASE = {0.06, 0.06, 0.10}

local particulas = {}
local textos = {}
local estrellas = {}
local monedas = {}
local confeti = {}
local golpe

local AMARILLO = { 1, 0.80, 0.46 }
local NARANJA = { 0.94, 0.49, 0.34 }
local COLORES_CONFETI = {
    { 0.69, 0.24, 0.33 }, { 1, 0.80, 0.46 }, { 0.65, 0.94, 0.44 },
    { 0.25, 0.65, 0.96 }, { 0.78, 0.44, 0.88 }, { 0.94, 0.49, 0.34 }, { 0.45, 0.94, 0.97 },
}
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

-- estrellitas de 4 puntas que brillan un momento y se apagan
function fx.chispa(x, y, color)
    local vida = 0.4 + love.math.random() * 0.5
    table.insert(estrellas, {
        x = x, y = y, vx = (love.math.random() - 0.5) * 10, vy = -4 - love.math.random() * 10,
        vida = vida, vidaMax = vida, color = color, grande = love.math.random() < 0.3,
    })
end

-- de vez en cuando una chispa en un rectangulo (x, y es el centro)
function fx.chispas(x, y, w, h, color, porSegundo)
    if love.math.random() < porSegundo * love.timer.getDelta() then
        fx.chispa(x + (love.math.random() - 0.5) * w, y + (love.math.random() - 0.5) * h, color)
    end
end

-- monedas que saltan girando y caen (abajo: donde rebotan)
function fx.monedas(x, y, cantidad, fuerza, abajo)
    for _ = 1, cantidad do
        local ang = -math.pi / 2 + (love.math.random() - 0.5) * 2.2
        local vel = (fuerza or 160) * (0.4 + love.math.random() * 0.6)
        table.insert(monedas, {
            x = x + (love.math.random() - 0.5) * 10, y = y,
            vx = math.cos(ang) * vel, vy = math.sin(ang) * vel,
            giro = love.math.random() * 6, velGiro = 8 + love.math.random() * 10,
            vida = 1.4 + love.math.random() * 0.8, abajo = abajo or 340, botes = 0,
        })
    end
end

-- lluvia de monedas desde arriba de la pantalla
function fx.lluviaMonedas(cantidad)
    for _ = 1, cantidad do
        table.insert(monedas, {
            x = love.math.random(0, 640), y = -6 - love.math.random() * 30,
            vx = (love.math.random() - 0.5) * 20, vy = 40 + love.math.random() * 60,
            giro = love.math.random() * 6, velGiro = 8 + love.math.random() * 10,
            vida = 2.2, abajo = 380, botes = 1,
        })
    end
end

-- papelitos de colores que caen despacio balanceandose
function fx.confeti(x, y, cantidad, fuerza)
    for _ = 1, cantidad do
        local ang = -math.pi / 2 + (love.math.random() - 0.5) * 2.6
        local vel = (fuerza or 150) * (0.3 + love.math.random() * 0.7)
        table.insert(confeti, {
            x = x, y = y, vx = math.cos(ang) * vel, vy = math.sin(ang) * vel,
            fase = love.math.random() * 6, vida = 1.6 + love.math.random() * 1,
            color = COLORES_CONFETI[love.math.random(#COLORES_CONFETI)],
        })
    end
end

-- texto enorme que cae de golpe en el centro (el nombre de la rareza)
function fx.golpear(cad, color, y)
    golpe = { cad = cad, color = color, y = y or 52, t = 0 }
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

-- lo que el tinte se aparta del fondo normal, para teñir el escritorio
function fx.tinteMesa()
    return {
        math.max(0, fx.fondo[1] - BASE[1]) * 1.6,
        math.max(0, fx.fondo[2] - BASE[2]) * 1.6,
        math.max(0, fx.fondo[3] - BASE[3]) * 1.6,
    }
end

function fx.escalaTiempo()
    if lenta.t > 0 then return lenta.escala end
    return 1
end

function fx.hayGolpe()
    return golpe ~= nil
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
    for i = #estrellas, 1, -1 do
        local q = estrellas[i]
        q.x = q.x + q.vx * dt
        q.y = q.y + q.vy * dt
        q.vida = q.vida - dt
        if q.vida <= 0 then table.remove(estrellas, i) end
    end
    for i = #monedas, 1, -1 do
        local m = monedas[i]
        m.vy = m.vy + 420 * dt
        m.x = m.x + m.vx * dt
        m.y = m.y + m.vy * dt
        m.giro = m.giro + m.velGiro * dt
        if m.y > m.abajo and m.vy > 0 and m.botes == 0 then
            m.vy = -m.vy * 0.45
            m.vx = m.vx * 0.6
            m.botes = 1
        end
        m.vida = m.vida - dt
        if m.vida <= 0 or m.y > 400 then table.remove(monedas, i) end
    end
    for i = #confeti, 1, -1 do
        local c = confeti[i]
        c.vx = c.vx * (1 - dt * 2.5)
        c.vy = c.vy * (1 - dt * 2.5) + 90 * dt
        c.fase = c.fase + dt * 7
        c.x = c.x + (c.vx + math.sin(c.fase) * 18) * dt
        c.y = c.y + c.vy * dt
        c.vida = c.vida - dt
        if c.vida <= 0 then table.remove(confeti, i) end
    end
    if golpe then
        golpe.t = golpe.t + dt
        if golpe.t > 1.6 then golpe = nil end
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
    for _, c in ipairs(confeti) do
        local a = math.min(1, c.vida * 2)
        love.graphics.setColor(c.color[1], c.color[2], c.color[3], a)
        if math.sin(c.fase) > 0 then
            love.graphics.rectangle("fill", math.floor(c.x), math.floor(c.y), 2, 1)
        else
            love.graphics.rectangle("fill", math.floor(c.x), math.floor(c.y), 1, 2)
        end
    end
    for _, m in ipairs(monedas) do
        local a = math.min(1, m.vida * 3)
        -- la moneda gira: se ve mas o menos ancha
        local ancho = math.max(1, math.floor(math.abs(math.cos(m.giro)) * 4 + 0.5))
        local x, y = math.floor(m.x - ancho / 2), math.floor(m.y)
        love.graphics.setColor(NARANJA[1], NARANJA[2], NARANJA[3], a)
        love.graphics.rectangle("fill", x, y, ancho, 4)
        love.graphics.setColor(AMARILLO[1], AMARILLO[2], AMARILLO[3], a)
        love.graphics.rectangle("fill", x, y, ancho, 3)
        if ancho >= 3 then
            love.graphics.setColor(1, 1, 1, a)
            love.graphics.rectangle("fill", x + 1, y + 1, 1, 1)
        end
    end
    for _, q in ipairs(estrellas) do
        local c = q.color
        local v = q.vida / q.vidaMax
        local brillo = math.sin(v * math.pi)
        local x, y = math.floor(q.x), math.floor(q.y)
        love.graphics.setColor(c[1], c[2], c[3], brillo)
        love.graphics.rectangle("fill", x, y, 1, 1)
        local largo = (q.grande and 3 or 2) * brillo
        if largo >= 1 then
            local l = math.floor(largo + 0.5)
            love.graphics.rectangle("fill", x - l, y, l * 2 + 1, 1)
            love.graphics.rectangle("fill", x, y - l, 1, l * 2 + 1)
        end
        love.graphics.setColor(1, 1, 1, brillo)
        love.graphics.rectangle("fill", x, y, 1, 1)
    end
    if golpe then
        local q = math.min(1, golpe.t / 0.18)
        local escala = math.floor(fx.lerp(10, 4, q * q) + 0.5)
        local a = golpe.t > 1.2 and (1.6 - golpe.t) / 0.4 or 1
        local c = golpe.color
        local w = fuentes.ancho(golpe.cad, escala)
        local y = golpe.y - escala * 2.5
        fuentes.texto(golpe.cad, 320 - w / 2 + escala, y + escala, escala, { 0, 0, 0, a * 0.7 })
        fuentes.texto(golpe.cad, 320 - w / 2, y, escala, { c[1], c[2], c[3], a })
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
