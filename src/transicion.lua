-- Paso del dia: fundido a negro, se ve el dia que acaba y el que empieza
-- (con el sol que se pone y la luna) y vuelve la imagen. Mientras dura no se
-- puede tocar nada. Se dibuja encima de todo, a la resolucion de la ventana.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local partida = require "src.partida"
local mercado = require "src.mercado"
local ui = require "src.ui"

local lg = love.graphics

local transicion = {}

local SALE, MUESTRA, ENTRA = 0.45, 1.9, 0.5
local estado, t = nil, 0
local accion
local diaAntes, resumen
-- lo que habia al empezar el dia, para el resumen
local dineroDia, abiertosDia

function transicion.empezarDia()
    dineroDia, abiertosDia = partida.dinero, partida.abiertos or 0
end

function transicion.activa()
    return estado ~= nil
end

-- f se llama con la pantalla ya en negro
function transicion.pasarDia(f)
    if estado then return end
    if not dineroDia then transicion.empezarDia() end
    estado, t, accion = "sale", 0, f
    diaAntes = mercado.dia()
    resumen = { dinero = partida.dinero - dineroDia, sobres = (partida.abiertos or 0) - abiertosDia }
end

-- tocar durante el negro lo acorta
function transicion.saltar()
    if estado == "muestra" and t > 0.5 then t = MUESTRA end
end

function transicion.update(dt)
    if not estado then return end
    t = t + dt
    if estado == "sale" and t >= SALE then
        estado, t = "muestra", 0
        if accion then accion() end
        accion = nil
        transicion.empezarDia()
    elseif estado == "muestra" and t >= MUESTRA then
        estado, t = "entra", 0
    elseif estado == "entra" and t >= ENTRA then
        estado = nil
    end
end

-- sol que baja y luna que sube por un arco
local function astro(cx, cy, r, color, ang, radio)
    local x = cx + math.cos(ang) * radio
    local y = cy - math.sin(ang) * radio
    lg.setColor(color)
    lg.circle("fill", x, y, r)
end

-- e, ox, oy: escala y origen del juego en la ventana; ancho: lo que se ve; OX: lo que sobra a cada lado
function transicion.dibujar(e, ox, oy, ancho, OX)
    if not estado then return end
    local a = 1
    if estado == "sale" then a = t / SALE end
    if estado == "entra" then a = 1 - t / ENTRA end
    local w, h = lg.getDimensions()
    lg.setColor(0, 0, 0, a)
    lg.rectangle("fill", 0, 0, w, h)
    if estado ~= "muestra" then return end

    lg.push("all")
    lg.origin()
    lg.translate(ox + OX * e, oy)
    lg.scale(e, e)
    local cx = ancho / 2 - OX
    local q = math.min(1, t / 1.1)
    local suave = 1 - (1 - q) * (1 - q)
    local aparece = math.min(1, t / 0.3) * math.min(1, (MUESTRA - t) / 0.3)
    -- horizonte y astros
    local hy = 150
    lg.setScissor()
    local ac = { p.amarillo[1], p.amarillo[2], p.amarillo[3], aparece }
    local lc = { p.blanco[1], p.blanco[2], p.blanco[3], aparece }
    astro(cx, hy, 9, ac, math.pi * 0.5 - suave * math.pi * 0.5 - 0.15, 58)
    astro(cx, hy, 7, lc, math.pi - suave * math.pi * 0.5, 58)
    -- lo que queda bajo el horizonte no se ve
    lg.setColor(0, 0, 0, a)
    lg.rectangle("fill", cx - 80, hy + 1, 160, 24)
    lg.setColor(p.gris[1], p.gris[2], p.gris[3], aparece * 0.6)
    lg.rectangle("fill", cx - 70, hy, 140, 1)
    -- estrellas que salen
    for i = 1, 14 do
        local sx = cx - 120 + (i * 53) % 240
        local sy = 40 + (i * 37) % 90
        local b = math.max(0, math.min(1, (t - 0.5 - i * 0.04) * 3)) * aparece
        lg.setColor(1, 1, 1, b * 0.7)
        lg.rectangle("fill", sx, sy, 1, 1)
    end
    -- dia que acaba y dia nuevo
    local nuevo = mercado.dia()
    local y0 = 170
    local salto = fuentes.alto(3) + 6
    local k = math.min(1, math.max(0, (t - 0.35) / 0.5))
    k = 1 - (1 - k) * (1 - k)
    lg.setScissor((cx - 120 + OX) * e + ox, (y0 - 2) * e + oy, 240 * e, salto * e)
    fuentes.texto("DÍA " .. diaAntes, cx - 120, y0 - k * salto, 3, { 0.6, 0.6, 0.6, aparece }, "center", 240)
    fuentes.texto("DÍA " .. nuevo, cx - 120, y0 + salto - k * salto, 3, { 1, 1, 1, aparece }, "center", 240)
    lg.setScissor()
    -- lo que hiciste ayer
    if resumen and (resumen.sobres > 0 or resumen.dinero ~= 0) then
        local d = resumen.dinero
        local cad = (d >= 0 and "+" or "-") .. ui.dinero(math.abs(d)) .. "   " .. resumen.sobres .. " SOBRES ABIERTOS"
        local col = d >= 0 and p.lima or p.rojo
        fuentes.texto("AYER", cx - 120, y0 + 30, 1, { 0.6, 0.6, 0.6, aparece }, "center", 240)
        fuentes.texto(cad, cx - 120, y0 + 40, 1, { col[1], col[2], col[3], aparece }, "center", 240)
    end
    lg.pop()
end

return transicion
