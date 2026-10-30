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

local tienda = {}

local tipo = sobres.lista[1]

local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 314, 28, 314, 258
local PRECIO_FUNDAS = 100
local PRECIO_TOPS = 150      -- 10 top loaders
local seccion = "sobres"     -- "sobres" o "cajas"

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

-- La tienda es una estanteria: cada mueble lleva 4 sets, arriba sus sobres
-- colgados, en medio fundas y tops y abajo sus cajas apiladas. Con mas sets
-- hay mas muebles y se pasa con las flechas
local POR_MUEBLE = 4
local M = { x = 22, y = 58, w = 266, h = 284, d = 24 }
local B1, B2 = M.y + 84, M.y + 150
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

local function grupo()
    local lista = conocidos()
    local pos = 1
    for i, s in ipairs(lista) do
        if s == tipo then pos = i end
    end
    local desde = math.floor((pos - 1) / POR_MUEBLE) * POR_MUEBLE + 1
    return lista, desde, math.min(#lista, desde + POR_MUEBLE - 1)
end

local function ganchoX(k) return M.x + muebles.dz(M.d) + 30 + (k - 1) * 62 end
local function cajaX(k) return M.x + 36 + (k - 1) * 62 end

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

local function dibujarMueble()
    local lista, desde, hasta = grupo()
    local sD = muebles.dz(M.d)
    muebles.mueble(M.x, M.y, M.w, M.h, M.d, 6)
    muebles.perforado(M.x + sD + 4, M.y + 4, M.w - sD - 6, M.h - M.d - 6, 8)
    muebles.balda(M.x, B1, M.w, M.d)
    muebles.balda(M.x, B2, M.w, M.d)
    muebles.bloque(M.x + 70, M.y - 22, 126, 14, 4, muebles.tonos(p.rojo, 1, 1.3, 0.6))
    local n = math.max(1, math.ceil(#lista / POR_MUEBLE))
    local num = math.floor((desde - 1) / POR_MUEBLE) + 1
    fuentes.texto(n > 1 and ("TIENDA " .. num .. "/" .. n) or "TIENDA", M.x + 70, M.y - 18, 1, p.amarillo, "center", 126)

    -- sobres colgados
    for k = 1, hasta - desde + 1 do
        local s = lista[desde + k - 1]
        local bx, by = ganchoX(k), M.y + 6
        local hx, hy = muebles.agujero(bx, by, L)
        local precio = mercado.enTienda(s)
        muebles.gancho(bx, by, L)
        if precio then
            local quedan = mercado.stock(s)
            if quedan > 0 then
                muebles.colgados(s.id, hx, hy, math.min(4, quedan), giro(s.id))
            else
                letrero(hx, hy + 14, "MAÑANA")
            end
            muebles.etiqueta(hx, B1 + 1, ui.dinero(precio))
        elseif mercado.salido(s.set) then
            love.graphics.push()
            love.graphics.translate(hx, hy + 22)
            love.graphics.rotate(-0.35)
            muebles.rect(p.rojo, -26, -5, 52, 10)
            fuentes.texto("AGOTADO", -26, -2, 1, p.blanco, "center", 52)
            love.graphics.pop()
            muebles.etiqueta(hx, B1 + 1, "REVENTA", p.grisosc, p.grisclaro)
        else
            letrero(hx, hy + 14, "DÍA " .. calendario.plan[s.set][1].desde)
        end
        muebles.punta(bx, by, L)
        ui.zona("tipo_" .. s.id, hx - 18, M.y + 2, 36, B1 - M.y - 6)
        if s == tipo and seccion == "sobres" then marco(hx - 19, M.y + 2, 38, B1 - M.y - 4) end
    end

    -- fundas y tops colgados
    if desbloqueos.hay("fundas") then
        local by = B1 + 12
        local bx = M.x + sD + 46
        local hx, hy = muebles.agujero(bx, by, L)
        muebles.gancho(bx, by, L)
        muebles.blister(hx, hy, 3, giro("fundas"))
        muebles.punta(bx, by, L)
        muebles.etiqueta(hx, B2 + 1, "20 X " .. ui.dinero(PRECIO_FUNDAS))
        ui.zona("fundas", hx - 16, by - 2, 32, B2 - by - 2)
        if desbloqueos.hay("tops") then
            bx = M.x + sD + 112
            hx, hy = muebles.agujero(bx, by, L)
            muebles.gancho(bx, by, L)
            muebles.bolsaTops(hx, hy, 3, giro("tops"))
            muebles.punta(bx, by, L)
            muebles.etiqueta(hx, B2 + 1, "10 X " .. ui.dinero(PRECIO_TOPS))
            ui.zona("tops", hx - 16, by - 2, 32, B2 - by - 2)
        end
        local tx = M.x + sD + 150
        fuentes.texto("TIENES", tx, B1 + 20, 1, p.grisclaro)
        fuentes.texto(partida.fundasLibres .. " FUNDAS", tx, B1 + 30, 1, p.cian)
        if desbloqueos.hay("tops") then fuentes.texto(partida.topsLibres .. " TOPS", tx, B1 + 40, 1, p.celeste) end
        fuentes.texto("TOCA PARA COMPRAR", tx, B1 + 52, 1, p.gris)
        if ui.encima == "tops" then
            ui.tooltip("Top loaders", p.celeste, { { "Plástico rígido encima de la funda" }, { "Elige en el armario desde qué rareza se ponen solos", p.grisclaro } })
        end
    end

    -- cajas apiladas en el suelo del mueble
    if desbloqueos.hay("cajas") then
        local suelo = M.y + M.h
        for k = 1, hasta - desde + 1 do
            local s = lista[desde + k - 1]
            local cx = cajaX(k) + muebles.dz(14)
            local precio = mercado.precioCaja(s)
            local pila = precio and math.min(3, mercado.stockCajas(s)) or 0
            for i = 0, pila - 1 do
                caja.dibujar(s.id, cx + (i % 2), suelo - 14 - 19 - i * 26, 1, {})
            end
            if precio then
                muebles.etiqueta(cajaX(k), suelo + 2, ui.dinero(precio))
                if pila == 0 then letrero(cx, suelo - 40, "MAÑANA") end
            elseif mercado.salido(s.set) then
                letrero(cx, suelo - 40, "AGOTADAS")
            end
            if mercado.salido(s.set) then
                ui.zona("ctipo_" .. s.id, cx - 30, B2 + 8, 60, suelo - B2 - 8)
                if s == tipo and seccion == "cajas" then marco(cx - 31, B2 + 8, 62, suelo - B2 - 6) end
            end
        end
    end

    -- flechas a los muebles de los lados
    if desde > 1 then ui.boton("tipo_" .. lista[desde - 1].id, "<", 2, 186, 12, 30, p.azul) end
    if hasta < #lista then ui.boton("tipo_" .. lista[hasta + 1].id, ">", 298, 186, 12, 30, p.azul) end
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

local function fichaCaja()
    cabecera("CAJA " .. sets[tipo.set].nombre:upper(), mercado.precioCaja(tipo), tipo.colores)
    local C = sobres.caja
    local texto, color = estado()
    chip(texto, PANEL_X + 8, PANEL_Y + 32, color)
    local tengo, t1 = partida.cajasDe(tipo.id), partida.cajasDe(tipo.id, true)
    local y = PANEL_Y + 50
    local lineas = {
        { C.sobres .. " SOBRES CERRADOS DEL " .. sets[tipo.set].nombre:upper(), p.blanco },
        { "SALE UN " .. math.floor(C.descuento * 100 + 0.5) .. "% MÁS BARATA QUE SUS SOBRES SUELTOS", p.lima },
        { "LLEGAN " .. C.porDia .. " CAJAS AL DÍA MIENTRAS EL SET ESTÁ EN LA TIENDA", p.grisclaro },
        { "CERRADA SUBE O BAJA COMO SUS SOBRES CERRADOS", p.grisclaro },
        { "LAS DE 1ª EDICIÓN GUARDADAS SUELEN SUBIR CON EL TIEMPO", p.amarillo },
        { "TIENES " .. tengo .. (tengo == 1 and " CAJA" or " CAJAS") .. (t1 > 0 and (" (" .. t1 .. " DE 1ª ED)") or ""), p.blanco },
        { "SE ABREN EN LA MESA Y SE VENDEN EN EL MÓVIL", p.gris },
    }
    for _, l in ipairs(lineas) do
        fuentes.texto(l[1], PANEL_X + 10, y, 1, l[2])
        y = y + 11
    end
    if mercado.salido(tipo.set) then
        fuentes.texto("VALE CERRADA (1ª ED): " .. ui.dinero(mercado.valorCaja(tipo, true)), PANEL_X + 10, y + 6, 1, p.amarillo)
    end
    local by = PANEL_Y + PANEL_H + 8
    local precio = mercado.precioCaja(tipo)
    if precio then
        local quedan = mercado.stockCajas(tipo)
        ui.boton("caja", "COMPRAR CAJA " .. ui.dinero(precio), PANEL_X, by, 208, 16, p.morado, quedan > 0 and partida.dinero >= precio)
        fuentes.texto(quedan > 0 and ("QUEDAN " .. quedan .. " HOY") or "MAÑANA MÁS", PANEL_X + 216, by + 5, 1,
            quedan > 0 and p.grisclaro or p.naranja)
    elseif mercado.salido(tipo.set) then
        fuentes.texto("YA NO SE VENDEN EN LA TIENDA", PANEL_X, by + 5, 1, p.grisclaro)
    end
    ui.boton("abrir", "A LA MESA", PANEL_X, by + 22, 100, 16, p.azul, tengo > 0)
end

function tienda.dibujar()
    if not calendario.conocido(tipo.set, mercado.dia()) then tipo = sobres.lista[1] end
    if not desbloqueos.hay("cajas") then seccion = "sobres" end
    dibujarMueble()
    if seccion == "cajas" then
        fichaCaja()
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

-- donde esta colgado un tipo de sobre (para las chispas al comprar)
local function sitio(t)
    local lista, desde = grupo()
    for i = desde, math.min(#lista, desde + POR_MUEBLE - 1) do
        if lista[i] == t then return muebles.agujero(ganchoX(i - desde + 1), M.y + 6, L) end
    end
    return 150, 100
end

local function comprar(cantidad, boton)
    local pagado = partida.comprar(tipo, cantidad)
    if not pagado then return end
    sonido.tocar("moneda")
    local x = boton == "comprar1" and PANEL_X + 50 or PANEL_X + 156
    fx.texto(x, PANEL_Y + PANEL_H, "-" .. ui.dinero(pagado), p.rojo)
    local sx, sy = sitio(tipo)
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
    elseif id == "caja" then
        local pagado = partida.comprarCaja(tipo)
        if pagado then
            sonido.tocar("moneda")
            fx.texto(PANEL_X + 104, PANEL_Y + PANEL_H + 8, "-" .. ui.dinero(pagado) .. "  +1 CAJA", p.amarillo)
            fx.sacudir(3)
            partida.guardar()
        end
    elseif id == "sec_sobres" or id == "sec_cajas" then
        seccion = id:sub(5)
    elseif id:match("^ctipo_") then
        tipo = sobres[id:sub(7)]
        seccion = "cajas"
    elseif id == "tops" then
        if partida.comprarTops(10, PRECIO_TOPS) then
            zarandeo.tops = love.timer.getTime()
            pagar(PRECIO_TOPS, "+10 TOP LOADERS", p.celeste)
        end
    elseif id:match("^tipo_") then
        tipo = sobres[id:sub(6)]
        seccion = "sobres"
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
