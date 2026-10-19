local p = require "datos.paleta"
local cartas = require "datos.cartas"
local fuentes = require "src.fuentes"
local carta = require "src.carta"
local sobre = require "src.sobre"
local sonido = require "src.sonido"
local fx = require "src.fx"
local ui = require "src.ui"
local nav = require "src.nav"
local partida = require "src.partida"
local apertura = require "src.apertura"
local tienda = require "src.tienda"
local armario = require "src.armario"

local lg = love.graphics

local ANCHO, ALTO = 640, 360
local pantalla
local escena = "armario"
local escenas = { tienda = tienda, armario = armario }
local tiempoFondo = 0
local dineroVisto = 0

-- escalado entero para que el pixel art no se deforme
local function escalaVentana()
    local w, h = lg.getDimensions()
    local e = math.max(1, math.floor(math.min(w / ANCHO, h / ALTO)))
    return e, math.floor((w - ANCHO * e) / 2), math.floor((h - ALTO * e) / 2)
end

local function raton()
    local e, ox, oy = escalaVentana()
    local mx, my = love.mouse.getPosition()
    return (mx - ox) / e, (my - oy) / e
end

local function bloqueado()
    return escena == "apertura" and apertura.bloqueada()
end

function nav.ir(nombre)
    sonido.carga(0)
    escena = nombre
end

function nav.abrir()
    local tipo = partida.sacarSobre()
    if not tipo then return end
    partida.guardar()
    apertura.empezar(tipo)
    escena = "apertura"
end

function love.load()
    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("rough")
    pantalla = lg.newCanvas(ANCHO, ALTO)
    fuentes.preparar()
    carta.preparar()
    sobre.preparar()
    sonido.preparar()
    partida.cargar()
    dineroVisto = partida.dinero
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    fx.update(dt)
    dineroVisto = fx.lerp(dineroVisto, partida.dinero, math.min(1, dt * 8))
    local dtJuego = dt * fx.escalaTiempo()
    tiempoFondo = tiempoFondo + dtJuego
    if escena == "apertura" then
        local mantenido = love.mouse.isDown(1) or love.keyboard.isDown("space")
        apertura.update(dtJuego, mantenido)
    end
end

function love.mousepressed(x, y, boton)
    if boton ~= 1 then return end
    local e, ox, oy = escalaVentana()
    local id = ui.click((x - ox) / e, (y - oy) / e)
    if id then sonido.tocar("click") end

    if id == "ir_tienda" then
        nav.ir("tienda")
    elseif id == "ir_armario" then
        nav.ir("armario")
    elseif escena == "apertura" then
        if id then apertura.boton(id) else apertura.pulsar() end
    elseif id then
        escenas[escena].click(id)
    end
end

function love.keypressed(tecla)
    if tecla == "escape" then
        love.event.quit()
    elseif tecla == "space" then
        if escena == "apertura" then apertura.pulsar() else nav.abrir() end
    elseif tecla == "tab" and not bloqueado() then
        nav.ir(escena == "tienda" and "armario" or "tienda")
    elseif escena == "armario" then
        armario.tecla(tecla)
    end
end

function love.quit()
    partida.guardar()
end

local function dibujarFondo()
    local d = (tiempoFondo * 8) % 20
    lg.setColor(1, 1, 1, 0.05)
    for y = -20, ALTO, 20 do
        for x = -20, ANCHO, 20 do
            lg.rectangle("fill", x + d, y + d, 2, 2)
        end
    end
    lg.setColor(1, 1, 1)
end

local function dibujarBarra()
    lg.setColor(p.negro)
    lg.rectangle("fill", 0, 0, ANCHO, 20)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", 0, 20, ANCHO, 1)

    if not bloqueado() then
        ui.boton("ir_tienda", "TIENDA", 6, 3, 56, 14, escena == "tienda" and p.verde or p.gris)
        ui.boton("ir_armario", "ARMARIO", 66, 3, 56, 14, escena == "armario" and p.verde or p.gris)
    end

    local dinero = ui.dinero(dineroVisto)
    local x = ANCHO - 8 - fuentes.ancho(dinero, 2)
    fuentes.texto(dinero, x, 4, 2, p.amarillo)
    local info = "SOBRES " .. partida.sobresGuardados() .. "    COLECCIÓN " .. partida.distintas() .. "/" .. #cartas
    fuentes.texto(info, x - 16 - fuentes.ancho(info), 8, 1, p.grisclaro)
end

function love.draw()
    ui.empezar(raton())

    lg.setCanvas(pantalla)
    lg.clear(fx.fondo[1], fx.fondo[2], fx.fondo[3], 1)
    dibujarFondo()

    local dx, dy = fx.desplazamiento()
    lg.push()
    lg.translate(dx, dy)
    if escena == "apertura" then
        apertura.dibujar()
    else
        escenas[escena].dibujar()
    end
    fx.dibujarParticulas()
    lg.pop()

    dibujarBarra()
    ui.dibujarTooltip(ANCHO, ALTO)
    fx.dibujarDestello(ANCHO, ALTO)
    lg.setCanvas()

    lg.clear(0, 0, 0)
    local e, ox, oy = escalaVentana()
    lg.draw(pantalla, ox, oy, 0, e, e)
end
