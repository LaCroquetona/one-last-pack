local rarezas = require "datos.rarezas"
local generador = require "src.generador"
local partida = require "src.partida"
local carta = require "src.carta"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"

local lg = love.graphics

local apertura = {}

local CX, CY = 320, 165
local GRANDE = 1.6
local MINI = 0.55
local RANURA_Y = 318
local GIRO = 0.2
local CORTE = 22   -- altura de la tira de arriba del sobre que se arranca

local estado, t
local mano, godpack, mejor
local idx, fase, tf
local carga = 0
local latido = 0
local pulsado = false
local sobreImg, quadArriba, quadAbajo

local function pintarSobre()
    lg.setColor(0.80, 0.18, 0.24)
    lg.rectangle("fill", 0, 6, 90, 118)
    for x = 0, 86, 4 do
        lg.polygon("fill", x, 6, x + 2, 1, x + 4, 6)
        lg.polygon("fill", x, 124, x + 2, 129, x + 4, 124)
    end
    lg.setColor(0.90, 0.30, 0.32)
    for i = -130, 90, 10 do
        lg.polygon("fill", i, 124, i + 4, 124, i + 122, 6, i + 118, 6)
    end
    lg.setColor(0.10, 0.08, 0.14)
    lg.rectangle("fill", 0, 44, 90, 44)
    lg.setColor(0.85, 0.75, 0.45)
    lg.polygon("fill", 45, 50, 57, 66, 45, 82, 33, 66)
    lg.setColor(0.10, 0.08, 0.14)
    lg.polygon("fill", 45, 55, 53, 66, 45, 77, 37, 66)
    lg.setColor(0.85, 0.75, 0.45)
    lg.setFont(fuentes.mini)
    lg.printf("ONE LAST PACK", 0, 98, 90, "center")
    lg.printf("SET 1", 0, 108, 90, "center")
    lg.setColor(1, 1, 1, 0.5)
    for x = 2, 88, 4 do
        lg.rectangle("fill", x, CORTE, 2, 1)
    end
end

function apertura.preparar()
    sobreImg = lg.newCanvas(90, 130)
    lg.setCanvas(sobreImg)
    lg.clear(0, 0, 0, 0)
    pintarSobre()
    lg.setCanvas()
    lg.setColor(1, 1, 1)
    quadArriba = lg.newQuad(0, 0, 90, CORTE, 90, 130)
    quadAbajo = lg.newQuad(0, CORTE, 90, 130 - CORTE, 90, 130)
end

local function ranuraX(i)
    return CX + (i - 3) * 46
end

