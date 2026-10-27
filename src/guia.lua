-- Lo que ya se ha explicado (datos/guia.lua) y los puntos rojos de lo nuevo.
-- partida.guia: { visto = { clave = true } }, o { todo = true } en partidas
-- de antes de la v0.9.2 que ya lo tenian todo abierto
local partida = require "src.partida"
local desbloqueos = require "src.desbloqueos"
local datos = require "datos.guia"

local guia = {}

-- las pruebas viejas no la quieren (herramientas/harness.lua)
guia.apagada = false

local APPS = { "cartera", "mercado", "ventas", "noticias", "calendario", "encargos", "mejoras", "logros" }

local function estado()
    local g = partida.guia
    if type(g) ~= "table" then
        g = { visto = {} }
        partida.guia = g
    end
    g.visto = g.visto or {}
    return g
end

function guia.datos(clave)
    return datos[clave]
end

function guia.vista(clave)
    local g = estado()
    return guia.apagada or g.todo or g.visto[clave] == true
end

function guia.marcar(clave)
    estado().visto[clave] = true
    partida.guardar()
end

-- existe y ya se puede ver
function guia.disponible(clave)
    local d = datos[clave]
    return d ~= nil and (not d.requiere or desbloqueos.hay(d.requiere))
end

function guia.pendiente(clave)
    return guia.disponible(clave) and not guia.vista(clave)
end

-- punto rojo en el icono de una app: desbloqueada y sin abrir aun
function guia.puntoApp(appId)
    return desbloqueos.app(appId) and guia.pendiente("app_" .. appId)
end

-- punto rojo en los botones de la barra
function guia.punto(id)
    if id == "ir_movil" then
        for _, a in ipairs(APPS) do
            if guia.puntoApp(a) then return true end
        end
    elseif id == "ir_tienda" then
        return guia.pendiente("tienda_cajas")
    end
    return false
end

-- VER TUTORIAL: todo se vuelve a explicar
function guia.reiniciar()
    partida.guia = { visto = {} }
end

-- el punto rojo (centro en x, y)
function guia.dibujarPunto(x, y)
    local lg = love.graphics
    local p = require "datos.paleta"
    local a = 0.75 + math.sin(love.timer.getTime() * 6) * 0.25
    lg.setColor(p.negro)
    lg.circle("fill", x, y, 4)
    lg.setColor(p.rojo[1], p.rojo[2], p.rojo[3], a)
    lg.circle("fill", x, y, 3)
    lg.setColor(1, 1, 1)
end

return guia
