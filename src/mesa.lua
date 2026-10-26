-- La mesa: donde se abren los sobres y se hacen los directos.
-- A la izquierda una caja de carton con los sobres guardados y las fundas;
-- en medio el tapete, donde se suelta el sobre y se abre (src/apertura.lua);
-- a la derecha el movil en el tripode con el chat (src/directo.lua).
-- Los sobres se arrastran con un poco de peso: se balancean al moverlos.
local sobres = require "datos.sobres"
local sets = require "datos.sets"
local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local partida = require "src.partida"
local mercado = require "src.mercado"
local carta = require "src.carta"
local sobre = require "src.sobre"
local caja = require "src.caja"
local encima = require "src.encima"
local logros = require "src.logros"
local apertura = require "src.apertura"
local directo = require "src.directo"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local desbloqueos = require "src.desbloqueos"
local ui = require "src.ui"

local lg = love.graphics

local mesa = {}

local CAJA = { x = 4, y = 24, w = 108, h = 330 }
local TAPETE = { x = 116, y = 24, w = 386, h = 330 }
local DIRECTO = { x = 506, y = 24, w = 130, h = 330 }
local FUNDAS = { x = CAJA.x + 8, y = CAJA.y + 228, w = CAJA.w - 16, h = 62 }
-- donde se queda la caja abierta: abajo a la derecha del tapete (no tapa las cartas)
local ESQUINA = { x = TAPETE.x + TAPETE.w - 36, y = TAPETE.y + 28, e = 1 }
-- animacion de abrir una caja (src/caja.lua)
local animCaja
local CW, CH = carta.ANCHO, carta.ALTO
-- tamaño de las cartas sueltas en la mesa (las del sobre y las sacadas del armario)
local ESCALA_COPIA = 1.75
local ESCALA_COGIDO = 2

-- lo que llevas en la mano: { cosa = "sobre" | "funda" | "copia", ... }
local mano
-- sobres que vuelven a la caja tras soltarlos fuera del tapete
local vuelos = {}
-- donde empezo el click: solo mantener sobre el tapete carga el sobre
local pulsadoEnTapete = false
local mesaSel      -- copia de la mesa elegida (u)
local zMesa = 0
-- donde se pulso el sobre del tapete: si se arrastra, se coge (para guardarlo)
local pulsoSobre
-- chip SACAR SOBRES junto a una caja cerrada que se ha tocado sin arrastrarla
local chipCaja
-- donde se pinta cada caja cerrada de la caja de carton (para el chip)
local sitioCajas = {}
-- bocadillo de ayuda que se esta viendo (cada uno sale una vez por partida)
local pistaVista
local reporte = require "src.reporte"

local function dentro(r, x, y)
    return x >= r.x and x < r.x + r.w and y >= r.y and y < r.y + r.h
end

-- tipos de sobre que se ven en la caja: caben 4; primero los que tienes y
-- luego huecos vacios de sets ya salidos
local function tiposCaja()
    local lista = {}
    for _, tipo in ipairs(sobres.lista) do
        if partida.disponibles(tipo.id) > 0 and #lista < 4 then table.insert(lista, tipo) end
    end
    for _, tipo in ipairs(sobres.lista) do
        if mercado.salido(tipo.set) and partida.disponibles(tipo.id) == 0 and #lista < 4 then table.insert(lista, tipo) end
    end
    return lista
end

-- centro del hueco de un tipo de sobre en la caja
local function hueco(k)
    local col, fila = (k - 1) % 2, math.floor((k - 1) / 2)
    return CAJA.x + 29 + col * 50, CAJA.y + 52 + fila * 66
end

local function huecoDe(tipoId)
    for k, tipo in ipairs(tiposCaja()) do
        if tipo.id == tipoId then return hueco(k) end
    end
    return CAJA.x + CAJA.w / 2, CAJA.y + 60
end

-- copias sacadas a la mesa: sitio por defecto abajo del tapete
local function sitioMesa(s, k)
    if s.x and dentro(TAPETE, s.x, s.y) then return s end
    local col, fila = (k - 1) % 5, math.floor((k - 1) / 5)
    s.x = TAPETE.x + 42 + col * 74 + love.math.random(-4, 4)
    s.y = TAPETE.y + TAPETE.h - 50 - fila * 40 + love.math.random(-4, 4)
    s.r = (love.math.random() - 0.5) * 0.15
    s.z = 0
    return s
end

-- tamaño de una carta de la mesa (las del sobre llegan con el del resumen)
local function escalaDe(s)
    return s.e or ESCALA_COPIA
end

local function entradaMesa(u)
    for _, s in ipairs(partida.mesa) do
        if s.u == u then return s end
    end
end

local function cobrar(ganado, x, y)
    if ganado <= 0 then return end
    sonido.tocar("moneda")
    fx.texto(x, y - 10, "+" .. ui.dinero(ganado), p.amarillo)
    fx.explosion(x, y, p.amarillo, 10 + math.min(40, math.floor(ganado / 20)), 90)
    partida.guardar()
end

local function sinFundas(x, y)
    sonido.tocar("latido")
    fx.texto(x, y - 10, "SIN FUNDAS: CÓMPRALAS EN LA TIENDA", p.rojo)
end

local function brilloFunda(x, y)
    sonido.tocar("nueva")
    fx.explosion(x, y, p.cian, 14, 70)
    partida.guardar()
end

-- sobres que puedes abrir: los guardados y los de la caja abierta
local function quedanSobres()
    local n = partida.cajaAbierta and partida.cajaAbierta.quedan or 0
    for _, t in ipairs(sobres.lista) do n = n + partida.disponibles(t.id) end
    return n
end

-- empezar a abrir un sobre de este tipo, llegando desde (x, y)
-- deCaja: el sobre sale de la caja abierta, no de los guardados
local function soltarSobre(tipoId, x, y, a, escala, deCaja)
    if apertura.bloqueada() or animCaja then return false end
    local tipo, primera
    if deCaja then
        tipo, primera = partida.sacarDeCaja()
    else
        tipo, primera = partida.sacarSobre(tipoId, true)
    end
    if not tipo then return false end
    -- lo que habia en la mesa vuelve solo al armario
    apertura.recoger()
    partida.recogerMesa()
    mesaSel = nil
    partida.guardar()
    sonido.tocar("giro")
    fx.sacudir(2)
    apertura.empezar(tipo, primera, { x = x, y = y, a = a, escala = escala, deCaja = deCaja or nil })
    reporte.apuntar("sobre " .. tipo.id .. (primera and " 1ed" or "") .. (deCaja and " de caja" or ""))
    return true
