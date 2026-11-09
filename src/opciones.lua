-- Opciones del juego (volumen de la musica y de los efectos, y el chat de
-- Twitch). Se guardan aparte de la partida: son del ordenador o del movil.
local p = require "datos.paleta"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local twitch = require "src.twitch"
local utf8 = require "utf8"

local lg = love.graphics

local opciones = {}

local ARCHIVO = "opciones.txt"
local PASOS = 10

-- niveles de 0 a PASOS
opciones.musica = 6
opciones.efectos = 10
-- Twitch: el canal, si se conecta al abrir el juego y si el chat del juego
-- se calla (solo = true) o se mezcla con el de verdad
opciones.twitch = ""
opciones.conectar = false
opciones.solo = false
-- tutorial: con false no hay intro, ni explicaciones, ni avisos de la mascota
-- (lo que se desbloquea llega como aviso pequeño)
opciones.tutorial = true

local alVerTutorial -- lo que hace VER TUTORIAL (lo pasa quien abre las opciones)
local editando -- canal de Twitch mientras se escribe
local MAX_CANAL = 25

local function aplicar()
    sonido.vol.musica = opciones.musica / PASOS
    sonido.vol.efectos = opciones.efectos / PASOS
end

function opciones.cargar()
    local texto = love.filesystem.read(ARCHIVO)
    if texto then
        for clave, valor in texto:gmatch("(%a+)=([%w_]*)") do
            if clave == "musica" or clave == "efectos" then
                opciones[clave] = math.max(0, math.min(PASOS, tonumber(valor) or opciones[clave]))
            elseif clave == "twitch" then
                opciones.twitch = valor:lower()
            elseif clave == "conectar" or clave == "solo" or clave == "tutorial" then
                opciones[clave] = valor == "1"
            end
        end
    end
    aplicar()
    if opciones.conectar and opciones.twitch ~= "" then twitch.conectar(opciones.twitch) end
end

local function guardar()
    love.filesystem.write(ARCHIVO, "musica=" .. opciones.musica .. "\nefectos=" .. opciones.efectos ..
        "\ntwitch=" .. opciones.twitch .. "\nconectar=" .. (opciones.conectar and 1 or 0) .. "\nsolo=" .. (opciones.solo and 1 or 0) ..
        "\ntutorial=" .. (opciones.tutorial and 1 or 0) .. "\n")
end

-- si el chat del juego se calla porque solo se quiere el de Twitch
function opciones.soloTwitch()
    return opciones.solo and twitch.estado ~= "apagado"
end

local ESTADOS = { apagado = { "SIN CONECTAR", p.gris }, conectando = { "CONECTANDO...", p.naranja },
    conectado = { "CONECTADO", p.lima }, error = { "NO SE PUEDE CONECTAR", p.rojo } }

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
    local w, h = 260, 222
    local x, y = 320 - w / 2, 180 - h / 2
    ui.caja(x, y, w, h)
    fuentes.texto("OPCIONES", x, y + 8, 2, p.amarillo, "center", w)
    fila("musica", "MÚSICA", x + 16, y + 30)
    fila("efectos", "EFECTOS", x + 16, y + 50)

    -- chat de Twitch
    local ty = y + 74
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 10, ty - 4, w - 20, 1)
    fuentes.texto("CHAT DE TWITCH", x + 16, ty, 1, p.violeta)
    local est = ESTADOS[twitch.estado] or ESTADOS.apagado
    fuentes.texto(est[1], x + 16, ty, 1, est[2], "right", w - 32)
    local nombre = editando or opciones.twitch
    local cursor = editando and math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""
    ui.caja(x + 16, ty + 10, 150, 14, editando and p.azulosc or p.grisosc)
    if nombre == "" and not editando then
        fuentes.texto("TOCA Y ESCRIBE TU CANAL", x + 20, ty + 15, 1, p.gris)
    else
        fuentes.texto(nombre:upper() .. cursor, x + 20, ty + 15, 1, editando and p.cian or p.blanco)
    end
    ui.zona("opc_canal", x + 16, ty + 10, 150, 14)
    if editando then
        ui.boton("opc_canalok", "OK", x + 170, ty + 10, 74, 14, p.verde)
    elseif twitch.estado == "apagado" or twitch.estado == "error" then
        ui.boton("opc_conectar", "CONECTAR", x + 170, ty + 10, 74, 14, p.morado, opciones.twitch ~= "")
    else
        ui.boton("opc_desconectar", "DESCONECTAR", x + 170, ty + 10, 74, 14, p.rojo)
    end
    fuentes.texto("CHAT DEL JUEGO", x + 16, ty + 32, 1, p.grisclaro)
    ui.boton("opc_mezcla", "MEZCLADO", x + 100, ty + 29, 70, 12, not opciones.solo and p.azul or p.grisosc)
    ui.boton("opc_solo", "SOLO TWITCH", x + 174, ty + 29, 70, 12, opciones.solo and p.azul or p.grisosc)
    fuentes.texto("SOLO SE LEE TU CHAT: SIN INICIAR SESIÓN", x + 16, ty + 48, 1, p.gris)

    -- tutorial y pantalla
    local uy = ty + 60
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 10, uy - 4, w - 20, 1)
    fuentes.texto("TUTORIAL", x + 16, uy + 3, 1, p.grisclaro)
    ui.boton("opc_tutsi", "SÍ", x + 100, uy, 70, 12, opciones.tutorial and p.azul or p.grisosc)
    ui.boton("opc_tutno", "NO", x + 174, uy, 70, 12, not opciones.tutorial and p.azul or p.grisosc)
    fuentes.texto(opciones.tutorial and "LA MASCOTA TE EXPLICA LO NUEVO" or "SIN EXPLICACIONES, SOLO AVISOS", x + 16, uy + 16, 1, p.gris)
    ui.boton("opc_vertut", "VER TUTORIAL", x + 16, uy + 27, 110, 14, p.morado, alVerTutorial ~= nil)
    local completa = require("src.nav").pantallaCompleta()
    ui.boton("opc_pantalla", completa and "VENTANA" or "PANTALLA COMPLETA", x + 134, uy + 27, 110, 14, p.gris)
    ui.boton("opc_vale", "VALE", x + w / 2 - 30, y + h - 22, 60, 14, p.verde)
