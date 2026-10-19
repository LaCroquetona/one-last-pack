local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local generador = require "src.generador"
local partida = require "src.partida"
local carta = require "src.carta"
local sobre = require "src.sobre"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local lg = love.graphics

local apertura = {}

local CX, CY = 320, 160
local GRANDE = 3
local MINI = 1
local ESCALA_SOBRE = 4
local RANURA_Y = 318
local GIRO = 0.2

local estado, t
local mano, godpack, mejor
local idx, fase, tf
local carga = 0
local latido = 0
local pulsado = false

local function ranuraX(i)
    return CX + (i - (#mano + 1) / 2) * 42
end

local function resumenX(i)
    return CX + (i - (#mano + 1) / 2) * 82
end

-- tipo: entrada de datos/sobres.lua (ya descontada de los guardados)
function apertura.empezar(tipo)
    local defs
    defs, godpack = generador.sobre(tipo)
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

local function siguiente()
    local tipo = partida.sacarSobre()
    if tipo then apertura.empezar(tipo) else nav.ir("armario") end
end

function apertura.boton(id)
    if id == "otro" then
        siguiente()
    elseif id == "armario" or id == "tienda" then
        nav.ir(id)
    end
end

local function rasgar()
    sonido.carga(0)
    sonido.tocar("rasgar")
    fx.sacudir(6)
    fx.destello({1, 1, 1}, 0.8)
    fx.explosion(CX, CY - 70, {1, 1, 1}, 40, 160)
    if godpack then
        fx.destello(rarezas.secreta.color, 1)
        fx.explosion(CX, CY, rarezas.secreta.color, 120, 260)
        fx.tintar(rarezas.secreta.color)
    end
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
        local q = fx.salidaSuave(math.min(1, tf / 0.22))
        c.x = fx.lerp(CX, ranuraX(idx), q)
        c.y = fx.lerp(CY, RANURA_Y, q)
        c.escala = fx.lerp(GRANDE, MINI, q)
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
            local q = fx.salidaRebote(math.min(1, math.max(0, (t - i * 0.05) / 0.35)))
            c.x = fx.lerp(ranuraX(i), resumenX(i), q)
            c.y = fx.lerp(RANURA_Y, 150, q)
            c.escala = fx.lerp(MINI, 2, q)
        end
        if pulsado and t > 0.5 then siguiente() end
    end

    pulsado = false
end

local function texto(cad, y, escala, color)
    fuentes.texto(cad, 0, y, escala, color, "center", 640)
end

local function parpadeo()
    return 0.55 + math.sin(love.timer.getTime() * 4) * 0.35
end

local function dibujarSobre()
    local y = CY
    if estado == "entrando" then
        y = fx.lerp(420, CY, fx.salidaRebote(math.min(1, t / 0.35)))
    end
    local bote = math.sin(love.timer.getTime() * 2) * 2 * (1 - carga)
    local dx = (love.math.random() * 2 - 1) * carga * 3
    local dy = (love.math.random() * 2 - 1) * carga * 3

    -- solo los sobres con premio brillan de color al cargar, el resto en blanco
    if carga > 0.4 then
        local color = mejor.nivel >= 4 and mejor.color or {1, 1, 1}
        fx.aura(CX, y, color, 90 + carga * 40, (carga - 0.4) * 1.2)
    end
    sobre.dibujar(CX + dx, y + bote + dy, ESCALA_SOBRE + carga * 0.4, (love.math.random() - 0.5) * carga * 0.06)

    if estado == "sobre" then
        local b = parpadeo()
        texto("MANTÉN CLICK O ESPACIO PARA ABRIR", 268, 1, {1, 1, 1, b})
    end
end

local function dibujarRasgado()
    local W, H = sobre.ANCHO * ESCALA_SOBRE, sobre.ALTO * ESCALA_SOBRE
    local izq, arriba = CX - W / 2, CY - H / 2
    local q = math.min(1, t / 0.55)

    local e = GRANDE * fx.lerp(0.6, 1, fx.salidaRebote(math.min(1, t / 0.4)))
    for i = #mano, 1, -1 do
        carta.dibujar(nil, CX, CY - (i - 1) * 2, e, e, 0, false)
    end

    lg.setColor(1, 1, 1, 1 - q)
    lg.draw(sobre.img, sobre.abajo, izq, arriba + sobre.CORTE * ESCALA_SOBRE + t * t * 900, 0, ESCALA_SOBRE, ESCALA_SOBRE)
    lg.draw(sobre.img, sobre.arriba, izq + t * 260, arriba - t * 300 + t * t * 500, t * 5, ESCALA_SOBRE, ESCALA_SOBRE)
    lg.setColor(1, 1, 1)
end

local function dibujarActual(c)
    local r = rarezas[c.def.rareza]
    local x, y = c.x, c.y
    local sx, sy = c.escala, c.escala
    local rot = 0
    local h

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
        local q = math.min(1, tf / 0.15)
        sx = c.escala * fx.lerp(1.15, 1, fx.salidaSuave(q))
        sy = sx
        rot = math.sin(love.timer.getTime() * 2) * 0.03
        -- se inclina un poco hacia el raton, como si la tuvieras en la mano
        local dx = math.max(-1, math.min(1, (ui.mx - CX) / 150))
        local dy = math.max(-1, math.min(1, (ui.my - CY) / 150))
        h = { kx = -dx * dy * 0.08, ky = dx * 0.05, brillo = 0.6, lx = dx, ly = dy }
    end

    carta.dibujar(c.def, x, y, sx, sy, rot, c.boca, h)

    if fase == "mostrando" then
        texto(c.def.nombre, 246, 3, p.blanco)
        texto(r.nombre, 268, 1, r.color)
        if c.nueva then texto("¡NUEVA!", 62, 3, p.amarillo) end
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
    if godpack then texto("¡¡GOD PACK!!", 36, 3, rarezas.secreta.color) end

    for i, c in ipairs(mano) do
        local r = rarezas[c.def.rareza]
        local id = "res" .. i
        local h = t > 0.6 and ui.hoverCarta(id, c.x, c.y, carta.ANCHO * 2, carta.ALTO * 2) or nil
        carta.dibujar(c.def, c.x, c.y, c.escala, c.escala, 0, true, h)
        if t > 0.6 then
            ui.zona(id, c.x - carta.ANCHO, c.y - carta.ALTO, carta.ANCHO * 2, carta.ALTO * 2)
            fuentes.texto(r.nombre, c.x - 40, 205, 1, r.color, "center", 80)
            if c.nueva then fuentes.texto("NUEVA", c.x - 40, 88, 1, p.amarillo, "center", 80) end
            if ui.encima == id then
                ui.tooltip(c.def.nombre, r.color, {
                    { r.nombre, r.color },
                    { "Copias: " .. partida.copias(c.def.id) },
                    { "Vale " .. ui.dinero(r.precio) .. " cada una", p.amarillo },
                })
            end
        end
    end

    if t > 0.5 then
        local quedan = partida.sobresGuardados()
        if quedan > 0 then
            ui.boton("otro", "SIGUIENTE SOBRE (" .. quedan .. ")", 214, 236, 110, 16, p.verde)
        else
            ui.boton("tienda", "COMPRAR MÁS", 214, 236, 110, 16, p.verde)
        end
        ui.boton("armario", "ARMARIO", 332, 236, 94, 16, p.azul)
        if quedan > 0 then
            texto("ESPACIO: SIGUIENTE SOBRE", 262, 1, {1, 1, 1, parpadeo() * 0.7})
        end
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

-- mientras se abre no se puede salir de la pantalla
function apertura.bloqueada()
    return estado ~= "resumen"
end

return apertura
