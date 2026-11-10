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
local productos = require "datos.productos"
local prDib = require "src.productos"
local datosFundas = require "datos.fundas"
local fundasDib = require "src.fundas"
local fundario = require "src.fundario"
local inspeccionar = require "src.inspeccionar"
local muebles = require "src.muebles"
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
-- arriba la balda de las cajas cerradas; debajo el tablero en 4 filas: 3
-- ganchos de sobres, la barra de los blisters (a tamano real), las fundas y los
-- tops basicos colgados y las cajitas de las fundas y los tops con diseno
local BALDA = CAJA.y + 60
local TABLERO = CAJA.y + 80
local POR_TABLERO = 3
local FILA = 58
local BLISTERS = { x = CAJA.x + 6, y = TABLERO + 72, w = CAJA.w - 14 }
local FUNDAS = { x = CAJA.x + 8, y = TABLERO + 140, w = CAJA.w - 16, h = 54 }
local CAJITAS = { x = CAJA.x + 6, y = TABLERO + 198, w = CAJA.w - 14, h = 50 }
-- lo de la balda va un poco hacia el fondo para no sobresalir
local FONDO_BALDA = 5
-- largo de la balda (con su lateral en perspectiva cabe en la columna) y lo que
-- ocupa cada pila encima: la caja 34, la ETB 24 y el tin 22
local BALDA_W = CAJA.w - 12
local ANCHO_PILA = { caja = 34, etb = 24, tin = 22 }
local MEDIO_PILA = { caja = 14, etb = 10, tin = 9 }
-- donde se queda la caja abierta: abajo a la derecha del tapete (no tapa las cartas)
local ESQUINA = { x = TAPETE.x + TAPETE.w - 36, y = TAPETE.y + 28, e = 1 }
-- los sobres de una ETB o un tin abiertos, en abanico (en el mismo rincon)
local ABANICO = { x = TAPETE.x + TAPETE.w - 70, y = TAPETE.y + 22 }
-- fundas y tops sueltos que trae un producto
local SUELTOS = { x = TAPETE.x + TAPETE.w - 30, y = TAPETE.y + 116 }
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

-- selector de set de la columna: "todo" (un gancho por set), el id de un
-- sobre (sus sobres de 1ª, de reimpresion y sus blisters) o "mix"
local filtro = "todo"

local function tieneAlgo(tipo)
    if partida.disponibles(tipo.id) > 0 then return true end
    for _, prod in ipairs(productos.lista) do
        if not prod.mix and partida.prodDisponibles(prod.id, tipo.id) > 0 then return true end
    end
    return false
end

-- lo que se puede elegir en el selector
local function opcionesFiltro()
    local lista = { "todo" }
    for _, tipo in ipairs(sobres.lista) do
        if mercado.salido(tipo.set) or tieneAlgo(tipo) then table.insert(lista, tipo.id) end
    end
    return lista
end

local function nombreFiltro(f)
    if f == "todo" then return "TODO" end
    if f == "mix" then return "MIX" end
    return sets[sobres[f].set].nombre:upper()
end

-- lo que cuelga en el tablero: { clase = "sobre" | "blister", tipo, primera, id }
local function entradasTodas()
    local lista = {}
    if filtro == "todo" then
        for _, tipo in ipairs(sobres.lista) do
            if partida.disponibles(tipo.id) > 0 then table.insert(lista, { clase = "sobre", tipo = tipo, id = "caja_" .. tipo.id }) end
        end
    elseif sobres[filtro] then
        local tipo = sobres[filtro]
        table.insert(lista, { clase = "sobre", tipo = tipo, primera = true, id = "caja_" .. tipo.id .. "_1" })
        table.insert(lista, { clase = "sobre", tipo = tipo, primera = false, id = "caja_" .. tipo.id .. "_n" })
    end
    -- sobrecitos promo (de la ETB y la caja) y sobres de torneo
    for _, tipo in ipairs(sobres.lista) do
        if filtro == "todo" or filtro == tipo.id then
            for _, o in ipairs({ "correo", "etb", "caja", "torneo" }) do
                if partida.promoSobresDe(o, tipo.id) > 0 then
                    table.insert(lista, { clase = "promo", origen = o, tipo = tipo, id = "pcaja_" .. o .. "_" .. tipo.id })
                end
            end
        end
    end
    return lista
end

-- blisters que cuelgan de la barra de abajo (los del set elegido o todos)
local function blistersMesa()
    local lista = {}
    for _, tipo in ipairs(sobres.lista) do
        if (filtro == "todo" or filtro == tipo.id) and partida.prodDisponibles("blister", tipo.id) > 0 then
            table.insert(lista, tipo)
        end
    end
    return lista
end

local function cuantosEntrada(e)
    if e.clase == "promo" then return partida.promoSobresDe(e.origen, e.tipo.id) end
    if e.primera == nil then return partida.disponibles(e.tipo.id) end
    return partida.sinApartar("s", e.tipo.id, e.primera)
end