end

-- vuelve volando a su sitio en la caja de carton (o a la caja abierta)
local function volarACaja(tipoId, x0, y0, e0, a, deCaja)
    local x1, y1
    if deCaja and partida.cajaAbierta then
        x1, y1 = ESQUINA.x, ESQUINA.y
    else
        x1, y1 = huecoDe(tipoId)
    end
    table.insert(vuelos, { tipo = tipoId, x0 = x0, y0 = y0, x1 = x1, y1 = y1, e0 = e0, a = a or 0, t = 0 })
end

local function verPista(id)
    if partida.pistas[id] then return end
    partida.pistas[id] = true
    partida.guardar()
end

-- guarda el sobre del tapete sin abrirlo (boton, ESC o clic derecho)
function mesa.cancelar()
    local r = apertura.cancelar()
    if not r then return false end
    local cx, cy = apertura.centro()
    volarACaja(r.tipo, cx, cy, 3, 0, r.deCaja)
    sonido.tocar("giro")
    fx.texto(cx, cy - 60, "GUARDADO", p.lima)
    verPista("guardar")
    pulsoSobre = nil
    reporte.apuntar("sobre guardado " .. r.tipo)
    partida.guardar()
    return true
end

-- todas las cartas sueltas de la mesa al armario
function mesa.recoger()
    if #partida.mesa == 0 or apertura.activa() or animCaja then return false end
    partida.recogerMesa()
    mesaSel = nil
    sonido.tocar("giro")
    fx.texto(TAPETE.x + TAPETE.w / 2, TAPETE.y + TAPETE.h / 2, "AL ARMARIO", p.lima)
    partida.guardar()
    return true
end

-- saca los sobres de una caja cerrada sin abrirla
local function sacarDeCajaCerrada(tipoId)
    local n = partida.vaciarCaja(sobres[tipoId])
    chipCaja = nil
    if not n then return end
    local s = sitioCajas[tipoId]
    sonido.tocar("giro")
    fx.texto(s and s.x or CAJA.x + CAJA.w / 2, (s and s.y or CAJA.y + 170) - 20, "+" .. n .. " SOBRES", p.lima)
    verPista("sacar")
    partida.guardar()
end

-- dibujo

-- un monton de fundas o de top loaders de la caja (se arrastran a una carta)
local function monton(que, x, y, w, h, estrecho)
    local esTop = que == "top"
    local libres = (esTop and partida.topsLibres or partida.fundasLibres) - ((mano and mano.cosa == que) and 1 or 0)
    local color = esTop and p.celeste or p.cian
    ui.caja(x, y, w, h, p.grisosc)
    fuentes.texto(esTop and "TOPS" or "FUNDAS", x, y + 4, 1, p.blanco, "center", w)
    for i = math.min(4, libres), 1, -1 do
        local fx0, fy0 = x + w / 2 - 11 + i * 2, y + 14 - i
        lg.setColor(1, 1, 1, esTop and 0.2 or 0.12)
        lg.rectangle("fill", fx0, fy0, 18, 25)
        lg.setColor(color[1], color[2], color[3], 0.7)
        lg.rectangle("line", fx0 + 0.5, fy0 + 0.5, 17, 24)
        -- el top loader es rigido: borde de arriba gordo
        if esTop then lg.rectangle("fill", fx0 + 1, fy0 + 1, 16, 3) end
    end
    fuentes.texto("X" .. math.max(0, libres), x, y + 44, 1, libres > 0 and color or p.rojo, "center", w)
    local puede = libres > 0 and not apertura.bloqueada()
    local pista
    if puede then pista = estrecho and "ARRASTRA" or "ARRÁSTRALA A UNA CARTA"
    elseif libres > 0 then pista = estrecho and "TRAS ABRIR" or "AL ACABAR EL SOBRE"
    else pista = estrecho and "EN TIENDA" or "CÓMPRALAS EN LA TIENDA" end
    fuentes.texto(pista, x, y + 52, 1, p.grisclaro, "center", w)
    if puede then ui.zona("caja_" .. que, x, y, w, h) end
end

