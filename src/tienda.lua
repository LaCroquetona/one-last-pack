local sobres = require "datos.sobres"
local sets = require "datos.sets"
local rarezas = require "datos.rarezas"
local datosCalendario = require "datos.calendario"
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local calendario = require "src.calendario"
local sobre = require "src.sobre"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"

local tienda = {}

local tipo = sobres.lista[1]

local PANEL_X, PANEL_Y, PANEL_W = 300, 30, 318
local PRECIO_FUNDAS = 100

local function porcentaje(peso, total)
    local v = math.floor(peso / total * 1000 + 0.5) / 10
    if v == math.floor(v) then return string.format("%d%%", v) end
    return string.format("%.1f%%", v)
end

-- probabilidades de un hueco en trozos de color, partidos en lineas si no caben
local function lineaPesos(pesos, x, y, limite)
    local total = 0
    for _, peso in pairs(pesos) do total = total + peso end
    local cx = x
    for _, r in ipairs(rarezas.lista) do
        local peso = pesos[r.id]
        if peso then
            local txt = r.nombre .. " " .. porcentaje(peso, total)
            local w = fuentes.ancho(txt)
            if cx + w > limite then
                cx = x
                y = y + 8
            end
            fuentes.texto(txt, cx, y, 1, r.color)
            cx = cx + w + 8
        end
    end
    return y
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
    local todo = partida.lote({ todo = true, primeras = true, fundas = true })
    return partida.dinero + todo.valor < barato.precio
end

