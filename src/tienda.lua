local sobres = require "datos.sobres"
local sets = require "datos.sets"
local rarezas = require "datos.rarezas"
local datosCalendario = require "datos.calendario"
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local calendario = require "src.calendario"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local desbloqueos = require "src.desbloqueos"
local ui = require "src.ui"
local nav = require "src.nav"
local caja = require "src.caja"
local muebles = require "src.muebles"
local pr_dib = require "src.productos"
local productos = require "datos.productos"

local tienda = {}

local tipo = sobres.lista[1]

local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 314, 28, 314, 258
local PRECIO_FUNDAS = 100
local PRECIO_TOPS = 150      -- 10 top loaders
local prodSel                -- producto elegido del set (nil: el sobre); en MIX "fundas" o "tops"
local mix = false            -- viendo la estanteria MIX

local function porcentaje(peso, total)
    local v = math.floor(peso / total * 1000 + 0.5) / 10
    if v == math.floor(v) then return string.format("%d%%", v) end
    return string.format("%.1f%%", v)
end

local function conocidos()
    local lista = {}
    for _, s in ipairs(sobres.lista) do
        if calendario.conocido(s.set, mercado.dia()) then table.insert(lista, s) end
    end
    return lista
end

-- el sobre mas barato que hay hoy en la tienda
local function masBarato()
    local mejor
    for _, s in ipairs(sobres.lista) do
        local precio = mercado.enTienda(s)
        if precio and (not mejor or precio < mejor.precio) then mejor = s end
    end
    return mejor
end

-- sin dinero, sin sobres y sin nada que vender que llegue para el sobre mas barato
local function sinSalida()
    local barato = masBarato()
    if not barato then return false end
    if partida.dinero >= barato.precio or partida.sobresGuardados() > 0 then return false end
    local todo = partida.lote({ todo = true, primeras = true, proteccion = "todo" })
    return partida.dinero + todo.valor < barato.precio
end

local function chip(texto, x, y, color)
    local w = fuentes.ancho(texto) + 6
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w, 9)
    fuentes.texto(texto, x + 3, y + 2, 1, p.negro)
end

local function estado()
    local fase, i = mercado.fase(tipo.set)
    if fase == "impresion" then
        if calendario.lanzando(tipo.set, mercado.dia()) then return "¡NOVEDAD! 1ª EDICIÓN", p.lima end
        if i.quedan < datosCalendario.ultimos then return "1ª EDICIÓN: ÚLTIMOS DÍAS", p.amarillo end
        return "1ª EDICIÓN", p.verde
    elseif fase == "reimpresion" then
        if i.quedan < datosCalendario.ultimos then return "REIMPRESIÓN: ÚLTIMOS DÍAS", p.amarillo end
        return "REIMPRESIÓN", p.celeste
    elseif fase == "anunciado" then
        return "SALE EN " .. i.faltan .. (i.faltan == 1 and " DÍA" or " DÍAS"), p.amarillo
    end
    return "AGOTADO EN TIENDAS", p.grisclaro
end

-- La tienda es una estanteria por set (pestañas arriba) y otra MIX con lo de
-- todos los sets. En la del set: arriba ganchos (sobres, blister y uno libre),
-- en medio 3 huecos (tins, ETB y uno libre) y abajo las cajas y el hueco del
-- case. Los huecos son los mismos que los del armario
local M = { x = 22, y = 58, w = 266, h = 284, d = 24 }
local B1, B2 = M.y + 78, M.y + 172
local SUELO = M.y + M.h
local L = 16
-- cuando se compro cada cosa, para que se zarandee
local zarandeo = {}

local function giro(id)
    local t0 = zarandeo[id]
    if not t0 then return 0 end
    local t = love.timer.getTime() - t0
    if t > 2 then zarandeo[id] = nil return 0 end
    return math.sin(t * 18) * 0.35 * math.exp(-t * 3.2)
end

local function marco(x, y, w, h)
    love.graphics.setColor(p.lima)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    love.graphics.setColor(1, 1, 1)
end