function apertura.empezar()
    local defs
    defs, godpack = generador.sobre()
    mano = {}
    for i, def in ipairs(defs) do
        mano[i] = { def = def, x = CX, y = CY, escala = GRANDE, boca = false, nueva = false }
    end
    mejor = rarezas[defs[#defs].rareza]
    carga = 0
    estado, t = "entrando", 0
end

function apertura.pulsar()
    pulsado = true
end

local function rasgar()
    sonido.carga(0)
    sonido.tocar("rasgar")
    fx.sacudir(6)
    fx.destello({1, 1, 1}, 0.8)
    fx.explosion(CX, CY - 80, {1, 1, 1}, 40, 160)
    if godpack then
        fx.destello(rarezas.secreta.color, 1)
        fx.explosion(CX, CY, rarezas.secreta.color, 120, 260)
        fx.tintar(rarezas.secreta.color)
    end
    partida.sobreAbierto()
    estado, t = "rasgado", 0
end

local function impacto(c, r)
    c.nueva = partida.anadir(c.def.id)
    sonido.tocar(r.id)
    fx.explosion(CX, CY, r.color, 8 + r.nivel ^ 2 * 6, 60 + r.nivel * 30)
    fx.sacudir(r.nivel ^ 1.4)
    if r.nivel >= 3 then fx.destello(r.color, 0.15 + r.nivel * 0.08) end
    if r.nivel >= 4 then
        fx.camaraLenta(0.6, 0.25)
        fx.tintar(r.color)
    end
    if c.nueva then
        sonido.tocar("nueva")
        fx.explosion(CX, CY - 60, {1, 1, 1}, 15, 90)
    end
end

local function actualizarCarta(dt, mantenido)
    local c = mano[idx]
    local r = rarezas[c.def.rareza]
    tf = tf + dt

    if fase == "esperando" then
        if pulsado or (mantenido and tf > 0.12) then
            fase, tf = r.suspense > 0 and "suspense" or "girando", 0
            latido = 0
        end
    elseif fase == "suspense" then
        latido = latido - dt
        if latido <= 0 then
            sonido.tocar("latido", 1 + tf * 0.4)
            fx.sacudir(1 + r.nivel * 0.4)
            latido = math.max(0.12, 0.4 - tf * 0.2)
        end
        if tf >= r.suspense then fase, tf = "girando", 0 end
    elseif fase == "girando" then
        if tf >= GIRO / 2 and not c.boca then
            c.boca = true
            sonido.tocar("giro")
            impacto(c, r)
        end
        if tf >= GIRO then fase, tf = "mostrando", 0 end
    elseif fase == "mostrando" then
        -- las normales pasan solas, las buenas esperan a que las mires
        local auto = r.nivel <= 2 and tf > (mantenido and 0.12 or 0.4)
        local minimo = r.nivel >= 4 and 0.6 or 0.15
        if auto or (pulsado and tf > minimo) then fase, tf = "volando", 0 end
    elseif fase == "volando" then
        local p = fx.salidaSuave(math.min(1, tf / 0.22))
        c.x = fx.lerp(CX, ranuraX(idx), p)
        c.y = fx.lerp(CY, RANURA_Y, p)
        c.escala = fx.lerp(GRANDE, MINI, p)
        if tf >= 0.22 then
            idx = idx + 1
            if idx > #mano then
                estado, t = "resumen", 0
                partida.guardar()
            else
                fase, tf = "esperando", 0
            end
        end
    end
end

function apertura.update(dt, mantenido)
    t = t + dt

    if estado == "entrando" then
        if t > 0.35 then estado, t = "sobre", 0 end
    elseif estado == "sobre" then
        if mantenido then
            carga = math.min(1, carga + dt / 0.8)
        else
            carga = math.max(0, carga - dt * 2.5)
        end
        sonido.carga(carga)
        if carga >= 1 then rasgar() end
    elseif estado == "rasgado" then
        if t > 0.55 then
            estado, t = "revelando", 0
            idx, fase, tf = 1, "esperando", 0
        end
    elseif estado == "revelando" then
        actualizarCarta(dt, mantenido)
    elseif estado == "resumen" then
        for i, c in ipairs(mano) do
            local p = fx.salidaRebote(math.min(1, math.max(0, (t - i * 0.06) / 0.35)))
            c.x = fx.lerp(ranuraX(i), CX + (i - 3) * 100, p)
            c.y = fx.lerp(RANURA_Y, 150, p)
            c.escala = fx.lerp(MINI, 1.15, p)
        end
        if pulsado and t > 0.5 then apertura.empezar() end
    end

    pulsado = false
end

local function texto(cad, y, fuente, color)
    lg.setFont(fuente)
    lg.setColor(color or {1, 1, 1})
    lg.printf(cad, 0, y, 640, "center")
    lg.setColor(1, 1, 1)
end

local function dibujarSobre()
    local y = CY
    if estado == "entrando" then
        y = fx.lerp(420, CY, fx.salidaRebote(math.min(1, t / 0.35)))
    end
    local bote = math.sin(love.timer.getTime() * 2) * 2 * (1 - carga)
    local dx = (love.math.random() * 2 - 1) * carga * 3
    local dy = (love.math.random() * 2 - 1) * carga * 3
    local e = GRANDE + carga * 0.15

    -- solo los sobres con premio brillan de color al cargar, el resto en blanco
    if carga > 0.4 then
        local color = mejor.nivel >= 4 and mejor.color or {1, 1, 1}
        fx.aura(CX, y, color, 90 + carga * 40, (carga - 0.4) * 1.2)
    end
    lg.draw(sobreImg, CX + dx, y + bote + dy, (love.math.random() - 0.5) * carga * 0.06, e, e, 45, 65)

    if estado == "sobre" then
        local a = 0.5 + math.sin(love.timer.getTime() * 4) * 0.3
        texto("Mantén click o espacio para abrir", 290, fuentes.normal, {1, 1, 1, a})
    end
end

local function dibujarRasgado()
    local izq = CX - 45 * GRANDE
    local arriba = CY - 65 * GRANDE
    local p = math.min(1, t / 0.55)

    local cartasP = fx.salidaRebote(math.min(1, t / 0.4))
    for i = #mano, 1, -1 do
        carta.dibujar(nil, CX, CY - (i - 1) * 2, GRANDE * fx.lerp(0.6, 1, cartasP), GRANDE * fx.lerp(0.6, 1, cartasP), 0, false)
    end

    lg.setColor(1, 1, 1, 1 - p)
    lg.draw(sobreImg, quadAbajo, izq, arriba + CORTE * GRANDE + t * t * 900, 0, GRANDE, GRANDE)
    lg.draw(sobreImg, quadArriba, izq + t * 260, arriba - t * 300 + t * t * 500, t * 5, GRANDE, GRANDE)
    lg.setColor(1, 1, 1)
end

local function dibujarActual(c)
    local r = rarezas[c.def.rareza]
    local x, y = c.x, c.y
    local sx, sy = c.escala, c.escala
    local rot = 0

    if fase == "suspense" then
        local fuerza = tf / r.suspense
        x = x + (love.math.random() * 2 - 1) * fuerza * 3
        y = y + (love.math.random() * 2 - 1) * fuerza * 3
        fx.aura(CX, CY, r.color, 70 + fuerza * 60, fuerza * 0.9)
    elseif fase == "girando" then
        sx = c.escala * math.max(0.05, math.abs(math.cos(math.pi * tf / GIRO)))
        sy = c.escala * (1 + math.sin(math.pi * tf / GIRO) * 0.12)
    elseif fase == "mostrando" then
        local giroRayos = love.timer.getTime() * 0.5
        if r.nivel >= 3 then fx.rayos(CX, CY, r.color, 220, 0.06 * r.nivel, giroRayos) end
        if r.nivel >= 2 then fx.aura(CX, CY, r.color, 110, 0.15 * r.nivel) end
        local p = math.min(1, tf / 0.15)
        sx = c.escala * fx.lerp(1.15, 1, fx.salidaSuave(p))
        sy = sx
        rot = math.sin(love.timer.getTime() * 2) * 0.03
    end

    carta.dibujar(c.def, x, y, sx, sy, rot, c.boca)

    if fase == "mostrando" then
        texto(c.def.nombre, 255, fuentes.grande)
        texto(r.nombre, 275, fuentes.normal, r.color)
        if c.nueva then
            texto("¡NUEVA!", 34, fuentes.grande, {1, 0.9, 0.3})
        end
    end
end

local function dibujarRevelando()
    for i = #mano, idx + 1, -1 do
        carta.dibujar(nil, CX, CY - (i - idx) * 2, GRANDE, GRANDE, 0, false)
    end
    for i = 1, idx - 1 do
        local c = mano[i]
        carta.dibujar(c.def, c.x, c.y, c.escala, c.escala, 0, true)
    end
    dibujarActual(mano[idx])
end

local function dibujarResumen()
    if godpack then
        texto("¡¡GOD PACK!!", 30, fuentes.grande, rarezas.secreta.color)
    end
    for i, c in ipairs(mano) do
        local r = rarezas[c.def.rareza]
        carta.dibujar(c.def, c.x, c.y, c.escala, c.escala, 0, true)
        if t > 0.4 then
            lg.setFont(fuentes.mini)
            lg.setColor(r.color)
            lg.printf(r.nombre, c.x - 50, 214, 100, "center")
            if c.nueva then
                lg.setColor(1, 0.9, 0.3)
                lg.printf("NUEVA", c.x - 50, 76, 100, "center")
            end
        end
    end
    lg.setColor(1, 1, 1)
    if t > 0.5 then
        local a = 0.5 + math.sin(love.timer.getTime() * 4) * 0.3
        texto("Click para otro sobre", 285, fuentes.normal, {1, 1, 1, a})
    end
end

function apertura.dibujar()
    if estado == "entrando" or estado == "sobre" then
        dibujarSobre()
    elseif estado == "rasgado" then
        dibujarRasgado()
    elseif estado == "revelando" then
        dibujarRevelando()
    elseif estado == "resumen" then
        dibujarResumen()
    end
end

return apertura
