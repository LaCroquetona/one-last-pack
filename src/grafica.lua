-- Graficas de precio para el movil: linea con relleno, barras de volumen,
-- marcas de noticias y lectura del valor al pasar el raton.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local ui = require "src.ui"

local lg = love.graphics

local grafica = {}

local function limites(series, i0, i1)
    local min, max = math.huge, -math.huge
    for _, s in ipairs(series) do
        for i = i0, i1 do
            local v = s.datos[i]
            if v and v > 0 then
                min = math.min(min, v)
                max = math.max(max, v)
            end
        end
    end
    if min == math.huge then return 0, 1 end
    if max - min < max * 0.04 then
        local medio = (max + min) / 2
        min, max = medio * 0.96, medio * 1.04
    end
    local margen = (max - min) * 0.1
    return math.max(0, min - margen), max + margen
end

-- o: x, y, w, h; series = { { datos, color, nombre, relleno } } (todas igual de largas,
-- 0 o nil = sin dato); volumen (opcional, misma longitud); rango (ultimos n puntos);
-- dia0 (dia del primer dato); marcas[dia] = true; formato (numero -> texto)
function grafica.dibujar(o)
    local base = o.series[1].datos
    local n = #base
    if n == 0 then return end
    local i0 = math.max(1, n - (o.rango or n) + 1)
    local x, y, w, h = o.x, o.y, o.w, o.h
    local altoVol = o.volumen and math.floor(h * 0.22) or 0
    local hl = h - altoVol - (o.volumen and 3 or 0)
    local min, max = limites(o.series, i0, n)
    local formato = o.formato or tostring

    local function px(i)
        if n == i0 then return x + w / 2 end
        return x + (i - i0) / (n - i0) * w
    end
    local function py(v)
        return y + hl - (v - min) / (max - min) * hl
    end

    -- rejilla y escala a la derecha
    for k = 0, 2 do
        local gy = math.floor(y + k * hl / 2) + 0.5
        lg.setColor(p.grisosc)
        for gx = x, x + w, 3 do lg.rectangle("fill", gx, gy, 1, 1) end
    end
    fuentes.texto(formato(max), x, y + 1, 1, p.gris, "right", w)
    fuentes.texto(formato(min), x, y + hl - 6, 1, p.gris, "right", w)

    if o.volumen then
        local vmax = 1
        for i = i0, n do vmax = math.max(vmax, o.volumen[i] or 0) end
        local ancho = math.max(1, math.floor(w / (n - i0 + 1)) - 1)
        for i = i0, n do
            local v = o.volumen[i] or 0
            local alto = math.floor(v / vmax * altoVol + 0.5)
            local bx = math.max(x, math.min(x + w - ancho, math.floor(px(i) - ancho / 2)))
            lg.setColor(p.grisosc)
            lg.rectangle("fill", bx, y + h - alto, ancho, alto)
        end
    end

    if o.marcas and o.dia0 then
        for i = i0, n do
            if o.marcas[o.dia0 + i - 1] then
                local mx = math.floor(px(i))
                lg.setColor(p.amarillo)
                lg.rectangle("fill", mx, y, 1, hl)
                lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 1)
                lg.polygon("fill", mx - 2, y, mx + 3, y, mx + 0.5, y + 3)
            end
        end
        lg.setColor(1, 1, 1)
    end

    for k, s in ipairs(o.series) do
        local puntos = {}
        local function cerrar()
            if #puntos >= 4 then
                lg.setColor(s.color)
                lg.line(puntos)
            elseif #puntos == 2 then
                lg.setColor(s.color)
                lg.rectangle("fill", puntos[1] - 1, puntos[2] - 1, 2, 2)
            end
            puntos = {}
        end
        for i = i0, n do
            local v = s.datos[i]
            if v and v > 0 then
                local ax, ay = math.floor(px(i)) + 0.5, math.floor(py(v)) + 0.5
                if k == 1 and s.relleno ~= false and #puntos >= 2 then
                    local bx, by = puntos[#puntos - 1], puntos[#puntos]
                    lg.setColor(s.color[1], s.color[2], s.color[3], 0.15)
                    lg.polygon("fill", bx, by, ax, ay, ax, y + hl, bx, y + hl)
                end
                table.insert(puntos, ax)
                table.insert(puntos, ay)
            else
                cerrar()
            end
        end
        cerrar()
        local ultimo = s.datos[n]
        if ultimo and ultimo > 0 then
            lg.setColor(s.color)
            lg.rectangle("fill", math.floor(px(n)) - 1, math.floor(py(ultimo)) - 1, 3, 3)
        end
    end

    -- leer el valor con el raton
    if o.id and ui.mx >= x and ui.mx <= x + w and ui.my >= y and ui.my <= y + h then
        local i = n == i0 and n or math.floor(i0 + (ui.mx - x) / w * (n - i0) + 0.5)
        i = math.max(i0, math.min(n, i))
        local cx = math.floor(px(i)) + 0.5
        lg.setColor(1, 1, 1, 0.5)
        lg.line(cx, y, cx, y + h)
        local lineas = {}
        for _, s in ipairs(o.series) do
            local v = s.datos[i]
            if v and v > 0 then table.insert(lineas, { (s.nombre and (s.nombre .. " ") or "") .. formato(v), s.color }) end
        end
        if o.volumen then table.insert(lineas, { "VENTAS " .. (o.volumen[i] or 0), p.grisclaro }) end
        if o.marcas and o.dia0 and type(o.marcas[o.dia0 + i - 1]) == "table" then
            table.insert(lineas, { o.marcas[o.dia0 + i - 1].texto, p.amarillo })
        end
        ui.tooltip(o.dia0 and ("DÍA " .. (o.dia0 + i - 1)) or "", p.blanco, lineas)
    end
    lg.setColor(1, 1, 1)
end

-- linea pequeña de los ultimos dias, verde si sube y roja si baja
function grafica.mini(datos, x, y, w, h, dias)
    local n = #datos
    if n < 2 then return end
    local i0 = math.max(1, n - (dias or 14) + 1)
    -- los ceros son dias en que aun no existia
    while i0 < n and datos[i0] <= 0 do i0 = i0 + 1 end
    if i0 >= n then return end
    local min, max = math.huge, -math.huge
    for i = i0, n do
        min = math.min(min, datos[i])
        max = math.max(max, datos[i])
    end
    if max - min < 1 then max, min = max + 1, min - 1 end
    local puntos = {}
    for i = i0, n do
        table.insert(puntos, math.floor(x + (i - i0) / (n - i0) * w) + 0.5)
        table.insert(puntos, math.floor(y + h - (datos[i] - min) / (max - min) * h) + 0.5)
    end
    lg.setColor(datos[n] >= datos[i0] and p.lima or p.rojo)
    if #puntos >= 4 then lg.line(puntos) end
    lg.setColor(1, 1, 1)
end

return grafica