local function selector()
    local lista = conocidos()
    local w = 66
    local x0 = 160 - (#lista * w + (#lista - 1) * 4) / 2
    for i, s in ipairs(lista) do
        local activo = s == tipo
        local salido = mercado.salido(s.set)
        local texto = sets[s.set].codigo .. "  " .. (salido and ui.dinero(s.precio) or ("DÍA " .. calendario.plan[s.set][1].desde))
        ui.boton("tipo_" .. s.id, texto, x0 + (i - 1) * (w + 4), 30, w, 16, activo and s.colores.rayas or p.grisosc)
    end
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

local function panelFundas()
    local x, y, w = 14, 296, 276
    ui.caja(x, y, w, 40)
    fuentes.texto("FUNDAS", x + 6, y + 5, 1, p.blanco)
    fuentes.texto("TIENES " .. partida.fundasLibres .. " SIN USAR", x + 6, y + 5, 1, p.grisclaro, "right", w - 12)
    ui.boton("fundas", "COMPRAR 20 FUNDAS  " .. ui.dinero(PRECIO_FUNDAS), x + 6, y + 18, w - 12, 15,
        p.verdeosc, partida.dinero >= PRECIO_FUNDAS)
end

function tienda.dibujar()
    if not calendario.conocido(tipo.set, mercado.dia()) then tipo = sobres.lista[1] end
    selector()
    local hora = love.timer.getTime()
    local sx, sy = 160, 160 + math.sin(hora * 2) * 3
    local h = ui.hoverCarta("escaparate", sx, sy, sobre.ANCHO * 4, sobre.ALTO * 4)
    local salido = mercado.salido(tipo.set)
    fx.aura(sx, sy, tipo.colores.rayas, 110, salido and 0.25 or 0.08)
    sobre.dibujar(tipo.id, sx, sy, 4, math.sin(hora * 1.3) * 0.03, h and h.lx * 0.05 or 0, 0)
    if not salido then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", sx - 62, sy - 90, 124, 180)
        fuentes.texto("PRÓXIMAMENTE", sx - 60, sy - 4, 2, p.amarillo, "center", 120)
    end
    ui.zona("escaparate", sx - 60, sy - 88, 120, 176)

    local guardados = partida.sobres(tipo.id)
    local frase = guardados == 1 and "TIENES 1 SIN ABRIR" or ("TIENES " .. guardados .. " SIN ABRIR")
    local p1 = partida.sobres(tipo.id, true)
    if p1 > 0 then frase = frase .. " (" .. p1 .. " DE 1ª ED)" end
    fuentes.texto(frase, sx - 120, 256, 1, p.grisclaro, "center", 240)
    fuentes.texto("COLECCIÓN " .. partida.distintas(tipo.set) .. "/" .. #partida.cartasDe(tipo.set), sx - 100, 266, 1, p.grisclaro, "center", 200)

    ui.caja(PANEL_X, PANEL_Y, PANEL_W, 236)
    fuentes.texto(tipo.nombre, PANEL_X + 10, PANEL_Y + 10, 2, p.blanco)
    local precio = mercado.enTienda(tipo)
    if precio then
        fuentes.texto(ui.dinero(precio), PANEL_X, PANEL_Y + 10, 2, p.amarillo, "right", PANEL_W - 10)
    end
    local texto, color = estado()
    chip(texto, PANEL_X + 10, PANEL_Y + 28, color)
    if precio then
        fuentes.texto("QUEDAN " .. mercado.stock(tipo) .. " HOY", PANEL_X, PANEL_Y + 30, 1, mercado.stock(tipo) > 0 and p.blanco or p.rojo, "right", PANEL_W - 10)
    end

    local cartasPorSobre = 0
    for _, hueco in ipairs(tipo.huecos) do cartasPorSobre = cartasPorSobre + hueco.cantidad end
    fuentes.texto(cartasPorSobre .. " CARTAS POR SOBRE  -  " .. #partida.cartasDe(tipo.set) .. " EN EL SET", PANEL_X + 10, PANEL_Y + 44, 1, p.grisclaro)

    local y = PANEL_Y + 58
    for _, hueco in ipairs(tipo.huecos) do
        fuentes.texto(hueco.cantidad .. " x " .. hueco.nombre, PANEL_X + 10, y, 1, p.blanco)
        y = lineaPesos(hueco.rarezas, PANEL_X + 18, y + 9, PANEL_X + PANEL_W - 10) + 13
    end
    y = y + 2
    fuentes.texto("GOD PACK: 1 DE CADA " .. math.floor(1 / tipo.godpack + 0.5) .. ", TODO EL SOBRE CON PROBABILIDADES", PANEL_X + 10, y, 1, p.amarillo)
    fuentes.texto("DE RARA O MEJOR", PANEL_X + 10, y + 8, 1, p.amarillo)
    fuentes.texto("PIEDAD: " .. tipo.piedad .. " SOBRES SIN HOLO Y EL SIGUIENTE LA TRAE SEGURO", PANEL_X + 10, y + 20, 1, p.violeta)
    if salido then
        fuentes.texto(ui.tirada(mercado.tirada(tipo.set)), PANEL_X + 10, y + 32, 1, p.grisclaro)
        if ui.encima == "info_tirada" then
            ui.tooltip("Tirada de 1ª edición", p.amarillo, {
                { "Los sobres de 1ª edición que se han impreso." },
                { "Si compras muchos, se imprimen más: nunca" },
                { "tendrás más de una pequeña parte del total." },
                { "Más tirada = 1ª ediciones más baratas.", p.amarillo },
            })
        end
        ui.zona("info_tirada", PANEL_X + 10, y + 30, PANEL_W - 20, 9)
    end

    local by = PANEL_Y + 246
    if precio then
        local max = partida.maxCompra(tipo)
        local cinco = math.min(5, max)
        ui.boton("comprar1", "COMPRAR " .. ui.dinero(precio), PANEL_X, by, 100, 16, p.verde, max >= 1)
        ui.boton("comprar5", (cinco > 1 and cinco or 5) .. " POR " .. ui.dinero(precio * math.max(2, cinco)), PANEL_X + 108, by, 100, 16, p.verde, cinco > 1)
    elseif salido then
        local reventa = mercado.compraReventa(tipo, true)
        local r2 = mercado.compraReventa(tipo, false)
        if r2 then
            ui.boton("reventar", "REVENTA " .. ui.dinero(r2), PANEL_X, by, 100, 16, p.celeste, partida.dinero >= r2)
        end
        if reventa then
            ui.boton("reventa1", "1ª ED " .. ui.dinero(reventa), PANEL_X + 108, by, 100, 16, p.amarillo, partida.dinero >= reventa)
        end
    end
    ui.boton("abrir", "ABRIR (" .. guardados .. ")", PANEL_X + 216, by, PANEL_W - 216, 16, p.azul, guardados > 0)

    local aviso
    if sinSalida() then
        ui.boton("rescate", "SOBRE DE RESCATE GRATIS", PANEL_X, by + 22, 208, 16, p.naranja)
    elseif precio and mercado.stock(tipo) == 0 then
        aviso = { "HOY NO QUEDAN MÁS: MAÑANA LLEGAN MÁS SOBRES", p.naranja }
    elseif not precio and salido then
        aviso = { "YA NO SE IMPRIME: SOLO SE CONSIGUE DE REVENTA", p.grisclaro }
    elseif precio and partida.dinero < precio and guardados == 0 then
        aviso = { "SIN DINERO: VENDE CARTAS EN EL ARMARIO O EN EL MÓVIL", p.naranja }
    end
    if aviso then fuentes.texto(aviso[1], PANEL_X, by + 26, 1, aviso[2]) end

    panelFundas()
end

local function comprar(cantidad, boton)
    local pagado = partida.comprar(tipo, cantidad)
    if not pagado then return end
    sonido.tocar("moneda")
    local x = boton == "comprar1" and PANEL_X + 50 or PANEL_X + 158
    fx.texto(x, PANEL_Y + 236, "-" .. ui.dinero(pagado), p.rojo)
    fx.explosion(160, 160, p.amarillo, 20 * cantidad, 120)
    fx.sacudir(2)
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
        nav.abrir(tipo.id)
    elseif id:match("^tipo_") then
        tipo = sobres[id:sub(6)]
    elseif id == "fundas" then
        if partida.comprarFundas(20, PRECIO_FUNDAS) then pagar(PRECIO_FUNDAS, "+20 FUNDAS", p.cian) end
    elseif id == "rescate" then
        local barato = masBarato()
        partida.regalar(barato.id, 1, select(2, mercado.enTienda(barato)))
        partida.guardar()
        sonido.tocar("nueva")
    elseif id == "escaparate" then
        fx.explosion(ui.mx, ui.my, p.amarillo, 6, 60)
    end
end

return tienda
