-- Opciones del juego (volumen de la musica y de los efectos). Se guardan
-- aparte de la partida: son del ordenador o del movil, no de la partida.
local p = require "datos.paleta"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"

local lg = love.graphics

local opciones = {}

local ARCHIVO = "opciones.txt"
local PASOS = 10

-- niveles de 0 a PASOS
opciones.musica = 6
opciones.efectos = 10

local function aplicar()
    sonido.vol.musica = opciones.musica / PASOS
    sonido.vol.efectos = opciones.efectos / PASOS
end

function opciones.cargar()
    local texto = love.filesystem.read(ARCHIVO)
    if texto then
        for clave, valor in texto:gmatch("(%a+)=(%d+)") do
            if clave == "musica" or clave == "efectos" then
                opciones[clave] = math.max(0, math.min(PASOS, tonumber(valor)))
            end
        end
    end
    aplicar()
end

local function guardar()
    love.filesystem.write(ARCHIVO, "musica=" .. opciones.musica .. "\nefectos=" .. opciones.efectos .. "\n")
end

-- una fila: nombre, menos, la barra de niveles y mas
local function fila(clave, nombre, x, y)
    fuentes.texto(nombre, x, y + 4, 1, p.blanco)
    local n = opciones[clave]
    ui.boton("opc_" .. clave .. "_menos", "-", x + 60, y, 16, 14, p.gris, n > 0)
    for i = 1, PASOS do
        lg.setColor(i <= n and p.lima or p.grisosc)
        lg.rectangle("fill", x + 80 + (i - 1) * 9, y + 2, 7, 10)
    end
    ui.boton("opc_" .. clave .. "_mas", "+", x + 172, y, 16, 14, p.gris, n < PASOS)
    fuentes.texto(n == 0 and "NO" or (n * 10 .. "%"), x + 192, y + 4, 1, p.grisclaro)
end

local function dibujar(ancho, alto)
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", -ancho, -alto, ancho * 3, alto * 3)
    local w, h = 260, 98
    local x, y = 320 - w / 2, 180 - h / 2
    ui.caja(x, y, w, h)
    fuentes.texto("OPCIONES", x, y + 8, 2, p.amarillo, "center", w)
    fila("musica", "MÚSICA", x + 16, y + 30)
    fila("efectos", "EFECTOS", x + 16, y + 50)
    ui.boton("opc_vale", "VALE", x + w / 2 - 30, y + h - 22, 60, 14, p.verde)
end

local function click(id)
    local clave, que = id:match("^opc_(%a+)_(%a+)$")
    if clave == "musica" or clave == "efectos" then
        opciones[clave] = math.max(0, math.min(PASOS, opciones[clave] + (que == "mas" and 1 or -1)))
        aplicar()
        guardar()
        if clave == "efectos" then sonido.tocar("moneda") end
    elseif id == "opc_vale" then
        ui.overlay = nil
    end
end

function opciones.abrir()
    ui.overlay = { dibujar = dibujar, click = click }
end

return opciones
