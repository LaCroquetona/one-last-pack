local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local generador = require "src.generador"
local partida = require "src.partida"
local mercado = require "src.mercado"
local dev = require "src.dev"
local carta = require "src.carta"
local sobre = require "src.sobre"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local ui = require "src.ui"
local nav = require "src.nav"
local directo = require "src.directo"

local lg = love.graphics

local apertura = {}

-- zona de la pantalla donde se abre (la mesa deja sitio a la caja y al directo)
local ZX, ZW = 0, 640
local CX, CY = 320, 160
local GRANDE = 3
local MINI = 1
local ESCALA_SOBRE = 4
local RANURA_Y = 318
local GIRO = 0.2
local DURACION_ENTRADA = 0.45

local estado, t
local entrada
local mano, godpack, mejor
local tipoActual, primeraActual
local lote
local idx, fase, tf
local carga = 0
local latido = 0
local pulsado = false

function apertura.zona(x, w)
    ZX, ZW = x, w
    CX = x + w / 2
end

local function ranuraX(i)
    local paso = math.min(42, (ZW - 40) / math.max(1, #mano - 1))
    return CX + (i - (#mano + 1) / 2) * paso
end

-- el resumen va en una fila si cabe grande; si no, en dos
local function filasResumen()
    local una = (ZW - 16) / #mano - 10
    return una / carta.ANCHO >= 1.5 and 1 or 2
end

local function porFila()
    return math.ceil(#mano / filasResumen())
end

local function escalaResumen()
    local n = porFila()
    local e = ((ZW - 16) / n - 10) / carta.ANCHO
    local tope = filasResumen() == 2 and 1.75 or 2
    return math.max(0.75, math.min(tope, math.floor(e * 4) / 4))
end

local function resumenX(i)
    local n = porFila()
    local fila = math.floor((i - 1) / n)
    local enFila = fila == 0 and math.min(n, #mano) or (#mano - n)
    local k = (i - 1) % n + 1
    local paso = carta.ANCHO * escalaResumen() + 10
    return CX + (k - (enFila + 1) / 2) * paso
end

local function resumenY(i)
    -- un poco bajado: arriba a la derecha va la caja abierta
    if filasResumen() == 1 then return 165 end
    local alto = carta.ALTO * escalaResumen()
    local fila = math.floor((i - 1) / porFila())
    return 172 + (fila == 0 and -1 or 1) * (alto / 2 + 11)
end

-- tipo: entrada de datos/sobres.lua (ya descontada de los guardados)
-- primera: si el sobre es de 1ª edicion
-- desde: { x, y, a, escala } si llega arrastrado (si no, sube desde abajo)
function apertura.empezar(tipo, primera, desde)
    tipoActual, primeraActual = tipo, primera
    entrada = desde
    local defs
    defs, godpack = generador.sobre(tipo)
    mano = {}
    for i, def in ipairs(defs) do
        mano[i] = { def = def, x = CX, y = CY, escala = GRANDE, boca = false, nueva = false }
    end
    mejor = rarezas[defs[#defs].rareza]
    carga = 0
    estado, t = "entrando", 0
    if dev.saltar then
        for i, c in ipairs(mano) do
            c.boca = true
            c.nueva, c.copia = partida.anadir(c.def.id, primera)
            c.x, c.y, c.escala = ranuraX(i), RANURA_Y, MINI
        end
        sonido.tocar(mejor.id)
        if mejor.nivel >= 4 then fx.destello(mejor.color, 0.3) end
        partida.guardar()
        estado = "resumen"
        directo.rasgar(godpack)
        for _, c in ipairs(mano) do directo.carta(c.def, c.nueva) end
        directo.finSobre(defs, godpack, tipo.id)
        partida.encargoSobre(tipo.id, primera)
    end
end

-- abre varios sobres de golpe y enseña todo junto, agrupado
function apertura.lote(n)
    local cuenta, nuevas, orden = {}, {}, {}
    local abiertos, godpacks, total, valor = 0, 0, 0, 0
    for _ = 1, n do
        local tipo, primera = partida.sacarSobre()
        if not tipo then break end
        abiertos = abiertos + 1
        local defs, gp = generador.sobre(tipo)
        if gp then godpacks = godpacks + 1 end
        partida.encargoSobre(tipo.id, primera)
        for _, def in ipairs(defs) do
            if partida.anadir(def.id, primera) then nuevas[def.id] = true end
            if not cuenta[def.id] then
                cuenta[def.id] = 0
                table.insert(orden, def)
            end
            cuenta[def.id] = cuenta[def.id] + 1
            total = total + 1
            valor = valor + mercado.valor(def.id, primera)
        end
    end
    if abiertos == 0 then return false end
    table.sort(orden, function(a, b)
        local na, nb = rarezas[a.rareza].nivel, rarezas[b.rareza].nivel
        if na ~= nb then return na > nb end
        return a.id < b.id
    end)
    local numNuevas = 0
    for _ in pairs(nuevas) do numNuevas = numNuevas + 1 end
    lote = { cartas = orden, cuenta = cuenta, nuevas = nuevas, abiertos = abiertos,
             total = total, valor = valor, numNuevas = numNuevas, godpacks = godpacks }
    partida.guardar()
    sonido.carga(0)
    sonido.tocar(rarezas[orden[1].rareza].id)
    fx.destello({1, 1, 1}, 0.5)
    fx.sacudir(4)
    estado, t = "lote", 0
    return true
end

function apertura.pulsar()
    pulsado = true
end

-- tipo del ultimo sobre abierto (para sacar otro igual)
function apertura.ultimoTipo()
    return tipoActual and tipoActual.id
end

function apertura.boton(id)
    if id == "otroLote" then
        apertura.lote(5)
    elseif id == "armario" or id == "tienda" then
        estado = nil
        nav.ir(id)
    end
end

local function rasgar()
    sonido.carga(0)
    sonido.tocar("rasgar")
    fx.sacudir(6)
    fx.destello({1, 1, 1}, 0.8)
    fx.explosion(CX, CY - 70, {1, 1, 1}, 40, 160)
    directo.rasgar(godpack)
    if godpack then
        fx.destello(rarezas.secreta.color, 1)
        fx.explosion(CX, CY, rarezas.secreta.color, 120, 260)
        fx.tintar(rarezas.secreta.color)
    end
    estado, t = "rasgado", 0
end

-- lo llamativo que es el precio de una carta: 0 apenas, 3 muchisimo (en centimos)
local function nivelPrecio(v)
    if v >= 3000 then return 3 end
    if v >= 500 then return 2 end
    if v >= 50 then return 1 end
    return 0
end
-- segundos que tarda en contar hasta el precio
local CUENTA = { [0] = 0, 0.35, 0.8, 1.5 }

local function impacto(c, r)
    c.nueva, c.copia = partida.anadir(c.def.id, primeraActual)
    c.precio = mercado.valor(c.def.id, primeraActual)
    c.nivelPrecio = nivelPrecio(c.precio)
    c.tPrecio, c.tic, c.contado = 0, 0, false
    c.tVista = 0
    c.coleccion = partida.distintas(c.def.set) .. "/" .. #partida.cartasDe(c.def.set)
    sonido.tocar(r.id)
    directo.carta(c.def, c.nueva)
    if r.nivel >= 4 then fx.golpear(r.nombre:upper(), r.color, 40) end
    if r.nivel >= 6 then
        fx.explosion(CX, CY, p.amarillo, 120, 240)
        fx.explosion(CX, CY, p.blanco, 40, 300)
    end
    fx.explosion(CX, CY, r.color, 8 + r.nivel ^ 2 * 6, 60 + r.nivel * 30)
    fx.sacudir(r.nivel ^ 1.4)
    if r.nivel >= 3 then fx.destello(r.color, 0.15 + r.nivel * 0.08) end
    if r.nivel >= 4 then
        fx.camaraLenta(0.6, 0.25)
        fx.tintar(r.color)
    end
    if c.nueva then
        sonido.tocar("nueva")
        sonido.tocar("nueva", 1.5)
        fx.confeti(CX - 50, CY - 74, 50, 170)
        fx.confeti(CX + 50, CY - 74, 30, 140)
        fx.destello(p.amarillo, 0.12)
    end
end

-- el precio sube contando hasta su valor; cuanto mas vale, mas tarda y mas ruido hace
local function contarPrecio(c, dt)
    if not c.precio then return end
    c.tVista = c.tVista + dt
    local dur = CUENTA[c.nivelPrecio]
    if c.contado then return end
    c.tPrecio = c.tPrecio + dt
    if c.nivelPrecio >= 2 then
        c.tic = c.tic - dt
        if c.tic <= 0 then
            sonido.tocar("encima", 0.8 + math.min(1, c.tPrecio / dur) * 1.6)
            c.tic = 0.05
        end
        if c.nivelPrecio == 3 and love.math.random() < 0.6 then fx.lluviaMonedas(1) end
    end
    if c.tPrecio >= dur then
        c.contado = true
        local n = c.nivelPrecio
        if n >= 1 then sonido.tocar("moneda", 1 + n * 0.1) end
        if n >= 2 then
            fx.monedas(CX + 110, CY, n == 3 and 70 or 18, n == 3 and 260 or 170, 300)
            fx.sacudir(n * 2)
        end
        if n == 3 then
            fx.destello(p.amarillo, 0.35)
            fx.lluviaMonedas(50)
            sonido.tocar("moneda", 0.8)
        end
    end
end

local function extra(barrido)
    return { primera = primeraActual, barrido = barrido }
end

local function actualizarCarta(dt, mantenido)
    local c = mano[idx]
    local r = rarezas[c.def.rareza]
    tf = tf + dt

    if fase == "esperando" then
        if pulsado or (mantenido and tf > 0.12) then
            fase, tf = r.suspense > 0 and "suspense" or "girando", 0
            latido = 0
            if r.suspense > 0 then directo.suspense() end
        end
    elseif fase == "suspense" then
        latido = latido - dt
        if latido <= 0 then
            sonido.tocar("latido", 1 + tf * 0.4)
            fx.sacudir(1 + r.nivel * 0.4)
            latido = math.max(0.12, 0.4 - tf * 0.2)
        end
        if tf >= r.suspense then fase, tf = "girando", 0 end
    elseif fase == "girando" then
        if tf >= GIRO / 2 and not c.boca then
            c.boca = true
            sonido.tocar("giro")
            impacto(c, r)
        end
        if tf >= GIRO then fase, tf = "mostrando", 0 end
    elseif fase == "mostrando" then
        contarPrecio(c, dt)
        -- las normales pasan solas, las buenas esperan a que las mires;
        -- y ninguna se va hasta que se ha visto su precio
        local cuenta = CUENTA[c.nivelPrecio or 0]
        local extraNueva = c.nueva and 0.3 or 0
        local auto = r.nivel <= 2 and c.nivelPrecio < 2 and tf > (mantenido and 0.12 or 0.4) + cuenta + extraNueva
        local minimo = math.max(r.nivel >= 4 and 0.6 or 0.15, cuenta * 0.85, c.nueva and 0.35 or 0)
        if auto or (pulsado and tf > minimo) then fase, tf = "volando", 0 end
    elseif fase == "volando" then
        local q = fx.salidaSuave(math.min(1, tf / 0.22))
        c.x = fx.lerp(CX, ranuraX(idx), q)
        c.y = fx.lerp(CY, RANURA_Y, q)
        c.escala = fx.lerp(GRANDE, MINI, q)
        if tf >= 0.22 then
            idx = idx + 1
            if idx > #mano then
                estado, t = "resumen", 0
                partida.guardar()
                local defs = {}
                for i, m in ipairs(mano) do defs[i] = m.def end
                directo.finSobre(defs, godpack, tipoActual.id)
                partida.encargoSobre(tipoActual.id, primeraActual)
            else
                fase, tf = "esperando", 0
            end
        end
    end
end

function apertura.update(dt, mantenido)
    if not estado then
        pulsado = false
        return
    end
    dt = dt * dev.velocidad
    t = t + dt

    if estado == "entrando" then
        if t > DURACION_ENTRADA then estado, t = "sobre", 0 end
    elseif estado == "sobre" then
        if mantenido then
            carga = math.min(1, carga + dt / 0.8)
        else
            carga = math.max(0, carga - dt * 2.5)
        end
        sonido.carga(carga)
        if carga >= 1 then rasgar() end
    elseif estado == "rasgado" then
        if t > 0.55 then
            estado, t = "revelando", 0
            idx, fase, tf = 1, "esperando", 0
        end
    elseif estado == "revelando" then
        actualizarCarta(dt, mantenido)
    elseif estado == "resumen" then
        for i, c in ipairs(mano) do
            local q = fx.salidaRebote(math.min(1, math.max(0, (t - i * 0.05) / 0.35)))
            c.x = fx.lerp(ranuraX(i), resumenX(i), q)
            c.y = fx.lerp(RANURA_Y, resumenY(i), q)
            c.escala = fx.lerp(MINI, escalaResumen(), q)
        end
    elseif estado == "lote" then
        if pulsado and t > 0.5 then
            if not apertura.lote(5) then estado = nil end
        end
    end

    pulsado = false
end

local function texto(cad, y, escala, color)
    if estado == "lote" then
        fuentes.texto(cad, 0, y, escala, color, "center", 640)
    else
        fuentes.texto(cad, ZX, y, escala, color, "center", ZW)
    end
end

local function parpadeo()
    return 0.55 + math.sin(love.timer.getTime() * 4) * 0.35
end

local function dibujarSobre()
    local x, y, giro, escala = CX, CY, 0, ESCALA_SOBRE
    if estado == "entrando" then
        local q = math.min(1, t / DURACION_ENTRADA)
        if entrada then
            -- llega desde donde se solto: rebota y se endereza bailando
            local e = fx.salidaRebote(q)
            x = fx.lerp(entrada.x, CX, e)
            y = fx.lerp(entrada.y, CY, e)
            escala = fx.lerp(entrada.escala, ESCALA_SOBRE, fx.salidaSuave(q))
            giro = entrada.a * math.cos(q * 9) * (1 - q)
        else
            y = fx.lerp(420, CY, fx.salidaRebote(q))
        end
    end
    local bote = math.sin(love.timer.getTime() * 2) * 2 * (1 - carga)
    local dx = (love.math.random() * 2 - 1) * carga * 3
    local dy = (love.math.random() * 2 - 1) * carga * 3

    -- solo los sobres con premio brillan de color al cargar, el resto en blanco
    if carga > 0.4 then
        local color = mejor.nivel >= 4 and mejor.color or {1, 1, 1}
        fx.aura(CX, y, color, 90 + carga * 40, (carga - 0.4) * 1.2)
    end
    sobre.dibujar(tipoActual.id, x + dx, y + bote + dy, escala + carga * 0.4, giro + (love.math.random() - 0.5) * carga * 0.06)

    if estado == "sobre" then
        local b = parpadeo()
        texto("MANTÉN CLICK O ESPACIO PARA ABRIR", 268, 1, {1, 1, 1, b})
    end
end

local function dibujarRasgado()
    local W, H = sobre.ANCHO * ESCALA_SOBRE, sobre.ALTO * ESCALA_SOBRE
    local izq, arriba = CX - W / 2, CY - H / 2
    local q = math.min(1, t / 0.55)

    local e = GRANDE * fx.lerp(0.6, 1, fx.salidaRebote(math.min(1, t / 0.4)))
    for i = #mano, 1, -1 do
        carta.dibujar(nil, CX, CY - (i - 1) * 2, e, e, 0, false)
    end

    lg.setColor(1, 1, 1, 1 - q)
    local img = sobre.imagen(tipoActual.id)
    lg.draw(img, sobre.abajo, izq, arriba + sobre.CORTE * ESCALA_SOBRE + t * t * 900, 0, ESCALA_SOBRE, ESCALA_SOBRE)
    lg.draw(img, sobre.arriba, izq + t * 260, arriba - t * 300 + t * t * 500, t * 5, ESCALA_SOBRE, ESCALA_SOBRE)
    lg.setColor(1, 1, 1)
end

local function dibujarLote()
    local L = lote
    local cabecera = L.abiertos .. " SOBRES  -  " .. L.total .. " CARTAS  -  " .. L.numNuevas .. " NUEVAS  -  VALOR " .. ui.dinero(L.valor)
    texto(cabecera, 30, 1, p.blanco)
    if L.godpacks > 0 then texto(L.godpacks == 1 and "¡GOD PACK!" or ("¡" .. L.godpacks .. " GOD PACKS!"), 40, 2, rarezas.secreta.color) end

    -- 12 por fila a tamaño normal; con muchas distintas, 24 por fila a la mitad
    local pequenas = #L.cartas > 48
    local columnas = pequenas and 24 or 12
    local base = pequenas and 0.5 or 1
    local pasoX, pasoY = pequenas and 25 or 48, pequenas and 33 or 62
    local cw, ch = carta.ANCHO * base, carta.ALTO * base
    for k, def in ipairs(L.cartas) do
        local aparece = math.min(1, math.max(0, (t - k * (pequenas and 0.01 or 0.03)) / 0.2))
        if aparece > 0 and k <= columnas * (pequenas and 8 or 4) then
            local col, fila = (k - 1) % columnas, math.floor((k - 1) / columnas)
            local cx = 320 + (col - (columnas - 1) / 2) * pasoX
            local cy = (pequenas and 74 or 88) + fila * pasoY
            local r = rarezas[def.rareza]
            local e = fx.salidaRebote(aparece) * base
            local id = "lote" .. def.id
            if r.nivel >= 4 then fx.aura(cx, cy, r.color, 34 * base, 0.35) end
            carta.dibujar(def, cx, cy, e, e, 0, true, ui.hoverCarta(id, cx, cy, cw, ch), partida.enfundadas(def.id) > 0)
            if L.cuenta[def.id] > 1 then carta.contador(L.cuenta[def.id], cx + cw / 2 + (pequenas and 3 or 0), cy + ch / 2) end
            if L.nuevas[def.id] then
                if pequenas then
                    lg.setColor(p.amarillo)
                    lg.rectangle("fill", cx - cw / 2, cy - ch / 2 - 3, cw, 2)
                    lg.setColor(1, 1, 1)
                else
                    fuentes.texto("NUEVA", cx - 20, cy - 33, 1, p.amarillo, "center", 40)
                end
            end
            ui.zona(id, cx - cw / 2, cy - ch / 2, cw, ch)
            if ui.encima == id then
                ui.tooltip(def.nombre, r.color, {
                    { r.nombre, r.color },
                    { "En este lote: " .. L.cuenta[def.id] },
                    { "Copias: " .. partida.copias(def.id) },
                    { "Valor " .. ui.dinero(mercado.valor(def.id)), p.amarillo },
                })
            end
        end
    end

    if t > 0.5 then
        local quedan = partida.sobresGuardados()
        if quedan > 0 then
            ui.boton("otroLote", "ABRIR " .. math.min(5, quedan) .. " MÁS (" .. quedan .. ")", 214, 330, 110, 16, p.verde)
        else
            ui.boton("tienda", "COMPRAR MÁS", 214, 330, 110, 16, p.verde)
        end
        ui.boton("armario", "ARMARIO", 332, 330, 94, 16, p.azul)
    end
end

local function dibujarPrecio(c)
    if not c.precio then return end
    local n = c.nivelPrecio
    local dur = CUENTA[n]
    local q = dur > 0 and math.min(1, c.tPrecio / dur) or 1
    local valor = c.precio * (1 - (1 - q) ^ 3)
    local escala = n + 1
    -- al acabar de contar da un saltito
    if c.contado and c.tVista - dur < 0.12 and n >= 1 then escala = escala + 1 end
    local cad = ui.dinero(valor)
    local x, y = CX + 66, CY - 4 - escala * 3
    if n == 3 and not c.contado then
        x = x + love.math.random(-1, 1)
        y = y + love.math.random(-1, 1)
    end
    local color = n == 0 and p.grisclaro or p.amarillo
    if n == 3 and math.floor(love.timer.getTime() * 10) % 2 == 0 then color = p.blanco end
    if n >= 2 then
        local w = fuentes.ancho(cad, escala)
        lg.setColor(0, 0, 0, 0.55)
        lg.rectangle("fill", x - 4, y - 4, w + 8, escala * 5 + 8)
    end
    if n >= 1 then fuentes.texto("VALE", x, y - 13, 1, p.grisclaro) end
    fuentes.texto(cad, x + escala, y + escala, escala, { 0, 0, 0, 0.7 })
    fuentes.texto(cad, x, y, escala, color)
    if n == 3 and c.contado then fx.chispas(x + fuentes.ancho(cad, escala) / 2, y + 10, fuentes.ancho(cad, escala), 24, p.amarillo, 12) end
end

-- cartel de NUEVA encima de la carta: entra con rebote y parpadea
local function dibujarNueva(c)
    local tv = c.tVista or 0
    local q = math.min(1, tv / 0.3)
    local s = q < 1 and fx.salidaRebote(q) or 1
    local x, y = CX, CY - 84
    local w, h = 70, 18
    local fondo = math.floor(tv * 6) % 2 == 0 and p.rojo or p.naranja
    lg.push()
    lg.translate(x, y)
    lg.scale(s, s)
    lg.setColor(p.negro)
    lg.rectangle("fill", -w / 2 - 2, -h / 2 - 2, w + 4, h + 4)
    lg.setColor(fondo)
    lg.rectangle("fill", -w / 2, -h / 2, w, h)
    lg.setColor(p.amarillo)
    lg.rectangle("fill", -w / 2, -h / 2, w, 2)
    lg.rectangle("fill", -w / 2, h / 2 - 2, w, 2)
    fuentes.texto("¡NUEVA!", -w / 2, -5, 2, p.amarillo, "center", w)
    lg.pop()
    fx.chispas(x, y, 90, 26, p.amarillo, 14)
    texto("+1 A TU COLECCIÓN  (" .. c.coleccion .. ")", 280, 1, { p.amarillo[1], p.amarillo[2], p.amarillo[3], math.min(1, tv * 3) })
end

local function dibujarActual(c)
    local r = rarezas[c.def.rareza]
    local x, y = c.x, c.y
    local sx, sy = c.escala, c.escala
    local rot = 0
    local h
    local barrido

    if fase == "suspense" then
        local fuerza = tf / r.suspense
        x = x + (love.math.random() * 2 - 1) * fuerza * 3
        y = y + (love.math.random() * 2 - 1) * fuerza * 3
        fx.aura(CX, CY, r.color, 70 + fuerza * 60, fuerza * 0.9)
    elseif fase == "girando" then
        sx = c.escala * math.max(0.05, math.abs(math.cos(math.pi * tf / GIRO)))
        sy = c.escala * (1 + math.sin(math.pi * tf / GIRO) * 0.12)
    elseif fase == "mostrando" then
        -- las mejores oscurecen todo lo demas
        if r.nivel >= 5 then
            lg.setColor(0, 0, 0, math.min(0.55, tf * 2))
            lg.rectangle("fill", -10, -10, 660, 380)
            lg.setColor(1, 1, 1)
            fx.chispas(CX, CY, 150, 190, r.color, r.nivel >= 6 and 40 or 18)
        end
        if r.nivel >= 3 then barrido = math.min(1, tf / 0.55) end
        local giroRayos = love.timer.getTime() * 0.5
        if r.nivel >= 3 then fx.rayos(CX, CY, r.color, 220, 0.06 * r.nivel, giroRayos) end
        if r.nivel >= 2 then fx.aura(CX, CY, r.color, 110, 0.15 * r.nivel) end
        local q = math.min(1, tf / 0.15)
        sx = c.escala * fx.lerp(1.15, 1, fx.salidaSuave(q))
        sy = sx
        rot = math.sin(love.timer.getTime() * 2) * 0.03
        -- se inclina un poco hacia el raton, como si la tuvieras en la mano
        local dx = math.max(-1, math.min(1, (ui.mx - CX) / 150))
        local dy = math.max(-1, math.min(1, (ui.my - CY) / 150))
        h = { brillo = 0.7, lx = dx, ly = dy }
    end

    carta.dibujar(c.def, x, y, sx, sy, rot, c.boca, h, false, extra(barrido))

    if fase == "mostrando" then
        texto(c.def.nombre, 246, 3, p.blanco)
        texto(r.nombre .. (primeraActual and "  -  1ª EDICIÓN" or ""), 268, 1, r.color)
        dibujarPrecio(c)
        if c.nueva then dibujarNueva(c) end
    end
end

local function dibujarRevelando()
    for i = #mano, idx + 1, -1 do
        carta.dibujar(nil, CX, CY - (i - idx) * 2, GRANDE, GRANDE, 0, false)
    end
    for i = 1, idx - 1 do
        local c = mano[i]
        carta.dibujar(c.def, c.x, c.y, c.escala, c.escala, 0, true, nil, false, extra())
    end
    dibujarActual(mano[idx])
end

local ANDROID = love.system.getOS() == "Android"

local function dibujarResumen()
    if godpack then texto("¡¡GOD PACK!!", 36, 3, rarezas.secreta.color) end
    local er = escalaResumen()
    local cw, ch = carta.ANCHO * er, carta.ALTO * er
    -- con dos filas los textos van mas pegados
    local dos = filasResumen() == 2

    for i, c in ipairs(mano) do
        local r = rarezas[c.def.rareza]
        local id = "res" .. i
        local h = t > 0.6 and ui.hoverCarta(id, c.x, c.y, cw, ch) or nil
        local funda = c.copia and c.copia.f
        if c.brillo then
            c.brillo = c.brillo - love.timer.getDelta() * 2
            if c.brillo <= 0 then c.brillo = nil end
        end
        if funda and c.brillo then fx.aura(c.x, c.y, p.cian, cw, c.brillo * 0.6) end
        local ex = extra()
        ex.top = c.copia and c.copia.t
        carta.dibujar(c.def, c.x, c.y, c.escala, c.escala, 0, true, h, funda, ex)
        if r.nivel >= 5 then fx.chispas(c.x, c.y, cw, ch, r.color, 4) end
        if t > 0.6 then
            ui.zona(id, c.x - cw / 2, c.y - ch / 2, cw, ch)
            local ty = c.y + ch / 2 + 4
            if not dos then
                fuentes.texto(r.nombre, c.x - 40, ty, 1, r.color, "center", 80)
                ty = ty + 9
            end
            if c.precio then
                local n = c.nivelPrecio
                local color = n == 0 and p.gris or (n >= 2 and p.amarillo or p.grisclaro)
                fuentes.texto(ui.dinero(c.precio), c.x - 40, ty, 1, dos and r.color or color, "center", 80)
            end
            if c.nueva then
                local pulso = 0.6 + math.sin(love.timer.getTime() * 6) * 0.4
                local mw, mh = cw + 6, ch + 6
                lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], pulso)
                lg.rectangle("line", math.floor(c.x - mw / 2) + 0.5, math.floor(c.y - mh / 2) + 0.5, mw, mh)
                fuentes.texto("¡NUEVA!", c.x - 40, c.y - ch / 2 - 10, 1, p.amarillo, "center", 80)
            end
            if ui.encima == id then
                ui.tooltip(c.def.nombre, r.color, {
                    { r.nombre, r.color },
                    { "Copias: " .. partida.copias(c.def.id) },
                    { "Valor " .. ui.dinero(mercado.valor(c.def.id, primeraActual)), p.amarillo },
                    { funda and "Enfundada" or "Arrastra una funda encima", funda and p.cian or p.gris },
                })
            end
        end
    end
    if primeraActual and t > 0.6 then texto("SOBRE DE 1ª EDICIÓN", 29, 1, p.amarillo) end

    -- sin botones: otro sobre se arrastra desde la caja (o espacio en el PC)
    if t > 0.5 then
        local a = parpadeo() * 0.7
        if partida.sobresGuardados() > 0 then
            texto(ANDROID and "ARRASTRA OTRO SOBRE DE LA CAJA" or "ARRASTRA OTRO SOBRE  -  ESPACIO: SIGUIENTE", 296, 1, {1, 1, 1, a})
        else
            texto("NO TE QUEDAN SOBRES: CÓMPRALOS EN LA TIENDA", 296, 1, {1, 1, 1, a})
        end
    end
end

function apertura.dibujar()
    if estado == "entrando" or estado == "sobre" then
        dibujarSobre()
    elseif estado == "rasgado" then
        dibujarRasgado()
    elseif estado == "revelando" then
        dibujarRevelando()
    elseif estado == "resumen" then
        dibujarResumen()
    elseif estado == "lote" then
        dibujarLote()
    end
end

-- mientras se abre no se puede salir de la pantalla
function apertura.bloqueada()
    return estado ~= nil and estado ~= "resumen" and estado ~= "lote"
end

-- hay algo en la mesa (un sobre, cartas o el resumen)
function apertura.activa()
    return estado ~= nil
end

function apertura.enResumen()
    return estado == "resumen"
end

function apertura.enLote()
    return estado == "lote"
end

-- el resumen se ve un momento y luego las cartas pasan a ser cosas de la mesa:
-- devuelve las cartas cuando ya toca (la mesa las coge y llama a recoger)
local ESPERA_MESA = 1.4

function apertura.cartasListas()
    if estado ~= "resumen" or t < ESPERA_MESA then return nil end
    return mano
end

-- se recoge la mesa: las cartas ya estan en el armario
function apertura.recoger()
    estado, mano = nil, nil
end

-- la carta del resumen que hay en (x, y), para soltarle una funda
function apertura.cartaEn(x, y)
    if estado ~= "resumen" or t < 0.6 then return nil end
    local er = escalaResumen()
    local cw, ch = carta.ANCHO * er, carta.ALTO * er
    for i = #mano, 1, -1 do
        local c = mano[i]
        if math.abs(x - c.x) <= cw / 2 and math.abs(y - c.y) <= ch / 2 then return c end
    end
end

-- centro de la zona de apertura
function apertura.centro()
    return CX, CY
end

return apertura
