-- Muebles y objetos en 3D con la misma perspectiva que la caja (src/caja.lua):
-- lo que esta a z pixeles de fondo sale z/2 a la derecha y z arriba, se ve la
-- tapa y el lateral derecho. Lo usan la tienda, la mesa y el armario.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local sobre = require "src.sobre"

local lg = love.graphics

local muebles = {}

muebles.MADERA = { 0.42, 0.26, 0.16 }
local MAD = muebles.MADERA

-- dorados del MASTER SET (fuera de la paleta)
muebles.ORO = { osc = { 0.50, 0.32, 0.10 }, oro = { 0.84, 0.62, 0.16 }, claro = { 0.98, 0.84, 0.42 }, brillo = { 1, 0.97, 0.80 } }
local ORO = muebles.ORO

local function col(c, a, k)
    k = k or 1
    lg.setColor(math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k), a or 1)
end
local function rect(c, x, y, w, h, a, k)
    col(c, a, k)
    lg.rectangle("fill", math.floor(x), math.floor(y), w, h)
end
local function px(c, x, y, a, k) rect(c, x, y, 1, 1, a, k) end
muebles.rect = rect

-- cuanto se va a la derecha algo que esta a z de fondo
function muebles.dz(z) return math.floor((z + 1) / 2) end
local dz = muebles.dz

-- frente, tapa y lado de un color
function muebles.tonos(c, frente, tapa, lado)
    local function k(f) return { math.min(1, c[1] * f), math.min(1, c[2] * f), math.min(1, c[3] * f) } end
    return { k(frente or 1), k(tapa or 1.3), k(lado or 0.65) }
end

local function silueta(x, y, w, h, d)
    rect(p.negro, x - 1, y - 1, w + 2, h + 2)
    for r = 0, d do rect(p.negro, x - 1 + dz(r), y - 2 - r, w + 2, 1) end
    for k = 0, math.floor(d / 2) do rect(p.negro, x + w + k, y - 2 * k, 1, h + 1) end
end

-- caja maciza: frente (x, y, w, h) y fondo d; c = { frente, tapa, lado }
function muebles.bloque(x, y, w, h, d, c)
    x, y = math.floor(x), math.floor(y)
    silueta(x, y, w, h, d)
    for r = 0, d - 1 do rect(c[2], x + dz(r), y - 1 - r, w, 1) end
    for k = 1, math.floor(d / 2) do rect(c[3], x + w - 1 + k, y - 2 * k + 1, 1, h) end
    rect(c[1], x, y, w, h)
end

-- sombra en el suelo, hacia abajo a la derecha como la de la caja
function muebles.sombra(x, y, w, h, d)
    col(p.negro, 0.3)
    for r = 0, d - 1 do lg.rectangle("fill", x + dz(r) + 3, y + h - r + 2, w, 1) end
end

-- hueco de una estanteria: frente abierto (x, y, w, h), fondo d y marco
function muebles.mueble(x, y, w, h, d, marco)
    muebles.bloque(x - marco, y - marco, w + 2 * marco, h + 2 * marco, d, muebles.tonos(MAD, 1, 1.35, 0.6))
    rect(MAD, x, y, w, h, 1, 0.5)
    rect(MAD, x + dz(d), y, w - dz(d), h - d, 1, 0.38)
    for r = 0, d - 1 do rect(MAD, x + dz(r), y + h - 1 - r, w - dz(r), 1, 1, 0.8) end
    rect(p.negro, x, y, w, 1, 0.5)
end

-- tablero perforado al fondo de un hueco
function muebles.perforado(x, y, w, h, paso)
    for gy = y, y + h - 1, paso do
        for gx = x, x + w - 1, paso do px(p.negro, gx, gy, 0.35) end
    end
end

-- balda: canto (x, y, w, 4) y su tapa de fondo d
function muebles.balda(x, y, w, d)
    for r = 0, d - 1 do rect(MAD, x + dz(r), y - 1 - r, w - dz(r), 1, 1, 1.05) end
    rect(p.negro, x, y - 1, w, 1, 0.25)
    rect(MAD, x, y, w, 4, 1, 1.3)
    rect(p.negro, x, y + 4, w, 1)
    rect(p.negro, x, y + 5, w, 3, 0.3)