local function dibujarCaja()
    -- caja de carton
    lg.setColor(p.negro)
    lg.rectangle("fill", CAJA.x, CAJA.y, CAJA.w, CAJA.h)
    lg.setColor(p.naranja[1] * 0.55, p.naranja[2] * 0.4, p.naranja[3] * 0.3)
    lg.rectangle("fill", CAJA.x + 1, CAJA.y + 1, CAJA.w - 2, CAJA.h - 2)
    lg.setColor(p.naranja[1] * 0.4, p.naranja[2] * 0.28, p.naranja[3] * 0.2)
    lg.rectangle("fill", CAJA.x + 4, CAJA.y + 14, CAJA.w - 8, CAJA.h - 18)
    -- cinta de embalar
    lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.25)
    lg.rectangle("fill", CAJA.x + CAJA.w / 2 - 6, CAJA.y + 1, 12, 13)
    fuentes.texto("TUS SOBRES", CAJA.x, CAJA.y + 5, 1, p.amarillo, "center", CAJA.w)

    local bloqueada = apertura.bloqueada()
    -- llevas un sobre: soltarlo aqui lo guarda (el de la caja abierta, todos)
    if mano and mano.cosa == "sobre" and dentro(CAJA, ui.mx, ui.my) then
        local a = 0.12 + math.sin(love.timer.getTime() * 8) * 0.05
        lg.setColor(p.lima[1], p.lima[2], p.lima[3], a)
        lg.rectangle("fill", CAJA.x + 1, CAJA.y + 1, CAJA.w - 2, CAJA.h - 2)
        local c = partida.cajaAbierta
        local cad = (mano.deCaja and c) and ("GUARDAR LOS " .. c.quedan) or "GUARDAR"
        fuentes.texto(cad, CAJA.x, CAJA.y + 15, 1, p.lima, "center", CAJA.w)
    end
    for k, tipo in ipairs(tiposCaja()) do
        local x, y = hueco(k)
        local n = partida.disponibles(tipo.id)
        local p1 = partida.apartado("s", tipo.id, true) and 0 or partida.sobres(tipo.id, true)
        local cogido = mano and mano.cosa == "sobre" and mano.tipo == tipo.id and not mano.deCaja and 1 or 0
        local quedan = n - cogido
        -- fondo del hueco
        lg.setColor(0, 0, 0, 0.25)
        lg.rectangle("fill", x - 23, y - 26, 46, 62)
        if quedan > 0 then
            for i = math.min(3, quedan), 1, -1 do
                local dy = (i - 1) * -2
                sobre.dibujar(tipo.id, x + (i - 1), y + dy, 1, (i - 1) * 0.04)
            end
            local enc = ui.encima == "caja_" .. tipo.id and not bloqueada
            if enc then
                lg.setColor(1, 1, 1, 0.25)
                lg.rectangle("line", x - 15.5, y - 22.5, 31, 45)
            end
            if not bloqueada then ui.zona("caja_" .. tipo.id, x - 18, y - 24, 36, 50) end
        else
            lg.setColor(1, 1, 1, 0.12)
            lg.rectangle("line", x - 14.5, y - 21.5, 29, 43)
        end
        fuentes.texto(sets[tipo.set].codigo .. " X" .. quedan, x - 23, y + 26, 1, quedan > 0 and p.blanco or p.gris, "center", 46)
        if p1 > 0 then fuentes.texto(p1 .. " 1ª ED", x - 23, y + 28 + fuentes.alto(), 1, p.amarillo, "center", 46) end
    end

    -- cajas cerradas: se arrastran al tapete para abrirlas
    -- hasta 4 sets de cajas, en 2 filas de 2
    local hayCajas = 0
    for _, tipo in ipairs(sobres.lista) do
        local n = partida.cajasDisponibles(tipo.id)
        if n > 0 and hayCajas < 4 then
            hayCajas = hayCajas + 1
            local col, fila = (hayCajas - 1) % 2, math.floor((hayCajas - 1) / 2)
            local cx, cy = CAJA.x + 29 + col * 50, CAJA.y + 172 + fila * 29
            local cogida = mano and mano.cosa == "cajabox" and mano.tipo == tipo.id
            local quedan = n - (cogida and 1 or 0)
            if quedan > 0 then caja.dibujar(tipo.id, cx, cy, 1, { mini = true }) end
            fuentes.texto("X" .. quedan, cx + 12, cy + 7, 1, p.blanco)
            sitioCajas[tipo.id] = { x = cx, y = cy }
            if not bloqueada and not animCaja then ui.zona("cajabox_" .. tipo.id, cx - 16, cy - 14, 32, 27) end
        end
    end
    -- chip para sacar los sobres de la caja tocada (se va solo)
    if chipCaja and not mano then
        local s = sitioCajas[chipCaja.tipo]
        if s and partida.cajasDisponibles(chipCaja.tipo) > 0 and not bloqueada then
            local w = math.min(CAJA.w - 4, math.max(62, fuentes.ancho("SACAR SOBRES") + 10))
            local x = math.max(CAJA.x + 2, math.min(CAJA.x + CAJA.w - w - 2, s.x - w / 2))
            ui.boton("mesa_sacar", "SACAR SOBRES", x, s.y - 30, w, 12, p.azul)
        else
            chipCaja = nil
        end
    end

    -- fundas (y top loaders al lado cuando salen): solo tras desbloquearlas
    if desbloqueos.hay("fundas") then
        local F = FUNDAS
        if desbloqueos.hay("tops") then
            local fw = math.floor(F.w / 2) - 1
            monton("funda", F.x, F.y, fw, F.h, true)
            monton("top", F.x + fw + 2, F.y, F.w - fw - 2, F.h, true)
        else
            monton("funda", F.x, F.y, F.w, F.h)
        end
    end

    -- copias en la mesa
    fuentes.texto("DEL ARMARIO " .. partida.propiasEnMesa() .. "/" .. partida.MAX_MESA, CAJA.x, CAJA.y + CAJA.h - 26, 1, p.grisclaro, "center", CAJA.w)
    if mano and mano.cosa == "copia" then
        fuentes.texto("SUÉLTALA AQUÍ PARA", CAJA.x, CAJA.y + CAJA.h - 17, 1, p.lima, "center", CAJA.w)
        fuentes.texto("GUARDARLA", CAJA.x, CAJA.y + CAJA.h - 10, 1, p.lima, "center", CAJA.w)
    end
end