local function letrero(x, y, texto, color)
    local w = fuentes.ancho(texto) + 6
    muebles.rect(p.negro, x - w / 2, y, w, 12, 0.55)
    fuentes.texto(texto, x - w / 2, y + 4, 1, color or p.grisclaro, "center", w)
end

-- productos que ya se ven en la tienda
local function visible(prod)
    return not prod.desbloqueo or desbloqueos.hay(prod.desbloqueo)
end

local function mueble(cartel, color)
    local sD = muebles.dz(M.d)
    muebles.mueble(M.x, M.y, M.w, M.h, M.d, 6)
    muebles.perforado(M.x + sD + 4, M.y + 4, M.w - sD - 6, M.h - M.d - 6, 8)
    muebles.balda(M.x, B1, M.w, M.d)
    muebles.balda(M.x, B2, M.w, M.d)
    muebles.bloque(M.x + 70, M.y - 22, 126, 14, 4, muebles.tonos(color, 1, 1.3, 0.6))
    fuentes.texto(cartel, M.x + 70, M.y - 18, 1, p.amarillo, "center", 126)
end

local function gancho(bx, by, que)
    local hx, hy = muebles.agujero(bx, by, L)
    muebles.gancho(bx, by, L)
    que(hx, hy)
    muebles.punta(bx, by, L)
    return hx, hy
end

-- huecos de la balda del medio y del suelo
local HX0 = M.x + muebles.dz(M.d) + 6
local function huecoMedio(i) return HX0 + (i - 1) * 76 end

-- lo que no se vende hoy: mañana, agotado o el dia en que sale
local function sinVenta(s, x, y, plural)
    if mercado.salido(s.set) then
        letrero(x, y, plural and "AGOTADOS" or "AGOTADO")
    else
        letrero(x, y, "DÍA " .. calendario.plan[s.set][1].desde)
    end
end

