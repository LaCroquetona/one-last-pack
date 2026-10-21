-- Interfaz de modo inmediato: cada frame las pantallas pintan sus botones y
-- zonas, y el click se resuelve con lo pintado en el frame anterior.
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"

local lg = love.graphics

local ui = { mx = 0, my = 0 }

local zonas = {}
-- lo que se ve de pantalla a lo ancho (mas que 0-640 en moviles alargados)
ui.izq, ui.der = 0, 640
local anims = {}
local anterior
local tip

local function dentro(z, x, y)
    return x >= z.x and x < z.x + z.w and y >= z.y and y < z.y + z.h
end

local function buscar(x, y)
    for i = #zonas, 1, -1 do
        if dentro(zonas[i], x, y) then return zonas[i].id end
    end
end

function ui.empezar(mx, my)
    ui.mx, ui.my = mx, my
    ui.encima = buscar(mx, my)
    if ui.encima and ui.encima ~= anterior then sonido.tocar("encima") end
    anterior = ui.encima
    zonas = {}
    tip = nil
end

-- ui.recorte: si esta puesto, las zonas se recortan a ese rectangulo (listas con scroll)
-- ui.sinZonas: no se apunta ninguna (mientras se anima una pantalla)
function ui.zona(id, x, y, w, h)
    if ui.sinZonas then return end
    local r = ui.recorte
    if r then
        local x2, y2 = math.min(x + w, r.x + r.w), math.min(y + h, r.y + r.h)
        x, y = math.max(x, r.x), math.max(y, r.y)
        w, h = x2 - x, y2 - y
        if w <= 0 or h <= 0 then return end
    end
    table.insert(zonas, { id = id, x = x, y = y, w = w, h = h })
end

function ui.click(mx, my)
    return buscar(mx, my)
end