local function dibujarTapete()
    local T = TAPETE
    lg.setColor(p.negro)
    lg.rectangle("fill", T.x, T.y, T.w, T.h)
    lg.setColor(p.verdeosc)
    lg.rectangle("fill", T.x + 1, T.y + 1, T.w - 2, T.h - 2)
    lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.22)
    for y = T.y + 3, T.y + T.h - 3, 6 do
        for x = T.x + 3 + (y % 12 == 3 and 3 or 0), T.x + T.w - 3, 6 do
            lg.rectangle("fill", x, y, 1, 1)
        end
    end
    -- marco del tapete
    lg.setColor(p.verde[1], p.verde[2], p.verde[3], 0.35)
    lg.rectangle("line", T.x + 6.5, T.y + 6.5, T.w - 13, T.h - 13)

    -- si llevas un sobre encima, el tapete se ilumina
    if mano and mano.cosa == "sobre" and dentro(T, ui.mx, ui.my) then
        local a = 0.12 + math.sin(love.timer.getTime() * 8) * 0.05
        lg.setColor(p.lima[1], p.lima[2], p.lima[3], a)
        lg.rectangle("fill", T.x + 1, T.y + 1, T.w - 2, T.h - 2)
    end

    -- lo que llevas del set del ultimo sobre, arriba a la izquierda
    local ultimo = apertura.ultimoTipo()
    if ultimo and not animCaja then
        local setId = sobres[ultimo].set
        local tiene, total = partida.distintas(setId), #partida.cartasDe(setId)
        local cad = sets[setId].codigo .. " " .. tiene .. "/" .. total .. "  " .. math.floor(tiene / total * 100) .. "%"
        if tiene >= total then cad = sets[setId].codigo .. " COMPLETO" end
        fuentes.texto(cad, T.x + 10, T.y + 10, 1, tiene >= total and p.amarillo or { 1, 1, 1, 0.55 })
    end

    -- mientras se abre una caja no hay pistas: la caja es la protagonista
    if not animCaja and not apertura.activa() and #partida.mesa > 0 then
        -- con cartas en la mesa, la pista va abajo y pequeña
        local a = 0.45 + math.sin(love.timer.getTime() * 4) * 0.2
        local cad
        if quedanSobres() == 0 then
            cad = "SIN SOBRES: CÓMPRALOS EN LA TIENDA"
            ui.boton("mesa_recoger", "RECOGER MESA", T.x + T.w - 92, T.y + T.h - 22, 84, 16, p.azul)
        elseif love.system.getOS() == "Android" then
            cad = "ARRASTRA OTRO SOBRE: LO DE LA MESA SE GUARDA SOLO"
        else
            cad = "ARRASTRA OTRO SOBRE O PULSA ESPACIO: LO DE LA MESA SE GUARDA SOLO"
        end
        fuentes.texto(cad, T.x, T.y + T.h - 12, 1, { 1, 1, 1, a }, "center", T.w)
    elseif not animCaja and not apertura.activa() then
        local cx, cy = T.x, T.y + T.h / 2 - 30
        if quedanSobres() > 0 then
            fuentes.texto("ARRASTRA UN SOBRE AQUÍ", cx, cy, 2, p.lima, "center", T.w)
            if love.system.getOS() ~= "Android" then
                fuentes.texto("O PULSA ESPACIO", cx, cy + 16, 1, p.verde, "center", T.w)
            end
            if directo.sugerir() then
                fuentes.texto("CONSEJO: EMPIEZA UN DIRECTO ANTES >", cx, cy + 30, 1, p.naranja, "center", T.w)
            end
        else
            fuentes.texto("NO TE QUEDAN SOBRES", cx, cy, 2, p.lima, "center", T.w)
            fuentes.texto("CÓMPRALOS EN LA TIENDA", cx, cy + 16, 1, p.verde, "center", T.w)
        end
    end
end

local function dibujarCopias()
    if #partida.mesa == 0 then return end
    -- mientras se abre un sobre se apartan un poco (se ven de fondo)
    local fondo = apertura.bloqueada()
    local lista = {}
    for k, s in ipairs(partida.mesa) do table.insert(lista, sitioMesa(s, k)) end
    table.sort(lista, function(a, b) return (a.z or 0) < (b.z or 0) end)
    for _, s in ipairs(lista) do
        local cogida = mano and mano.cosa == "copia" and mano.u == s.u
        local e = escalaDe(s)
        local w, h = CW * e, CH * e
        if not cogida then
            local def = partida.carta(s.id)
            local c = partida.copia(s.id, s.u)
            local zid = "m" .. s.u
            if fondo then
                carta.dibujar(def, s.x, s.y, e, e, s.r or 0, true, nil, c.f, { primera = c.p, top = c.t })
                lg.setColor(p.verdeosc[1], p.verdeosc[2], p.verdeosc[3], 0.6)
                lg.rectangle("fill", s.x - w / 2, s.y - h / 2, w, h)
                lg.setColor(1, 1, 1)
            else
                if mesaSel == s.u then
                    lg.setColor(p.amarillo)
                    lg.rectangle("line", s.x - w / 2 - 2.5, s.y - h / 2 - 2.5, w + 5, h + 5)
                end
                if s.brillo then fx.aura(s.x, s.y, p.cian, w, s.brillo * 0.6) end
                carta.dibujar(def, s.x, s.y, e, e, s.r or 0, true, ui.hoverCarta(zid, s.x, s.y, w, h), c.f, { primera = c.p, top = c.t })
                ui.zona(zid, s.x - w / 2, s.y - h / 2, w, h)
                if s.nueva then
                    fuentes.texto("¡NUEVA!", s.x - 30, s.y - h / 2 - 8, 1, p.amarillo, "center", 60)
                end
                if ui.encima == zid and not mano then
                    local r = rarezas[def.rareza]
                    ui.tooltip(def.nombre, r.color, {
                        { r.nombre .. (c.p and "  -  1ª ED" or ""), r.color },
                        { "Copias: " .. partida.copias(s.id) },
                        { "Valor " .. ui.dinero(mercado.valor(s.id, c.p)), p.amarillo },
                        { c.f and "Enfundada" or "Sin funda", c.f and p.cian or p.gris },
                        { "Tócala para más opciones", p.grisclaro },
                    })
                end
            end
        end
    end
end

-- botones de la copia elegida, debajo (o encima) de ella
local function botonesCopia()
    local s = mesaSel and entradaMesa(mesaSel)
    if not s or apertura.bloqueada() then
        mesaSel = nil
        return
    end
    local c = partida.copia(s.id, s.u)
    if not c then
        mesaSel = nil
        return
    end
    -- en el movil los botones son mas grandes
    local w = ui.tactil and 90 or 76
    local bh, paso = 12, 14
    if ui.tactil then bh, paso = 17, 20 end
    local n = 2 + (desbloqueos.hay("fundas") and 1 or 0) + (desbloqueos.hay("tops") and 1 or 0)
    local e = escalaDe(s)
    local x = math.max(TAPETE.x + 2, math.min(TAPETE.x + TAPETE.w - w - 2, s.x - w / 2))
    local y = s.y + CH * e / 2 + 4
    if y + n * paso > TAPETE.y + TAPETE.h then y = s.y - CH * e / 2 - n * paso - 4 end
    y = math.max(TAPETE.y + 2, y)
    -- fundas y tops solo cuando ya han salido
    local by = y
    if desbloqueos.hay("fundas") then
        ui.boton("mesa_funda", c.f and "QUITAR FUNDA" or "ENFUNDAR", x, by, w, bh, c.f and p.gris or p.verdeosc)
        by = by + paso
    end
    ui.boton("mesa_vender", "VENDER +" .. ui.dinero(mercado.ventaRapida(s.id, c.p)), x, by, w, bh,
        partida.copias(s.id) == 1 and p.rojo or p.naranja)
    by = by + paso
    if desbloqueos.hay("tops") then
        ui.boton("mesa_top", c.t and "QUITAR TOP" or "PONER TOP", x, by, w, bh, c.t and p.gris or p.azul, c.t or partida.topsLibres > 0)
        by = by + paso
    end
    ui.boton("mesa_guardar", "AL ARMARIO", x, by, w, bh, p.azul)
