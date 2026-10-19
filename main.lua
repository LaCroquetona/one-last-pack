local fuentes = require "src.fuentes"
local carta = require "src.carta"
local sonido = require "src.sonido"
local fx = require "src.fx"
local partida = require "src.partida"
local apertura = require "src.apertura"
local album = require "src.album"
local cartas = require "datos.cartas"

local lg = love.graphics

local ANCHO, ALTO = 640, 360
local pantalla
local escena = "apertura"
local tiempoFondo = 0

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

function love.load()
    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("rough")
    pantalla = lg.newCanvas(ANCHO, ALTO)
    fuentes.preparar()
    carta.preparar()
    sonido.preparar()
    apertura.preparar()
    partida.cargar()
    apertura.empezar()
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    fx.update(dt)
    local dtJuego = dt * fx.escalaTiempo()
    tiempoFondo = tiempoFondo + dtJuego
    if escena == "apertura" then
        local mantenido = love.mouse.isDown(1) or love.keyboard.isDown("space")
        apertura.update(dtJuego, mantenido)
    end
end

function love.mousepressed(_, _, boton)
    if boton == 1 and escena == "apertura" then apertura.pulsar() end
end

function love.keypressed(tecla)
    if tecla == "space" and escena == "apertura" then
        apertura.pulsar()
    elseif tecla == "tab" or tecla == "a" then
        escena = escena == "apertura" and "album" or "apertura"
        sonido.carga(0)
    elseif tecla == "escape" then
        love.event.quit()
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

local function dibujarHud()
    lg.setFont(fuentes.normal)
    lg.setColor(1, 1, 1, 0.8)
    lg.print("Sobres: " .. partida.sobres .. "   Colección: " .. partida.distintas() .. "/" .. #cartas, 10, 340)
    local ayuda = escena == "apertura" and "[TAB] Álbum" or "[TAB] Volver"
    lg.printf(ayuda, 0, 340, ANCHO - 10, "right")
    lg.setColor(1, 1, 1)
end

function love.draw()
    lg.setCanvas(pantalla)
    lg.clear(fx.fondo[1], fx.fondo[2], fx.fondo[3], 1)
    dibujarFondo()

    local dx, dy = fx.desplazamiento()
    lg.push()
    lg.translate(dx, dy)
    if escena == "apertura" then
        apertura.dibujar()
    else
        album.dibujar(raton())
    end
    fx.dibujarParticulas()
    lg.pop()

    dibujarHud()
    fx.dibujarDestello(ANCHO, ALTO)
    lg.setCanvas()

    lg.clear(0, 0, 0)
    local e, ox, oy = escalaVentana()
    lg.draw(pantalla, ox, oy, 0, e, e)
end