local function dibujarSet()
    local s = tipo
    local col = s.colores
    mueble(sets[s.set].nombre:upper(), col.base)
    local sD = muebles.dz(M.d)
    local salido = mercado.salido(s.set)
    -- sobres colgados
    local precio = mercado.enTienda(s)
    local hx = gancho(M.x + sD + 30, M.y + 4, function(gx, gy)
        if precio then
            local quedan = mercado.stock(s)
            if quedan > 0 then muebles.colgados(s.id, gx, gy, math.min(4, quedan), giro(s.id))
            else letrero(gx, gy + 14, "MAÑANA") end
        elseif salido then
            love.graphics.push()
            love.graphics.translate(gx, gy + 22)
            love.graphics.rotate(-0.35)
            muebles.rect(p.rojo, -26, -5, 52, 10)
            fuentes.texto("AGOTADO", -26, -2, 1, p.blanco, "center", 52)
            love.graphics.pop()
        else
            letrero(gx, gy + 14, "DÍA " .. calendario.plan[s.set][1].desde)
        end
    end)
    if precio then muebles.etiqueta(hx, B1 + 1, ui.dinero(precio))
    elseif salido then muebles.etiqueta(hx, B1 + 1, "REVENTA", p.grisosc, p.grisclaro) end
    ui.zona("tipo_" .. s.id, hx - 18, M.y + 2, 36, B1 - M.y - 6)
    if not prodSel then marco(hx - 19, M.y + 2, 38, B1 - M.y - 4) end

    -- cada producto en su sitio: gancho, hueco de la balda o suelo
    local prods = {}
    for _, prod in ipairs(mercado.productosDe(s)) do prods[prod.id] = visible(prod) and prod or nil end
    local function datosProd(prod)
        local pr = mercado.precioProd(prod, s)
        return pr, pr and mercado.stockProd(prod, s) or 0
    end
    -- blister: gancho mas separado
    local bl = prods.blister
    if bl then
        local pr, quedan = datosProd(bl)
        local bx = gancho(M.x + sD + 104, M.y + 4, function(gx, gy)
            if pr and quedan > 0 then pr_dib.blister(s.id, col, gx, gy, math.min(3, quedan), giro("blister")) end
            if not (pr and quedan > 0) then
                if pr then letrero(gx, gy + 14, "MAÑANA") else sinVenta(s, gx, gy + 14, true) end
            end
        end)
        if pr then muebles.etiqueta(bx, B1 + 1, ui.dinero(pr)) end
        if salido then
            ui.zona("prod_blister", bx - 34, M.y + 2, 68, B1 - M.y - 6)
            if prodSel == "blister" then marco(bx - 35, M.y + 2, 70, B1 - M.y - 4) end
        end
        pr_dib.hueco(M.x + sD + 160, M.y + 6, 60, B1 - M.y - 10, "LIBRE")
    else
        pr_dib.hueco(M.x + sD + 84, M.y + 6, 136, B1 - M.y - 10, "LIBRE")
    end
    -- balda del medio: tins, ETB y uno libre
    for i, pid in ipairs({ "tin", "etb", "libre" }) do
        local prod = prods[pid]
        local x = huecoMedio(i)
        local t0 = B1 + 6
        if i > 1 then muebles.rect(p.negro, x - 2, B1 + 10, 1, B2 - B1 - 14, 0.25) end
        if prod then
            local pr, quedan = datosProd(prod)
            local n = pr and math.min(prod.cabe, quedan) or 0
            pr_dib.enHueco(pid, s.id, x, B2, n)
            if pr then
                muebles.etiqueta(x + 36, B2 + 1, ui.dinero(pr))
                if n == 0 then letrero(x + 36, B2 - 30, "MAÑANA") end
            else
                sinVenta(s, x + 36, B2 - 30, true)
            end
            if salido then
                ui.zona("prod_" .. pid, x, t0, 74, B2 - t0)
                if prodSel == pid then marco(x, t0, 74, B2 - t0) end
            end
        else
            pr_dib.hueco(x + 3, t0 + 6, 68, B2 - t0 - 10, "LIBRE")
        end
    end
    -- suelo: cajas y el hueco del case (2 huecos)
    local cj = prods.caja
    if cj then
        local pr, quedan = datosProd(cj)
        local x = M.x + 4
        local n = pr and math.min(2, quedan) or 0
        for i = 0, n - 1 do caja.dibujar(s.id, M.x + 36 + muebles.dz(14) + i, SUELO - 33 - i * 26, 1, {}) end
        if pr then
            muebles.etiqueta(M.x + 36, SUELO + 2, ui.dinero(pr))
            if n == 0 then letrero(M.x + 43, SUELO - 40, "MAÑANA") end
        else
            sinVenta(s, M.x + 43, SUELO - 40, true)
        end
        if salido then
            ui.zona("prod_caja", x, B2 + 8, 74, SUELO - B2 - 8)
            if prodSel == "caja" then marco(x, B2 + 8, 74, SUELO - B2 - 6) end
        end
        pr_dib.hueco(M.x + 92, B2 + 30, 150, SUELO - B2 - 34, "CASE: PRÓXIMAMENTE")
    else
        pr_dib.hueco(M.x + 12, B2 + 30, 230, SUELO - B2 - 34, "LIBRE")
    end
end

-- MIX: lo que no es de un set (fundas y tops) y sitio para lo que vendra
local function dibujarMix()
    mueble("MIX", p.morado)
    local sD = muebles.dz(M.d)
    local bx = gancho(M.x + sD + 30, M.y + 4, function(gx, gy) muebles.blister(gx, gy, 3, giro("fundas")) end)
    muebles.etiqueta(bx, B1 + 1, "20 X " .. ui.dinero(PRECIO_FUNDAS))
    ui.zona("fundas", bx - 18, M.y + 2, 36, B1 - M.y - 6)
    if prodSel == "fundas" then marco(bx - 19, M.y + 2, 38, B1 - M.y - 4) end
    if desbloqueos.hay("tops") then
        bx = gancho(M.x + sD + 84, M.y + 4, function(gx, gy) muebles.bolsaTops(gx, gy, 3, giro("tops")) end)
        muebles.etiqueta(bx, B1 + 1, "10 X " .. ui.dinero(PRECIO_TOPS))
        ui.zona("tops", bx - 18, M.y + 2, 36, B1 - M.y - 6)
        if prodSel == "tops" then marco(bx - 19, M.y + 2, 38, B1 - M.y - 4) end
    end
    pr_dib.hueco(M.x + sD + 116, M.y + 6, 104, B1 - M.y - 10, "FUNDAS ESPECIALES")
    pr_dib.hueco(huecoMedio(1) + 3, B1 + 12, 68, B2 - B1 - 16, "TIN MIX")
    pr_dib.hueco(huecoMedio(2) + 3, B1 + 12, 144, B2 - B1 - 16, "RECOPILACIONES")
    pr_dib.hueco(M.x + 12, B2 + 30, 230, SUELO - B2 - 34, "CAJAS ESPECIALES")