end

local function dibujarMano()
    if not mano then return end
    if mano.cosa == "sobre" then
        -- colgando del dedo: el giro es alrededor de la parte de arriba
        local W, H = sobre.ANCHO, sobre.ALTO
        local e = mano.escala
        lg.setColor(0, 0, 0, 0.3)
        lg.push()
        lg.translate(mano.x + 6, mano.y + 10)
        lg.rotate(mano.a)
        lg.rectangle("fill", -W / 2 * e, -4 * e, W * e, H * e)
        lg.pop()
        lg.setColor(1, 1, 1)
        lg.draw(sobre.imagen(mano.tipo), mano.x, mano.y, mano.a, e, e, W / 2, 4)
    elseif mano.cosa == "cajabox" then
        caja.dibujar(mano.tipo, mano.x, mano.y, mano.escala, { rot = mano.a, colgada = true, sombra = { 6, 10 } })
    elseif mano.cosa == "funda" or mano.cosa == "top" then
        local esTop = mano.cosa == "top"
        local w, h = CW * 2, CH * 2
        lg.push()
        lg.translate(mano.x, mano.y)
        lg.rotate(mano.a)
        lg.setColor(1, 1, 1, 0.18)
        lg.rectangle("fill", -w / 2, -h / 2, w, h)
        local color = esTop and p.celeste or p.cian
        lg.setColor(color[1], color[2], color[3], 0.8)
        lg.rectangle("line", -w / 2 + 0.5, -h / 2 + 0.5, w - 1, h - 1)
        if esTop then
            lg.rectangle("line", -w / 2 + 1.5, -h / 2 + 1.5, w - 3, h - 3)
            lg.rectangle("fill", -w / 2 + 2, -h / 2 + 2, w - 4, 5)
        end
        lg.setColor(1, 1, 1, 0.35)
        lg.rectangle("fill", -w / 2 + 4, -h / 2 + 4, 3, h - 8)
        lg.pop()
        lg.setColor(1, 1, 1)
        local objetivo = apertura.cartaEn(ui.mx, ui.my)
        local ya = objetivo and objetivo.copia and (esTop and objetivo.copia.t or (not esTop and objetivo.copia.f))
        if objetivo and not ya then
            fuentes.texto(esTop and "SUELTA PARA PONER TOP" or "SUELTA PARA ENFUNDAR", ui.mx - 50, ui.my + CH + 4, 1, color, "center", 100)
        end
    elseif mano.cosa == "copia" then
        local def = partida.carta(mano.id)
        local c = partida.copia(mano.id, mano.u)
        if def and c then
            carta.dibujar(def, mano.x, mano.y, ESCALA_COPIA * 1.1, ESCALA_COPIA * 1.1, mano.a, true, nil, c.f, { primera = c.p, top = c.t })
        end
    end
end

-- la caja abierta en su esquina, con los sobres que le quedan
local function dibujarCajaAbierta()
    local c = partida.cajaAbierta
    if not c or animCaja then return end
    local cogido = mano and mano.cosa == "sobre" and mano.deCaja and 1 or 0
    local quedan = c.quedan - cogido
    caja.dibujar(c.tipo, ESQUINA.x, ESQUINA.y, ESQUINA.e, { abierta = true, quedan = quedan })
    fuentes.texto("X" .. quedan, ESQUINA.x - 20, ESQUINA.y + 22, 1, p.amarillo, "center", 40)
    if quedan > 0 and not apertura.bloqueada() then
        ui.zona("caja_abierta", ESQUINA.x - 30, ESQUINA.y - 22, 60, 42)
        if ui.encima == "caja_abierta" and not mano then
            ui.tooltip("Caja abierta", p.amarillo, { { "Quedan " .. quedan .. " sobres" }, { "Arrastra uno al tapete", p.grisclaro } })
        end
    end
end

local function dibujarVuelos()
    for _, v in ipairs(vuelos) do
        local q = fx.salidaSuave(math.min(1, v.t / 0.3))
        local x, y = fx.lerp(v.x0, v.x1, q), fx.lerp(v.y0, v.y1, q)
        sobre.dibujar(v.tipo, x, y, fx.lerp(v.e0, 1, q), v.a * (1 - q))
    end
end

-- bocadillos de ayuda: cada gesto nuevo se explica una vez, cuando toca
local PISTAS = {
    guardar = "¿MEJOR LUEGO? TOCA GUARDAR O ARRASTRA EL SOBRE A TU CAJA",
    sacar = "TOCA UNA CAJA PARA SACAR SUS SOBRES SIN ABRIRLA",
    cajaAbierta = "ARRASTRA UN SOBRE DE LA CAJA A TU CAJA Y SE GUARDAN TODOS",
}

-- la pista que toca ahora y donde apunta
local function pistaQueToca()
    if partida.tutorial or ui.overlay or ui.modal or mano or animCaja then return nil end
    if apertura.cancelable() and not partida.pistas.guardar then
        local cx = apertura.centro()
        return "guardar", cx, 300
    end
    if apertura.activa() then return nil end
    if partida.cajaAbierta and not partida.pistas.cajaAbierta then
        return "cajaAbierta", ESQUINA.x - 20, ESQUINA.y + 40
    end
    if not partida.pistas.sacar then
        for id, s in pairs(sitioCajas) do
            if partida.cajasDisponibles(id) > 0 then return "sacar", s.x + 20, s.y - 26 end
        end
    end
end