end

-- gancho que sale del tablero en (bx, by) hacia delante, de largo L; la
-- punta (lo que se ve delante de lo colgado) se pinta luego con punta()
function muebles.gancho(bx, by, L)
    for i = 0, L do
        px(p.grisclaro, bx - dz(i), by + i)
        px(p.gris, bx - dz(i) + 1, by + i)
    end
    rect(p.negro, bx - 1, by - 1, 3, 2)
end
function muebles.punta(bx, by, L)
    for i = L - 3, L do px(p.grisclaro, bx - dz(i), by + i) end
    px(p.blanco, bx - dz(L) - 1, by + L - 2)
end
-- donde cuelga lo de delante de un gancho
function muebles.agujero(bx, by, L)
    return bx - dz(L - 4), by + L - 4
end

-- sobres colgados: (hx, hy) el agujero del de delante; los de atras solo
-- asoman por arriba (la pila recta, para que no parezcan achatados)
function muebles.colgados(id, hx, hy, n, giro)
    for k = n - 1, 0, -1 do
        local x, y = hx, hy - k * 2
        local l = 1 - k * 0.12
        local rot = k == 0 and (giro or 0) or (giro or 0) * 0.5
        lg.setColor(0, 0, 0, 0.3)
        lg.draw(sobre.imagen(id), x + 3, y + 3, rot, 1, 1, 15, 3)
        lg.setColor(l, l, l)
        lg.draw(sobre.imagen(id), x, y, rot, 1, 1, 15, 3)
        rect(p.negro, x - 3, y - 1, 6, 2, 0.8)
    end
    lg.setColor(1, 1, 1)
end

-- blister de fundas y bolsa de top loaders, colgados del agujero (hx, hy)
local function paquete(hx, hy, n, giro, cabecera, letra, cuerpo, titulo, cantidad, tops)
    lg.push()
    lg.translate(hx, hy)
    lg.rotate(giro or 0)
    for k = n - 1, 0, -1 do
        local ox, oy = dz(k * 3), -k * 3
        local l = 1 - k * 0.12
        rect(p.negro, ox - 15, oy - 3, 30, 44)
        rect(cabecera, ox - 14, oy - 2, 28, 9, 1, l)
        rect(p.negro, ox - 3, oy - 1, 6, 2)
        if tops then
            rect(p.blanco, ox - 14, oy + 7, 28, 33, 0.35 * l)
            for i = 0, 3 do rect(p.celeste, ox - 12 + i, oy + 9 + i, 22, 26, 0.5) end
            rect(p.blanco, ox - 10, oy + 12, 18, 1, 0.8)
        else
            rect(cuerpo, ox - 14, oy + 7, 28, 33, 1, l)
            rect(p.cian, ox - 11, oy + 10, 22, 27, 0.35)
            rect(p.blanco, ox - 9, oy + 12, 2, 22, 0.5)
        end
        if k == 0 then
            fuentes.texto(titulo, ox - 14, oy, 1, letra, "center", 28)
            fuentes.texto(cantidad, ox - 14, oy + 21, 1, p.blanco, "center", 28)
        end
    end
    lg.pop()
    lg.setColor(1, 1, 1)
end
function muebles.blister(hx, hy, n, giro, cantidad)
    paquete(hx, hy, n, giro, p.blanco, p.negro, p.verdeosc, "FUNDAS", cantidad or "X20")
end
function muebles.bolsaTops(hx, hy, n, giro, cantidad)
    paquete(hx, hy, n, giro, p.azul, p.blanco, nil, "TOPS", cantidad or "X10", true)
end

-- etiqueta de precio centrada en x
function muebles.etiqueta(x, y, texto, fondo, letra)
    local w = math.ceil(fuentes.ancho(texto)) + 6
    local h = math.max(9, math.ceil(fuentes.alto(1)) + 4)
    rect(p.negro, x - w / 2, y, w, h)
    rect(fondo or p.blanco, x - w / 2 + 1, y + 1, w - 2, h - 2)
    fuentes.texto(texto, x - w / 2, y + math.floor((h - fuentes.alto(1)) / 2), 1, letra or p.negro, "center", w)
    lg.setColor(1, 1, 1)