-- la zona de arriba del todo en (x, y) cuyo id empieza por prefijo
function ui.zonaEn(x, y, prefijo)
    for i = #zonas, 1, -1 do
        local z = zonas[i]
        if z.id:sub(1, #prefijo) == prefijo and dentro(z, x, y) then return z.id end
    end
end

-- la ultima zona pintada cuyo id empieza por prefijo (para señalarla)
function ui.rect(prefijo)
    for i = #zonas, 1, -1 do
        local z = zonas[i]
        if z.id:sub(1, #prefijo) == prefijo then return z end
    end
end

-- valor que va suave hacia el objetivo, uno por id
function ui.anim(id, objetivo, velocidad)
    local v = anims[id] or 0
    v = v + (objetivo - v) * math.min(1, love.timer.getDelta() * (velocidad or 14))
    anims[id] = v
    return v
end

local function oscuro(c)
    return { c[1] * 0.55, c[2] * 0.55, c[3] * 0.55 }
end

function ui.boton(id, texto, x, y, w, h, color, activo)
    if activo == nil then activo = true end
    local alza = ui.anim(id, (activo and ui.encima == id) and 1 or 0)
    local dy = -math.floor(alza * 2 + 0.5)
    local c = activo and color or p.grisosc

    lg.setColor(p.negro)
    lg.rectangle("fill", x, y + 1, w, h + 1)
    lg.setColor(oscuro(c))
    lg.rectangle("fill", x, y + dy, w, h)
    lg.setColor(c)
    lg.rectangle("fill", x + 1, y + dy + 1, w - 2, h - 3)
    fuentes.texto(texto, x, y + dy + math.floor((h - 5) / 2), 1, activo and p.blanco or p.gris, "center", w)

    if activo then ui.zona(id, x, y, w, h) end
end

-- caja oscura con borde, la de los paneles
function ui.caja(x, y, w, h, relleno)
    lg.setColor(p.negro)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(relleno or p.grisosc)
    lg.rectangle("fill", x + 1, y + 1, w - 2, h - 2)
    lg.setColor(1, 1, 1)
end

-- inclinacion de una carta segun donde este el raton, para carta.dibujar
function ui.hoverCarta(id, x, y, ancho, alto)
    local a = ui.anim(id, ui.encima == id and 1 or 0)
    if a < 0.01 then return nil end
    local dx = math.max(-1, math.min(1, (ui.mx - x) / (ancho / 2)))
    local dy = math.max(-1, math.min(1, (ui.my - y) / (alto / 2)))
    return { kx = -dx * dy * 0.12 * a, ky = dx * 0.06 * a, brillo = a, lx = dx, ly = dy }
end

-- se pide durante el frame y se pinta al final, por encima de todo
function ui.tooltip(titulo, color, lineas)
    tip = { titulo = titulo, color = color, lineas = lineas }
end

function ui.dibujarTooltip(anchoPantalla, altoPantalla)
    if not tip then return end
    local w = fuentes.ancho(tip.titulo) + 10
    for _, l in ipairs(tip.lineas) do
        w = math.max(w, fuentes.ancho(l[1]) + 10)
    end
    local h = 14 + #tip.lineas * 8
    local x = math.min(ui.mx + 10, anchoPantalla - w - 4)
    local y = ui.my + 12
    if y + h > altoPantalla - 4 then y = ui.my - h - 6 end

    ui.caja(x, y, w, h, p.negro)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 2, y + 11, w - 4, h - 13)
    fuentes.texto(tip.titulo, x + 5, y + 3, 1, tip.color)
    for i, l in ipairs(tip.lineas) do
        fuentes.texto(l[1], x + 5, y + 6 + i * 8, 1, l[2] or p.blanco)
    end
end

-- centimos -> "1.234,50 €"
function ui.dinero(c)
    c = math.floor(c + 0.5)
    local signo = c < 0 and "-" or ""
    c = math.abs(c)
    local euros = tostring(math.floor(c / 100))
    euros = euros:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return string.format("%s%s,%02d €", signo, euros, c % 100)
end

-- 12345 -> "12.345"
function ui.numero(n)
    local s = tostring(math.floor(n + 0.5))
    return (s:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", ""))
end

-- texto de la tirada de 1ª edicion de un set: cuantos sobres y cuantos son tuyos
function ui.tirada(total, parte)
    local pc = parte * 100
    local txt = pc > 0 and pc < 1 and "<1" or tostring(math.floor(pc + 0.5))
    return "TIRADA 1ª ED: " .. ui.numero(total) .. " SOBRES  -  TUYOS: " .. txt .. "%"
end

-- 0.12 -> "+12%"
function ui.porcentaje(v)
    local n = math.floor(v * 100 + 0.5)
    if n > 0 then return "+" .. n .. "%" end
    return n .. "%"
end

function ui.colorCambio(v)
    if v > 0.005 then return p.lima end
    if v < -0.005 then return p.rojo end
    return p.grisclaro
end

-- aviso grande en rojo: mientras esta abierto solo valen sus dos botones
function ui.confirmar(titulo, lineas, textoSi, accion)
    ui.modal = { titulo = titulo, lineas = lineas, si = textoSi, accion = accion, t = 0 }
end

function ui.dibujarModal(ancho, alto)
    local m = ui.modal
    if not m then return end
    m.t = m.t + love.timer.getDelta()
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", ui.izq, 0, ui.der - ui.izq, alto)

    local w, h = 360, 150
    local x, y = math.floor((ancho - w) / 2), math.floor((alto - h) / 2)
    local pulso = 0.75 + math.sin(m.t * 8) * 0.25
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 2, y - 2, w + 4, h + 4)
    lg.setColor(p.rojo[1] * pulso, p.rojo[2] * pulso, p.rojo[3] * pulso)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(p.morado)
    lg.rectangle("fill", x + 4, y + 4, w - 8, h - 8)

    fuentes.texto(m.titulo, x, y + 14, 3, p.amarillo, "center", w)
    for i, l in ipairs(m.lineas) do
        fuentes.texto(l, x, y + 44 + i * 10, 1, p.blanco, "center", w)
    end

    -- los botones del aviso se pintan aqui, encima de todo
    zonas = {}
    ui.boton("modal_si", m.si, x + 24, y + h - 34, 150, 20, p.rojo)
    ui.boton("modal_no", "CANCELAR", x + w - 174, y + h - 34, 150, 20, p.gris)
end

function ui.clickModal(id)
    local m = ui.modal
    if not m then return false end
    if id == "modal_si" then
        ui.modal = nil
        m.accion()
    elseif id == "modal_no" then
        ui.modal = nil
    end
    return true
end

-- panel encima de todo (como el aviso, pero lo pinta quien lo abre):
-- ui.overlay = { dibujar = function(ancho, alto), click = function(id) }
function ui.dibujarOverlay(ancho, alto)
    if not ui.overlay then return end
    zonas = {}
    ui.overlay.dibujar(ancho, alto)
end

function ui.clickOverlay(id)
    if not ui.overlay then return false end
    if id then ui.overlay.click(id) end
    return true
end

-- arrastrar: la pantalla dice que cosas se pueden arrastrar y donde se sueltan
function ui.cogerSi(id, x, y)
    ui.cogida = { id = id, x0 = x, y0 = y, moviendo = false }
end

function ui.moverRaton(x, y)
    local c = ui.cogida
    if c and not c.moviendo and (math.abs(x - c.x0) + math.abs(y - c.y0)) > 4 then
        c.moviendo = true
    end
end

function ui.soltar()
    local c = ui.cogida
    ui.cogida = nil
    return c
end

function ui.arrastrando()
    return ui.cogida and ui.cogida.moviendo and ui.cogida.id
end

return ui
