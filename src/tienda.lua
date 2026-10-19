local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local partida = require "src.partida"
local sobre = require "src.sobre"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local tienda = {}

local tipo = sobres.lista[1]

local PANEL_X, PANEL_Y, PANEL_W = 300, 30, 318

local function porcentaje(peso, total)
    local v = math.floor(peso / total * 1000 + 0.5) / 10
    if v == math.floor(v) then return string.format("%d%%", v) end
    return string.format("%.1f%%", v)
end

-- probabilidades de un hueco en trozos de color, partidos en lineas si no caben
local function lineaPesos(pesos, x, y, limite)
    local total = 0
    for _, peso in pairs(pesos) do total = total + peso end
    local cx = x
    for _, r in ipairs(rarezas.lista) do
        local peso = pesos[r.id]
        if peso then
            local txt = r.nombre .. " " .. porcentaje(peso, total)
            local w = fuentes.ancho(txt)
            if cx + w > limite then
                cx = x
                y = y + 8
            end
            fuentes.texto(txt, cx, y, 1, r.color)
            cx = cx + w + 8
        end
    end
    return y
end

local function sinSalida()
    local repes = partida.repetidas()
    return partida.dinero < tipo.precio and partida.sobresGuardados() == 0 and repes == 0
end

function tienda.dibujar()
    local hora = love.timer.getTime()
    local sx, sy = 160, 170 + math.sin(hora * 2) * 3
    local h = ui.hoverCarta("escaparate", sx, sy, sobre.ANCHO * 4, sobre.ALTO * 4)
    fx.aura(sx, sy, p.rojo, 110, 0.25)
    sobre.dibujar(sx, sy, 4, math.sin(hora * 1.3) * 0.03, h and h.kx or 0, h and h.ky or 0)
    ui.zona("escaparate", sx - 60, sy - 88, 120, 176)

    local guardados = partida.sobresGuardados()
    local frase = guardados == 1 and "TIENES 1 SOBRE SIN ABRIR" or ("TIENES " .. guardados .. " SOBRES SIN ABRIR")
    fuentes.texto(frase, sx - 100, 274, 1, p.grisclaro, "center", 200)

    ui.caja(PANEL_X, PANEL_Y, PANEL_W, 236)
    fuentes.texto(tipo.nombre, PANEL_X + 10, PANEL_Y + 10, 2, p.blanco)
    fuentes.texto(ui.dinero(tipo.precio), PANEL_X, PANEL_Y + 10, 2, p.amarillo, "right", PANEL_W - 10)

    local cartasPorSobre = 0
    for _, hueco in ipairs(tipo.huecos) do cartasPorSobre = cartasPorSobre + hueco.cantidad end
    fuentes.texto(cartasPorSobre .. " CARTAS POR SOBRE", PANEL_X + 10, PANEL_Y + 30, 1, p.grisclaro)

    local y = PANEL_Y + 46
    for _, hueco in ipairs(tipo.huecos) do
        fuentes.texto(hueco.cantidad .. " x " .. hueco.nombre, PANEL_X + 10, y, 1, p.blanco)
        y = lineaPesos(hueco.rarezas, PANEL_X + 18, y + 9, PANEL_X + PANEL_W - 10) + 14
    end

    y = y + 4
    fuentes.texto("GOD PACK: 1 DE CADA " .. math.floor(1 / tipo.godpack + 0.5) .. ", TODO EL SOBRE", PANEL_X + 10, y, 1, p.amarillo)
    fuentes.texto("CON PROBABILIDADES DE RARA O MEJOR", PANEL_X + 10, y + 8, 1, p.amarillo)
    fuentes.texto("PIEDAD: " .. tipo.piedad .. " SOBRES SIN HOLO Y EL SIGUIENTE", PANEL_X + 10, y + 22, 1, p.violeta)
    fuentes.texto("TRAE HOLO O MEJOR SEGURO", PANEL_X + 10, y + 30, 1, p.violeta)

    local by = PANEL_Y + 246
    ui.boton("comprar1", "COMPRAR " .. ui.dinero(tipo.precio), PANEL_X, by, 100, 16, p.verde, partida.dinero >= tipo.precio)
    ui.boton("comprar5", "5 POR " .. ui.dinero(tipo.precio * 5), PANEL_X + 108, by, 100, 16, p.verde, partida.dinero >= tipo.precio * 5)
    ui.boton("abrir", "ABRIR (" .. guardados .. ")", PANEL_X + 216, by, PANEL_W - 216, 16, p.azul, guardados > 0)

    if sinSalida() then
        ui.boton("rescate", "SOBRE DE RESCATE GRATIS", PANEL_X, by + 24, 208, 16, p.naranja)
    elseif partida.dinero < tipo.precio and guardados == 0 then
        fuentes.texto("SIN DINERO: VENDE REPES EN EL ARMARIO", PANEL_X, by + 28, 1, p.naranja)
    end
end

local function comprar(cantidad, boton)
    if not partida.comprar(tipo.id, cantidad) then return end
    sonido.tocar("moneda")
    local x = boton == "comprar1" and PANEL_X + 50 or PANEL_X + 158
    fx.texto(x, PANEL_Y + 236, "-" .. ui.dinero(tipo.precio * cantidad), p.rojo)
    fx.explosion(160, 170, p.amarillo, 20 * cantidad, 120)
    fx.sacudir(2)
    partida.guardar()
end

function tienda.click(id)
    if id == "comprar1" then
        comprar(1, id)
    elseif id == "comprar5" then
        comprar(5, id)
    elseif id == "abrir" then
        nav.abrir()
    elseif id == "rescate" then
        partida.regalar(tipo.id)
        partida.guardar()
        sonido.tocar("nueva")
    elseif id == "escaparate" then
        fx.explosion(ui.mx, ui.my, p.amarillo, 6, 60)
    end
end

return tienda