local function dibujarPista()
    local id, x, y = pistaQueToca()
    if not id then
        pistaVista = nil
        return
    end
    if not pistaVista or pistaVista.id ~= id then pistaVista = { id = id, t = 0 } end
    local texto = PISTAS[id]
    local w = math.min(200, fuentes.ancho(texto) + 12)
    local _, lineas = fuentes.envolver(texto, w - 12)
    local h = #lineas * fuentes.linea() + 8
    local bx = math.max(TAPETE.x + 4, math.min(TAPETE.x + TAPETE.w - w - 4, x - w / 2))
    local by = math.min(TAPETE.y + TAPETE.h - h - 4, y)
    local a = math.min(1, pistaVista.t * 4)
    lg.setColor(0, 0, 0, 0.5 * a)
    lg.rectangle("fill", bx + 2, by + 3, w, h, 3, 3)
    lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], a)
    lg.rectangle("fill", bx, by, w, h, 3, 3)
    fuentes.parrafo(texto, bx + 6, by + 4, { 0, 0, 0, a }, w - 12)
end

function mesa.dibujar()
    dibujarTapete()
    dibujarCaja()
    directo.dibujar(DIRECTO.x, DIRECTO.y, DIRECTO.w, DIRECTO.h)
    if apertura.enLote() then
        -- abrir en lote (DEV) ocupa toda la pantalla
        lg.setColor(0, 0, 0, 0.85)
        lg.rectangle("fill", ui.izq, 0, ui.der - ui.izq, 360)
        lg.setColor(1, 1, 1)
        apertura.dibujar()
        return
    end
    dibujarCajaAbierta()
    dibujarCopias()
    apertura.dibujar()
    if animCaja then
        local cx, cy = apertura.centro()
        caja.dibujarAnim(animCaja, cx, cy)
    end
    botonesCopia()
    -- el sobre del tapete aun se puede guardar sin abrir
    if apertura.cancelable() and not mano then
        local cx = apertura.centro()
        ui.boton("mesa_cancelar", "GUARDAR", cx - 30, 280, 60, 12, p.gris)
    end
    dibujarPista()
    -- lo que vuela y lo que llevas en la mano gira, asi que va encima
    encima.anotar(dibujarVuelos)
    if mano then encima.anotar(dibujarMano) end
end

-- logica

function mesa.preparar()
    apertura.zona(TAPETE.x, TAPETE.w)
end

-- lo que se mantiene pulsado para cargar el sobre (solo si el click empezo en el tapete)
function mesa.mantenido()
    if love.keyboard.isDown("space") then return true end
    return love.mouse.isDown(1) and pulsadoEnTapete and not mano
end

function mesa.update(dt)
    apertura.update(dt, mesa.mantenido())
    if chipCaja then
        chipCaja.t = chipCaja.t - dt
        if chipCaja.t <= 0 then chipCaja = nil end
    end
    -- cada bocadillo se ve unos segundos y ya no vuelve
    if pistaVista then
        pistaVista.t = pistaVista.t + dt
        if pistaVista.t > 6 then verPista(pistaVista.id) end
    end

    -- abriendo una caja: al saltar la tapa, fiesta
    if animCaja then
        local cx, cy = apertura.centro()
        if caja.avanzar(animCaja, dt, cx, cy) then
            local col = sobres[animCaja.tipo].colores
            sonido.tocar("rasgar")
            sonido.tocar("secreta")
            fx.sacudir(7)
            fx.destello({ 1, 1, 1 }, 0.7)
            fx.explosion(cx, cy - 30, col.letras, 90, 240)
            fx.explosion(cx, cy - 30, p.blanco, 40, 300)
            fx.confeti(cx, cy - 40, 70, 200)
            fx.tintar(col.rayas)
            directo.caja()
        end
        if animCaja.t >= caja.DURACION then
            animCaja = nil
            sonido.tocar("giro")
            partida.guardar()
        end
    end

    -- el resumen se queda un momento y las cartas pasan a estar sueltas en la mesa
    local listas = apertura.cartasListas()
    if listas then
        for _, c in ipairs(listas) do
            local s = c.copia and partida.aLaMesa(c.def.id, c.copia, true)
            if s then
                zMesa = zMesa + 1
                s.x, s.y, s.r, s.z, s.e = c.x, c.y, 0, zMesa, c.escala
                s.nueva = c.nueva or nil
                s.brillo = c.brillo
            end
        end
        apertura.recoger()
        partida.guardar()
    end
    -- las que llegan con otro tamaño se ajustan, y el brillo de la funda se apaga
    for _, s in ipairs(partida.mesa) do
        if s.ra then
            s.r = fx.lerp(s.r or 0, s.ra, math.min(1, dt * 7))
            if math.abs(s.r - s.ra) < 0.005 then s.r, s.ra = s.ra, nil end
        end
        if s.e then
            s.e = fx.lerp(s.e, ESCALA_COPIA, math.min(1, dt * 8))
            if math.abs(s.e - ESCALA_COPIA) < 0.01 then s.e = nil end
        end
        if s.brillo then
            s.brillo = s.brillo - dt * 2
            if s.brillo <= 0 then s.brillo = nil end
        end
    end

    -- lo que llevas en la mano sigue al dedo y se balancea como un pendulo:
    -- cuelga del punto por donde lo coges y el centro se queda atras al moverlo
    if mano then
        local mx, my = ui.mx, ui.my
        local px, py = mano.px or mano.x, mano.py or mano.y
        local k = math.min(1, dt * 12)
        mano.vx = fx.lerp(mano.vx or 0, (mx - px) / math.max(dt, 1e-3), k)
        mano.vy = fx.lerp(mano.vy or 0, (my - py) / math.max(dt, 1e-3), k)
        mano.px, mano.py = mx, my
        -- brazo: del dedo al centro de lo que llevas, sin girar
        local bx, by
        if mano.cosa == "copia" then
            bx, by = -mano.ax, -mano.ay
        elseif mano.cosa == "sobre" then
            bx, by = 0, (sobre.ALTO / 2 - 4) * mano.escala
        elseif mano.cosa == "cajabox" then
            bx, by = 0, caja.COLGADO * mano.escala
        else
            bx, by = 0, 0
        end
        local a0 = mano.a0 or 0
        local rel = mano.a - a0
        local c, sn = math.cos(rel), math.sin(rel)
        local rx, ry = bx * c - by * sn, bx * sn + by * c
        -- el par que hace arrastrarlo; si lo coges casi por el centro, igual se mece
        local largo = math.sqrt(rx * rx + ry * ry)
        if largo < 8 then
            rx, ry = -sn * 8, c * 8
            largo = 8
        end
        local par = (ry * mano.vx - rx * mano.vy) / largo * 20
        -- lo pesado se mece menos
        local G, tope = 0.015, 0.9
        if mano.cosa == "cajabox" then G, tope = 0.009, 0.5 end
        if mano.cosa == "copia" then G, tope = 0.012, 0.45 end
        local K, C = 120, 7
        mano.w = (mano.w or 0) + (G * par - K * rel - C * mano.w) * dt
        mano.a = a0 + math.max(-tope, math.min(tope, rel + mano.w * dt))
        if mano.cosa == "copia" then
            -- el centro de la carta cuelga del dedo
            rel = mano.a - a0
            c, sn = math.cos(rel), math.sin(rel)
            mano.x, mano.y = mx + bx * c - by * sn, my + bx * sn + by * c
        else
            mano.x, mano.y = mx, my
            local objetivoE = (mano.cosa == "sobre" and ESCALA_COGIDO) or (mano.cosa == "cajabox" and 1.5) or 1
            mano.escala = fx.lerp(mano.escala, objetivoE, math.min(1, dt * 14))
        end
    end

    for i = #vuelos, 1, -1 do
        local v = vuelos[i]
        v.t = v.t + dt
        if v.t > 0.3 then table.remove(vuelos, i) end
    end
