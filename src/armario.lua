local sets = require "datos.sets"
local sobres = require "datos.sobres"
local rarezas = require "datos.rarezas"
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
local paginas = {}   -- pagina de la rejilla en cada modo
local seleccion      -- carta elegida (id)
local bandeja        -- carta cuyas copias se ven abajo (id)
local elegidas = {}  -- copias elegidas en la bandeja: elegidas[u] = true
local vista          -- copia que se enseña en grande (u)
local barrido        -- arrastrando por la bandeja: { valor = true | false }
local desplaza = 0   -- primera copia visible de la bandeja si no caben todas
local rarezaAbierta
local agarre = { x = 0, y = 0 }   -- donde se cogio la carta, para la mesa
local zMesa = 0
local mesaSel        -- copia de la mesa elegida (u)
local loteOp = { todo = false, primeras = false, fundas = false, set = false }

local POR_PAGINA = 9
local AREA_X = 134
local CW, CH = carta.ANCHO, carta.ALTO
local MESA = { x = 132, y = 26, w = 502, h = 328 }
local FUNDAS = { x = 6, y = 296, w = 118, h = 34 }
local B = { x = 132, y = 234, w = 502, h = 120 }   -- bandeja de copias
local COLUMNAS = 11

local function delSet()
    return partida.cartasDe(setActivo)
end

