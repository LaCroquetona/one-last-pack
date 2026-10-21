-- Tutorial guiado de la primera partida. No bloquea nada: un panel con lo que
-- toca hacer, una flecha a donde hay que tocar y un boton para saltarlo.
-- Cada paso se da por hecho solo (hecho) o con el boton (boton).
-- partida.tutorial: numero del paso, o false si ya se acabo o se salto
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local directo = require "src.directo"
local apertura = require "src.apertura"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"
local ui = require "src.ui"

local lg = love.graphics

local tutorial = {}

local dia0 = 1

local PASOS = {
    { texto = "¡BIENVENIDO A ONE LAST PACK! ABRE SOBRES, COMPLETA LA COLECCIÓN Y SÁCATE UN DINERO VENDIENDO CARTAS Y HACIENDO DIRECTOS.",
      boton = "EMPEZAR" },
    { texto = "EMPIEZA UN DIRECTO: MIENTRAS ABRES, EL CHAT TE DA PROPINAS Y GANAS SEGUIDORES.",
      apunta = "dir_empezar", boton = "AHORA NO", hecho = function() return directo.activo() end },
    { texto = "ARRASTRA UN SOBRE DE LA CAJA AL TAPETE.",
      apunta = "caja_set", hecho = function() return apertura.activa() or partida.abiertos > 0 end },
    { texto = "MANTÉN PULSADO EL SOBRE PARA RASGARLO Y VE SACANDO LAS CARTAS.",
      hecho = function() return partida.abiertos > 0 and not apertura.bloqueada() end },
    { texto = "TOCA UNA CARTA DE LA MESA.",
      hecho = function() return ui.rect("mesa_vender") ~= nil end, boton = "SIGUIENTE" },
    { texto = "PUEDES ENFUNDARLA, VENDERLA AL MOMENTO O MANDARLA AL ARMARIO. LAS FUNDAS DE LA CAJA TAMBIÉN SE ARRASTRAN A UNA CARTA.",
      boton = "SIGUIENTE" },
    { texto = "EL DIRECTO LO PARAS CUANDO QUIERAS. SI SACAS EL MÓVIL O PASAS EL DÍA, SE CORTA.",
      boton = "SIGUIENTE", salta = function() return not directo.activo() end },
    { texto = "VE A LA TIENDA A POR MÁS SOBRES.",
      apunta = "ir_tienda", hecho = function(escena) return escena == "tienda" end },
    { texto = "AQUÍ COMPRAS SOBRES, CAJAS Y FUNDAS. CADA SET ESTÁ UN TIEMPO EN TIENDA Y LUEGO SE AGOTA. LA 1ª EDICIÓN VALE MÁS.",
      apunta = "comprar1", boton = "SIGUIENTE" },
    { texto = "EN EL ARMARIO ESTÁ TU COLECCIÓN.",
      apunta = "ir_armario", hecho = function(escena) return escena == "armario" end },
    { texto = "TUS CARTAS POR SETS: COPIAS, ÁLBUM Y LO QUE GUARDAS SIN ABRIR. DESDE AQUÍ TAMBIÉN SE VENDE.",
      boton = "SIGUIENTE" },
    { texto = "SACA EL MÓVIL.",
      apunta = "ir_movil", hecho = function(escena) return escena == "movil" end },
    { texto = "MERCADO: SOBRES Y CAJAS DE CADA SET. VENTAS: TUS ANUNCIOS. ENCARGOS: TE PAGAN POR ABRIR. MEJORAS: SUERTE, VENTA Y DIRECTO.",
      apunta = "m_app_mercado", boton = "SIGUIENTE" },
    { texto = "PASA EL DÍA: LLEGAN OFERTAS A TUS ANUNCIOS, NOTICIAS Y SOBRES A LA TIENDA, Y LOS PRECIOS SE MUEVEN.",
      apunta = "pasarDia", boton = "¡A JUGAR!", hecho = function() return mercado.dia() > dia0 end },
}

function tutorial.activo()
    return partida.tutorial and PASOS[partida.tutorial] ~= nil
end

local function terminar()
    partida.tutorial = false
    partida.guardar()
end

local function siguiente()
    partida.tutorial = partida.tutorial + 1
    dia0 = mercado.dia()
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

function tutorial.dibujar(escena)
    if not tutorial.activo() or ui.modal or ui.overlay then return end
    if escena ~= "mesa" and escena ~= "tienda" and escena ~= "armario" and escena ~= "movil" then return end
    revisar(escena)
    if not tutorial.activo() then return end
    t = t + love.timer.getDelta()
    local paso = PASOS[partida.tutorial]

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
    fuentes.texto("TUTORIAL " .. partida.tutorial .. "/" .. #PASOS, x + 8, y + 6, 1, p.amarillo)
    fuentes.texto(paso.texto, x + 8, y + 17, 1, p.blanco, "left", w - 16)
    local by = y + h - 17
    ui.boton("tut_saltar", "SALTAR TUTORIAL", x + 8, by, 74, 12, p.grisosc)
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
    end
end

-- volver a verlo desde el menu
function tutorial.repetir()
    partida.tutorial = 1
    dia0 = mercado.dia()
end

return tutorial