end

-- devuelve true si se ha encargado del click
function mesa.presionar(id, x, y)
    pulsadoEnTapete = false
    pulsoSobre = nil
    if id ~= "mesa_sacar" then chipCaja = nil end
    if id == "mesa_cancelar" then return mesa.cancelar() or true end
    if id == "mesa_recoger" then
        mesa.recoger()
        return true
    end
    if id == "mesa_sacar" then
        if chipCaja then sacarDeCajaCerrada(chipCaja.tipo) end
        return true
    end
    if id and directo.click(id) then return true end
    if apertura.enLote() then
        if id then apertura.boton(id) else apertura.pulsar() end
        return true
    end
    if id and id:match("^cajabox_") then
        mano = { cosa = "cajabox", tipo = id:sub(9), x = x, y = y, a = 0, w = 0, vx = 0, escala = 0.8, x0 = x, y0 = y }
        sonido.tocar("encima", 1.0)
        return true
    end
    if id == "caja_abierta" and partida.cajaAbierta then
        mano = { cosa = "sobre", tipo = partida.cajaAbierta.tipo, deCaja = true, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1,
                 hx = ESQUINA.x, hy = ESQUINA.y }
        sonido.tocar("encima", 1.3)
        return true
    end
    if id and id:match("^caja_") then
        local que = id:sub(6)
        if que == "funda" or que == "top" then
            mano = { cosa = que, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1 }
        else
            local hx, hy = huecoDe(que)
            mano = { cosa = "sobre", tipo = que, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1, hx = hx, hy = hy }
        end
        sonido.tocar("encima", 1.3)
        return true
    end
    if id and id:match("^m%d") then
        local s = entradaMesa(tonumber(id:sub(2)))
        if s then
            zMesa = zMesa + 1
            s.z = zMesa
            mano = { cosa = "copia", u = s.u, id = s.id, x = s.x, y = s.y, ax = x - s.x, ay = y - s.y, a = s.r or 0,
                     a0 = s.r or 0, w = 0, px = x, py = y,
                     x0 = x, y0 = y, movida = false }
        end
        return true
    end
    if id and id:match("^mesa_") then
        mesa.click(id)
        return true
    end
    if id and id:match("^res%d") then
        -- las cartas del resumen solo se miran
        return true
    end
    if dentro(TAPETE, x, y) then
        pulsadoEnTapete = true
        mesaSel = nil
        if apertura.sobreEn(x, y) then pulsoSobre = { x = x, y = y } end
        if apertura.activa() and not apertura.enResumen() then apertura.pulsar() end
        return true
    end
    return id ~= nil
end

function mesa.mover(x, y)
    if mano and (mano.cosa == "copia" or mano.cosa == "cajabox") and not mano.movida then
        if math.abs(x - mano.x0) + math.abs(y - mano.y0) > 4 then mano.movida = true end
    end
    -- arrastrar el sobre del tapete (sin rasgar) es cogerlo: se puede guardar
    if pulsoSobre and not mano and love.mouse.isDown(1) and math.abs(x - pulsoSobre.x) + math.abs(y - pulsoSobre.y) > (ui.tactil and 24 or 16) then
        pulsoSobre = nil
        local r = apertura.cancelar()
        if r then
            pulsadoEnTapete = false
            local hx, hy = huecoDe(r.tipo)
            if r.deCaja and partida.cajaAbierta then hx, hy = ESQUINA.x, ESQUINA.y end
            mano = { cosa = "sobre", tipo = r.tipo, deCaja = r.deCaja or nil, x = x, y = y, a = 0, w = 0, vx = 0,
                     escala = 3, hx = hx, hy = hy }
            sonido.tocar("encima", 1.3)
        end
    end
end

local function enfundarCopia(c, x, y)
    if c.f then return false end
    if partida.fundasLibres <= 0 then
        sinFundas(x, y)
        return false
    end
    if partida.enfundarCopia(c) then
        brilloFunda(x, y)
        return true
    end
    return false
end

local function ponerTopCopia(c, x, y)
    if c.t then return false end
    if partida.topsLibres <= 0 then
        sonido.tocar("latido")
        fx.texto(x, y - 10, "SIN TOP LOADERS: CÓMPRALOS EN LA TIENDA", p.rojo)
        return false
    end
    if not c.f and partida.fundasLibres <= 0 then
        sinFundas(x, y)
        return false
    end
    if partida.ponerTop(c) then
        brilloFunda(x, y)
        return true
    end
    return false
end

