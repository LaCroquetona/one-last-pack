local cartas = require "datos.cartas"
local firma = require "datos.firma"
local p = require "datos.paleta"
local partida = require "src.partida"
local sobres = require "datos.sobres"
local carta = require "src.carta"
local fx = require "src.fx"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local menu = {}

local VERSION = "v0.6.0"
local abanico = {}

function menu.preparar()
    -- cinco cartas al azar en abanico detras del titulo, siempre con una secreta en medio
    abanico = {}
    local usadas = {}
    for i = 1, 5 do
        local def
        if i == 3 then
            def = cartas[#cartas]
        else
            repeat def = cartas[love.math.random(#cartas - 1)] until not usadas[def.id]
        end
        usadas[def.id] = true
        abanico[i] = def
    end
end

function menu.dibujar()
    local hora = love.timer.getTime()
    fx.aura(320, 150, p.amarillo, 150, 0.15)
    for i, def in ipairs(abanico) do
        local a = (i - 3) * 0.28 + math.sin(hora * 0.8 + i) * 0.02
        local x = 320 + (i - 3) * 50
        local y = 150 + math.abs(i - 3) * 12 + math.sin(hora * 1.5 + i) * 3
        carta.dibujar(def, x, y, 2, 2, a, true, { kx = 0, ky = 0, brillo = i == 3 and 1 or 0.3, lx = math.sin(hora), ly = 0 })
    end

    local titulo = "ONE LAST PACK"
    fuentes.texto(titulo, 3, 43, 6, p.negro, "center", 640)
    fuentes.texto(titulo, 0, 40, 6, p.amarillo, "center", 640)

    local hay = partida.existe()
    local y = 236
    if hay then
        ui.boton("continuar", "CONTINUAR", 250, y, 140, 20, p.verde)
        y = y + 26
    end
    ui.boton("nueva", "PARTIDA NUEVA", 250, y, 140, 20, hay and p.azul or p.verde)
    local completa = nav.pantallaCompleta()
    ui.boton("pantalla", completa and "VENTANA" or "PANTALLA COMPLETA", 250, y + 26, 140, 20, p.gris)
    ui.boton("salir", "SALIR", 250, y + 52, 140, 20, p.gris)
    fuentes.texto("F11 O ALT+ENTER: PANTALLA COMPLETA", 0, 348, 1, p.grisosc, "center", 640)

    fuentes.texto(firma.nombre, 8, 348, 1, p.gris)
    fuentes.texto(VERSION, 0, 348, 1, p.gris, "right", 632)
end

function menu.click(id)
    if id == "continuar" then
        partida.cargar()
        nav.empezar()
    elseif id == "nueva" then
        if partida.existe() then
            ui.confirmar("¿BORRAR TU PARTIDA?", {
                "EMPEZARÁS DE CERO CON " .. ui.dinero(sobres.inicio.dinero),
                "PERDERÁS TODAS TUS CARTAS, SOBRES Y DINERO",
            }, "SÍ, EMPEZAR DE CERO", function()
                partida.borrar()
                nav.empezar()
            end)
        else
            partida.borrar()
            nav.empezar()
        end
    elseif id == "pantalla" then
        nav.alternarPantalla()
    elseif id == "salir" then
        love.event.quit()
    end
end

return menu
