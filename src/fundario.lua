-- Fundas y tops con diseno en rejilla: el selector de las cajitas de la mesa
-- (solo lo que tienes, para elegir el de arriba) y el FUNDARIO del armario
-- (todos los disenos, los conseguidos y los que faltan)
local p = require "datos.paleta"
local cartas = require "datos.cartas"
local datos = require "datos.fundas"
local partida = require "src.partida"
local carta = require "src.carta"
local fundasDib = require "src.fundas"
local fuentes = require "src.fuentes"
local muebles = require "src.muebles"
local ui = require "src.ui"

local lg = love.graphics
local fundario = {}

local FILTROS = { "todas", "set", "mix", "especial" }
local NOMBRE_FILTRO = { todas = "TODAS", set = "SET", mix = "MIX", especial = "ESPECIALES" }
local COLS, FILAS = 8, 3
local PW, PH = 432, 268

local estado -- { esTop, filtro, pagina, elegir = fn, actual, todo = (fundario) }

local function enFiltro(d, filtro)
    if filtro == "todas" then return true end
    if filtro == "set" then return d.familia == "set" or d.familia == "etb" end
    return d.familia == filtro
end

local function lista()
    local l = {}
    for _, d in ipairs(estado.esTop and datos.tops or datos.lista) do
        local tienes = (estado.esTop and partida.topsDe or partida.fundasDe)(d.id)
        local visto = partida.fundario[estado.esTop and "t" or "f"][d.id]
        if enFiltro(d, estado.filtro) and (estado.todo or tienes > 0) then
            table.insert(l, { d = d, n = tienes, visto = visto or tienes > 0 })
        end
    end
    return l
end

-- conseguidos de todos los disenos (para el fundario y su logro)
function fundario.cuenta(esTop)
    local n, total = 0, 0
    local vistos = partida.fundario[esTop and "t" or "f"]
    for _, d in ipairs(esTop and datos.tops or datos.lista) do
        total = total + 1
        if vistos[d.id] then n = n + 1 end
    end
    return n, total
end

local CARTA = cartas[1]

-- miniatura de un diseno en (x, y) (centro), a escala e
function fundario.miniatura(id, esTop, x, y, e)
    if esTop then
        carta.dibujar(CARTA, x, y, e, e, 0, true, nil, true, { quieta = true, top = id })
    else
        lg.setColor(0, 0, 0, 0.35)
        lg.rectangle("fill", x - fundasDib.W / 2 * e + 2, y - fundasDib.H / 2 * e + 3, fundasDib.W * e, fundasDib.H * e)
        fundasDib.dibujarDorso(id, x, y, e)
    end
    lg.setShader()
    lg.setColor(1, 1, 1)
end