function mesa.soltar(x, y)
    pulsadoEnTapete = false
    local m = mano
    mano = nil
    if not m then return end
    if m.cosa == "sobre" then
        if dentro(TAPETE, x, y) and soltarSobre(m.tipo, m.x, m.y + sobre.ALTO * m.escala / 2 - 4 * m.escala, m.a, m.escala, m.deCaja) then
            return
        end
        -- el de la caja abierta soltado en la caja de carton: se guardan todos
        if m.deCaja and dentro(CAJA, x, y) and partida.cajaAbierta then
            local n = partida.cerrarCajaAbierta()
            sonido.tocar("giro")
            fx.texto(x, y - 10, "+" .. n .. " SOBRES GUARDADOS", p.lima)
            verPista("cajaAbierta")
            partida.guardar()
            table.insert(vuelos, { tipo = m.tipo, x0 = m.x, y0 = m.y + sobre.ALTO * m.escala / 2, x1 = CAJA.x + CAJA.w / 2,
                                   y1 = CAJA.y + 60, e0 = m.escala, a = m.a, t = 0 })
            return
        end
        if dentro(CAJA, x, y) then verPista("guardar") end
        -- fuera del tapete: vuelve a su sitio en la caja
        table.insert(vuelos, { tipo = m.tipo, x0 = m.x, y0 = m.y + sobre.ALTO * m.escala / 2, x1 = m.hx, y1 = m.hy,
                               e0 = m.escala, a = m.a, t = 0 })
    elseif m.cosa == "cajabox" then
        -- tocada sin arrastrar: sale el chip para sacar sus sobres
        if not m.movida then
            chipCaja = { tipo = m.tipo, t = 3 }
            return
        end
        if dentro(TAPETE, x, y) and not apertura.bloqueada() and not animCaja and partida.abrirCaja(sobres[m.tipo]) then
            apertura.recoger()
            partida.recogerMesa()
            mesaSel = nil
            logros.marcar("caja")
            animCaja = { tipo = m.tipo, t = 0, x0 = m.x, y0 = m.y + caja.COLGADO * m.escala, x1 = ESQUINA.x, y1 = ESQUINA.y, e1 = ESQUINA.e,
                         quedan = sobres.caja.sobres }
            sonido.tocar("giro")
            partida.guardar()
        end
    elseif m.cosa == "funda" or m.cosa == "top" then
        local hacer = m.cosa == "top" and ponerTopCopia or enfundarCopia
        local c = apertura.cartaEn(x, y)
        if c and c.copia then
            if hacer(c.copia, x, y) then c.brillo = 1 end
            return
        end
        -- la copia de la mesa de mas arriba en ese punto
        local s
        for _, e in ipairs(partida.mesa) do
            local w, h = CW * escalaDe(e) / 2, CH * escalaDe(e) / 2
            if e.x and math.abs(x - e.x) <= w and math.abs(y - e.y) <= h and (not s or (e.z or 0) >= (s.z or 0)) then s = e end
        end
        if s then
            local copia = partida.copia(s.id, s.u)
            if copia and hacer(copia, x, y) then s.brillo = 1 end
        end
    elseif m.cosa == "copia" then
        local s = entradaMesa(m.u)
        if not s then return end
        if not m.movida then
            mesaSel = mesaSel ~= s.u and s.u or nil
            return
        end
        if dentro(CAJA, x, y) then
            if partida.guardarDeMesa(s.u) then
                sonido.tocar("giro")
                fx.texto(x, y - 10, "AL ARMARIO", p.lima)
                partida.guardar()
            end
            return
        end
        local w, h = CW * ESCALA_COPIA / 2, CH * ESCALA_COPIA / 2
        s.x = math.max(TAPETE.x + w, math.min(TAPETE.x + TAPETE.w - w, m.x))
        s.y = math.max(TAPETE.y + h, math.min(TAPETE.y + TAPETE.h - h, m.y))
        -- se queda como cayo y se asienta poco a poco
        s.r, s.ra = m.a, (love.math.random() - 0.5) * 0.2
        sonido.tocar("giro")
        partida.guardar()
    end
end

function mesa.click(id)
    local s = mesaSel and entradaMesa(mesaSel)
    if not s then return end
    local c = partida.copia(s.id, s.u)
    if not c then return end
    if id == "mesa_guardar" then
        if partida.guardarDeMesa(s.u) then
            mesaSel = nil
            sonido.tocar("giro")
            partida.guardar()
        end
    elseif id == "mesa_funda" then
        if c.f then
            partida.desenfundarCopia(c)
            partida.guardar()
        elseif enfundarCopia(c, ui.mx, ui.my) then
            s.brillo = 1
        end
    elseif id == "mesa_top" then
        if c.t then
            partida.quitarTop(c)
        elseif partida.ponerTop(c) then
            s.brillo = 1
            brilloFunda(ui.mx, ui.my)
        end
        partida.guardar()
    elseif id == "mesa_vender" then
        local def = partida.carta(s.id)
        local x, y = ui.mx, ui.my
        local function hacer() cobrar(partida.venderCopias(s.id, { s.u }), x, y) end
        if partida.copias(s.id) == 1 then
            ui.confirmar("¿VENDER LA ÚLTIMA?", { "ES TU ÚNICA COPIA DE " .. def.nombre:upper(), "DESAPARECERÁ DEL ÁLBUM" },
                "SÍ, VENDERLA", hacer)
        else
            hacer()
        end
        mesaSel = nil
    end
end

-- espacio: si se esta abriendo, sigue; si no, recoge la mesa y abre otro
function mesa.espacio()
    if apertura.bloqueada() or apertura.enLote() then
        apertura.pulsar()
        return
    end
    if mano or animCaja then return end
    -- primero de la caja abierta
    if partida.cajaAbierta then
        soltarSobre(nil, ESQUINA.x, ESQUINA.y, 0.5, 1, true)
        return
    end
    local tipoId = apertura.ultimoTipo()
    if not tipoId or partida.disponibles(tipoId) == 0 then
        tipoId = nil
        for _, tipo in ipairs(tiposCaja()) do
            if partida.disponibles(tipo.id) > 0 then
                tipoId = tipo.id
                break
            end
        end
    end
    if not tipoId then
        if mesa.recoger() then return end
        fx.texto(TAPETE.x + TAPETE.w / 2, TAPETE.y + 40, "NO TE QUEDAN SOBRES", p.naranja)
        return
    end
    local x, y = huecoDe(tipoId)
    soltarSobre(tipoId, x, y, 0.5, 1)
end

-- al empezar o cargar otra partida
function mesa.reiniciar()
    mano, mesaSel, animCaja = nil, nil, nil
    pulsoSobre, chipCaja, pistaVista = nil, nil, nil
    vuelos = {}
    apertura.recoger()
end

return mesa