end

-- archivador de pie: el lomo es el frente, arriba las hojas, al lado la portada
muebles.ALBUM = { w = 30, h = 100, d = 26 }
-- pegatina de la edicion: crece con el texto (el del movil es mas grande)
local function pegatina(x, y, w, primera)
    local txt = primera and "1ª ED" or "REIMP"
    local pw = math.max(w - 8, math.ceil(fuentes.ancho(txt)) + 4)
    local ph = math.max(9, math.ceil(fuentes.alto(1)) + 4)
    local px0 = math.floor(x + w / 2 - pw / 2)
    rect(p.negro, px0 - 1, y + 38, pw + 2, ph + 2)
    rect(primera and p.amarillo or p.grisclaro, px0, y + 39, pw, ph)
    fuentes.texto(txt, px0, y + 39 + math.floor((ph - fuentes.alto(1)) / 2), 1, p.negro, "center", pw)
end

-- MASTER SET: los colores del set con cantos, lomo, bandas y esquineras dorados
local function albumMaster(c, x, y, codigo, primera, tengo, total)
    local A = muebles.ALBUM
    local w, h, d = A.w, A.h, A.d
    muebles.bloque(x, y, w, h, d, { c.base, ORO.claro, { c.base[1] * 0.7, c.base[2] * 0.7, c.base[3] * 0.7 } })
    for r = 0, d - 1 do
        rect(c.base, x + dz(r), y - 1 - r, 3, 1)
        rect(c.base, x + dz(r) + w - 3, y - 1 - r, 3, 1)
        if r % 3 == 1 then rect(ORO.oro, x + dz(r) + 4, y - 1 - r, w - 8, 1) end
        if r % 5 == 3 then rect(ORO.brillo, x + dz(r) + 6 + r % 7, y - 1 - r, 2, 1) end
    end
    col(c.rayas, 0.55)
    for yy = 0, h - 1 do
        for xx = 3, w - 1 do
            if (xx + yy) % 7 < 2 then lg.rectangle("fill", x + xx, y + yy, 1, 1) end
        end
        for k = 1, math.floor(d / 2) do
            if (yy + k * 3) % 7 < 2 then lg.rectangle("fill", x + w - 1 + k, y - 2 * k + 1 + yy, 1, 1) end
        end
    end
    rect(c.base, x + 3, y + 14, w - 3, 76, 1, 0.75)
    -- lomo dorado con nervios
    rect(ORO.oro, x, y, 3, h)
    rect(ORO.claro, x, y, 1, h)
    rect(ORO.osc, x + 2, y, 1, h)
    for _, ny in ipairs({ 6, 30, 70, 94 }) do rect(ORO.osc, x, y + ny, 3, 1) end
    for _, by in ipairs({ 8, h - 12 }) do
        rect(ORO.oro, x + 3, y + by, w - 3, 3)
        rect(ORO.claro, x + 3, y + by, w - 3, 1)
        rect(ORO.osc, x + 3, y + by + 2, w - 3, 1)
    end
    -- esquineras de metal
    for _, q in ipairs({ { x + w - 1, y, -1, 1 }, { x + w - 1, y + h - 1, -1, -1 } }) do
        for k = 0, 4 do
            rect(k == 0 and ORO.brillo or ORO.oro, q[1] + q[3] * k, q[2], 1, 1)
            rect(ORO.oro, q[1], q[2] + q[4] * k, 1, 1)
            if k < 4 then rect(ORO.osc, q[1] + q[3] * k, q[2] + q[4] * (4 - k), 1, 1) end
        end
        for a = 1, 3 do
            for b = 1, 4 - a do rect(ORO.claro, q[1] + q[3] * a, q[2] + q[4] * b, 1, 1) end
        end
    end
    fuentes.texto(codigo, x + 2, y + 18, 2, ORO.claro, "center", w - 2)
    pegatina(x, y, w, primera)
    fuentes.texto(tengo .. "/" .. total, x, y + 54, 1, ORO.claro, "center", w)
    rect(p.negro, x + 4, y + 61, w - 8, 5)
    rect(ORO.claro, x + 5, y + 62, w - 10, 3)
    rect(p.negro, x + 4, y + 67, w - 8, 5)
    rect(ORO.oro, x + 5, y + 68, w - 10, 3)
    rect(ORO.brillo, x + 5, y + 68, w - 10, 1)
    -- placa MASTER, dentro de la tapa (crece con el texto, como la pegatina)
    local pw = math.max(w - 5, math.ceil(fuentes.ancho("MASTER")) + 2)
    local ph = math.max(9, math.ceil(fuentes.alto(1)) + 4)
    local px0 = math.floor(x + 4 + (w - 5) / 2 - pw / 2)
    rect(p.negro, px0 - 1, y + 75, pw + 2, ph + 2)
    rect(ORO.oro, px0, y + 76, pw, ph)
    rect(ORO.claro, px0, y + 76, pw, 1)
    rect(ORO.osc, px0, y + 76 + ph - 1, pw, 1)
    fuentes.texto("MASTER", px0 + math.floor((pw - fuentes.ancho("MASTER")) / 2), y + 76 + math.floor((ph - fuentes.alto(1)) / 2), 1, p.negro)
    lg.setColor(1, 1, 1)