end

-- pestañas: un set cada una (las que aun no salen, en gris) y MIX
local function pestanas()
    local lista = conocidos()
    local nombres, total = {}, 0
    for i, s in ipairs(lista) do
        local n = sets[s.set].nombre:upper()
        if not mercado.salido(s.set) then n = n .. " DÍA " .. calendario.plan[s.set][1].desde end
        nombres[i] = n
        total = total + fuentes.ancho(n) + 13
    end
    local corto = total > 250
    local x = M.x
    for i, s in ipairs(lista) do
        local n = corto and sets[s.set].codigo or nombres[i]
        local w = fuentes.ancho(n) + 10
        local color = (not mix and s == tipo) and p.azul or (mercado.salido(s.set) and p.gris or p.grisosc)
        ui.boton("tset_" .. s.id, n, x, 20, w, 11, color)
        x = x + w + 3
    end
    if desbloqueos.hay("fundas") then
        ui.boton("tmix", "MIX", x, 20, fuentes.ancho("MIX") + 10, 11, mix and p.azul or p.gris)
    end
    -- flechas al set de al lado
    if not mix then
        local pos
        for i, s in ipairs(lista) do if s == tipo then pos = i end end
        if pos and pos > 1 then ui.boton("tset_" .. lista[pos - 1].id, "<", 2, 186, 12, 30, p.azul) end
        if pos and pos < #lista then ui.boton("tset_" .. lista[pos + 1].id, ">", 298, 186, 12, 30, p.azul)
        elseif desbloqueos.hay("fundas") then ui.boton("tmix", ">", 298, 186, 12, 30, p.azul) end
    elseif #lista > 0 then
        ui.boton("tset_" .. lista[#lista].id, "<", 2, 186, 12, 30, p.azul)
    end
end

local function dibujarMueble()
    if mix then dibujarMix() else dibujarSet() end
    pestanas()
end

-- lo que trae cada hueco del sobre: una barra con un trozo por rareza
local CORTO = { comun = "COMÚN", infrecuente = "INFREC.", rara = "RARA", holo = "HOLO", fullart = "F. ART", secreta = "SECRETA" }
-- probabilidad en %, con decimales solo si hace falta: 10%, 2,5%, 0,11%
local function porSobre(prob)
    local v = prob * 100
    local cad
    if v >= 10 then cad = string.format("%.0f", v)
    elseif v >= 1 then cad = string.format("%.1f", v)
    elseif v >= 0.1 then cad = string.format("%.2f", v)
    else cad = string.format("%.3f", v) end
    return (cad:gsub("%.", ",")) .. "%"
end

local function huecos(y, alto)
    local paso = math.min(34, math.floor(alto / #tipo.huecos))
    for i, hueco in ipairs(tipo.huecos) do
        local cy = y + (i - 1) * paso
        muebles.rect(p.negro, PANEL_X + 6, cy - 2, PANEL_W - 12, paso - 3, 0.25)
        fuentes.texto(hueco.cantidad .. " X " .. string.upper(hueco.nombre), PANEL_X + 12, cy + 2, 1, p.blanco)
        local total = 0
        for _, peso in pairs(hueco.rarezas) do total = total + peso end
        local bx, bw = PANEL_X + 140, PANEL_W - 152
        muebles.rect(p.negro, bx - 1, cy, bw + 2, 9)
        local x, tx = bx, PANEL_X + 12
        for _, r in ipairs(rarezas.lista) do
            local peso = hueco.rarezas[r.id]
            if peso then
                local ancho = math.max(1, math.floor(bw * peso / total + 0.5))
                muebles.rect(r.color, x, cy + 1, math.min(ancho, bx + bw - x), 7)
                x = x + ancho
                local txt = CORTO[r.id] .. " " .. porcentaje(peso, total)
                fuentes.texto(txt, tx, cy + 15, 1, r.color)
                tx = tx + fuentes.ancho(txt) + 6
            end
        end
    end
end

local function cabecera(nombre, precio, color)
    ui.caja(PANEL_X, PANEL_Y, PANEL_W, PANEL_H)
    muebles.rect(color.base, PANEL_X + 1, PANEL_Y + 1, PANEL_W - 2, 24)
    muebles.rect(color.rayas, PANEL_X + 1, PANEL_Y + 22, PANEL_W - 2, 3)
    fuentes.texto(nombre, PANEL_X + 8, PANEL_Y + 7, 2, p.blanco)
    if precio then fuentes.texto(ui.dinero(precio), PANEL_X, PANEL_Y + 7, 2, p.amarillo, "right", PANEL_W - 8) end
end

-- lo que lleva un producto, en lineas
local function contenido(prod, s)
    local l = { { prod.sobres .. " SOBRES CERRADOS DEL " .. sets[s.set].nombre:upper(), p.blanco } }
    if prod.fundas then table.insert(l, { "Y " .. prod.fundas .. " FUNDAS", p.cian }) end
    if prod.tops then table.insert(l, { "Y " .. prod.tops .. " TOP LOADERS", p.celeste }) end
    return l
end

local function fichaProd(prod)
    local s = tipo
    local precio = mercado.precioProd(prod, s)
    cabecera(prod.nombre .. " " .. sets[s.set].nombre:upper(), precio, s.colores)
    local texto, color = estado()
    chip(texto, PANEL_X + 8, PANEL_Y + 32, color)
    local tengo, t1 = partida.prodDe(prod.id, s.id), partida.prodDe(prod.id, s.id, true)
    local y = PANEL_Y + 50
    local lineas = contenido(prod, s)
    if prod.id == "caja" then
        local C = sobres.caja
        table.insert(lineas, { "SALE UN " .. math.floor(C.descuento * 100 + 0.5) .. "% MÁS BARATA QUE SUS SOBRES SUELTOS", p.lima })
    end
    if prod.id == "blister" then
        table.insert(lineas, { "EN LA MESA SE RASGA Y DEJA SUS SOBRES", p.grisclaro })
    elseif prod.id ~= "caja" then
        table.insert(lineas, { "AL ABRIRLA, SUS SOBRES SALEN A LA ESQUINA DE LA MESA", p.grisclaro })
    end
    table.insert(lineas, { "LLEGAN " .. (prod.porDia or sobres.caja.porDia) .. " AL DÍA MIENTRAS EL SET ESTÁ EN LA TIENDA", p.grisclaro })
    table.insert(lineas, { "CERRADO SUBE O BAJA COMO SUS SOBRES CERRADOS", p.grisclaro })
    table.insert(lineas, { "LO DE 1ª EDICIÓN GUARDADO SUELE SUBIR CON EL TIEMPO", p.amarillo })
    table.insert(lineas, { "TIENES " .. tengo .. (t1 > 0 and (" (" .. t1 .. " DE 1ª ED)") or ""), p.blanco })
    table.insert(lineas, { "SE ABRE EN LA MESA Y SE VENDE EN EL MÓVIL", p.gris })
    for _, l in ipairs(lineas) do
        fuentes.texto(l[1], PANEL_X + 10, y, 1, l[2])
        y = y + 11
    end
    if mercado.salido(s.set) then
        fuentes.texto("VALE CERRADO (1ª ED): " .. ui.dinero(mercado.valorProd(prod, s, true)), PANEL_X + 10, y + 6, 1, p.amarillo)
    end
    -- dibujo a la derecha
    local dx, dy = PANEL_X + PANEL_W - 80, PANEL_Y + PANEL_H - 20
    pr_dib.enHueco(prod.id, s.id, dx, dy, 1)
    local by = PANEL_Y + PANEL_H + 8
    if precio then
        local quedan = mercado.stockProd(prod, s)
        ui.boton("comprarProd", "COMPRAR " .. prod.nombre .. " " .. ui.dinero(precio), PANEL_X, by, 208, 16, p.morado,
            quedan > 0 and partida.dinero >= precio)
        fuentes.texto(quedan > 0 and ("QUEDAN " .. quedan .. " HOY") or "MAÑANA MÁS", PANEL_X + 216, by + 5, 1,
            quedan > 0 and p.grisclaro or p.naranja)
    elseif mercado.salido(s.set) then
        fuentes.texto("YA NO SE VENDE EN LA TIENDA", PANEL_X, by + 5, 1, p.grisclaro)
    end
    ui.boton("abrir", "A LA MESA", PANEL_X, by + 22, 100, 16, p.azul, tengo > 0)
end

local function fichaMix()
    cabecera("MIX", nil, { base = p.morado, rayas = p.azul })
    local y = PANEL_Y + 34
    local lineas = {
        { "LO QUE NO ES DE UN SET", p.blanco },
        { "FUNDAS: 20 POR " .. ui.dinero(PRECIO_FUNDAS) .. ". PROTEGEN LAS CARTAS", p.cian },
    }
    if desbloqueos.hay("tops") then
        table.insert(lineas, { "TOP LOADERS: 10 POR " .. ui.dinero(PRECIO_TOPS) .. ". PLÁSTICO RÍGIDO ENCIMA DE LA FUNDA", p.celeste })
    end
    table.insert(lineas, { "-" })
    table.insert(lineas, { "TIENES " .. partida.fundasLibres .. " FUNDAS" .. (desbloqueos.hay("tops") and (" Y " .. partida.topsLibres .. " TOPS") or ""), p.blanco })
    table.insert(lineas, { "TOCA UN GANCHO PARA COMPRAR", p.grisclaro })
    table.insert(lineas, { "-" })
    table.insert(lineas, { "PRÓXIMAMENTE: PRODUCTOS DE VARIOS SETS", p.gris })
    for _, l in ipairs(lineas) do
        if l[1] ~= "-" then fuentes.texto(l[1], PANEL_X + 10, y, 1, l[2]) end
        y = y + 11
    end
    local by = PANEL_Y + PANEL_H + 8
    ui.boton("fundas", "20 FUNDAS " .. ui.dinero(PRECIO_FUNDAS), PANEL_X, by, 100, 16, p.cian, partida.dinero >= PRECIO_FUNDAS)
    if desbloqueos.hay("tops") then
        ui.boton("tops", "10 TOPS " .. ui.dinero(PRECIO_TOPS), PANEL_X + 106, by, 100, 16, p.celeste, partida.dinero >= PRECIO_TOPS)
    end
end

function tienda.dibujar()
    if not calendario.conocido(tipo.set, mercado.dia()) then tipo = sobres.lista[1] end
    if mix and not desbloqueos.hay("fundas") then mix = false end
    local prod = prodSel and productos[prodSel]
    if prod and (not mercado.salido(tipo.set) or (prod.desbloqueo and not desbloqueos.hay(prod.desbloqueo))) then prodSel, prod = nil, nil end
    dibujarMueble()
    if mix then
        fichaMix()
        return
    end
    if prod then
        fichaProd(prod)
        return
    end

    local precio = mercado.enTienda(tipo)
    local salido = mercado.salido(tipo.set)
    cabecera(tipo.nombre, precio, tipo.colores)
    local texto, color = estado()
    local x = PANEL_X + 8
    chip(texto, x, PANEL_Y + 32, color)
    x = x + fuentes.ancho(texto) + 12
    if precio then
        local q = mercado.stock(tipo)
        local t = "QUEDAN " .. q .. " HOY"
        chip(t, x, PANEL_Y + 32, q > 0 and p.grisclaro or p.rojo)
        x = x + fuentes.ancho(t) + 12
    end
    chip("TUYAS " .. partida.distintas(tipo.set) .. "/" .. #partida.cartasDe(tipo.set), x, PANEL_Y + 32, p.celeste)

    fuentes.texto("QUÉ PUEDE SALIR EN CADA HUECO", PANEL_X + 8, PANEL_Y + 48, 1, p.grisclaro)
    huecos(PANEL_Y + 60, 140)
    -- god pack con el iman ya aplicado
    local y = PANEL_Y + 204
    local iman = partida.efecto("godpack")
    muebles.rect(p.amarillo, PANEL_X + 8, y, PANEL_W - 16, 28, 0.15)
    fuentes.texto("GOD PACK", PANEL_X + 14, y + 5, 1, p.amarillo)
    fuentes.texto("1 DE CADA " .. math.floor(1 / (tipo.godpack * iman) + 0.5), PANEL_X + 14, y + 5, 2, p.lima, "right", PANEL_W - 36)
    fuentes.texto(iman > 1 and ("ANTES 1 DE CADA " .. math.floor(1 / tipo.godpack + 0.5) .. ": TU IMÁN LO MEJORA") or "TODO EL SOBRE DE HOLO O MEJOR",
        PANEL_X + 14, y + 17, 1, iman > 1 and p.lima or p.grisclaro)
    -- fuera de set: lo que sale por sobre, en %
    local v = tipo.variantes
    if v then
        local alt = 1 / v.alt_holo + 1 / v.alt_fullart + 1 / v.alt_secreta
        fuentes.texto("FUERA DE SET POR SOBRE: ALT " .. porSobre(alt) .. ", SILVER " .. porSobre(1 / v.silver) .. ", GOLDEN " .. porSobre(1 / v.golden),
            PANEL_X + 10, y + 31, 1, p.grisclaro)
    end
    if salido then
        fuentes.texto(ui.tirada(mercado.tirada(tipo.set)), PANEL_X + 10, PANEL_Y + PANEL_H - 14, 1, p.grisclaro)
        if ui.encima == "info_tirada" then
            ui.tooltip("Tirada de 1ª edición", p.amarillo, {
                { "Los sobres de 1ª edición que se han impreso." },
                { "Si compras muchos, se imprimen más: nunca" },
                { "tendrás más de una pequeña parte del total." },
                { "Más tirada = 1ª ediciones más baratas.", p.amarillo },
            })
        end
        ui.zona("info_tirada", PANEL_X + 10, PANEL_Y + PANEL_H - 16, PANEL_W - 20, 9)
    else
        fuentes.texto("PRÓXIMAMENTE", PANEL_X + 10, PANEL_Y + PANEL_H - 14, 1, p.amarillo)
    end

    local guardados = partida.sobres(tipo.id)
    local by = PANEL_Y + PANEL_H + 8
    if precio then
        local max = partida.maxCompra(tipo)
        local cinco = math.min(5, max)
        ui.boton("comprar1", "COMPRAR " .. ui.dinero(precio), PANEL_X, by, 100, 16, p.verde, max >= 1)
        local n = cinco > 1 and cinco or 5
        ui.boton("comprar5", n .. " POR " .. ui.dinero(precio * n), PANEL_X + 106, by, 100, 16, p.verde, cinco > 1)
    elseif salido then
        local reventa = mercado.compraReventa(tipo, true)
        local r2 = mercado.compraReventa(tipo, false)
        if r2 then ui.boton("reventar", "REVENTA " .. ui.dinero(r2), PANEL_X, by, 100, 16, p.celeste, partida.dinero >= r2) end
        if reventa then ui.boton("reventa1", "1ª ED " .. ui.dinero(reventa), PANEL_X + 106, by, 100, 16, p.amarillo, partida.dinero >= reventa) end
    end
    ui.boton("abrir", "A LA MESA (" .. guardados .. ")", PANEL_X + 212, by, PANEL_W - 212, 16, p.azul, guardados > 0)

    local fila = by + 22
    local aviso
    if sinSalida() then
        ui.boton("rescate", "SOBRE DE RESCATE GRATIS", PANEL_X, fila, 208, 16, p.naranja)
    elseif precio and mercado.stock(tipo) == 0 then
        aviso = { desbloqueos.app("mercado") and "HOY NO QUEDAN: MAÑANA LLEGAN MÁS, O MIRA EN EL MERCADO DEL MÓVIL"
            or "HOY NO QUEDAN MÁS: MAÑANA LLEGAN MÁS SOBRES", p.naranja }
    elseif not precio and salido then
        aviso = { "YA NO SE IMPRIME: SOLO SE CONSIGUE DE REVENTA", p.grisclaro }
    elseif precio and partida.dinero < precio and guardados == 0 then
        aviso = { "SIN DINERO: VENDE CARTAS EN EL ARMARIO O EN EL MÓVIL", p.naranja }
    end
    if aviso then fuentes.texto(aviso[1], PANEL_X, fila + 4, 1, aviso[2]) end
end

-- donde esta colgado el sobre (para las chispas al comprar)
local function sitio()
    return muebles.agujero(M.x + muebles.dz(M.d) + 30, M.y + 4, L)
end

local function comprar(cantidad, boton)
    local pagado = partida.comprar(tipo, cantidad)
    if not pagado then return end
    sonido.tocar("moneda")
    local x = boton == "comprar1" and PANEL_X + 50 or PANEL_X + 156
    fx.texto(x, PANEL_Y + PANEL_H, "-" .. ui.dinero(pagado), p.rojo)
    local sx, sy = sitio()
    fx.explosion(sx, sy + 20, p.amarillo, 10 * cantidad, 80)
    zarandeo[tipo.id] = love.timer.getTime()
    partida.guardar()
end

local function pagar(pagado, texto, color)
    if not pagado then return end
    sonido.tocar("moneda")
    fx.texto(ui.mx, ui.my - 10, texto or ("-" .. ui.dinero(pagado)), color or p.rojo)
    partida.guardar()
end

function tienda.click(id)
    if id == "comprar1" then
        comprar(1, id)
    elseif id == "comprar5" then
        comprar(math.min(5, partida.maxCompra(tipo)), id)
    elseif id == "reventa1" or id == "reventar" then
        pagar(partida.comprarReventa(tipo, id == "reventa1"))
    elseif id == "abrir" then
        nav.abrir()
    elseif id == "comprarProd" then
        local prod = productos[prodSel]
        local pagado = prod and partida.comprarProd(prod, tipo)
        if pagado then
            sonido.tocar("moneda")
            fx.texto(PANEL_X + 104, PANEL_Y + PANEL_H + 8, "-" .. ui.dinero(pagado) .. "  +1 " .. prod.nombre, p.amarillo)
            fx.sacudir(3)
            zarandeo[prod.id] = love.timer.getTime()
            partida.guardar()
        end
    elseif id:match("^prod_") then
        prodSel = id:sub(6)
    elseif id == "tmix" then
        mix, prodSel = true, nil
    elseif id:match("^tset_") then
        tipo = sobres[id:sub(6)]
        mix, prodSel = false, nil
    elseif id == "tops" then
        if partida.comprarTops(10, PRECIO_TOPS) then
            zarandeo.tops = love.timer.getTime()
            pagar(PRECIO_TOPS, "+10 TOP LOADERS", p.celeste)
        end
    elseif id:match("^tipo_") then
        tipo = sobres[id:sub(6)]
        mix, prodSel = false, nil
    elseif id == "fundas" then
        if partida.comprarFundas(20, PRECIO_FUNDAS) then
            zarandeo.fundas = love.timer.getTime()
            pagar(PRECIO_FUNDAS, "+20 FUNDAS", p.cian)
        end
    elseif id == "rescate" then
        local barato = masBarato()
        partida.regalar(barato.id, 1, select(2, mercado.enTienda(barato)))
        partida.guardar()
        sonido.tocar("nueva")
    end
end

return tienda
