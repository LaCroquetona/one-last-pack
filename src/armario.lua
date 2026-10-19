local todas = require "datos.cartas"
local sets = require "datos.sets"
local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
local datosMercado = require "datos.mercado"
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local carta = require "src.carta"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local lg = love.graphics

local armario = {}

local modo = "copias"
local setActivo = sets.lista[1].id
local pliegos = {}   -- pagina del album abierta en cada set
local seleccion
local edicion = false   -- edicion de la carta elegida con la que se vende y publica
local rarezaAbierta
local agarre = { x = 0, y = 0 }   -- donde se cogio la carta, para la mesa
local zMesa = 0

local POR_PAGINA = 9
local AREA_X = 134
local CW, CH = carta.ANCHO, carta.ALTO
local MESA = { x = 132, y = 26, w = 502, h = 328 }
local FUNDAS = { x = 6, y = 296, w = 118, h = 34 }

local function delSet()
    return partida.cartasDe(setActivo)
end

local function totalPliegos()
    return math.ceil(math.ceil(#delSet() / POR_PAGINA) / 2)
end

local function pliego()
    return pliegos[setActivo] or 1
end

-- ids de partida.orden que son del set activo y tienes
local function ordenVisible()
    local lista = {}
    for _, id in ipairs(partida.orden) do
        local def = partida.carta(id)
        if def and def.set == setActivo and partida.copias(id) > 0 then table.insert(lista, id) end
    end
    return lista
end

local function enFunda(id)
    return partida.enfundadas(id) > 0
end

-- sello de 1ª edicion si tienes alguna copia que lo sea
local function extraCarta(id)
    return { primera = partida.deEdicion(id, true) > 0 }
end

-- edicion de cada copia del monton, las de 1ª arriba
local function edicionesPila(id)
    local lista = {}
    local p1 = partida.deEdicion(id, true)
    for i = 1, math.min(4, partida.copias(id)) do lista[i] = i <= p1 end
    return { ediciones = lista }
end

local function hayAmbas(id)
    return partida.deEdicion(id, true) > 0 and partida.deEdicion(id, false) > 0
end

local function tooltipCarta(def)
    local r = rarezas[def.rareza]
    local n = partida.copias(def.id)
    local primera = partida.deEdicion(def.id, false) == 0
    local cambio = mercado.cambio(def.id, 7, primera)
    local copias = "Copias: " .. n
    if partida.enfundadas(def.id) > 0 then copias = copias .. " (" .. partida.enfundadas(def.id) .. " en funda)" end
    local lineas = {
        { r.nombre .. (def.chase and "  -  CHASE" or ""), r.color },
        { copias },
    }
    if hayAmbas(def.id) then
        table.insert(lineas, { "1ª edición: " .. partida.deEdicion(def.id, true) .. "  -  " .. ui.dinero(mercado.valor(def.id, true)), p.amarillo })
    end
    table.insert(lineas, { "Valor " .. ui.dinero(mercado.valor(def.id, primera)) .. "  " .. ui.porcentaje(cambio) .. " en 7 días", ui.colorCambio(cambio) })
    table.insert(lineas, { "Venta rápida " .. ui.dinero(mercado.ventaRapida(def.id, primera)), p.amarillo })
    if partida.publicadas(def.id) > 0 then
        table.insert(lineas, { "En el móvil: " .. partida.publicadas(def.id), p.celeste })
    end
    table.insert(lineas, { "Click: ver  -  Arrastra: mover", p.gris })
    ui.tooltip(def.nombre, r.color, lineas)
end

local function tengo(filtro)
    local lista = {}
    for _, def in ipairs(delSet()) do
        if partida.copias(def.id) > 0 and (not filtro or def.rareza == filtro) then
            table.insert(lista, def)
        end
    end
    return lista
end

local COLUMNAS, FILAS = 11, 5

local function posRejilla(k, x0, y0)
    local col = (k - 1) % COLUMNAS
    local fila = math.floor((k - 1) / COLUMNAS)
    return x0 + col * 44 + 20, y0 + fila * 58 + 31
end

local function pilaRejilla(def, cx, cy, arrastrada)
    local id = "c" .. def.id
    if arrastrada then
        lg.setColor(1, 1, 1, 0.08)
        lg.rectangle("fill", cx - CW / 2, cy - CH / 2, CW, CH)
        lg.setColor(1, 1, 1)
        return
    end
    if seleccion == def.id then
        lg.setColor(p.amarillo)
        lg.rectangle("line", cx - CW / 2 - 2.5, cy - CH / 2 - 7.5, CW + 9, CH + 11)
    end
    carta.pila({ def }, cx, cy, 1, partida.copias(def.id), ui.hoverCarta(id, cx, cy, CW, CH), enFunda(def.id), edicionesPila(def.id))
    if partida.publicadas(def.id) > 0 then
        lg.setColor(p.celeste)
        lg.rectangle("fill", cx - CW / 2, cy - CH / 2 - 3, 6, 3)
    end
    ui.zona(id, cx - CW / 2, cy - CH / 2 - 4, CW + 4, CH + 4)
    if ui.encima == id and not ui.arrastrando() then tooltipCarta(def) end
end

local function dibujarCopias()
    local lista = {}
    for _, id in ipairs(ordenVisible()) do
        table.insert(lista, partida.carta(id))
    end
    if #lista == 0 then
        fuentes.texto("AÚN NO TIENES CARTAS DE ESTE SET: COMPRA Y ABRE UN SOBRE", AREA_X, 170, 1, p.grisclaro, "center", 500)
        return
    end

    local cogida = ui.arrastrando()
    local encima
    for k = 1, math.min(#lista + 1, COLUMNAS * FILAS) do
        local cx, cy = posRejilla(k, AREA_X, 28)
        if cogida then
            local zid = "drop_pos" .. k
            ui.zona(zid, cx - 22, cy - 29, 44, 58)
            if ui.zonaEn(ui.mx, ui.my, "drop_pos") == zid then
                lg.setColor(p.amarillo)
                lg.rectangle("fill", cx - CW / 2 - 4, cy - CH / 2, 2, CH)
            end
        end
        local def = lista[k]
        -- la que tiene el raton encima se pinta al final, para que su abanico quede por encima
        if def and ui.encima == "c" .. def.id then
            encima = { def = def, x = cx, y = cy }
        elseif def then
            pilaRejilla(def, cx, cy, cogida == "c" .. def.id)
        end
    end
    if encima then pilaRejilla(encima.def, encima.x, encima.y, cogida == "c" .. encima.def.id) end
    if #lista > COLUMNAS * FILAS then
        fuentes.texto("+" .. (#lista - COLUMNAS * FILAS) .. " MÁS", AREA_X, 326, 1, p.grisclaro, "center", 490)
    end
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
        local total = 0
        for _, def in ipairs(delSet()) do
            if def.rareza == r.id then total = total + 1 end
        end
        local copias = 0
        for _, def in ipairs(lista) do copias = copias + partida.copias(def.id) end

        if #lista > 0 then
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
        fuentes.texto(#lista .. "/" .. total, cx - 40, 150, 1, p.grisclaro, "center", 80)
        if rarezaAbierta == r.id then
            lg.setColor(r.color)
            lg.rectangle("fill", cx - 20, 159, 40, 2)
        end
        if ui.encima == id then
            ui.tooltip(r.nombre, r.color, {
                { #lista .. " de " .. total .. " distintas" },
                { copias .. " cartas en total" },
            })
        end
    end

    if not rarezaAbierta then return end
    local cogida = ui.arrastrando()
    local encima
    for k, def in ipairs(tengo(rarezaAbierta)) do
        if k > COLUMNAS * 3 then break end
        local cx, cy = posRejilla(k, AREA_X, 166)
        if ui.encima == "c" .. def.id then
            encima = { def = def, x = cx, y = cy }
        else
            pilaRejilla(def, cx, cy, cogida == "c" .. def.id)
        end
    end
    if encima then pilaRejilla(encima.def, encima.x, encima.y, cogida == "c" .. encima.def.id) end
end

local function dibujarPagina(num, x, y)
    ui.caja(x, y, 236, 324, p.grisosc)
    for j = 1, POR_PAGINA do
        local def = delSet()[(num - 1) * POR_PAGINA + j]
        if def then
            local col = (j - 1) % 3
            local fila = math.floor((j - 1) / 3)
            local cx = x + 44 + col * 76
            local cy = y + 58 + fila * 104
            local n = partida.copias(def.id)
            if n > 0 then
                local id = "a" .. def.id
                carta.dibujar(def, cx, cy, 2, 2, 0, true, ui.hoverCarta(id, cx, cy, CW * 2, CH * 2), enFunda(def.id), extraCarta(def.id))
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
    local izq = pliego() * 2 - 1
    dibujarPagina(izq, 146, 28)
    if izq * POR_PAGINA < #delSet() then dibujarPagina(izq + 1, 392, 28) end
    lg.setColor(p.grisclaro)
    for _, y in ipairs({ 60, 140, 220, 300 }) do
        lg.circle("line", 387, y, 4)
    end
    lg.setColor(1, 1, 1)
end

-- sitio de partida en la mesa para las cartas que aun no has movido
local function sitioMesa(id)
    local s = partida.mesa[id]
    if s then return s end
    local rng = love.math.newRandomGenerator(id * 31 + 5)
    local k = 0
    for i, v in ipairs(ordenVisible()) do
        if v == id then k = i break end
    end
    local col, fila = (k - 1) % 8, math.floor((k - 1) / 8)
    s = {
        x = MESA.x + 50 + col * 58 + rng:random(-8, 8),
        y = MESA.y + 60 + fila * 70 + rng:random(-8, 8),
        r = (rng:random() - 0.5) * 0.25,
        z = 0,
    }
    partida.mesa[id] = s
    return s
end

local function dibujarMesa()
    lg.setColor(p.verdeosc)
    lg.rectangle("fill", MESA.x, MESA.y, MESA.w, MESA.h)
    lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.25)
    for y = MESA.y + 2, MESA.y + MESA.h - 2, 6 do
        for x = MESA.x + 2 + (y % 12 == 2 and 3 or 0), MESA.x + MESA.w - 2, 6 do
            lg.rectangle("fill", x, y, 1, 1)
        end
    end
    lg.setColor(p.negro)
    lg.rectangle("line", MESA.x + 0.5, MESA.y + 0.5, MESA.w - 1, MESA.h - 1)

    local lista = ordenVisible()
    if #lista == 0 then
        fuentes.texto("LA MESA ESTÁ VACÍA", MESA.x, MESA.y + MESA.h / 2, 1, p.lima, "center", MESA.w)
        return
    end
    table.sort(lista, function(a, b) return (sitioMesa(a).z or 0) < (sitioMesa(b).z or 0) end)

    local cogida = ui.arrastrando()
    for _, id in ipairs(lista) do
        local zid = "m" .. id
        if cogida ~= zid then
            local s = sitioMesa(id)
            local def = partida.carta(id)
            carta.dibujar(def, s.x, s.y, 2, 2, s.r or 0, true, ui.hoverCarta(zid, s.x, s.y, CW * 2, CH * 2), enFunda(id), extraCarta(id))
            if partida.copias(id) > 1 then carta.contador(partida.copias(id), s.x + CW, s.y + CH) end
            ui.zona(zid, s.x - CW, s.y - CH, CW * 2, CH * 2)
            if ui.encima == zid and not cogida then tooltipCarta(def) end
        end
    end
    fuentes.texto("ARRASTRA LAS CARTAS COMO QUIERAS", MESA.x, MESA.y + MESA.h - 10, 1, p.verde, "center", MESA.w)
end

local function panelSobres()
    ui.caja(6, 44, 118, 50)
    local fila = 0
    for _, tipo in ipairs(sobres.lista) do
        if mercado.salido(tipo.set) and fila < 4 then
            local y = 47 + fila * 11
            fila = fila + 1
            local n = partida.sobres(tipo.id)
            local p1 = partida.sobres(tipo.id, true)
            lg.setColor(tipo.colores.base)
            lg.rectangle("fill", 10, y + 1, 6, 8)
            lg.setColor(tipo.colores.rayas)
            lg.rectangle("fill", 10, y + 4, 6, 2)
            fuentes.texto(sets[tipo.set].codigo, 20, y + 3, 1, p.blanco)
            fuentes.texto("X" .. n, 34, y + 3, 1, n > 0 and p.amarillo or p.gris)
            if p1 > 0 and p1 < n then fuentes.texto("(" .. p1 .. " 1ª)", 50, y + 3, 1, p.amarillo) end
            ui.boton("abrir_" .. tipo.id, "ABRIR", 82, y, 38, 10, p.azul, n > 0)
        end
    end
end

local function panelSeleccion()
    ui.caja(6, 98, 118, 194)
    if not seleccion or partida.copias(seleccion) == 0 then
        seleccion = nil
        fuentes.texto("PULSA UNA CARTA", 6, 180, 1, p.grisclaro, "center", 118)
        fuentes.texto("PARA VERLA", 6, 188, 1, p.grisclaro, "center", 118)
        return
    end
    local def = partida.carta(seleccion)
    local r = rarezas[def.rareza]
    local n = partida.copias(def.id)
    if partida.deEdicion(def.id, edicion) == 0 then edicion = not edicion end
    local libres = partida.libres(def.id, edicion)
    carta.dibujar(def, 65, 144, 2, 2, 0, true, ui.hoverCarta("sel", 65, 144, CW * 2, CH * 2), enFunda(def.id), { primera = edicion })
    ui.zona("sel", 65 - CW, 144 - CH, CW * 2, CH * 2)

    fuentes.texto(def.nombre, 6, 198, 1, p.blanco, "center", 118)
    fuentes.texto(r.nombre .. (def.chase and " - CHASE" or ""), 6, 206, 1, r.color, "center", 118)
    fuentes.texto("COPIAS " .. n, 12, 215, 1, p.grisclaro)
    local extra = {}
    if partida.enfundadas(def.id) > 0 then table.insert(extra, "FUNDA " .. partida.enfundadas(def.id)) end
    if partida.publicadas(def.id) > 0 then table.insert(extra, "MÓVIL " .. partida.publicadas(def.id)) end
    fuentes.texto(table.concat(extra, " "), 12, 215, 1, p.cian, "right", 106)
    local cambio = mercado.cambio(def.id, 7, edicion)
    fuentes.texto("VALOR " .. ui.dinero(mercado.valor(def.id, edicion)), 12, 223, 1, p.amarillo)
    fuentes.texto(ui.porcentaje(cambio), 12, 223, 1, ui.colorCambio(cambio), "right", 106)

    if hayAmbas(def.id) then
        ui.boton("ed_normal", "NORMAL " .. partida.deEdicion(def.id, false), 12, 231, 52, 10, not edicion and p.azul or p.grisosc)
        ui.boton("ed_primera", "1ª ED " .. partida.deEdicion(def.id, true), 66, 231, 52, 10, edicion and p.amarillo or p.grisosc)
    elseif edicion then
        fuentes.texto("1ª EDICIÓN", 12, 233, 1, p.amarillo)
    end

    ui.boton("vender1", "VENDER 1  +" .. ui.dinero(mercado.ventaRapida(def.id, edicion)), 12, 244, 106, 13, n == 1 and p.rojo or p.naranja, libres > 0)
    local lleno = #partida.anuncios >= datosMercado.anuncios.maximo
    ui.boton("publicar", lleno and "MÓVIL LLENO" or "PUBLICAR", 12, 259, 60, 13, p.celeste, libres > 0 and not lleno)
    ui.boton("ficha", "FICHA", 74, 259, 44, 13, p.azul)
    ui.boton("enfundar", "ENFUNDAR", 12, 274, 52, 13, p.verdeosc, partida.enfundadas(def.id) < n)
    ui.boton("desenfundar", "QUITAR FUNDA", 66, 274, 52, 13, p.gris, partida.enfundadas(def.id) > 0)
end

local function panelFundas()
    local cogida = ui.arrastrando()
    local encima = cogida and ui.zonaEn(ui.mx, ui.my, "drop_funda")
    ui.caja(FUNDAS.x, FUNDAS.y, FUNDAS.w, FUNDAS.h, encima and p.verdeosc or p.grisosc)
    if cogida then ui.zona("drop_funda", FUNDAS.x, FUNDAS.y, FUNDAS.w, FUNDAS.h) end

    -- montoncito de fundas vacias
    for i = 2, 0, -1 do
        lg.setColor(1, 1, 1, 0.1)
        lg.rectangle("fill", FUNDAS.x + 6 + i * 2, FUNDAS.y + 5 - i, 16, 22)
        lg.setColor(p.cian[1], p.cian[2], p.cian[3], 0.7)
        lg.rectangle("line", FUNDAS.x + 6.5 + i * 2, FUNDAS.y + 5.5 - i, 15, 21)
    end
    fuentes.texto("FUNDAS " .. partida.fundasLibres, FUNDAS.x + 30, FUNDAS.y + 4, 1, partida.fundasLibres > 0 and p.blanco or p.rojo)
    fuentes.texto(cogida and "SUÉLTALA AQUÍ" or "ARRASTRA AQUÍ", FUNDAS.x + 30, FUNDAS.y + 12, 1, cogida and p.lima or p.grisclaro)
    local auto = partida.opciones.autoFundas
    ui.boton("autoFundas", auto and "AUTO RARAS: SÍ" or "AUTO RARAS: NO", FUNDAS.x + 30, FUNDAS.y + 20, 82, 11, auto and p.verde or p.gris)
end

local function botonesVenta()
    local repes, valorRepes = partida.lote(false)
    local todas = partida.lote(true)
    ui.boton("venderRepes", "REPES +" .. ui.dinero(valorRepes), 6, 336, 57, 16, p.naranja, repes > 0)
    if ui.encima == "venderRepes" then
        local lineas = { { "Vende todas las copias menos una de cada carta" }, { "Las fundas de las repes vuelven a la caja" } }
        local enMovil = partida.repesPublicadas()
        if enMovil > 0 then table.insert(lineas, { enMovil .. " repes no se venden: están en el móvil", p.celeste }) end
        ui.tooltip(repes .. " cartas por " .. ui.dinero(valorRepes), p.amarillo, lineas)
    end
    ui.boton("venderTodo", "VENDER TODO", 67, 336, 57, 16, p.rojo, todas > 0)
end

local function panelAlbum()
    ui.caja(6, 98, 118, 194)
    local paginas = math.ceil(#delSet() / POR_PAGINA)
    local izq = pliego() * 2 - 1
    local der = math.min(izq + 1, paginas)
    fuentes.texto("PÁGINAS " .. izq .. "-" .. der .. " DE " .. paginas, 6, 106, 1, p.blanco, "center", 118)
    ui.boton("pagAnt", "<", 12, 118, 50, 14, p.azul, pliego() > 1)
    ui.boton("pagSig", ">", 68, 118, 50, 14, p.azul, pliego() < totalPliegos())

    local y = 146
    for _, r in ipairs(rarezas.lista) do
        local total, tiene = 0, 0
        for _, def in ipairs(delSet()) do
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
    fuentes.texto(partida.distintas(setActivo) .. "/" .. #delSet(), 14, y, 1, p.blanco, "right", 98)
end

local function dibujarCogida()
    local cogida = ui.arrastrando()
    if not cogida then return end
    local id = tonumber(cogida:sub(2))
    local def = partida.carta(id)
    if not def then return end
    local escala = cogida:sub(1, 1) == "m" and 2 or 1
    local x, y = ui.mx, ui.my
    if escala == 2 then x, y = x - agarre.x, y - agarre.y end
    local balanceo = math.sin(love.timer.getTime() * 6) * 0.04
    carta.dibujar(def, x, y, escala * 1.08, escala * 1.08, balanceo, true, { kx = 0, ky = 0, brillo = 1, lx = 0, ly = 0 }, enFunda(id))
end

function armario.dibujar()
    ui.boton("modo_copias", "COPIAS", 6, 26, 28, 14, modo == "copias" and p.azul or p.gris)
    ui.boton("modo_rareza", "RAREZA", 36, 26, 28, 14, modo == "rareza" and p.azul or p.gris)
    ui.boton("modo_album", "ÁLBUM", 66, 26, 28, 14, modo == "album" and p.azul or p.gris)
    ui.boton("modo_mesa", "MESA", 96, 26, 28, 14, modo == "mesa" and p.azul or p.gris)

    panelSobres()
    if modo == "album" then panelAlbum() else panelSeleccion() end
    panelFundas()
    botonesVenta()

    if modo == "copias" then
        dibujarCopias()
    elseif modo == "rareza" then
        dibujarRareza()
    elseif modo == "album" then
        dibujarAlbum()
    else
        dibujarMesa()
    end
    dibujarCogida()
end

local function cobrar(ganado)
    if ganado <= 0 then return end
    sonido.tocar("moneda")
    fx.texto(ui.mx, ui.my - 10, "+" .. ui.dinero(ganado), p.amarillo)
    fx.explosion(ui.mx, ui.my, p.amarillo, 10 + math.min(40, math.floor(ganado / 20)), 90)
    partida.guardar()
end

local function cambiarPliego(d)
    pliegos[setActivo] = math.max(1, math.min(totalPliegos(), pliego() + d))
end

local function enfundar(id)
    if partida.fundasLibres <= 0 then
        sonido.tocar("latido")
        fx.texto(ui.mx, ui.my - 10, "SIN FUNDAS: CÓMPRALAS EN LA TIENDA", p.rojo)
        return
    end
    if partida.enfundar(id) then
        sonido.tocar("nueva")
        fx.explosion(ui.mx, ui.my, p.cian, 14, 70)
        partida.guardar()
    end
end

local function venderUna()
    local def = partida.carta(seleccion)
    local id, ed = seleccion, edicion
    if partida.copias(id) == 1 then
        ui.confirmar("¿VENDER LA ÚLTIMA?", {
            "ES TU ÚNICA COPIA DE " .. def.nombre:upper(),
            "DESAPARECERÁ DEL ÁLBUM",
        }, "SÍ, VENDERLA", function() cobrar(partida.vender(id, 1, ed)) end)
        return
    end
    cobrar(partida.vender(id, 1, ed))
end

local function publicar()
    local def = partida.carta(seleccion)
    local id, ed = seleccion, edicion
    local function hacer()
        if partida.publicar(id, ed) then
            sonido.tocar("click")
            fx.texto(ui.mx, ui.my - 10, "PUBLICADA", p.celeste)
            partida.guardar()
        end
    end
    if partida.copias(id) == 1 then
        ui.confirmar("¿PUBLICAR LA ÚLTIMA?", {
            "ES TU ÚNICA COPIA DE " .. def.nombre:upper(),
            "SI ALGUIEN LA COMPRA, LA PIERDES DEL ÁLBUM",
        }, "SÍ, PUBLICARLA", hacer)
        return
    end
    hacer()
end

local function venderTodo()
    local n, valor = partida.lote(true)
    local ultimas = 0
    for _, def in ipairs(todas) do
        local c = partida.copias(def.id)
        if c > 0 and partida.libres(def.id) - partida.enfundadas(def.id) >= c then ultimas = ultimas + 1 end
    end
    local lineas = { "VAS A VENDER " .. n .. " CARTAS DE TODOS LOS SETS POR " .. ui.dinero(valor) }
    if ultimas > 0 then table.insert(lineas, ultimas .. " SON TU ÚLTIMA COPIA Y SE IRÁN DEL ÁLBUM") end
    table.insert(lineas, "LAS ENFUNDADAS Y LAS DEL MÓVIL NO SE VENDEN")
    ui.confirmar("¿VENDER TODO?", lineas, "SÍ, VENDER TODO", function() cobrar(partida.venderLote(true)) end)
end

function armario.click(id)
    if id:match("^modo_") then
        modo = id:sub(6)
    elseif id:match("^abrir_") then
        nav.abrir(id:sub(7))
    elseif id:match("^set_") then
        setActivo = id:sub(5)
        rarezaAbierta = nil
    elseif id == "tienda" then
        nav.ir("tienda")
    elseif id == "venderRepes" then
        cobrar(partida.venderLote(false))
    elseif id == "venderTodo" then
        venderTodo()
    elseif id == "vender1" then
        venderUna()
    elseif id == "publicar" then
        publicar()
    elseif id == "enfundar" then
        enfundar(seleccion)
    elseif id == "desenfundar" then
        if partida.desenfundar(seleccion) then partida.guardar() end
    elseif id == "ed_normal" or id == "ed_primera" then
        edicion = id == "ed_primera"
    elseif id == "ficha" then
        nav.ficha(seleccion, edicion)
    elseif id == "autoFundas" then
        partida.opciones.autoFundas = not partida.opciones.autoFundas
        partida.guardar()
    elseif id == "pagAnt" then
        cambiarPliego(-1)
    elseif id == "pagSig" then
        cambiarPliego(1)
    elseif id:match("^[cma]%d") then
        armario.seleccionar(tonumber(id:sub(2)))
        if modo == "album" then modo = "copias" end
    elseif id:match("^r_") then
        rarezaAbierta = id:sub(3)
    end
end

-- se pueden arrastrar las cartas de las rejillas y de la mesa
function armario.coger(id, x, y)
    if not id or not id:match("^[cm]%d") then return false end
    local cid = tonumber(id:sub(2))
    if id:sub(1, 1) == "m" then
        local s = sitioMesa(cid)
        agarre.x, agarre.y = x - s.x, y - s.y
        zMesa = zMesa + 1
        s.z = zMesa
    end
    ui.cogerSi(id, x, y)
    return true
end

function armario.soltar(c, x, y)
    if not c.moviendo then
        armario.click(c.id)
        return
    end
    local cid = tonumber(c.id:sub(2))
    if ui.zonaEn(x, y, "drop_funda") then
        enfundar(cid)
        return
    end
    if c.id:sub(1, 1) == "m" then
        local s = sitioMesa(cid)
        s.x = math.max(MESA.x + CW, math.min(MESA.x + MESA.w - CW, x - agarre.x))
        s.y = math.max(MESA.y + CH, math.min(MESA.y + MESA.h - CH, y - agarre.y))
        s.r = (love.math.random() - 0.5) * 0.2
        sonido.tocar("giro")
        partida.guardar()
        return
    end
    local destino = ui.zonaEn(x, y, "drop_pos")
    if destino and modo == "copias" then
        local k = tonumber(destino:sub(9))
        local actual
        local lista = ordenVisible()
        for i, v in ipairs(lista) do
            if v == cid then actual = i end
        end
        if not actual then return end
        if k > actual then k = k - 1 end
        table.remove(lista, actual)
        table.insert(lista, math.min(k, #lista + 1), cid)
        -- las de los otros sets se quedan detras, en su orden
        local visibles = {}
        for _, v in ipairs(lista) do visibles[v] = true end
        for _, v in ipairs(partida.orden) do
            if not visibles[v] and partida.copias(v) > 0 then table.insert(lista, v) end
        end
        partida.orden = lista
        sonido.tocar("giro")
        partida.guardar()
    end
end

function armario.tecla(tecla)
    if modo ~= "album" then return end
    if tecla == "left" then cambiarPliego(-1) end
    if tecla == "right" then cambiarPliego(1) end
end

-- pestañas de los sets que ya han salido, en la barra de arriba
function armario.pestanas()
    if not mercado.salido(setActivo) then setActivo = sets.lista[1].id end
    for i, set in ipairs(mercado.setsSalidos()) do
        local texto = set.codigo .. " " .. partida.distintas(set.id) .. "/" .. #partida.cartasDe(set.id)
        ui.boton("set_" .. set.id, texto, 210 + (i - 1) * 56, 3, 53, 14, set.id == setActivo and p.azul or p.grisosc)
    end
end

function armario.seleccionar(id)
    seleccion = id
    edicion = partida.deEdicion(id, false) == 0
    local def = partida.carta(id)
    if def then setActivo = def.set end
end

return armario