local function totalPliegos()
    return math.ceil(math.ceil(#delSet() / POR_PAGINA) / 2)
end

local function pliego()
    return pliegos[setActivo] or 1
end

local function bandejaAbierta()
    return bandeja and partida.copias(bandeja) > 0 and (modo == "copias" or modo == "rareza")
end

-- ids de partida.orden que son del set activo
local function ordenVisible()
    local lista = {}
    for _, id in ipairs(partida.orden) do
        if partida.carta(id).set == setActivo then table.insert(lista, id) end
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
    for i, c in ipairs(partida.lista(id)) do
        if i > 4 then break end
        lista[i] = c.p or false
    end
    return { ediciones = lista }
end

local function hayNormales(def)
    return mercado.hayNormales(def.set)
end

local function tooltipCarta(def)
    local r = rarezas[def.rareza]
    local n = partida.copias(def.id)
    local p1 = partida.deEdicion(def.id, true)
    local lineas = {
        { r.nombre .. (def.chase and "  -  CHASE" or ""), r.color },
        { "Copias: " .. n .. (p1 > 0 and p1 < n and ("  (" .. p1 .. " de 1ª edición)") or "") },
    }
    if partida.enfundadas(def.id) > 0 then table.insert(lineas, { "En funda: " .. partida.enfundadas(def.id), p.cian }) end
    if partida.publicadas(def.id) > 0 then table.insert(lineas, { "En el móvil: " .. partida.publicadas(def.id), p.celeste }) end
    if hayNormales(def) then
        local c0 = mercado.cambio(def.id, 7, false)
        table.insert(lineas, { "Normal " .. ui.dinero(mercado.valor(def.id, false)) .. "  " .. ui.porcentaje(c0), ui.colorCambio(c0) })
    end
    local c1 = mercado.cambio(def.id, 7, true)
    table.insert(lineas, { "1ª ed. " .. ui.dinero(mercado.valor(def.id, true)) .. "  " .. ui.porcentaje(c1), ui.colorCambio(c1) })
    table.insert(lineas, { "Click: ver copias  -  Arrastra: mover", p.gris })
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

-- botones de pagina de una rejilla (solo si hace falta)
local function botonesPagina(clave, total, x, y)
    if total <= 1 then return end
    local pag = math.min(paginas[clave] or 1, total)
    ui.boton("pag_" .. clave .. "_-1", "<", x, y, 12, 9, p.azul, pag > 1)
    fuentes.texto(pag .. "/" .. total, x + 12, y + 2, 1, p.grisclaro, "center", 26)
    ui.boton("pag_" .. clave .. "_1", ">", x + 38, y, 12, 9, p.azul, pag < total)
end

-- pinta una rejilla de montones paginada; con reordenar se pueden soltar cartas entre ellas
local function rejilla(clave, lista, y0, filas, reordenar, xPag, yPag)
    local porPagina = COLUMNAS * filas
    local total = math.max(1, math.ceil(#lista / porPagina))
    paginas[clave] = math.min(paginas[clave] or 1, total)
    local inicio = (paginas[clave] - 1) * porPagina
    botonesPagina(clave, total, xPag, yPag)

    local cogida = ui.arrastrando()
    local encima
    local hasta = math.min(porPagina, #lista - inicio + (reordenar and 1 or 0))
    for k = 1, hasta do
        local cx, cy = posRejilla(k, AREA_X, y0)
        if cogida and reordenar then
            local zid = "drop_pos" .. (inicio + k)
            ui.zona(zid, cx - 22, cy - 29, 44, 58)
            if ui.zonaEn(ui.mx, ui.my, "drop_pos") == zid then
                lg.setColor(p.amarillo)
                lg.rectangle("fill", cx - CW / 2 - 4, cy - CH / 2, 2, CH)
            end
        end
        local def = lista[inicio + k]
        -- la que tiene el raton encima se pinta al final, para que su abanico quede por encima
        if def and ui.encima == "c" .. def.id then
            encima = { def = def, x = cx, y = cy }
        elseif def then
            pilaRejilla(def, cx, cy, cogida == "c" .. def.id)
        end
    end
    if encima then pilaRejilla(encima.def, encima.x, encima.y, cogida == "c" .. encima.def.id) end
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
    rejilla("copias" .. setActivo, lista, 28, bandejaAbierta() and 3 or 5, true, 584, 23)
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
    rejilla("rareza" .. setActivo .. rarezaAbierta, tengo(rarezaAbierta), 166, bandejaAbierta() and 1 or 3, false, 584, 162)
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

-- mesa: solo las copias que has sacado

local function sitioMesa(s, k)
    if s.x then return s end
    local col, fila = (k - 1) % 5, math.floor((k - 1) / 5)
    s.x = MESA.x + 70 + col * 90 + love.math.random(-6, 6)
    s.y = MESA.y + 90 + fila * 130 + love.math.random(-6, 6)
    s.r = (love.math.random() - 0.5) * 0.15
    s.z = 0
    return s
end

local function entradaMesa(u)
    for _, s in ipairs(partida.mesa) do
        if s.u == u then return s end
    end
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

    if #partida.mesa == 0 then
        fuentes.texto("LA MESA ESTÁ VACÍA", MESA.x, MESA.y + MESA.h / 2 - 10, 2, p.lima, "center", MESA.w)
        fuentes.texto("ELIGE COPIAS EN COPIAS O RAREZA Y PULSA \"A LA MESA\"", MESA.x, MESA.y + MESA.h / 2 + 8, 1, p.verde, "center", MESA.w)
        return
    end
    local lista = {}
    for k, s in ipairs(partida.mesa) do table.insert(lista, sitioMesa(s, k)) end
    table.sort(lista, function(a, b) return (a.z or 0) < (b.z or 0) end)

    local cogida = ui.arrastrando()
    for _, s in ipairs(lista) do
        local zid = "m" .. s.u
        if cogida ~= zid then
            local def = partida.carta(s.id)
            local c = partida.copia(s.id, s.u)
            if mesaSel == s.u then
                lg.setColor(p.amarillo)
                lg.rectangle("line", s.x - CW - 3.5, s.y - CH - 3.5, CW * 2 + 7, CH * 2 + 7)
            end
            carta.dibujar(def, s.x, s.y, 2, 2, s.r or 0, true, ui.hoverCarta(zid, s.x, s.y, CW * 2, CH * 2), c.f, { primera = c.p })
            ui.zona(zid, s.x - CW, s.y - CH, CW * 2, CH * 2)
        end
    end
    fuentes.texto(#partida.mesa .. " DE " .. partida.MAX_MESA .. "  -  ARRÁSTRALAS COMO QUIERAS", MESA.x, MESA.y + MESA.h - 10, 1, p.verde, "center", MESA.w)
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

-- la copia que se ve en grande: la que tiene el raton, si no la elegida, si no la mejor
local function copiaVista(id)
    if vista then
        local c = partida.copia(id, vista)
        if c then return c end
    end
    for _, c in ipairs(partida.lista(id)) do
        if elegidas[c.u] then return c end
    end
    return partida.lista(id)[1]
end

local function lineaValor(def, primera, y)
    local cambio = mercado.cambio(def.id, 7, primera)
    fuentes.texto((primera and "1ª ED " or "NORMAL ") .. ui.dinero(mercado.valor(def.id, primera)), 12, y, 1, primera and p.amarillo or p.blanco)
    fuentes.texto(ui.porcentaje(cambio), 12, y, 1, ui.colorCambio(cambio), "right", 106)
end

local function panelSeleccion()
    ui.caja(6, 98, 118, 194)
    local id = seleccion
    if modo == "mesa" then
        local s = mesaSel and entradaMesa(mesaSel)
        id = s and s.id
    end
    if not id or partida.copias(id) == 0 then
        seleccion, mesaSel = nil, nil
        fuentes.texto(modo == "mesa" and "PULSA UNA CARTA" or "PULSA UN MONTÓN", 6, 180, 1, p.grisclaro, "center", 118)
        fuentes.texto(modo == "mesa" and "DE LA MESA" or "PARA VER SUS COPIAS", 6, 188, 1, p.grisclaro, "center", 118)
        return
    end
    local def = partida.carta(id)
    local r = rarezas[def.rareza]
    local c = modo == "mesa" and partida.copia(id, mesaSel) or copiaVista(id)
    carta.dibujar(def, 65, 144, 2, 2, 0, true, ui.hoverCarta("sel", 65, 144, CW * 2, CH * 2), c.f, { primera = c.p })
    ui.zona("sel", 65 - CW, 144 - CH, CW * 2, CH * 2)

    fuentes.texto(def.nombre, 6, 198, 1, p.blanco, "center", 118)
    fuentes.texto(r.nombre .. (def.chase and " - CHASE" or ""), 6, 206, 1, r.color, "center", 118)
    local n, p1 = partida.copias(id), partida.deEdicion(id, true)
    fuentes.texto("COPIAS " .. n, 12, 216, 1, p.grisclaro)
    if p1 > 0 then fuentes.texto("1ª ED " .. p1, 12, 216, 1, p.amarillo, "right", 106) end
    local y = 226
    if hayNormales(def) then
        lineaValor(def, false, y)
        y = y + 9
    end
    lineaValor(def, true, y)

    if modo == "mesa" then
        ui.boton("mesa_funda", c.f and "QUITAR FUNDA" or "ENFUNDAR", 12, 248, 106, 12, c.f and p.gris or p.verdeosc)
        ui.boton("mesa_vender", "VENDER +" .. ui.dinero(mercado.ventaRapida(id, c.p)), 12, 262, 106, 12, n == 1 and p.rojo or p.naranja)
        ui.boton("mesa_guardar", "GUARDAR EN ARMARIO", 12, 276, 106, 12, p.azul)
        return
    end
    if not bandejaAbierta() then
        ui.boton("verCopias", "VER COPIAS", 12, 262, 106, 13, p.azul)
    end
    ui.boton("ficha", "FICHA EN EL MÓVIL", 12, 277, 106, 12, p.morado)
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

local function panelAlbum()
    ui.caja(6, 98, 118, 194)
    local paginasAlbum = math.ceil(#delSet() / POR_PAGINA)
    local izq = pliego() * 2 - 1
    local der = math.min(izq + 1, paginasAlbum)
    fuentes.texto("PÁGINAS " .. izq .. "-" .. der .. " DE " .. paginasAlbum, 6, 106, 1, p.blanco, "center", 118)
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

-- bandeja: todas las copias de una carta, para elegir cuales

-- copias de la bandeja que cumplen algo y estan elegidas
local function elegidasQue(condicion)
    local lista = {}
    for _, c in ipairs(partida.lista(bandeja)) do
        if elegidas[c.u] and (not condicion or condicion(c)) then table.insert(lista, c) end
    end
    return lista
end

local function elegible(c)
    return not c.a
end

local function filtrar(f)
    elegidas = {}
    for _, c in ipairs(partida.lista(bandeja)) do
        if elegible(c) and f(c) then elegidas[c.u] = true end
    end
end

local FILTROS = {
    todas = function() return true end,
    primera = function(c) return c.p end,
    normal = function(c) return not c.p end,
    sinFunda = function(c) return not c.f end,
    ninguna = function() return false end,
}

-- donde va cada copia en la bandeja
local function geometriaBandeja(n)
    local ancho = B.w - 24
    local caben = math.floor((ancho - CW) / 6) + 1
    local visibles = math.min(n, caben)
    desplaza = math.max(0, math.min(desplaza, n - visibles))
    local paso = visibles > 1 and math.min(40, (ancho - CW) / (visibles - 1)) or 0
    -- siempre centradas: con pocas copias quedan en medio de la bandeja
    return B.x + B.w / 2 - (visibles - 1) * paso / 2, paso, visibles
end

local function tooltipCopia(def, c)
    local lineas = {
        { c.p and "1ª edición" or "Normal", c.p and p.amarillo or p.blanco },
        { "Valor " .. ui.dinero(mercado.valor(def.id, c.p)), p.amarillo },
    }
    if c.f then table.insert(lineas, { "En funda", p.cian }) end
    if c.a then table.insert(lineas, { "Publicada en el móvil", p.celeste }) end
    if c.m then table.insert(lineas, { "En la mesa", p.lima }) end
    ui.tooltip(def.nombre, rarezas[def.rareza].color, lineas)
end

local function dibujarBandeja()
    local id = bandeja
    local def = partida.carta(id)
    local r = rarezas[def.rareza]
    local lista = partida.lista(id)
    local n = #lista

    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", B.x, B.y - 4, B.w, 4)
    ui.caja(B.x, B.y, B.w, B.h, p.negro)
    lg.setColor(r.color)
    lg.rectangle("fill", B.x + 1, B.y + 1, B.w - 2, 1)
    ui.zona("bandeja", B.x, B.y, B.w, B.h)

    local p1, fu, mo = partida.deEdicion(id, true), partida.enfundadas(id), partida.publicadas(id)
    fuentes.texto(def.nombre:upper(), B.x + 8, B.y + 5, 1, r.color)
    local resumen = n .. (n == 1 and " COPIA" or " COPIAS") .. "  -  " .. p1 .. " DE 1ª ED  -  " .. fu .. " EN FUNDA"
    if mo > 0 then resumen = resumen .. "  -  " .. mo .. " EN EL MÓVIL" end
    fuentes.texto(resumen, B.x + 14 + fuentes.ancho(def.nombre:upper()), B.y + 5, 1, p.grisclaro)
    ui.boton("cerrarBandeja", "X", B.x + B.w - 18, B.y + 3, 12, 10, p.gris)

    -- filtros rapidos
    local fx0 = B.x + 8
    local botones = {
        { "todas", "TODAS" }, { "primera", "1ª ED (" .. p1 .. ")" }, { "normal", "NORMALES (" .. (n - p1) .. ")" },
        { "sinFunda", "SIN FUNDA" }, { "ninguna", "NINGUNA" },
    }
    for _, b in ipairs(botones) do
        local w = fuentes.ancho(b[2]) + 10
        ui.boton("filtro_" .. b[1], b[2], fx0, B.y + 15, w, 10, p.grisosc)
        fx0 = fx0 + w + 3
    end

    -- las copias en fila; las elegidas suben
    local x0, paso, visibles = geometriaBandeja(n)
    local cy = B.y + 60
    local function pintarCopia(c, cx, alza, h)
        local y = cy - (elegidas[c.u] and 6 or 0) - alza
        if elegidas[c.u] then
            lg.setColor(p.amarillo)
            lg.rectangle("fill", cx - CW / 2 - 1, y - CH / 2 - 1, CW + 2, CH + 2)
        end
        carta.dibujar(def, cx, y, 1, 1, 0, true, h, c.f, { primera = c.p, quieta = h == nil })
        if c.a or c.m then
            lg.setColor(0, 0, 0, 0.5)
            lg.rectangle("fill", cx - CW / 2, y - CH / 2, CW, CH)
            fuentes.texto(c.a and "MÓVIL" or "MESA", cx - CW / 2, y - 2, 1, c.a and p.celeste or p.lima, "center", CW)
        end
    end
    local encima
    for k = 1, visibles do
        local c = lista[desplaza + k]
        local cx = x0 + (k - 1) * paso
        local zid = "cp_" .. c.u
        local w = (k < visibles) and math.max(6, paso) or CW
        ui.zona(zid, cx - CW / 2, cy - CH / 2 - 6, w, CH + 6)
        -- rayita debajo: amarilla si es de 1ª edicion
        lg.setColor(c.p and p.amarillo or p.grisosc)
        lg.rectangle("fill", cx - CW / 2, cy + CH / 2 + 2, math.min(CW, math.max(2, paso - 1)), 2)
        -- la del raton se pinta al final, levantada y entera (y solo una vez)
        if ui.encima == zid then
            encima = { c = c, x = cx }
        else
            pintarCopia(c, cx, 0)
        end
    end
    if encima then
        local c = encima.c
        pintarCopia(c, encima.x, 3, ui.hoverCarta("cp_" .. c.u, encima.x, cy - 3, CW, CH))
        if not barrido then tooltipCopia(def, c) end
        vista = c.u
    else
        vista = nil
    end
    if n > visibles then
        ui.boton("desplaza_-1", "<", B.x + 2, cy - 10, 8, 20, p.azul, desplaza > 0)
        ui.boton("desplaza_1", ">", B.x + B.w - 10, cy - 10, 8, 20, p.azul, desplaza + visibles < n)
    end

    -- acciones con las elegidas
    local sel = elegidasQue()
    local valor = 0
    for _, c in ipairs(sel) do valor = valor + mercado.ventaRapida(id, c.p) end
    local sinFunda = #elegidasQue(function(c) return not c.f end)
    local conFunda = #sel - sinFunda
    local aMesa = #elegidasQue(function(c) return not c.m end)
    fuentes.texto(#sel == 0 and "CLICK O ARRASTRA POR ENCIMA DE LAS COPIAS PARA ELEGIR" or (#sel .. (#sel == 1 and " ELEGIDA" or " ELEGIDAS")),
        B.x + 8, B.y + 94, 1, #sel == 0 and p.gris or p.amarillo)
    local by, x = B.y + 103, B.x + 8
    local function accion(idB, texto, w, color, activo)
        ui.boton(idB, texto, x, by, w, 13, color, activo)
        x = x + w + 4
    end
    accion("sel_vender", "VENDER " .. #sel .. "  +" .. ui.dinero(valor), 118, #sel > 0 and #sel >= n and p.rojo or p.naranja, #sel > 0)
    accion("sel_publicar", "PUBLICAR " .. #sel, 72, p.celeste, #sel > 0 and partida.huecosAnuncios() > 0)
    accion("sel_enfundar", "ENFUNDAR " .. sinFunda, 76, p.verdeosc, sinFunda > 0)
    accion("sel_desenfundar", "QUITAR FUNDA " .. conFunda, 92, p.gris, conFunda > 0)
    accion("sel_mesa", "A LA MESA " .. aMesa, B.x + B.w - 8 - x, p.verde, aMesa > 0 and #partida.mesa < partida.MAX_MESA)
end

local function dibujarCogida()
    local cogida = ui.arrastrando()
    if not cogida then return end
    local x, y = ui.mx, ui.my
    local def, c
    if cogida:sub(1, 1) == "m" then
        local s = entradaMesa(tonumber(cogida:sub(2)))
        if not s then return end
        def, c = partida.carta(s.id), partida.copia(s.id, s.u)
        x, y = x - agarre.x, y - agarre.y
    else
        def = partida.carta(tonumber(cogida:sub(2)))
        if not def then return end
    end
    local escala = c and 2 or 1
    local balanceo = math.sin(love.timer.getTime() * 6) * 0.04
    carta.dibujar(def, x, y, escala * 1.08, escala * 1.08, balanceo, true, { kx = 0, ky = 0, brillo = 1, lx = 0, ly = 0 },
        c and c.f or enFunda(def.id), { primera = c and c.p })
end

function armario.dibujar()
    ui.boton("modo_copias", "COPIAS", 6, 26, 28, 14, modo == "copias" and p.azul or p.gris)
    ui.boton("modo_rareza", "RAREZA", 36, 26, 28, 14, modo == "rareza" and p.azul or p.gris)
    ui.boton("modo_album", "ÁLBUM", 66, 26, 28, 14, modo == "album" and p.azul or p.gris)
    ui.boton("modo_mesa", "MESA", 96, 26, 28, 14, modo == "mesa" and p.azul or p.gris)

    panelSobres()
    if modo == "album" then panelAlbum() else panelSeleccion() end
    panelFundas()
    ui.boton("venderLote", "VENDER EN LOTE...", 6, 336, 118, 16, p.naranja, partida.totalCartas() > 0)
    if ui.encima == "venderLote" then
        ui.tooltip("Vender muchas de golpe", p.amarillo, { { "Eliges qué: repes, 1ª edición, fundas, set" } })
    end

    if modo == "copias" then
        dibujarCopias()
    elseif modo == "rareza" then
        dibujarRareza()
    elseif modo == "album" then
        dibujarAlbum()
    else
        dibujarMesa()
    end
    if bandejaAbierta() then dibujarBandeja() end
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

local function sinFundas()
    sonido.tocar("latido")
    fx.texto(ui.mx, ui.my - 10, "SIN FUNDAS: CÓMPRALAS EN LA TIENDA", p.rojo)
end

local function brilloFunda()
    sonido.tocar("nueva")
    fx.explosion(ui.mx, ui.my, p.cian, 14, 70)
    partida.guardar()
end

local function enfundarMonton(id)
    if partida.fundasLibres <= 0 then return sinFundas() end
    if partida.enfundar(id) then brilloFunda() end
end

-- acciones de la bandeja

local function venderElegidas()
    local id = bandeja
    local def = partida.carta(id)
    local uids = {}
    for _, c in ipairs(elegidasQue(elegible)) do table.insert(uids, c.u) end
    if #uids == 0 then return end
    local function hacer()
        cobrar(partida.venderCopias(id, uids))
        for _, u in ipairs(uids) do elegidas[u] = nil end
    end
    if #uids >= partida.copias(id) then
        ui.confirmar(#uids == 1 and "¿VENDER LA ÚLTIMA?" or "¿VENDER TODAS?", {
            "SON TODAS TUS COPIAS DE " .. def.nombre:upper(),
            "DESAPARECERÁ DEL ÁLBUM",
        }, "SÍ, VENDER", hacer)
        return
    end
    hacer()
end

local function publicarElegidas()
    local id = bandeja
    local lista = elegidasQue(elegible)
    local function hacer()
        local n = 0
        for _, c in ipairs(lista) do
            if partida.publicarCopia(id, c) then
                n = n + 1
                elegidas[c.u] = nil
            end
        end
        if n > 0 then
            sonido.tocar("click")
            fx.texto(ui.mx, ui.my - 10, n == 1 and "PUBLICADA" or (n .. " PUBLICADAS"), p.celeste)
            partida.guardar()
        end
        if n < #lista then fx.texto(ui.mx, ui.my - 20, "EL MÓVIL ESTÁ LLENO", p.rojo) end
    end
    if #lista >= partida.libres(id) then
        ui.confirmar("¿PUBLICAR TODAS?", {
            "NO TE QUEDARÁ NINGUNA EN EL ARMARIO",
            "SI ALGUIEN LA COMPRA, LA PIERDES DEL ÁLBUM",
        }, "SÍ, PUBLICAR", hacer)
        return
    end
    hacer()
end

local function enfundarElegidas(poner)
    local hecho = false
    for _, c in ipairs(elegidasQue()) do
        if poner and not c.f then
            if partida.fundasLibres <= 0 then
                sinFundas()
                break
            end
            hecho = partida.enfundarCopia(c) or hecho
        elseif not poner and c.f then
            hecho = partida.desenfundarCopia(c) or hecho
        end
    end
    if hecho then
        if poner then brilloFunda() else partida.guardar() end
    end
end

local function mesaElegidas()
    local n = 0
    for _, c in ipairs(elegidasQue(elegible)) do
        if partida.aLaMesa(bandeja, c) then n = n + 1 end
    end
    if n > 0 then
        sonido.tocar("giro")
        fx.texto(ui.mx, ui.my - 10, n == 1 and "A LA MESA" or (n .. " A LA MESA"), p.lima)
        partida.guardar()
    end
    if #partida.mesa >= partida.MAX_MESA then fx.texto(ui.mx, ui.my - 20, "LA MESA ESTÁ LLENA", p.naranja) end
end

local function abrirBandeja(id)
    if bandeja ~= id then
        elegidas = {}
        desplaza = 0
    end
    bandeja = id
end

-- venta en lote: panel encima de todo con sus opciones

local function dibujarLote(ancho, alto)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, ancho, alto)
    local w, h = 320, 190
    local x, y = math.floor((ancho - w) / 2), math.floor((alto - h) / 2)
    ui.caja(x - 2, y - 2, w + 4, h + 4, p.naranja)
    ui.caja(x, y, w, h, p.negro)
    fuentes.texto("VENDER EN LOTE", x, y + 8, 2, p.amarillo, "center", w)
    fuentes.texto("A LA TIENDA, AL MOMENTO Y A LA MITAD DE SU VALOR", x, y + 22, 1, p.grisclaro, "center", w)

    local filas = {
        { "QUÉ", "todo", { { false, "REPES (DEJA 1 DE CADA)" }, { true, "TODO" } } },
        { "1ª EDICIÓN", "primeras", { { false, "NO SE VENDEN" }, { true, "TAMBIÉN" } } },
        { "ENFUNDADAS", "fundas", { { false, "NO SE VENDEN" }, { true, "TAMBIÉN" } } },
        { "SETS", "set", { { false, "TODOS" }, { true, "SOLO " .. sets[setActivo].codigo } } },
    }
    local fy = y + 36
    for _, f in ipairs(filas) do
        fuentes.texto(f[1], x + 12, fy + 3, 1, p.blanco)
        for k, op in ipairs(f[3]) do
            local activo = (loteOp[f[2]] or false) == op[1]
            ui.boton("lote_" .. f[2] .. "_" .. tostring(op[1]), op[2], x + 84 + (k - 1) * 114, fy, 110, 11, activo and p.azul or p.grisosc)
        end
        fy = fy + 15
    end

    local o = { todo = loteOp.todo, primeras = loteOp.primeras, fundas = loteOp.fundas, set = loteOp.set and setActivo or nil }
    local r = partida.lote(o)
    fy = fy + 4
    fuentes.texto(r.n .. (r.n == 1 and " CARTA POR " or " CARTAS POR ") .. ui.dinero(r.valor), x, fy, 2, r.n > 0 and p.amarillo or p.gris, "center", w)
    fy = fy + 14
    if r.ultimas > 0 then
        fuentes.texto(r.ultimas .. " SON TU ÚLTIMA COPIA Y SE IRÁN DEL ÁLBUM", x, fy, 1, p.rojo, "center", w)
    else
        fuentes.texto("NUNCA SE VENDEN LAS DEL MÓVIL NI LAS DE LA MESA", x, fy, 1, p.gris, "center", w)
    end

    ui.boton("lote_si", "VENDER", x + 20, y + h - 26, 130, 18, r.ultimas > 0 and p.rojo or p.naranja, r.n > 0)
    ui.boton("lote_no", "CANCELAR", x + w - 150, y + h - 26, 130, 18, p.gris)
end

local function clickLote(id)
    if id == "lote_no" then
        ui.overlay = nil
    elseif id == "lote_si" then
        ui.overlay = nil
        cobrar(partida.venderLote({ todo = loteOp.todo, primeras = loteOp.primeras, fundas = loteOp.fundas,
            set = loteOp.set and setActivo or nil }))
    else
        local campo, valor = id:match("^lote_(%a+)_(%a+)$")
        if campo then loteOp[campo] = valor == "true" end
    end
end

function armario.click(id)
    if id:match("^modo_") then
        modo = id:sub(6)
    elseif id:match("^abrir_") then
        nav.abrir(id:sub(7))
    elseif id:match("^set_") then
        setActivo = id:sub(5)
        rarezaAbierta = nil
    elseif id:match("^pag_") then
        local clave, d = id:match("^pag_(.+)_(%-?%d)$")
        paginas[clave] = (paginas[clave] or 1) + tonumber(d)
    elseif id == "venderLote" then
        ui.overlay = { dibujar = dibujarLote, click = clickLote }
    elseif id == "verCopias" then
        abrirBandeja(seleccion)
    elseif id == "cerrarBandeja" then
        bandeja = nil
    elseif id:match("^filtro_") then
        filtrar(FILTROS[id:sub(8)])
    elseif id:match("^desplaza_") then
        desplaza = desplaza + tonumber(id:sub(10)) * 10
    elseif id == "sel_vender" then
        venderElegidas()
    elseif id == "sel_publicar" then
        publicarElegidas()
    elseif id == "sel_enfundar" then
        enfundarElegidas(true)
    elseif id == "sel_desenfundar" then
        enfundarElegidas(false)
    elseif id == "sel_mesa" then
        mesaElegidas()
    elseif id == "mesa_guardar" then
        if partida.guardarDeMesa(mesaSel) then
            mesaSel = nil
            sonido.tocar("giro")
            partida.guardar()
        end
    elseif id == "mesa_funda" then
        local s = entradaMesa(mesaSel)
        local c = s and partida.copia(s.id, s.u)
        if c then
            if c.f then
                partida.desenfundarCopia(c)
                partida.guardar()
            elseif partida.fundasLibres <= 0 then
                sinFundas()
            elseif partida.enfundarCopia(c) then
                brilloFunda()
            end
        end
    elseif id == "mesa_vender" then
        local s = entradaMesa(mesaSel)
        if s then
            local def = partida.carta(s.id)
            local function hacer() cobrar(partida.venderCopias(s.id, { s.u })) end
            if partida.copias(s.id) == 1 then
                ui.confirmar("¿VENDER LA ÚLTIMA?", { "ES TU ÚNICA COPIA DE " .. def.nombre:upper(), "DESAPARECERÁ DEL ÁLBUM" },
                    "SÍ, VENDERLA", hacer)
            else
                hacer()
            end
            mesaSel = nil
        end
    elseif id == "ficha" then
        local c = copiaVista(seleccion)
        nav.ficha(seleccion, c and c.p or false)
    elseif id == "autoFundas" then
        partida.opciones.autoFundas = not partida.opciones.autoFundas
        partida.guardar()
    elseif id == "pagAnt" then
        cambiarPliego(-1)
    elseif id == "pagSig" then
        cambiarPliego(1)
    elseif id:match("^[ca]%d") then
        armario.seleccionar(tonumber(id:sub(2)))
        if modo == "album" then modo = "copias" end
        abrirBandeja(seleccion)
    elseif id:match("^m%d") then
        mesaSel = tonumber(id:sub(2))
    elseif id:match("^r_") then
        rarezaAbierta = id:sub(3)
    end
end

-- se pueden arrastrar los montones de las rejillas y las cartas de la mesa;
-- en la bandeja, pulsar y arrastrar elige copias
function armario.coger(id, x, y)
    if not id then return false end
    local u = id:match("^cp_(%d+)")
    if u then
        u = tonumber(u)
        local c = partida.copia(bandeja, u)
        if c and elegible(c) then
            barrido = { valor = not elegidas[u] }
            elegidas[u] = barrido.valor or nil
            sonido.tocar("encima", barrido.valor and 1.4 or 0.9)
        end
        return true
    end
    if not id:match("^[cm]%d") then return false end
    if id:sub(1, 1) == "m" then
        local s = entradaMesa(tonumber(id:sub(2)))
        if not s then return false end
        agarre.x, agarre.y = x - s.x, y - s.y
        zMesa = zMesa + 1
        s.z = zMesa
    end
    ui.cogerSi(id, x, y)
    return true
end

function armario.mover(x, y)
    if not barrido then return end
    local zid = ui.zonaEn(x, y, "cp_")
    if not zid then return end
    local u = tonumber(zid:sub(4))
    local c = partida.copia(bandeja, u)
    if c and elegible(c) and (elegidas[u] or false) ~= barrido.valor then
        elegidas[u] = barrido.valor or nil
        sonido.tocar("encima", barrido.valor and 1.4 or 0.9)
    end
end

-- devuelve true si el raton estaba eligiendo copias
function armario.acabarBarrido()
    local habia = barrido ~= nil
    barrido = nil
    return habia
end

function armario.soltar(c, x, y)
    if not c.moviendo then
        armario.click(c.id)
        return
    end
    if c.id:sub(1, 1) == "m" then
        local s = entradaMesa(tonumber(c.id:sub(2)))
        if not s then return end
        if ui.zonaEn(x, y, "drop_funda") then
            mesaSel = s.u
            armario.click("mesa_funda")
            return
        end
        s.x = math.max(MESA.x + CW, math.min(MESA.x + MESA.w - CW, x - agarre.x))
        s.y = math.max(MESA.y + CH, math.min(MESA.y + MESA.h - CH, y - agarre.y))
        s.r = (love.math.random() - 0.5) * 0.2
        sonido.tocar("giro")
        partida.guardar()
        return
    end
    local cid = tonumber(c.id:sub(2))
    if ui.zonaEn(x, y, "drop_funda") then
        enfundarMonton(cid)
        return
    end
    local destino = ui.zonaEn(x, y, "drop_pos")
    if destino and modo == "copias" then
        local k = tonumber(destino:sub(9))
        local lista = ordenVisible()
        local actual
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
            if not visibles[v] then table.insert(lista, v) end
        end
        partida.orden = lista
        sonido.tocar("giro")
        partida.guardar()
    end
end

function armario.tecla(tecla)
    if tecla == "escape" and bandeja then
        bandeja = nil
        return true
    end
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

-- desde fuera (movil, apertura): enseña esa carta con sus copias
function armario.seleccionar(id)
    seleccion = id
    local def = partida.carta(id)
    if def then setActivo = def.set end
    if modo == "mesa" or modo == "album" then modo = "copias" end
    if partida.copias(id) > 0 then abrirBandeja(id) end
end

return armario