-- pagina del tablero (solo con mas de 3 ganchos)
local paginaTablero = 1
local function paginasTablero()
    return math.max(1, math.ceil(#entradasTodas() / POR_TABLERO))
end

-- lo que se ve en el tablero: caben 3; en TODO, primero lo que tienes y luego
-- huecos vacios de sets ya salidos
local function entradas()
    local todos = entradasTodas()
    paginaTablero = math.max(1, math.min(paginaTablero, paginasTablero()))
    local lista = {}
    for i = (paginaTablero - 1) * POR_TABLERO + 1, math.min(#todos, paginaTablero * POR_TABLERO) do
        table.insert(lista, todos[i])
    end
    if filtro == "todo" and #todos <= POR_TABLERO then
        for _, tipo in ipairs(sobres.lista) do
            if mercado.salido(tipo.set) and partida.disponibles(tipo.id) == 0 and #lista < POR_TABLERO then
                table.insert(lista, { clase = "sobre", tipo = tipo, id = "caja_" .. tipo.id })
            end
        end
    end
    return lista
end

-- gancho del hueco k del tablero
local function ganchoHueco(k)
    local col, fila = (k - 1) % 3, math.floor((k - 1) / 3)
    return CAJA.x + 22 + col * 32, TABLERO + 6 + fila * FILA
end

-- centro del sobre colgado en el hueco k
local function hueco(k)
    local bx, by = ganchoHueco(k)
    local hx, hy = muebles.agujero(bx, by, 12)
    return hx, hy + 19
end

local function huecoDe(tipoId, primera, idEntrada)
    local libre
    for k, e in ipairs(entradas()) do
        if idEntrada and e.id == idEntrada then return hueco(k) end
        if e.clase == "sobre" and e.tipo.id == tipoId then
            if e.primera == nil or e.primera == primera then return hueco(k) end
            libre = libre or k
        end
    end
    if libre then return hueco(libre) end
    return CAJA.x + CAJA.w / 2, CAJA.y + 60
end

-- lo sellado grande de la balda: { prod, tipo } con algo que abrir
local function pilasBalda()
    local lista = {}
    for _, tipo in ipairs(sobres.lista) do
        if filtro == "todo" or filtro == tipo.id then
            for _, prod in ipairs(productos.lista) do
                if prod.sitio ~= "gancho" and not prod.mix and partida.prodDisponibles(prod.id, tipo.id) > 0 then
                    table.insert(lista, { prod = prod, tipo = tipo })
                end
            end
        end
    end
    return lista
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

-- sobres que puedes abrir: los guardados, los de los blisters y los de la caja abierta
local function quedanSobres()
    local n = partida.cajaAbierta and partida.cajaAbierta.quedan or 0
    for _, t in ipairs(sobres.lista) do
        n = n + partida.disponibles(t.id) + partida.prodDisponibles("blister", t.id) * productos.blister.sobres
    end
    return n
end

-- lo que se queda en la mesa al abrir un producto: sus sobres en abanico y lo que trae
local function hayAbanico()
    return partida.cajaAbierta and partida.cajaAbierta.prod ~= nil
end

-- donde vuelven los sobres de lo abierto: la caja o el abanico
-- donde espera el sobrecito i de la mesa (debajo del abanico de la esquina)
local function sitioPromo(i)
    -- con la ETB abierta, a la izquierda del abanico (debajo estan las fundas sueltas)
    if hayAbanico() then return ABANICO.x - 88 - (i - 1) * 14, TAPETE.y + 22 end
    return TAPETE.x + TAPETE.w - 24 - (i - 1) * 14, TAPETE.y + 70
end

local function rincon()
    if hayAbanico() then return ABANICO.x, ABANICO.y + 20 end
    return ESQUINA.x, ESQUINA.y
end

-- donde acaba cada sobre del abanico al abrir una ETB o un tin
local function destinosAbanico(n)
    local l = {}
    local x0 = ABANICO.x - (n - 1) * 5
    for i = 0, n - 1 do
        local d = i - (n - 1) / 2
        l[i + 1] = { x0 + i * 10, ABANICO.y + math.abs(d) * 1.5, d * 0.06 }
    end
    return l
end

local function haySueltos()
    return partida.sueltos.fundas > 0 or partida.sueltos.tops > 0
end

-- empezar a abrir un sobre de este tipo, llegando desde (x, y)
-- deCaja: el sobre sale de la caja abierta, no de los guardados
local function soltarSobre(tipoId, x, y, a, escala, deCaja, ed)
    if apertura.bloqueada() or animCaja then return false end
    local tipo, primera
    if deCaja then
        tipo, primera = partida.sacarDeCaja()
    else
        tipo, primera = partida.sacarSobre(tipoId, true, ed)
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

-- abre un sobrecito promo (o de torneo) soltado en el tapete
local function soltarPromo(m)
    if apertura.bloqueada() or animCaja then return false end
    local defs
    if m.deMesa then defs = partida.abrirPromoMesa(m.deMesa) else defs = partida.sacarPromoSobre(m.promo, m.tipoReal) end
    if not defs then return false end
    apertura.recoger()
    partida.recogerMesa()
    mesaSel = nil
    partida.guardar()
    sonido.tocar("giro")
    fx.sacudir(2)
    local tipo = sobres[m.tipoReal]
    local falso = { id = m.tipo, set = tipo.set, promo = m.promo, colores = tipo.colores, nombre = tipo.nombre }
    apertura.empezar(falso, false, { x = m.x, y = m.y + sobre.ALTO * m.escala / 2 - 4 * m.escala, a = m.a, escala = m.escala }, defs)
    reporte.apuntar("sobre promo " .. m.tipo)
    return true
end

-- vuelve volando a su sitio en la caja de carton (o a la caja abierta)
local function volarACaja(tipoId, x0, y0, e0, a, deCaja, primera)
    local x1, y1
    if deCaja and partida.cajaAbierta then
        x1, y1 = rincon()
    else
        x1, y1 = huecoDe(tipoId, primera)
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
    volarACaja(r.tipo, cx, cy, 3, 0, r.deCaja, r.primera)
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
    if apertura.activa() or animCaja then return false end
    if #partida.mesa == 0 and not hayAbanico() and not haySueltos() and #partida.promoMesa == 0 then return false end
    -- los sobres del abanico vuelven con los guardados y lo suelto a su caja
    if hayAbanico() then partida.cerrarCajaAbierta() end
    partida.guardarPromoMesa()
    partida.guardarSueltos("fundas")
    partida.guardarSueltos("tops")
    partida.recogerMesa()
    mesaSel = nil
    sonido.tocar("giro")
    fx.texto(TAPETE.x + TAPETE.w / 2, TAPETE.y + TAPETE.h / 2, "AL ARMARIO", p.lima)
    partida.guardar()
    return true
end

-- saca los sobres de una caja cerrada sin abrirla
local function sacarDeCajaCerrada(pid, tipoId)
    local n = partida.vaciarProd(pid, sobres[tipoId])
    chipCaja = nil
    if not n then return end
    local s = sitioCajas[pid .. "_" .. tipoId]
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
    -- colgadas del tablero, como en la tienda
    local bx, by = x + w / 2 + 6, y + 2
    local hx, hy = muebles.agujero(bx, by, 12)
    muebles.gancho(bx, by, 12)
    if libres > 0 then
        local n = math.min(2, math.ceil(libres / 20))
        if esTop then muebles.bolsaTops(hx, hy, n, 0, "") else muebles.blister(hx, hy, n, 0, "") end
    end
    muebles.punta(bx, by, 12)
    muebles.etiqueta(x + w / 2, y + 50, "X" .. math.max(0, libres), libres > 0 and color or p.rojo)
    local puede = libres > 0 and not apertura.bloqueada()
    local pista
    if puede then pista = estrecho and "ARRASTRA" or "ARRÁSTRALA A UNA CARTA"
    elseif libres > 0 then pista = estrecho and "TRAS ABRIR" or "AL ACABAR EL SOBRE"
    else pista = estrecho and "EN TIENDA" or "CÓMPRALAS EN LA TIENDA" end
    if ui.encima == "caja_" .. que then ui.tooltip(esTop and "Top loaders" or "Fundas", color, { { pista } }) end
    if puede then ui.zona("caja_" .. que, x, y, w, h) end
end

-- cajitas de fundas y tops con diseno: el diseno de arriba (si se acaba, pasa
-- al siguiente que tengas)
local function disenoCajita(esTop)
    local k = esTop and "t" or "f"
    local de = esTop and partida.topsDe or partida.fundasDe
    local cur = partida.cajitas[k]
    if cur and de(cur) > 0 then return cur end
    local orden = esTop and datosFundas.tops or datosFundas.lista
    local pos = 0
    for i, d in ipairs(orden) do if d.id == cur then pos = i end end
    local nuevo
    for i = 1, #orden do
        local d = orden[(pos + i - 1) % #orden + 1]
        if de(d.id) > 0 then nuevo = d.id break end
    end
    partida.cajitas[k] = nuevo
    return nuevo
end

local function zonaCajita(esTop)
    local cw = math.floor(CAJITAS.w / 2) - 1
    local x = esTop and CAJITAS.x + cw + 2 or CAJITAS.x
    return x, CAJITAS.y, cw, CAJITAS.h
end

local function cajita(esTop)
    local x, y, w, h = zonaCajita(esTop)
    local k = esTop and "t" or "f"
    local cur = disenoCajita(esTop)
    local d = cur and (esTop and datosFundas.top[cur] or datosFundas[cur])
    local n = cur and (esTop and partida.topsDe(cur) or partida.fundasDe(cur)) or 0
    local cogida = mano and mano.cosa == (esTop and "top" or "funda") and mano.id ~= nil
    local quedan = n - (cogida and mano.id == cur and 1 or 0)
    local cuantos = #partida.disenosLibres(esTop)
    -- llevas una carta de la mesa: soltarla aqui la enfunda con este diseno
    local soltando = mano and mano.cosa == "copia" and d and ui.mx >= x and ui.mx < x + w and ui.my >= y and ui.my < y + h
    if soltando then muebles.rect(p.lima, x, y, w, h, 0.25) end
    -- nombre (se toca para verlas todas)
    muebles.rect(p.negro, x, y, w, 9, 0.6)
    fuentes.texto(d and d.corto or (esTop and "TOPS" or "FUNDAS"), x, y + 2, 1, d and d.color or p.gris, "center", w)
    if cuantos > 0 then
        ui.zona("mesa_cajitanom_" .. k, x, y, w, 9)
        if ui.encima == "mesa_cajitanom_" .. k and not mano then
            ui.tooltip(esTop and "Tops con diseño" or "Fundas con diseño", p.amarillo,
                { { cuantos .. (cuantos == 1 and " DISEÑO" or " DISEÑOS") }, { "Toca para verlos todos", p.grisclaro } })
        end
    end
    -- carton bajo con el diseno de arriba asomando
    local cx, by = x + w / 2, y + 33
    if d and quedan > 0 then
        if esTop then fundario.miniatura(cur, true, cx, by - 6, 0.5)
        else
            fundasDib.dibujarDorso(cur, cx + 2, by - 6, 0.55)
            fundasDib.dibujarDorso(cur, cx, by - 8, 0.55)
        end
    end
    local bw = w - 16
    muebles.bloque(cx - bw / 2, by, bw, 13, 6, muebles.tonos({ 0.62, 0.44, 0.26 }, 1, 1.25, 0.7))
    fuentes.texto(d and ("X" .. math.max(0, quedan)) or "VACÍA", cx - bw / 2, by + 4, 1, d and p.blanco or p.grisclaro, "center", bw)
    local libre = not apertura.bloqueada() and not animCaja
    if cuantos > 1 then
        ui.boton("mesa_cajita_" .. k .. "_-1", "<", x, by - 6, 7, 14, p.azul, libre)
        ui.boton("mesa_cajita_" .. k .. "_1", ">", x + w - 7, by - 6, 7, 14, p.azul, libre)
    end
    if d and quedan > 0 and libre then
        local zid = "cajita_" .. k
        ui.zona(zid, cx - bw / 2, y + 10, bw, h - 10)
        if ui.encima == zid and not mano then
            ui.tooltip(d.nombre, d.color, { { quedan .. " LIBRES" }, { "Arrástrala a una carta", p.grisclaro },
                { "O suelta aquí una carta de la mesa", p.grisclaro } })
        end
    end
end

local function dibujarCaja()
    -- tablero con ganchos al fondo de la mesa, como el de la tienda
    muebles.bloque(CAJA.x + 2, TABLERO, CAJA.w - 8, CAJA.y + CAJA.h - TABLERO - 2, 8, muebles.tonos(muebles.MADERA, 1.15, 1.5, 0.7))
    muebles.perforado(CAJA.x + 6, TABLERO + 4, CAJA.w - 14, CAJA.y + CAJA.h - TABLERO - 10, 7)
    -- y encima la balda de las cajas cerradas
    muebles.balda(CAJA.x + 1, BALDA, BALDA_W, 14, true)

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
    -- selector de set
    local ops = opcionesFiltro()
    local pos = 1
    for i, f in ipairs(ops) do if f == filtro then pos = i end end
    if pos == 1 then filtro = "todo" end
    if #ops > 1 then
        local sy = CAJA.y + 2
        ui.boton("mesa_filtro_-1", "<", CAJA.x + 2, sy, 14, 11, p.azul, pos > 1)
        ui.boton("mesa_filtro_1", ">", CAJA.x + CAJA.w - 20, sy, 14, 11, p.azul, pos < #ops)
        local cad = nombreFiltro(filtro)
        local col = filtro ~= "todo" and sobres[filtro] and sobres[filtro].colores.letras or p.blanco
        muebles.rect(p.negro, CAJA.x + 18, sy, CAJA.w - 40, 11, 0.6)
        fuentes.texto(cad, CAJA.x + 18, sy + 3, 1, col, "center", CAJA.w - 40)
    end

    for k, e in ipairs(entradas()) do
        local tipo = e.tipo
        local x, y = hueco(k)
        local n = cuantosEntrada(e)
        local p1 = 0
        if e.clase == "sobre" and e.primera ~= false then p1 = partida.sinApartar("s", tipo.id, true) end
        local cogido = mano and mano.cosa == "sobre" and not mano.deCaja and mano.id == e.id and 1 or 0
        local quedan = n - cogido
        -- colgados de su gancho
        local bx, by = ganchoHueco(k)
        local hx, hy = muebles.agujero(bx, by, 12)
        muebles.gancho(bx, by, 12)
        local imagen = e.clase == "promo" and sobre.clavePromo(e.origen, tipo.id) or tipo.id
        if quedan > 0 then muebles.colgados(imagen, hx, hy, math.min(3, quedan), 0) end
        muebles.punta(bx, by, 12)
        -- pegatina dorada en el de delante si te queda alguno de 1ª edicion
        if quedan > 0 and p1 > 0 then
            local sw, sh = math.max(10, fuentes.ancho("1ª") + 4), fuentes.alto(1) + 2
            lg.setColor(p.negro)
            lg.rectangle("fill", hx + 15 - sw, hy + 1, sw + 2, sh + 2)
            lg.setColor(p.amarillo)
            lg.rectangle("fill", hx + 16 - sw, hy + 2, sw, sh)
            fuentes.texto("1ª", hx + 16 - sw, hy + 3, 1, p.negro, "center", sw)
        end
        if quedan > 0 then
            local enc = ui.encima == e.id and not bloqueada
            if enc then
                lg.setColor(1, 1, 1, 0.25)
                lg.rectangle("line", x - 15.5, y - 22.5, 31, 45)
                local lineas = { { quedan .. (quedan == 1 and " SOBRE" or " SOBRES") } }
                if p1 > 0 then table.insert(lineas, { math.min(p1, quedan) .. " DE 1ª EDICIÓN", p.amarillo }) end
                if e.clase == "promo" then
                    local que = { torneo = "Trae 1 de sus 3 promos de torneo", correo = "Dentro va tu placa del canal" }
                    table.insert(lineas, { que[e.origen] or "Trae 1 de sus 4 promos", p.naranja })
                end
                table.insert(lineas, { "Arrástralo al tapete", p.grisclaro })
                local titulo = sets[tipo.set].nombre:upper()
                if e.clase == "promo" then
                    local nombres = { torneo = "SOBRE DE TORNEO ", etb = "SOBRECITO PROMO (ETB) ", caja = "SOBRECITO PROMO (CAJA) " }
                    titulo = e.origen == "correo" and "CORREO DE ONE LAST PACK" or (nombres[e.origen] .. sets[tipo.set].codigo)
                end
                ui.tooltip(titulo, e.clase == "promo" and p.naranja or p.blanco, lineas)
            end
            if not bloqueada then ui.zona(e.id, x - 16, y - 24, 32, 50) end
        end
        -- etiqueta: set y cuantos (en un set: la edicion o BLÍSTER)
        local txt
        if e.clase == "promo" then
            txt = ({ torneo = "TOR X", correo = "OLP X" })[e.origen] or "PR X"
            txt = txt .. quedan
        elseif filtro == "todo" then
            txt = sets[tipo.set].codigo .. " X" .. quedan
        else
            txt = (e.primera and "1ª X" or "X") .. quedan
        end
        if fuentes.ancho(txt) > 28 then txt = "X" .. quedan end
        local fondo = quedan > 0 and (e.clase == "promo" and p.naranja or (e.primera and p.amarillo or p.blanco)) or p.grisosc
        muebles.etiqueta(x, y + 24, txt, fondo, quedan > 0 and p.negro or p.gris)
    end
    if filtro ~= "todo" and not sobres[filtro] then
        fuentes.texto("NADA DE MIX", CAJA.x, TABLERO + 40, 1, p.grisclaro, "center", CAJA.w - 6)
    end
    -- con mas de 6 ganchos, flechas para ver los demas
    local paginas = paginasTablero()
    if paginas > 1 then
        ui.boton("mesa_tablero_-1", "<", CAJA.x + 4, TABLERO + 1, 10, 8, p.azul, paginaTablero > 1)
        ui.boton("mesa_tablero_1", ">", CAJA.x + CAJA.w - 20, TABLERO + 1, 10, 8, p.azul, paginaTablero < paginas)
    end

    -- blisters: colgados de la barra de abajo a tamaño real; si hay de varios
    -- sets se solapan y el de la izquierda queda delante
    sitioCajas = {}
    local bls = blistersMesa()
    local BW = prDib.BLISTER.W
    local B = BLISTERS
    if #bls > 0 then
        local paso = #bls > 1 and math.min(BW + 2, (B.w - BW) / (#bls - 1)) or 0
        local x0 = #bls == 1 and B.x + (B.w - BW) / 2 or B.x
        muebles.rect(p.negro, B.x, B.y - 1, B.w, 3, 0.5)
        muebles.rect(p.grisclaro, B.x, B.y - 1, B.w, 1, 0.6)
        for i = #bls, 1, -1 do
            local tipo = bls[i]
            local cogido = mano and mano.cosa == "cajabox" and mano.prod == "blister" and mano.tipo == tipo.id
            local n = partida.prodDisponibles("blister", tipo.id) - (cogido and 1 or 0)
            local cx = math.floor(x0 + (i - 1) * paso + BW / 2)
            local hx, hy = muebles.agujero(cx, B.y, 6)
            muebles.gancho(cx, B.y, 6)
            if n > 0 then prDib.blister(tipo.id, tipo.colores, hx, hy, math.min(3, n), 0) end
            sitioCajas["blister_" .. tipo.id] = { x = cx, y = hy + 10, chipY = hy + prDib.BLISTER.H - 16, pid = "blister", tipo = tipo.id }
            muebles.punta(cx, B.y, 6)
            local izq = i == 1 and cx - BW / 2 or math.floor(x0 + (i - 2) * paso + BW)
            local der = cx + BW / 2
            local zid = "blis_" .. tipo.id
            if not bloqueada and not animCaja and n > 0 and der > izq then ui.zona(zid, izq, hy - 4, der - izq, prDib.BLISTER.H + 4) end
            if ui.encima == zid and not mano then
                lg.setColor(1, 1, 1, 0.25)
                lg.rectangle("line", izq + 0.5, hy - 3.5, der - izq - 1, prDib.BLISTER.H + 3)
                ui.tooltip("BLÍSTER " .. sets[tipo.set].nombre:upper(), p.blanco,
                    { { n .. (n == 1 and " BLÍSTER" or " BLÍSTERS") }, { "Arrástralo al tapete para abrirlo", p.grisclaro },
                      { "Tócalo para sacar sus sobres", p.grisclaro } })
            end
            local txt = (filtro == "todo" and #bls > 1) and (sets[tipo.set].codigo .. " X" .. n) or ("BL X" .. n)
            -- en el pie del blister, en lugar de "2 SOBRES"
            if i == 1 then muebles.rect(p.negro, cx - BW / 2, hy + prDib.BLISTER.H - 9, BW, 6) end
            if der - izq >= fuentes.ancho(txt) + 2 then
                if i > 1 then muebles.rect(p.negro, izq, hy + prDib.BLISTER.H - 9, der - izq, 6) end
                fuentes.texto(txt, izq, hy + prDib.BLISTER.H - 8, 1, tipo.colores.letras, "center", der - izq)
            end
        end
    end

    -- lo sellado grande (cajas, ETB y tins): se arrastra al tapete para abrirlo.
    -- Caben las pilas que quepan encima de la balda
    local izq = CAJA.x + 2 + muebles.dz(FONDO_BALDA)
    for _, pila in ipairs(pilasBalda()) do
        local pid, tipo = pila.prod.id, pila.tipo
        local ancho = ANCHO_PILA[pid] or 24
        -- caben las que caben, cada una con su ancho de verdad
        if izq + ancho > CAJA.x + 1 + BALDA_W + 1 then break end
        local n = partida.prodDisponibles(pid, tipo.id)
        local cx, cy = izq + (MEDIO_PILA[pid] or 10), BALDA - 9 - FONDO_BALDA
        izq = izq + ancho + 1
        local cogida = mano and mano.cosa == "cajabox" and mano.tipo == tipo.id and mano.prod == pid
        local quedan = n - (cogida and 1 or 0)
        local pila_ = math.min(pid == "caja" and 4 or 3, quedan)
        local alto = pid == "caja" and 9 or (pid == "etb" and 17 or 10)
        for k = 0, pila_ - 1 do
            if pid == "caja" then caja.dibujar(tipo.id, cx + (k % 2), cy - k * 9, 1, { mini = true })
            else prDib.mini(pid, tipo.id, cx + (k % 2), BALDA - FONDO_BALDA - k * alto) end
        end
        fuentes.texto("X" .. quedan, izq - ancho - 1, BALDA + 7, 1, p.blanco, "center", ancho)
        local top = pid == "caja" and cy - math.max(0, pila_ - 1) * 9 or BALDA - FONDO_BALDA - pila_ * alto + 6
        sitioCajas[pid .. "_" .. tipo.id] = { x = cx, y = top, pid = pid, tipo = tipo.id }
        local zid = pid == "caja" and ("cajabox_" .. tipo.id) or ("prodbox_" .. pid .. "_" .. tipo.id)
        if not bloqueada and not animCaja and quedan > 0 then ui.zona(zid, izq - ancho - 1, top - 10, ancho, BALDA - top + 12) end
        if ui.encima == zid and not mano then
            ui.tooltip(pila.prod.nombre .. " " .. sets[tipo.set].nombre:upper(), p.amarillo,
                { { quedan .. " SIN ABRIR" }, { "Arrástrala al tapete para abrirla", p.grisclaro }, { "Tócala para sacar sus sobres", p.grisclaro } })
        end
    end
    -- chip para sacar los sobres de lo tocado (se va solo)
    if chipCaja and not mano then
        local s = sitioCajas[chipCaja.prod .. "_" .. chipCaja.tipo]
        if s and partida.prodDisponibles(chipCaja.prod, chipCaja.tipo) > 0 and not bloqueada then
            local w = math.min(CAJA.w - 4, math.max(62, fuentes.ancho("SACAR SOBRES") + 10))
            local x = math.max(CAJA.x + 2, math.min(CAJA.x + CAJA.w - w - 2, s.x - w / 2))
            ui.boton("mesa_sacar", "SACAR SOBRES", x, s.chipY or (BALDA + 14), w, 12, p.azul)
        else
            chipCaja = nil
        end
    end

    -- fundas (y top loaders al lado cuando salen): solo tras desbloquearlas
    if desbloqueos.hay("fundas") then
        -- las fundas siempre a la izquierda, encima de su cajita (los tops, a la derecha)
        local F = FUNDAS
        local fw = math.floor(F.w / 2) - 1
        monton("funda", F.x, F.y, fw, F.h, true)
        if desbloqueos.hay("tops") then monton("top", F.x + fw + 2, F.y, F.w - fw - 2, F.h, true) end
        cajita(false)
        if desbloqueos.hay("tops") then cajita(true) end
    end

    -- copias en la mesa
    -- copias en la mesa: solo al llevar una (arriba: abajo van las cajitas,
    -- donde soltarla la enfunda con su diseno)
    if mano and mano.cosa == "copia" then
        local y = TABLERO + 30
        muebles.rect(p.negro, CAJA.x + 4, y - 3, CAJA.w - 8, 27, 0.8)
        fuentes.texto("DEL ARMARIO " .. partida.propiasEnMesa() .. "/" .. partida.MAX_MESA, CAJA.x, y, 1, p.grisclaro, "center", CAJA.w)
        fuentes.texto("SUÉLTALA AQUÍ PARA", CAJA.x, y + 8, 1, p.lima, "center", CAJA.w)
        fuentes.texto("GUARDARLA", CAJA.x, y + 15, 1, p.lima, "center", CAJA.w)
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
        local cod, pct = sets[setId].codigo, partida.porcentaje(setId)
        local cad = cod .. " " .. tiene .. "/" .. total .. "  " .. pct .. "%"
        local color = tiene >= total and p.amarillo or { 1, 1, 1, 0.55 }
        -- completo: pasa del 100% con las de fuera de set
        if partida.master(setId) then
            cad, color = cod .. " MASTER SET", muebles.ORO.claro
        elseif tiene >= total then
            cad = cod .. (pct > 100 and (" " .. pct .. "%") or " COMPLETO")
        end
        fuentes.texto(cad, T.x + 10, T.y + 10, 1, color)
    end

    -- velocidad de apertura (con la mejora MANOS RAPIDAS); se cambia en cualquier momento
    if partida.nivelMejora("velocidad") > 0 then
        local v = partida.velocidad()
        local cad = "X" .. (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ","))
        ui.boton("mesa_velocidad", ">> " .. cad, T.x + 6, T.y + 20, 38, 12, v > 1 and p.naranja or p.grisosc)
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
    -- con un abanico o algo suelto, RECOGER MESA lo guarda todo
    if not animCaja and not apertura.activa() and (hayAbanico() or haySueltos()) and not (#partida.mesa > 0 and quedanSobres() == 0) then
        ui.boton("mesa_recoger", "RECOGER MESA", T.x + T.w - 92, T.y + T.h - 22, 84, 16, p.azul)
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
        -- la promo del blister o del tin que aun va volando (dibujarPromoVolando)
        local cogida = (mano and mano.cosa == "copia" and mano.u == s.u) or (animCaja and animCaja.promo == s.u)
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
                    local r = rarezas.de(def)
                    ui.tooltip(rarezas.nombre(def), r.color, {
                        { r.nombre .. (c.p and "  -  1ª ED" or ""), r.color },
                        { "Copias: " .. partida.copias(s.id) },
                        { mercado.textoValor(s.id, c.p), p.amarillo },
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
    elseif mano.cosa == "cajabox" and mano.prod ~= "caja" then
        prDib.uno(mano.prod, mano.tipo, mano.x, mano.y + 14 * mano.escala, mano.escala, mano.a)
    elseif mano.cosa == "cajabox" then
        caja.dibujar(mano.tipo, mano.x, mano.y, mano.escala, { rot = mano.a, colgada = true, sombra = { 6, 10 } })
    elseif mano.cosa == "suelto" then
        local n = partida.sueltos[mano.que]
        if mano.que == "fundas" then muebles.blister(mano.x, mano.y - 4, 1, mano.a, "X" .. n) else muebles.bolsaTops(mano.x, mano.y - 4, 1, mano.a, "X" .. n) end
    elseif mano.cosa == "funda" or mano.cosa == "top" then
        local esTop = mano.cosa == "top"
        local w, h = CW * 2, CH * 2
        lg.push()
        lg.translate(mano.x, mano.y)
        lg.rotate(mano.a)
        lg.setColor(1, 1, 1, 0.18)
        lg.rectangle("fill", -w / 2, -h / 2, w, h)
        local color = esTop and p.celeste or p.cian
        if mano.id then color = fundasDib.color(mano.id, esTop) end
        if mano.id and not esTop then
            lg.setColor(1, 1, 1, 0.85)
            lg.draw(fundasDib.dorso(mano.id), 0, 0, 0, 2, 2, fundasDib.W / 2, fundasDib.H / 2)
        end
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
        local ya = objetivo and objetivo.copia and not mano.id and (esTop and objetivo.copia.t or (not esTop and objetivo.copia.f))
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
-- los sobres de una ETB o un tin abiertos, en abanico en la esquina
local function dibujarAbanico(c, quedan)
    local n = math.min(9, quedan)
    local x0 = ABANICO.x - (n - 1) * 5
    lg.setColor(1, 1, 1)
    for i = 0, n - 1 do
        local d = i - (n - 1) / 2
        lg.draw(sobre.imagen(c.tipo), x0 + i * 10, ABANICO.y + math.abs(d) * 1.5, d * 0.06, 0.8, 0.8, 15, 0)
    end
    fuentes.texto("X" .. quedan, ABANICO.x - 20, ABANICO.y + 40, 1, p.amarillo, "center", 40)
    if quedan > 0 and not apertura.bloqueada() then
        ui.zona("caja_abierta", ABANICO.x - 52, ABANICO.y - 4, 104, 42)
        if ui.encima == "caja_abierta" and not mano then
            ui.tooltip((productos[c.prod] and productos[c.prod].nombre or "") .. " abierta", p.amarillo,
                { { "Quedan " .. quedan .. " sobres" }, { "Arrastra uno al tapete", p.grisclaro }, { "RECOGER MESA los guarda", p.grisclaro } })
        end
    end
end

-- sobrecitos de la ETB o la caja que esperan en la mesa (debajo del abanico)
local function dibujarPromoMesa()
    if animCaja then return end
    for i, pm in ipairs(partida.promoMesa) do
        if not (mano and mano.deMesa == i) then
            local x, y = sitioPromo(i)
            local clave = sobre.clavePromo(pm.o, pm.t)
            lg.setColor(0, 0, 0, 0.3)
            lg.draw(sobre.imagen(clave), x + 3, y + 3, 0.08, 1, 1, 15, 0)
            lg.setColor(1, 1, 1)
            lg.draw(sobre.imagen(clave), x, y, 0.08, 1, 1, 15, 0)
            if not apertura.bloqueada() then
                local zid = "pmesa_" .. i
                ui.zona(zid, x - 15, y, 30, 44)
                if ui.encima == zid and not mano then
                    ui.tooltip("SOBRECITO PROMO (" .. (pm.o == "etb" and "ETB" or "CAJA") .. ")", p.naranja, {
                        { "Trae 1 de sus 4 promos" },
                        { "Arrástralo al tapete para abrirlo", p.grisclaro },
                        { "o a tu caja para guardarlo (sellado)", p.grisclaro },
                    })
                end
            end
        end
    end
end

-- la promo del blister o del tin sale a la vez que los sobres y vuela a su sitio
local function promoVolando()
    local a = animCaja
    if not (a and a.promo) then return end
    local s = entradaMesa(a.promo)
    if not s then return end
    local q = (a.t - prDib.SALTO - 0.15) / 0.55
    if q <= 0 then return end
    q = math.min(1, q)
    if q >= 1 and not a.promoLlego then
        a.promoLlego = true
        sonido.tocar("nueva")
        fx.explosion(s.x, s.y, p.amarillo, 14, 80)
    end
    return s, q
end

local function dibujarPromoVolando()
    local s, q = promoVolando()
    if not s then return end
    local cx, cy = apertura.centro()
    local qq = fx.salidaSuave(q)
    local x = fx.lerp(cx, s.x, qq)
    local y = fx.lerp(cy - 30, s.y, qq) - math.sin(q * math.pi) * 50
    local e = fx.lerp(escalaDe(s) * 1.6, escalaDe(s), qq)
    local def, c = partida.carta(s.id), partida.copia(s.id, s.u)
    if not (def and c) then return end
    encima.anotar(function()
        if q < 1 then fx.aura(x, y, p.amarillo, CW * e, 0.5 * (1 - q)) end
        carta.dibujar(def, x, y, e, e, fx.lerp(0, s.r or 0, qq) + (1 - qq) * 6.283, true, nil, c.f, { primera = c.p, top = c.t })
    end)
end

local function dibujarCajaAbierta()
    local c = partida.cajaAbierta
    if not c or animCaja then return end
    local cogido = mano and mano.cosa == "sobre" and mano.deCaja and 1 or 0
    local quedan = c.quedan - cogido
    if c.prod then return dibujarAbanico(c, quedan) end
    caja.dibujar(c.tipo, ESQUINA.x, ESQUINA.y, ESQUINA.e, { abierta = true, quedan = quedan })
    fuentes.texto("X" .. quedan, ESQUINA.x - 20, ESQUINA.y + 22, 1, p.amarillo, "center", 40)
    if quedan > 0 and not apertura.bloqueada() then
        ui.zona("caja_abierta", ESQUINA.x - 30, ESQUINA.y - 22, 60, 42)
        if ui.encima == "caja_abierta" and not mano then
            ui.tooltip("Caja abierta", p.amarillo, { { "Quedan " .. quedan .. " sobres" }, { "Arrastra uno al tapete", p.grisclaro } })
        end
    end
end

-- fundas y tops que trae un producto: sueltos en la mesa hasta que se guardan
local function dibujarSueltos()
    if animCaja then return end
    local x, y = SUELTOS.x, SUELTOS.y
    local hay = false
    for _, que in ipairs({ "fundas", "tops" }) do
        local n = partida.sueltos[que]
        local cogido = mano and mano.cosa == "suelto" and mano.que == que
        if n > 0 and not cogido then
            hay = true
            if que == "fundas" then muebles.blister(x, y, 1, 0.12, "X" .. n) else muebles.bolsaTops(x, y, 1, -0.1, "X" .. n) end
            if not apertura.bloqueada() then ui.zona("suelto_" .. que, x - 16, y - 2, 32, 48) end
            if ui.encima == "suelto_" .. que and not mano then
                ui.tooltip(que == "fundas" and "Fundas" or "Top loaders", que == "fundas" and p.cian or p.celeste,
                    { { n .. " sueltos en la mesa" }, { "Arrástralos a tu caja", p.grisclaro } })
            end
        end
        x = x - 40
    end
    if hay then fuentes.texto("< A TU CAJA", SUELTOS.x - 70, SUELTOS.y + 54, 1, p.lima, "center", 100) end
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
    sueltos = "ARRASTRA LAS FUNDAS Y LOS TOPS A TU CAJA PARA GUARDARLOS",
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
        for _, s in pairs(sitioCajas) do
            if partida.prodDisponibles(s.pid, s.tipo) > 0 then return "sacar", s.x + 20, s.y - 26 end
        end
    end
    if haySueltos() and not partida.pistas.sueltos then return "sueltos", SUELTOS.x - 30, SUELTOS.y + 34 end
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
    dibujarPromoMesa()
    dibujarSueltos()
    dibujarCopias()
    apertura.dibujar()
    if animCaja then
        local cx, cy = apertura.centro()
        if animCaja.prod then prDib.dibujarAnim(animCaja, cx, cy) else caja.dibujarAnim(animCaja, cx, cy) end
        dibujarPromoVolando()
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
        local avanzar = animCaja.prod and prDib.avanzarAnim or caja.avanzar
        if avanzar(animCaja, dt, cx, cy) then
            local col = sobres[animCaja.tipo].colores
            sonido.tocar("rasgar")
            sonido.tocar("secreta")
            fx.sacudir(7)
            fx.destello({ 1, 1, 1 }, 0.7)
            fx.explosion(cx, cy - 30, col.letras, 90, 240)
            fx.explosion(cx, cy - 30, p.blanco, 40, 300)
            fx.confeti(cx, cy - 40, 70, 200)
            fx.tintar(col.rayas)
            directo.producto(animCaja.prod or "caja")
        end
        if animCaja.t >= (animCaja.prod and prDib.DURACION or caja.DURACION) then
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
            local objetivoE = (mano.cosa == "sobre" and ESCALA_COGIDO) or (mano.cosa == "cajabox" and (mano.prod == "blister" and 1.1 or 1.5)) or 1
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
    if id == "mesa_velocidad" then
        -- la siguiente velocidad (tras la mas rapida, vuelve a la mas lenta)
        local lista, ahora = partida.velocidades(), partida.velocidad()
        local sig = lista[1]
        for _, v in ipairs(lista) do
            if v > ahora + 0.001 then sig = v break end
        end
        partida.opciones.velocidad = sig
        sonido.tocar("encima", 0.8 + sig * 0.3)
        partida.guardar()
        return true
    end
    if id ~= "mesa_sacar" then chipCaja = nil end
    if id == "mesa_cancelar" then return mesa.cancelar() or true end
    if id == "mesa_recoger" then
        mesa.recoger()
        return true
    end
    if id == "mesa_sacar" then
        if chipCaja then sacarDeCajaCerrada(chipCaja.prod, chipCaja.tipo) end
        return true
    end
    if id and directo.click(id) then return true end
    if apertura.enLote() then
        if id then apertura.boton(id) else apertura.pulsar() end
        return true
    end
    if id and id:match("^cajabox_") then
        mano = { cosa = "cajabox", prod = "caja", tipo = id:sub(9), x = x, y = y, a = 0, w = 0, vx = 0, escala = 0.8, x0 = x, y0 = y }
        sonido.tocar("encima", 1.0)
        return true
    end
    if id and id:match("^prodbox_") then
        local pid, tipoId = id:match("^prodbox_([^_]+)_(.+)$")
        mano = { cosa = "cajabox", prod = pid, tipo = tipoId, x = x, y = y, a = 0, w = 0, vx = 0, escala = 0.8, x0 = x, y0 = y }
        sonido.tocar("encima", 1.0)
        return true
    end
    -- el blister se coge como una ETB: al tapete se abre, tocado saca sus sobres
    -- de una cajita se coge una con el diseno de arriba
    if id == "cajita_f" or id == "cajita_t" then
        local esTop = id == "cajita_t"
        mano = { cosa = esTop and "top" or "funda", id = disenoCajita(esTop), x = x, y = y, a = 0, w = 0, vx = 0, escala = 1 }
        sonido.tocar("encima", 1.2)
        return true
    end
    if id and id:match("^blis_") then
        mano = { cosa = "cajabox", prod = "blister", tipo = id:sub(6), x = x, y = y, a = 0, w = 0, vx = 0, escala = 1, x0 = x, y0 = y }
        sonido.tocar("encima", 1.1)
        return true
    end
    if id and id:match("^suelto_") then
        mano = { cosa = "suelto", que = id:sub(8), x = x, y = y, a = 0, w = 0, vx = 0, escala = 1 }
        sonido.tocar("encima", 1.2)
        return true
    end
    if id == "caja_abierta" and partida.cajaAbierta then
        mano = { cosa = "sobre", tipo = partida.cajaAbierta.tipo, deCaja = true, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1,
                 hx = select(1, rincon()), hy = select(2, rincon()) }
        sonido.tocar("encima", 1.3)
        return true
    end
    -- un sobrecito de la mesa (de la ETB o la caja abierta)
    local im = id and tonumber(id:match("^pmesa_(%d+)$") or "")
    if im and partida.promoMesa[im] then
        local pm = partida.promoMesa[im]
        local px, py = sitioPromo(im)
        mano = { cosa = "sobre", tipo = sobre.clavePromo(pm.o, pm.t), promo = pm.o, tipoReal = pm.t, deMesa = im, id = id,
                 x = x, y = y, a = 0, w = 0, vx = 0, escala = 1, hx = px, hy = py + 20, x0 = x, y0 = y }
        sonido.tocar("encima", 1.3)
        return true
    end
    -- un sobrecito promo o de torneo
    if id and id:match("^pcaja_") then
        local origen, tipoId = id:match("^pcaja_(%a+)_(.+)$")
        local hx, hy = huecoDe(tipoId, nil, id)
        mano = { cosa = "sobre", tipo = sobre.clavePromo(origen, tipoId), promo = origen, tipoReal = tipoId, id = id,
                 x = x, y = y, a = 0, w = 0, vx = 0, escala = 1, hx = hx, hy = hy }
        sonido.tocar("encima", 1.3)
        return true
    end
    if id and id:match("^caja_") then
        local que = id:sub(6)
        if que == "funda" or que == "top" then
            mano = { cosa = que, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1 }
        else
            local tipoId, ed = que:match("^(.-)_([1n])$")
            tipoId = tipoId or que
            local primera
            if ed then primera = ed == "1" end
            local hx, hy = huecoDe(tipoId, primera)
            mano = { cosa = "sobre", tipo = tipoId, primera = primera, id = id, x = x, y = y, a = 0, w = 0, vx = 0, escala = 1, hx = hx, hy = hy }
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
            if r.deCaja and partida.cajaAbierta then hx, hy = rincon() end
            -- el id de su gancho: mientras lo llevas no cuenta en la pila
            local idGancho = "caja_" .. r.tipo
            if filtro ~= "todo" then idGancho = idGancho .. (r.primera and "_1" or "_n") end
            mano = { cosa = "sobre", tipo = r.tipo, deCaja = r.deCaja or nil, x = x, y = y, a = 0, w = 0, vx = 0,
                     escala = 3, hx = hx, hy = hy, id = not r.deCaja and idGancho or nil, primera = r.primera }
            sonido.tocar("encima", 1.3)
        end
    end
end

local function enfundarCopia(c, x, y, id)
    -- con diseno: se pone aunque ya tenga funda (la de antes vuelve a su caja)
    if id then
        if partida.cambiarFunda(c, id) then
            brilloFunda(x, y)
            return true
        end
        return false
    end
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

-- top loader sin funda: se deja, pero se avisa de que se puede rayar
local function avisoRayar(c, x, y)
    if c.f then return end
    sonido.tocar("latido")
    fx.texto(x, y - 18, "¡OJO! SIN FUNDA SE PUEDE RAYAR", p.naranja, 2.5)
    fx.texto(x, y - 6, "MEJOR PONLE FUNDA PRIMERO", p.grisclaro, 2.5)
end

local function ponerTopCopia(c, x, y, id)
    if id then
        if partida.cambiarTop(c, id) then
            brilloFunda(x, y)
            avisoRayar(c, x, y)
            return true
        end
        return false
    end
    if c.t then return false end
    if partida.topsLibres <= 0 then
        sonido.tocar("latido")
        fx.texto(x, y - 10, "SIN TOP LOADERS: CÓMPRALOS EN LA TIENDA", p.rojo)
        return false
    end
    if partida.ponerTop(c) then
        brilloFunda(x, y)
        avisoRayar(c, x, y)
        return true
    end
    return false
end

function mesa.soltar(x, y)
    pulsadoEnTapete = false
    local m = mano
    mano = nil
    if not m then return end
    if m.cosa == "sobre" and m.promo then
        -- el de la mesa, soltado en tu caja: se guarda como producto sellado
        if m.deMesa and dentro(CAJA, x, y) then
            partida.guardarPromoMesa(m.deMesa)
            sonido.tocar("giro")
            fx.texto(x, y - 10, "GUARDADO", p.lima)
            partida.guardar()
            table.insert(vuelos, { tipo = m.tipo, x0 = m.x, y0 = m.y + sobre.ALTO * m.escala / 2, x1 = CAJA.x + CAJA.w / 2,
                                   y1 = CAJA.y + 60, e0 = m.escala, a = m.a, t = 0 })
            return
        end
        -- el de la mesa ya esta en el tapete: hay que arrastrarlo un poco para abrirlo
        local movido = not m.deMesa or math.abs(x - m.x0) + math.abs(y - m.y0) > 12
        if dentro(TAPETE, x, y) and movido and soltarPromo(m) then return end
        table.insert(vuelos, { tipo = m.tipo, x0 = m.x, y0 = m.y + sobre.ALTO * m.escala / 2, x1 = m.hx, y1 = m.hy,
                               e0 = m.escala, a = m.a, t = 0 })
    elseif m.cosa == "sobre" then
        if dentro(TAPETE, x, y) and soltarSobre(m.tipo, m.x, m.y + sobre.ALTO * m.escala / 2 - 4 * m.escala, m.a, m.escala, m.deCaja, m.primera) then
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
            chipCaja = { prod = m.prod, tipo = m.tipo, t = 3 }
            return
        end
        if dentro(TAPETE, x, y) and not apertura.bloqueada() and not animCaja and partida.abrirProd(m.prod, sobres[m.tipo]) then
            apertura.recoger()
            partida.recogerMesa()
            mesaSel = nil
            -- la promo del blister o del tin se queda en la mesa (para enfundarla...)
            local r, promoU = partida.promoReciente, nil
            if r then
                partida.promoReciente = nil
                local s = partida.aLaMesa(r.id, r.c, true)
                if s then
                    sitioMesa(s, #partida.mesa)
                    promoU = s.u
                end
            end
            if m.prod == "caja" then
                logros.marcar("caja")
                animCaja = { tipo = m.tipo, t = 0, x0 = m.x, y0 = m.y + caja.COLGADO * m.escala, x1 = ESQUINA.x, y1 = ESQUINA.y, e1 = ESQUINA.e,
                             quedan = sobres.caja.sobres }
            else
                if m.prod == "etb" then logros.marcar("etb") end
                if m.prod == "etb" or m.prod == "blister" then
                    -- si alguien del directo lo habia comprado, se cobra y sus sobres son suyos
                    directo.abrirProducto(m.prod, m.tipo, partida.cajaAbierta and partida.cajaAbierta.primera == true)
                end
                animCaja = { prod = m.prod, tipo = m.tipo, t = 0, x0 = m.x, y0 = m.y + 10, destinos = destinosAbanico(productos[m.prod].sobres),
                             promo = promoU }
            end
            reporte.apuntar("abre " .. m.prod .. " " .. m.tipo)
            sonido.tocar("giro")
            partida.guardar()
        end
    elseif m.cosa == "suelto" then
        if dentro(CAJA, x, y) then
            local n = partida.guardarSueltos(m.que)
            if n > 0 then
                brilloFunda(x, y)
                fx.texto(x, y - 10, "+" .. n .. (m.que == "fundas" and " FUNDAS" or " TOPS"), m.que == "fundas" and p.cian or p.celeste)
                verPista("sueltos")
            end
        end
    elseif m.cosa == "funda" or m.cosa == "top" then
        local hacer = m.cosa == "top" and ponerTopCopia or enfundarCopia
        local c = apertura.cartaEn(x, y)
        if c and c.copia then
            if hacer(c.copia, x, y, m.id) then c.brillo = 1 end
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
            if copia and hacer(copia, x, y, m.id) then s.brillo = 1 end
        end
    elseif m.cosa == "copia" then
        local s = entradaMesa(m.u)
        if not s then return end
        -- tocada sin arrastrar: INSPECCIONAR (girarla, funda, top, vender)
        if not m.movida then
            mesaSel = nil
            inspeccionar.abrir(s.id, s.u, { alArmario = function()
                if partida.guardarDeMesa(s.u) then
                    sonido.tocar("giro")
                    partida.guardar()
                end
            end })
            return
        end
        -- soltada en una cajita: se enfunda con su diseno y vuelve a su sitio
        for _, esTop in ipairs({ false, true }) do
            local cx, cy, cw, ch = zonaCajita(esTop)
            local id = disenoCajita(esTop)
            if id and (not esTop or desbloqueos.hay("tops")) and desbloqueos.hay("fundas") and x >= cx and x < cx + cw and y >= cy and y < cy + ch then
                local c = partida.copia(s.id, s.u)
                local hacer = esTop and ponerTopCopia or enfundarCopia
                if c and hacer(c, x, y, id) then
                    s.brillo = 1
                    partida.guardar()
                end
                return
            end
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
    local d = id and id:match("^mesa_tablero_(%-?1)$")
    if d then
        paginaTablero = paginaTablero + tonumber(d)
        return
    end
    local k, paso = (id or ""):match("^mesa_cajita_([ft])_(%-?1)$")
    if k then
        local esTop = k == "t"
        local l = partida.disenosLibres(esTop)
        local pos = 1
        for i, x in ipairs(l) do if x == disenoCajita(esTop) then pos = i end end
        partida.cajitas[k] = l[(pos - 1 + tonumber(paso)) % #l + 1]
        return
    end
    k = (id or ""):match("^mesa_cajitanom_([ft])$")
    if k then
        fundario.elegir(k == "t", disenoCajita(k == "t"), function(nuevo) partida.cajitas[k] = nuevo end)
        return
    end
    d = id and id:match("^mesa_filtro_(%-?1)$")
    if d then
        local ops = opcionesFiltro()
        local pos = 1
        for i, f in ipairs(ops) do if f == filtro then pos = i end end
        filtro = ops[math.max(1, math.min(#ops, pos + tonumber(d)))]
        paginaTablero = 1
        return
    end
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
            avisoRayar(c, ui.mx, ui.my)
        end
        partida.guardar()
    elseif id == "mesa_vender" then
        local def = partida.carta(s.id)
        local x, y = ui.mx, ui.my
        local function hacer() cobrar(partida.venderCopias(s.id, { s.u }), x, y) end
        if partida.copias(s.id) == 1 then
            ui.confirmar("¿VENDER LA ÚLTIMA?", { "ES TU ÚNICA COPIA DE " .. rarezas.nombre(def):upper(), "DESAPARECERÁ DEL ÁLBUM" },
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
        for _, tipo in ipairs(sobres.lista) do
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

-- el armario manda algo a la mesa: se ve su set
function mesa.verSet(tipoId)
    filtro = tipoId and sobres[tipoId] and tipoId or "todo"
    paginaTablero = 1
end

-- al empezar o cargar otra partida
function mesa.reiniciar()
    mano, mesaSel, animCaja = nil, nil, nil
    pulsoSobre, chipCaja, pistaVista = nil, nil, nil
    paginaTablero = 1
    filtro = "todo"
    vuelos = {}
    apertura.recoger()
end

return mesa