end

local function acabarCanal()
    if not editando then return end
    opciones.twitch = editando:lower()
    editando = nil
    love.keyboard.setTextInput(false)
    guardar()
end

function opciones.texto(t)
    if not editando then return false end
    for _, cp in utf8.codes(t) do
        local c = utf8.char(cp)
        if #editando < MAX_CANAL and c:match("^[%w_]$") then editando = editando .. c:lower() end
    end
    return true
end

function opciones.tecla(tecla)
    if not editando then return false end
    if tecla == "backspace" then
        editando = editando:sub(1, -2)
    elseif tecla == "return" or tecla == "kpenter" or tecla == "escape" then
        acabarCanal()
    end
    return true
end

local function click(id)
    local clave, que = id:match("^opc_(%a+)_(%a+)$")
    if clave == "musica" or clave == "efectos" then
        opciones[clave] = math.max(0, math.min(PASOS, opciones[clave] + (que == "mas" and 1 or -1)))
        aplicar()
        guardar()
        if clave == "efectos" then sonido.tocar("moneda") end
    elseif id == "opc_canal" then
        if not editando then
            editando = opciones.twitch
            love.keyboard.setTextInput(true)
        end
    elseif id == "opc_canalok" then
        acabarCanal()
    elseif id == "opc_conectar" then
        acabarCanal()
        opciones.conectar = twitch.conectar(opciones.twitch)
        guardar()
    elseif id == "opc_desconectar" then
        twitch.desconectar()
        opciones.conectar = false
        guardar()
    elseif id == "opc_mezcla" or id == "opc_solo" then
        opciones.solo = id == "opc_solo"
        guardar()
    elseif id == "opc_tutsi" or id == "opc_tutno" then
        opciones.tutorial = id == "opc_tutsi"
        guardar()
        -- apagarlo a mitad de la intro la quita
        local partida = require "src.partida"
        if not opciones.tutorial and partida.tutorial then
            partida.tutorial = false
            partida.guardar()
        end
    elseif id == "opc_vertut" then
        acabarCanal()
        ui.overlay = nil
        opciones.tutorial = true
        guardar()
        if alVerTutorial then alVerTutorial() end
    elseif id == "opc_pantalla" then
        require("src.nav").alternarPantalla()
    elseif id == "opc_vale" then
        acabarCanal()
        ui.overlay = nil
    end
end

-- verTutorial (opcional): lo que hace el boton VER TUTORIAL
function opciones.abrir(verTutorial)
    alVerTutorial = verTutorial
    ui.overlay = { dibujar = dibujar, click = click }
end

return opciones
