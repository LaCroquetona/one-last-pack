local cartas = require "datos.cartas"
local firma = require "datos.firma"
local p = require "datos.paleta"
local partida = require "src.partida"
local sobres = require "datos.sobres"
local carta = require "src.carta"
local fx = require "src.fx"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"
local tutorial = require "src.tutorial"
local opciones = require "src.opciones"
local reporte = require "src.reporte"
local mercado = require "src.mercado"

local menu = {}

local VERSION = "v0.10.3"
reporte.version = VERSION
local abanico = {}
local resumenes = {}

local function leerResumenes()
    for n = 1, partida.RANURAS do resumenes[n] = partida.resumen(n) or false end
end

-- tus mejores cartas de la partida elegida (la mejor copia de cada una),
-- mezcladas cada vez; sin cartas, al azar
local function elegirCartas()
    local tuyas = {}
    for id, l in pairs(partida.inv or {}) do
        if #l > 0 then
            local mejor = l[1]
            for _, c in ipairs(l) do
                if (c.p and not mejor.p) or (c.f and not mejor.f) then mejor = c end
            end
            table.insert(tuyas, { def = partida.carta(id), c = mejor, valor = mercado.valor(id, mejor.p) })
        end
    end
    table.sort(tuyas, function(a, b) return a.valor > b.valor end)
    local lista = {}
    for i = 1, math.min(10, #tuyas) do lista[i] = tuyas[i] end
    for i = #lista, 2, -1 do
        local j = love.math.random(i)
        lista[i], lista[j] = lista[j], lista[i]
    end
    local usadas = {}
    for _, e in ipairs(lista) do usadas[e.def.id] = true end
    while #lista < 5 do
        local def
        repeat def = cartas[love.math.random(#cartas)] until not usadas[def.id] and not def.fuera
        usadas[def.id] = true
        table.insert(lista, { def = def })
    end
    return lista
end

function menu.preparar()
    leerResumenes()
    abanico = {}
    for i, e in ipairs(elegirCartas()) do
        if i > 5 then break end
        e.i = i
        e.cara = true
        abanico[i] = e
    end
end

-- coger, arrastrar y girar las cartas del abanico
local cogida       -- { e, dx, dy, x0, y0, movida }
local GIRO = { 1, 0.55, 0.12, 0.55, 1 }
local PASO = 0.05

local function posicion(e, hora)
    if e.x then return e.x, e.y, e.a or 0 end
    local i = e.i
    local ax, ay = 448, 200
    local a = (i - 3) * 0.24 + math.sin(hora * 0.8 + i) * 0.02
    return ax + (i - 3) * 46, ay + math.abs(i - 3) * 11 + math.sin(hora * 1.5 + i) * 3, a
end

function menu.coger(id, mx, my)
    local i = tonumber(id:match("^abanico(%d)$"))
    local e
    for k, x in ipairs(abanico) do
        if x.i == i then
            e = x
            -- la que coges pasa por encima de las demas
            table.remove(abanico, k)
            table.insert(abanico, e)
            break
        end
    end
    if not e then return end
    local x, y = posicion(e, love.timer.getTime())
    cogida = { e = e, dx = x - mx, dy = y - my, x0 = mx, y0 = my }
end

function menu.mover(mx, my)
    if not cogida then return end
    if math.abs(mx - cogida.x0) + math.abs(my - cogida.y0) > 4 then cogida.movida = true end
    if cogida.movida then
        local e = cogida.e
        e.x = math.max(20, math.min(620, mx + cogida.dx))
        e.y = math.max(40, math.min(330, my + cogida.dy))
        e.a = (e.a or 0) * 0.5
    end
end

function menu.soltar()
    if not cogida then return end
    local e = cogida.e
    -- tocada sin moverla: se gira
    if not cogida.movida and not e.giro then e.giro = { t = 0, desde = e.cara } end
    cogida = nil
end

function menu.update(dt)
    for _, e in ipairs(abanico) do
        if e.giro then
            e.giro.t = e.giro.t + dt
            if e.giro.t >= #GIRO * PASO then
                e.cara = not e.giro.desde
                e.giro = nil
            end
        end
    end
end

-- una partida en la lista: nombre, dia y dinero (o VACIA)
local function ranura(n, x, y, w)
    local id = "ranura" .. n
    local esta = partida.ranura == n
    local r = resumenes[n]
    local alza = ui.anim(id, ui.encima == id and 1 or 0)
    local dy = -math.floor(alza * 2 + 0.5)
    ui.caja(x, y + dy, w, 24, esta and p.azulosc or p.negro)
    if esta then
        love.graphics.setColor(p.amarillo)
        love.graphics.rectangle("fill", x, y + dy, 3, 24)
    end
    fuentes.texto("PARTIDA " .. n, x + 9, y + dy + 5, 1, esta and p.amarillo or p.grisclaro)
    if r then
        fuentes.texto("DÍA " .. r.dia, x + 9, y + dy + 14, 1, p.gris)
        fuentes.texto(ui.dinero(r.dinero), x, y + dy + 9, 1, esta and p.blanco or p.grisclaro, "right", w - 8)
    else
        fuentes.texto("VACÍA", x, y + dy + 9, 1, p.gris, "right", w - 8)
    end
    ui.zona(id, x, y, w, 24)
end

function menu.dibujar()
    local hora = love.timer.getTime()
    -- el abanico de cartas a la derecha: se cogen, se arrastran y se giran
    fx.aura(448, 200, p.amarillo, 140, 0.15)
    for _, e in ipairs(abanico) do
        local x, y, a = posicion(e, hora)
        local sx, cara = 1, e.cara
        if e.giro then
            local f = math.min(#GIRO, math.floor(e.giro.t / PASO) + 1)
            sx = GIRO[f]
            cara = f < 4 and e.giro.desde or not e.giro.desde
        end
        local c = e.c or {}
        local luz = (cogida and cogida.e == e) and 1 or (e.i == 3 and 1 or 0.3)
        carta.dibujar(e.def, x, y, 2 * sx, 2, a, cara, { kx = 0, ky = 0, brillo = luz, lx = math.sin(hora), ly = 0 },
            cara and c.f or nil, { primera = cara and c.p or nil, top = cara and c.t or nil })
        ui.zona("abanico" .. e.i, x - 36, y - 50, 72, 100)
    end

    local titulo = "ONE LAST PACK"
    fuentes.texto(titulo, 3, 31, 6, p.negro, "center", 640)
    fuentes.texto(titulo, 0, 28, 6, p.amarillo, "center", 640)

    -- columna de la izquierda: las partidas y lo que se puede hacer
    local x, w = 56, 176
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x - 10, 84, w + 20, 258, 4, 4)
    fuentes.texto("PARTIDAS", x, 92, 1, p.grisclaro)
    local y = 104
    for n = 1, partida.RANURAS do
        ranura(n, x, y, w)
        y = y + 28
    end
    if partida.ranura ~= 1 and resumenes[1] then
        ui.boton("copiar1", "COPIAR LA PARTIDA 1 AQUÍ", x, y, w, 12, p.grisosc)
    end
    y = 206
    local hay = partida.existe()
    if hay then
        ui.boton("continuar", "CONTINUAR", x, y, w, 22, p.verde)
        ui.boton("nueva", "PARTIDA NUEVA", x, y + 28, w, 18, p.azul)
    else
        ui.boton("nueva", "EMPEZAR", x, y, w, 22, p.verde)
    end
    y = y + (hay and 52 or 28)
    ui.boton("opciones", "OPCIONES", x, y, w, 18, p.gris)
    ui.boton("reportar", "REPORTAR BUG", x, y + 22, w, 18, p.grisosc)
    ui.boton("salir", "SALIR", x, y + 44, w, 18, p.grisosc)

    fuentes.texto(firma.nombre, 8, 348, 1, p.gris)
    fuentes.texto(VERSION, 0, 348, 1, p.gris, "right", 632)
end

local function verTutorial()
    partida.cargar()
    tutorial.repetir()
    nav.empezar()
end

function menu.click(id)
    if id:match("^abanico%d$") then return end
    local n = id:match("^ranura(%d)$")
    if n then
        partida.elegirRanura(tonumber(n))
        partida.cargar()
        menu.preparar()
        return
    end
    if id == "copiar1" then
        ui.confirmar("¿COPIAR LA PARTIDA 1 AQUÍ?", {
            "LA PARTIDA " .. partida.ranura .. " SE CAMBIA POR UNA COPIA DE LA 1",
            "LA 1 SE QUEDA COMO ESTÁ",
        }, "SÍ, COPIAR", function()
            partida.copiarDe(1)
            leerResumenes()
        end)
        return
    end
    if id == "continuar" then
        partida.cargar()
        nav.empezar()
    elseif id == "nueva" then
        if partida.existe() then
            ui.confirmar("¿BORRAR LA PARTIDA " .. partida.ranura .. "?", {
                "EMPEZARÁS DE CERO CON " .. ui.dinero(sobres.inicio.dinero),
                "PERDERÁS TODAS TUS CARTAS, SOBRES Y DINERO",
            }, "SÍ, EMPEZAR DE CERO", function()
                partida.borrar()
                if not opciones.tutorial then partida.tutorial = false end
                nav.empezar()
            end)
        else
            partida.borrar()
            if not opciones.tutorial then partida.tutorial = false end
            nav.empezar()
        end
    elseif id == "opciones" then
        opciones.abrir(partida.existe() and verTutorial or nil)
    elseif id == "reportar" then
        reporte.abrir(function() return partida.archivo() or partida.texto() end)
    elseif id == "pantalla" then
        nav.alternarPantalla()
    elseif id == "salir" then
        love.event.quit()
    end
end

return menu
