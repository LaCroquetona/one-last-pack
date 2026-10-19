local cartas = require "datos.cartas"
local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local partida = require "src.partida"
local carta = require "src.carta"
local sobre = require "src.sobre"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local lg = love.graphics

local armario = {}

local modo = "copias"
local seleccion
local rarezaAbierta
local pliego = 1   -- dos paginas del album a la vez

local POR_PAGINA = 9
local AREA_X = 134
local CW, CH = carta.ANCHO, carta.ALTO

local function totalPliegos()
    return math.ceil(math.ceil(#cartas / POR_PAGINA) / 2)
end

local function tooltipCarta(def)
    local r = rarezas[def.rareza]
    local n = partida.copias(def.id)
    ui.tooltip(def.nombre, r.color, {
        { r.nombre, r.color },
        { "Copias: " .. n },
        { "Vale " .. ui.dinero(r.precio) .. " cada una", p.amarillo },
        n > 1 and { "Click para vender repes", p.grisclaro } or { "Única: no se vende", p.gris },
    })
end

-- un monton por carta distinta, en rejilla
local function rejilla(defs, x0, y0, columnas, filas)
    for k, def in ipairs(defs) do
        local col = (k - 1) % columnas
        local fila = math.floor((k - 1) / columnas)
        if fila >= filas then return end
        local cx = x0 + col * 44 + 20
        local cy = y0 + fila * 58 + 31
        local id = "c" .. def.id
        if seleccion == def.id then
            lg.setColor(p.amarillo)
            lg.rectangle("line", cx - CW / 2 - 2.5, cy - CH / 2 - 7.5, CW + 9, CH + 11)
        end
        carta.pila({ def }, cx, cy, 1, partida.copias(def.id), ui.hoverCarta(id, cx, cy, CW, CH))
        ui.zona(id, cx - CW / 2, cy - CH / 2 - 4, CW + 4, CH + 4)
        if ui.encima == id then tooltipCarta(def) end
    end
end

local function tengo(filtro)
    local lista = {}
    for _, def in ipairs(cartas) do
        if partida.copias(def.id) > 0 and (not filtro or def.rareza == filtro) then
            table.insert(lista, def)
        end
    end
    return lista
end

local function dibujarCopias()
    local lista = tengo()
    if #lista == 0 then
        fuentes.texto("AÚN NO TIENES CARTAS: ABRE UN SOBRE", AREA_X, 170, 1, p.grisclaro, "center", 500)
        return
    end
    rejilla(lista, AREA_X, 28, 11, 5)
end

local function dibujarRareza()
    if not rarezaAbierta then
        for _, r in ipairs(rarezas.lista) do
            if #tengo(r.id) > 0 then
                rarezaAbierta = r.id
                break
            end
        end
    end

    for i, r in ipairs(rarezas.lista) do
        local cx, cy = AREA_X + 40 + (i - 1) * 82, 86
        local lista = tengo(r.id)
        local id = "r_" .. r.id
        local total, distintas = 0, 0
        for _, def in ipairs(cartas) do
            if def.rareza == r.id then total = total + 1 end
        end
        local copias = 0
        for _, def in ipairs(lista) do copias = copias + partida.copias(def.id) end
        distintas = #lista

        if distintas > 0 then
            -- arriba del monton, las que mas copias tienen
            table.sort(lista, function(a, b) return partida.copias(a.id) > partida.copias(b.id) end)
            carta.pila(lista, cx, cy, 2, copias, ui.hoverCarta(id, cx, cy, CW * 2, CH * 2))
            ui.zona(id, cx - CW, cy - CH - 6, CW * 2 + 6, CH * 2 + 6)
        else
            lg.setColor(p.grisosc)
            lg.rectangle("line", cx - CW + 0.5, cy - CH + 0.5, CW * 2 - 1, CH * 2 - 1)
            fuentes.texto("?", cx - 20, cy - 5, 2, p.grisosc, "center", 40)
        end

        fuentes.texto(r.nombre, cx - 40, 142, 1, r.color, "center", 80)
        fuentes.texto(distintas .. "/" .. total, cx - 40, 150, 1, p.grisclaro, "center", 80)
        if rarezaAbierta == r.id then
            lg.setColor(r.color)
            lg.rectangle("fill", cx - 20, 159, 40, 2)
        end
        if ui.encima == id then
            ui.tooltip(r.nombre, r.color, {
                { distintas .. " de " .. total .. " distintas" },
                { copias .. " cartas en total" },
            })
        end
    end

    if rarezaAbierta then rejilla(tengo(rarezaAbierta), AREA_X, 166, 11, 3) end
end

local function dibujarPagina(num, x, y)
    ui.caja(x, y, 236, 324, p.grisosc)
    for j = 1, POR_PAGINA do
        local def = cartas[(num - 1) * POR_PAGINA + j]
        if def then
            local col = (j - 1) % 3
            local fila = math.floor((j - 1) / 3)
            local cx = x + 44 + col * 76
            local cy = y + 58 + fila * 104
            local n = partida.copias(def.id)
            if n > 0 then
                local id = "a" .. def.id
                carta.dibujar(def, cx, cy, 2, 2, 0, true, ui.hoverCarta(id, cx, cy, CW * 2, CH * 2))
                if n > 1 then carta.contador(n, cx + CW, cy + CH) end
                ui.zona(id, cx - CW, cy - CH, CW * 2, CH * 2)
                if ui.encima == id then tooltipCarta(def) end
            else
                carta.hueco(def, cx, cy, 2)
            end
        end
    end
end

local function dibujarAlbum()
    local izq = pliego * 2 - 1
    dibujarPagina(izq, 146, 28)
    if (izq) * POR_PAGINA < #cartas then dibujarPagina(izq + 1, 392, 28) end
    lg.setColor(p.grisclaro)
    for _, y in ipairs({ 60, 140, 220, 300 }) do
        lg.circle("line", 387, y, 4)
    end
    lg.setColor(1, 1, 1)
end

local function panelSeleccion()
    if not seleccion then
        fuentes.texto("PULSA UNA CARTA", 6, 200, 1, p.grisclaro, "center", 118)
        fuentes.texto("PARA VERLA Y", 6, 208, 1, p.grisclaro, "center", 118)
        fuentes.texto("VENDER REPES", 6, 216, 1, p.grisclaro, "center", 118)
        return
    end
    local def = partida.carta(seleccion)
    local r = rarezas[def.rareza]
    local n = partida.copias(def.id)
    carta.dibujar(def, 65, 182, 2, 2, 0, true, ui.hoverCarta("sel", 65, 182, CW * 2, CH * 2))
    ui.zona("sel", 65 - CW, 182 - CH, CW * 2, CH * 2)
    fuentes.texto(def.nombre, 6, 238, 1, p.blanco, "center", 118)
    fuentes.texto(r.nombre, 6, 246, 1, r.color, "center", 118)
    fuentes.texto("COPIAS: " .. n, 6, 256, 1, p.grisclaro, "center", 118)
    ui.boton("vender1", "VENDER 1 +" .. ui.dinero(r.precio), 12, 270, 106, 14, p.naranja, n > 1)
    ui.boton("venderSel", "VENDER " .. math.max(0, n - 1) .. " +" .. ui.dinero(r.precio * math.max(0, n - 1)), 12, 288, 106, 14, p.naranja, n > 1)
end

local function panelAlbum()
    local paginas = math.ceil(#cartas / POR_PAGINA)
    local izq = pliego * 2 - 1
    local der = math.min(izq + 1, paginas)
    fuentes.texto("PÁGINAS " .. izq .. "-" .. der .. " DE " .. paginas, 6, 132, 1, p.blanco, "center", 118)
    ui.boton("pagAnt", "<", 12, 144, 50, 14, p.azul, pliego > 1)
    ui.boton("pagSig", ">", 68, 144, 50, 14, p.azul, pliego < totalPliegos())

    local y = 172
    for _, r in ipairs(rarezas.lista) do
        local total, tiene = 0, 0
        for _, def in ipairs(cartas) do
            if def.rareza == r.id then
                total = total + 1
                if partida.copias(def.id) > 0 then tiene = tiene + 1 end
            end
        end
        fuentes.texto(r.nombre, 14, y, 1, r.color)
        fuentes.texto(tiene .. "/" .. total, 14, y, 1, tiene == total and p.amarillo or p.blanco, "right", 98)
        y = y + 10
    end
    y = y + 6
    fuentes.texto("TOTAL", 14, y, 1, p.blanco)
    fuentes.texto(partida.distintas() .. "/" .. #cartas, 14, y, 1, p.blanco, "right", 98)
end

function armario.dibujar()
    ui.boton("modo_copias", "COPIAS", 6, 26, 38, 14, modo == "copias" and p.azul or p.gris)
    ui.boton("modo_rareza", "RAREZA", 46, 26, 38, 14, modo == "rareza" and p.azul or p.gris)
    ui.boton("modo_album", "ÁLBUM", 86, 26, 38, 14, modo == "album" and p.azul or p.gris)

    ui.caja(6, 46, 118, 72)
    local guardados = partida.sobresGuardados()
    fuentes.texto("SOBRES", 12, 51, 1, p.blanco)
    for i = math.min(guardados, 3) - 1, 0, -1 do
        sobre.dibujar(32 + i * 2, 88 - i * 3, 1)
    end
    if guardados == 0 then
        lg.setColor(p.gris)
        lg.rectangle("line", 17.5, 66.5, 30, 44)
    elseif guardados > 1 then
        carta.contador(guardados, 50, 112)
    end
    ui.boton("abrir", "ABRIR", 62, 66, 56, 14, p.azul, guardados > 0)
    ui.boton("tienda", "TIENDA", 62, 86, 56, 14, p.verde)

    ui.caja(6, 124, 118, 206)
    if modo == "album" then panelAlbum() else panelSeleccion() end

    local repes, valor = partida.repetidas()
    ui.boton("venderRepes", "VENDER REPES +" .. ui.dinero(valor), 6, 336, 118, 16, p.naranja, repes > 0)

    if modo == "copias" then
        dibujarCopias()
    elseif modo == "rareza" then
        dibujarRareza()
    else
        dibujarAlbum()
    end
end

local function cobrar(ganado)
    if ganado <= 0 then return end
    sonido.tocar("moneda")
    fx.texto(ui.mx, ui.my - 10, "+" .. ui.dinero(ganado), p.amarillo)
    fx.explosion(ui.mx, ui.my, p.amarillo, 10 + math.min(40, math.floor(ganado / 10)), 90)
    partida.guardar()
end

local function cambiarPliego(d)
    pliego = math.max(1, math.min(totalPliegos(), pliego + d))
end

function armario.click(id)
    if id:match("^modo_") then
        modo = id:sub(6)
    elseif id == "abrir" then
        nav.abrir()
    elseif id == "tienda" then
        nav.ir("tienda")
    elseif id == "venderRepes" then
        cobrar(partida.venderRepes())
    elseif id == "vender1" then
        cobrar(partida.vender(seleccion, 1))
    elseif id == "venderSel" then
        cobrar(partida.vender(seleccion, math.huge))
    elseif id == "pagAnt" then
        cambiarPliego(-1)
    elseif id == "pagSig" then
        cambiarPliego(1)
    elseif id:match("^c%d") then
        seleccion = tonumber(id:sub(2))
    elseif id:match("^r_") then
        rarezaAbierta = id:sub(3)
    end
end

function armario.tecla(tecla)
    if modo ~= "album" then return end
    if tecla == "left" then cambiarPliego(-1) end
    if tecla == "right" then cambiarPliego(1) end
end

return armario
