-- Pruebas del juego: se copia el juego a una carpeta, main.lua pasa a llamarse
-- main_juego.lua y este archivo hace de main. Pulsa botones por su id, hace
-- capturas y comprueba la logica.
love.filesystem.load("main_juego.lua")()

local ui = require "src.ui"
local partida = require "src.partida"
local mercado = require "src.mercado"
local armario = require "src.armario"

local Z = {}
local zonaReal = ui.zona
function ui.zona(id, x, y, w, h)
    if not ui.sinZonas then Z[id] = { x = x, y = y, w = w, h = h } end
    return zonaReal(id, x, y, w, h)
end

local empezarReal = ui.empezar
function ui.empezar(...)
    for k in pairs(Z) do Z[k] = nil end
    return empezarReal(...)
end

local MX, MY = 0, 0
local abajo = false
function love.mouse.getPosition() return MX, MY end
function love.mouse.isDown() return abajo end

-- OLP_VENTANA=2400x1080 prueba una pantalla de movil alargada
local nav = require "src.nav"
local tam = os.getenv("OLP_VENTANA")
if tam then
    local vw, vh = tam:match("(%d+)x(%d+)")
    love.window.setMode(tonumber(vw), tonumber(vh), { resizable = true })
    love.resize()
end

local function aVentana(x, y)
    local w, h = love.graphics.getDimensions()
    local visto, ox = nav.vista()
    local e = math.min(w / visto, h / 360)
    return (x + ox) * e + math.floor((w - visto * e) / 2 + 0.5), y * e + math.floor((h - 360 * e) / 2 + 0.5)
end

local fallos, pasos = 0, 0
local function ok(cond, texto)
    pasos = pasos + 1
    if not cond then
        fallos = fallos + 1
        print("FALLO: " .. texto)
    else
        print("ok: " .. texto)
    end
end

local function esperar(n)
    for _ = 1, n or 1 do coroutine.yield() end
end

local function mover(x, y)
    MX, MY = aVentana(x, y)
    love.mousemoved(MX, MY, 0, 0)
end

local function pulsar(x, y)
    mover(x, y)
    esperar(1)
    abajo = true
    love.mousepressed(MX, MY, 1)
end

local function soltar()
    abajo = false
    love.mousereleased(MX, MY, 1)
end

local function clickEn(x, y)
    pulsar(x, y)
    soltar()
    esperar(2)
end

local function click(id)
    local z = Z[id]
    if not z then
        ok(false, "no existe el boton " .. id)
        return
    end
    clickEn(z.x + z.w / 2, z.y + z.h / 2)
end

local function foto(nombre)
    esperar(2)
    love.graphics.captureScreenshot("foto_" .. nombre .. ".png")
    esperar(1)
end

local function contarInv()
    local n, p1, f = 0, 0, 0
    for _, l in pairs(partida.inv) do
        for _, c in ipairs(l) do
            n = n + 1
            if c.p then p1 = p1 + 1 end
            if c.f then f = f + 1 end
        end
    end
    return n, p1, f
end

-- la mascota explicando cada pantalla para las pruebas viejas; GUIA=1 la deja
require("src.guia").apagada = os.getenv("GUIA") ~= "1"
local guion = require "guion"  -- guion.lua: los pasos de la prueba

local co = coroutine.create(function()
    guion({ ok = ok, esperar = esperar, click = click, clickEn = clickEn, pulsar = pulsar, soltar = soltar,
        mover = mover, foto = foto, Z = Z, contarInv = contarInv, partida = partida, mercado = mercado, armario = armario })
    print(string.format("RESULTADO: %d pasos, %d fallos", pasos, fallos))
    love.event.quit()
end)

local updateReal = love.update
function love.update(dt)
    updateReal(dt)
    if coroutine.status(co) ~= "dead" then
        local bien, err = coroutine.resume(co)
        if not bien then
            print("ERROR EN EL GUION: " .. tostring(err) .. "\n" .. debug.traceback(co))
            love.event.quit()
        end
    end
end