local function dibujar(ancho, alto)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", ui.izq or 0, 0, (ui.der or ancho) - (ui.izq or 0), alto)
    local x0, y0 = math.floor(320 - PW / 2), math.floor(180 - PH / 2)
    ui.caja(x0, y0, PW, PH)
    local titulo
    if estado.todo then
        local n, total = fundario.cuenta(estado.esTop)
        titulo = "FUNDARIO  " .. n .. "/" .. total
    else
        titulo = estado.esTop and "TUS TOPS CON DISEÑO" or "TUS FUNDAS CON DISEÑO"
    end
    fuentes.texto(titulo, x0 + 8, y0 + 7, 2, p.amarillo)
    ui.boton("fsel_cerrar", "X", x0 + PW - 18, y0 + 4, 14, 12, p.rojo)
    -- fundas o tops (en el fundario) y filtros
    local fx = x0 + 8
    if estado.todo then
        ui.boton("fsel_fundas", "FUNDAS", fx, y0 + 24, 40, 11, not estado.esTop and p.azul or p.grisosc)
        ui.boton("fsel_tops", "TOPS", fx + 43, y0 + 24, 32, 11, estado.esTop and p.azul or p.grisosc)
        fx = fx + 84
    end
    for _, f in ipairs(FILTROS) do
        local w = fuentes.ancho(NOMBRE_FILTRO[f]) + 10
        ui.boton("fsel_f_" .. f, NOMBRE_FILTRO[f], fx, y0 + 24, w, 11, estado.filtro == f and p.morado or p.grisosc)
        fx = fx + w + 3
    end
    local l = lista()
    local porPagina = COLS * FILAS
    local paginas = math.max(1, math.ceil(#l / porPagina))
    estado.pagina = math.max(1, math.min(estado.pagina, paginas))
    if #l == 0 then
        fuentes.texto(estado.todo and "AÚN NO HAY NINGUNA" or "NO TIENES NINGUNA DE ESTAS", x0, y0 + 120, 1, p.grisclaro, "center", PW)
    end
    for i = (estado.pagina - 1) * porPagina + 1, math.min(#l, estado.pagina * porPagina) do
        local k = i - (estado.pagina - 1) * porPagina - 1
        local e = l[i]
        local cx = x0 + 32 + (k % COLS) * 52
        local cy = y0 + 72 + math.floor(k / COLS) * 64
        if e.visto then
            fundario.miniatura(e.d.id, estado.esTop, cx, cy, 0.85)
        else
            -- la que falta: hueco con un ?
            muebles.rect(p.negro, cx - 16, cy - 22, 32, 44, 0.5)
            lg.setColor(p.grisosc)
            lg.rectangle("line", cx - 15.5, cy - 21.5, 31, 43)
            fuentes.texto("?", cx - 16, cy - 5, 2, p.gris, "center", 32)
        end
        if estado.actual == e.d.id then
            lg.setColor(p.amarillo)
            lg.rectangle("line", cx - 19.5, cy - 25.5, 39, 51)
        end
        fuentes.texto(e.visto and e.d.corto or "???", cx - 26, cy + 25, 1, e.visto and e.d.color or p.gris, "center", 52)
        if not estado.todo or e.n > 0 then
            fuentes.texto("X" .. e.n, cx - 26, cy + 32, 1, e.n > 0 and p.blanco or p.gris, "center", 52)
        end
        local zid = "fsel_id_" .. e.d.id
        ui.zona(zid, cx - 20, cy - 26, 40, 64)
        if ui.encima == zid then
            local lineas = { { e.visto and e.d.de or "AÚN NO LA TIENES", p.grisclaro } }
            if e.visto then table.insert(lineas, { "SOLO DE ESTILO: NO CAMBIA EL PRECIO", p.gris }) end
            if not estado.todo then table.insert(lineas, { "TÓCALA PARA PONERLA ARRIBA", p.lima }) end
            ui.tooltip(e.visto and e.d.nombre or "???", e.visto and e.d.color or p.gris, lineas)
        end
    end
    if paginas > 1 then
        ui.boton("fsel_pag_-1", "<", x0 + 8, y0 + PH - 18, 14, 12, p.azul, estado.pagina > 1)
        fuentes.texto(estado.pagina .. "/" .. paginas, x0, y0 + PH - 15, 1, p.blanco, "center", PW)
        ui.boton("fsel_pag_1", ">", x0 + PW - 22, y0 + PH - 18, 14, 12, p.azul, estado.pagina < paginas)
    end
    if estado.todo then
        fuentes.texto("SOLO DE ESTILO: NO CAMBIAN EL PRECIO DE LA CARTA. VUELVEN A SU CAJA AL VENDERLA", x0, y0 + PH - 28, 1, p.gris, "center", PW)
    end
end

local function click(id)
    if id == "fsel_cerrar" then
        ui.overlay = nil
    elseif id == "fsel_fundas" or id == "fsel_tops" then
        estado.esTop, estado.pagina = id == "fsel_tops", 1
    elseif id:match("^fsel_f_") then
        estado.filtro, estado.pagina = id:sub(8), 1
    elseif id:match("^fsel_pag_") then
        estado.pagina = estado.pagina + tonumber(id:sub(10))
    elseif id:match("^fsel_id_") then
        if estado.elegir then
            estado.elegir(id:sub(9))
            ui.overlay = nil
        end
    end
end

-- rejilla para elegir el diseno de arriba de una cajita (solo los que tienes)
function fundario.elegir(esTop, actual, alElegir)
    estado = { esTop = esTop, filtro = "todas", pagina = 1, elegir = alElegir, actual = actual }
    ui.overlay = { dibujar = dibujar, click = click }
end

-- el fundario: todos los disenos, conseguidos o no
function fundario.abrir()
    estado = { esTop = false, filtro = "todas", pagina = 1, todo = true }
    ui.overlay = { dibujar = dibujar, click = click }
end

return fundario