end

-- fuera: { tengo, total } de las de fuera de set (nil si aun no tienes ninguna)
function muebles.album(colores, x, y, codigo, primera, tengo, total, fuera)
    if fuera and fuera[1] >= fuera[2] and tengo >= total then
        return albumMaster(colores, x, y, codigo, primera, tengo, total)
    end
    local A = muebles.ALBUM
    local w, h, d = A.w, A.h, A.d
    local c = colores
    muebles.bloque(x, y, w, h, d, { c.base, p.blanco, { c.base[1] * 0.7, c.base[2] * 0.7, c.base[3] * 0.7 } })
    for r = 0, d - 1 do
        rect(c.base, x + dz(r), y - 1 - r, 3, 1, 1, 1.2)
        rect(c.base, x + dz(r) + w - 3, y - 1 - r, 3, 1, 1, 1.2)
        if r % 3 == 1 then rect(p.grisclaro, x + dz(r) + 4, y - 1 - r, w - 8, 1) end
    end
    -- rayas en diagonal en el lomo y la portada, como la caja
    col(c.rayas, 0.55)
    for yy = 0, h - 1 do
        for xx = 3, w - 1 do
            if (xx + yy) % 7 < 2 then lg.rectangle("fill", x + xx, y + yy, 1, 1) end
        end
        for k = 1, math.floor(d / 2) do
            if (yy + k * 3) % 7 < 2 then lg.rectangle("fill", x + w - 1 + k, y - 2 * k + 1 + yy, 1, 1) end
        end
    end
    rect(c.base, x + 3, y + 14, w - 3, 76, 1, 0.75)
    rect(c.borde, x, y, 3, h)
    rect(c.rayas, x, y + 8, w, 3)
    rect(c.rayas, x, y + h - 12, w, 3)
    fuentes.texto(codigo, x + 2, y + 18, 2, c.letras, "center", w - 2)
    pegatina(x, y, w, primera)
    fuentes.texto(tengo .. "/" .. total, x, y + 56, 1, p.blanco, "center", w)
    rect(p.negro, x + 4, y + 66, w - 8, 5)
    if tengo > 0 then
        rect(tengo >= total and p.amarillo or p.lima, x + 5, y + 67, math.max(1, math.floor((w - 10) * tengo / total)), 3)
    end
    -- segunda barra: las de fuera de set
    if fuera then
        rect(p.negro, x + 4, y + 74, w - 8, 5)
        rect(p.naranja, x + 5, y + 75, math.max(1, math.floor((w - 10) * fuera[1] / fuera[2])), 3)
        fuentes.texto("+" .. fuera[1] .. "/" .. fuera[2], x, y + 80, 1, p.amarillo, "center", w)
    end
    lg.setColor(1, 1, 1)
end

return muebles
