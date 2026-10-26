-- Tutorial guiado de la primera partida. No bloquea nada: un panel con lo que
-- toca hacer, una flecha a donde hay que tocar y un boton para saltarlo.
-- Cada paso se da por hecho solo (hecho) o con el boton (boton).
-- partida.tutorial: numero del paso, o false si ya se acabo o se salto
local p = require "datos.paleta"
local partida = require "src.partida"
local directo = require "src.directo"
local apertura = require "src.apertura"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"
local ui = require "src.ui"
local desbloqueos = require "src.desbloqueos"

local lg = love.graphics

local tutorial = {}


-- la intro es corta: lo demas se explica al desbloquearse (src/desbloqueos.lua)
local PASOS = {
    { texto = "¡BIENVENIDO A ONE LAST PACK! ABRE SOBRES, HAZ DIRECTOS Y SÁCATE UN DINERO. LO DEMÁS SE IRÁ DESBLOQUEANDO SOBRE LA MARCHA.",
      boton = "EMPEZAR" },
    { texto = "EMPIEZA UN DIRECTO: MIENTRAS ABRES, EL CHAT TE DA PROPINAS Y GANAS SEGUIDORES.",
      apunta = "dir_empezar", boton = "AHORA NO", hecho = function() return directo.activo() end },
    { texto = "ARRASTRA UN SOBRE DE LA CAJA AL TAPETE Y MANTÉN PULSADO PARA ABRIRLO.",
      apunta = "caja_set1", hecho = function() return partida.abiertos > 0 and not apertura.bloqueada() end },
}

function tutorial.activo()
    return partida.tutorial and PASOS[partida.tutorial] ~= nil
end

local function terminar()
    partida.tutorial = false
    desbloqueos.vale(require("datos.desbloqueos").esperaTutorial)
    partida.guardar()
end

local function siguiente()
    partida.tutorial = partida.tutorial + 1
    if not PASOS[partida.tutorial] then
        terminar()
        sonido.tocar("nueva")
    else
        sonido.tocar("encima", 1.4)
    end
    partida.guardar()
end

-- se mira despues de pintar (algunos pasos miran los botones que hay)
local function revisar(escena)
    local paso = PASOS[partida.tutorial]
    if paso.salta and paso.salta(escena) then
        siguiente()
    elseif paso.hecho and paso.hecho(escena) then
        siguiente()
    end
end

local t = 0

-- el aviso de desbloqueo que toca (cuando no hay intro ni se esta abriendo)
local function avisoActual()
    if tutorial.activo() then return nil end
    return desbloqueos.siguiente()
end

function tutorial.dibujar(escena)
    if ui.modal or ui.overlay then return end
    if escena ~= "mesa" and escena ~= "tienda" and escena ~= "armario" and escena ~= "movil" then return end
    if tutorial.activo() then revisar(escena) end
    local paso = tutorial.activo() and PASOS[partida.tutorial] or avisoActual()
    if not paso then return end
    local esAviso = not tutorial.activo()
    t = t + love.timer.getDelta()

    -- marco y flecha sobre lo que hay que tocar
    local z = paso.apunta and ui.rect(paso.apunta)
    if z then
        local a = 0.6 + math.sin(t * 6) * 0.4
        lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], a)
        lg.setLineWidth(2)
        lg.rectangle("line", z.x - 3, z.y - 3, z.w + 6, z.h + 6, 3, 3)
        lg.setLineWidth(1)
        local cx = z.x + z.w / 2
        local bote = math.abs(math.sin(t * 5)) * 5
        lg.setColor(p.amarillo)
        if z.y > 60 then
            local y = z.y - 8 - bote
            lg.polygon("fill", cx - 7, y - 9, cx + 7, y - 9, cx, y)
        else
            local y = z.y + z.h + 8 + bote
            lg.polygon("fill", cx - 7, y + 9, cx + 7, y + 9, cx, y)
        end
    end

    -- el panel: en el movil a la derecha; si no, arriba o abajo, lejos de la flecha
    local w = escena == "movil" and 196 or 270
    local _, lineas = fuentes.envolver(paso.texto, w - 16)
    local h = 26 + #lineas * fuentes.linea() + 18
    local x, y
    if escena == "movil" then
        x, y = 436, 40
    else
        x = 320 - w / 2
        y = (z and z.y + z.h / 2 > 200) and 26 or 360 - h - 6
    end
    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", x + 3, y + 4, w, h, 4, 4)
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2, 5, 5)
    lg.setColor(p.azulosc)
    lg.rectangle("fill", x, y, w, h, 4, 4)
    lg.setColor(p.amarillo)
    lg.rectangle("fill", x, y, 3, h, 2, 2)
    fuentes.texto(esAviso and "¡NUEVO!" or ("TUTORIAL " .. partida.tutorial .. "/" .. #PASOS), x + 8, y + 6, 1, p.amarillo)
    fuentes.parrafo(paso.texto, x + 8, y + 17, p.blanco, w - 16)
    local by = y + h - 17
    if esAviso then
        ui.boton("tut_vale", "VALE", x + w - 68, by, 60, 12, p.verde)
        return
    end
    -- en el ultimo paso ya no se salta nada: se termina
    local ultimo = partida.tutorial == #PASOS
    local texto = ultimo and "TERMINAR TUTORIAL" or "SALTAR TUTORIAL"
    ui.boton("tut_saltar", texto, x + 8, by, math.max(74, fuentes.ancho(texto) + 10), 12, ultimo and p.verde or p.grisosc)
    if paso.boton then
        local bw = math.max(60, fuentes.ancho(paso.boton) + 12)
        ui.boton("tut_sig", paso.boton, x + w - bw - 8, by, bw, 12, p.verde)
    end
end

function tutorial.click(id)
    if id == "tut_saltar" then
        terminar()
    elseif id == "tut_sig" then
        siguiente()
    elseif id == "tut_vale" then
        desbloqueos.vale()
        sonido.tocar("encima", 1.4)
    end
end

-- volver a verlo desde el menu
function tutorial.repetir()
    partida.tutorial = 1
end

return tutorial
