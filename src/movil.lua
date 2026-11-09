local sobres = require "datos.sobres"
local productos = require "datos.productos"
local sets = require "datos.sets"
local rarezas = require "datos.rarezas"
local datosMercado = require "datos.mercado"
local datosCalendario = require "datos.calendario"
local datosMejoras = require "datos.mejoras"
local p = require "datos.paleta"
local partida = require "src.partida"
local datosFundas = require "datos.fundas"
local mercado = require "src.mercado"
local calendario = require "src.calendario"
local carta = require "src.carta"
local sobre = require "src.sobre"
local grafica = require "src.grafica"
local fx = require "src.fx"
local sonido = require "src.sonido"
local fuentes = require "src.fuentes"
local desbloqueos = require "src.desbloqueos"
local ui = require "src.ui"
local nav = require "src.nav"
local vendedores = require "src.vendedores"
local guia = require "src.guia"
local logros = require "src.logros"

local lg = love.graphics

local movil = {}

-- proporcion de movil (no de tablet): pantalla de 196x326
local TEL = { x = 217, y = 22, w = 206, h = 336 }
local PANT = { x = 222, y = 27, w = 196, h = 326 }
local BARRA = 11      -- barra de estado
local CABECERA = 14   -- titulo de cada app
local INICIO = 10     -- barra de abajo para volver al inicio
local CONT = { x = PANT.x, y = PANT.y + BARRA + CABECERA, w = PANT.w, h = PANT.h - BARRA - CABECERA - INICIO }

local app = "inicio"
local volver = {}         -- de donde se vino, para el boton de atras
local fichaId, fichaPrimera
local setVista
local rango = 30
local pestanaCartera = "top"
local pestanaMejoras = "suerte"
local seccionSet = "s1"
local scroll, altoContenido = {}, {}
local abriendo            -- animacion al abrir una app
local avisos = {}         -- notificaciones que bajan por arriba
local sinLeer = 0
local mano = { y = 0, t = 1, entrando = true, alAcabar = nil }   -- sacar y guardar el movil
local SACAR, GUARDAR = 0.35, 0.2
local elegido             -- indice del anuncio que se ve a la derecha
local envio               -- animacion de empaquetado
local fondo               -- fondo de pantalla, se pinta una vez

local APPS = {
    { id = "cartera",    nombre = "CARTERA",    color = p.verde },
    { id = "mercado",    nombre = "MERCADO",    color = p.azul },
    { id = "ventas",     nombre = "VENTAS",     color = p.naranja },
    { id = "noticias",   nombre = "NOTICIAS",   color = p.rojo },
    { id = "calendario", nombre = "CALENDARIO", color = p.morado },
    { id = "encargos",   nombre = "ENCARGOS",   color = p.verdeosc },
    { id = "mejoras",    nombre = "MEJORAS",    color = p.violeta },
    { id = "logros",     nombre = "LOGROS",     color = p.amarillo },
}

-- las apps que ya has desbloqueado (src/desbloqueos.lua)
local function apps()
    local lista = {}
    for _, a in ipairs(APPS) do
        if desbloqueos.app(a.id) then table.insert(lista, a) end
    end
    return lista
end

local TITULOS = { cartera = "CARTERA", mercado = "MERCADO", ventas = "VENTAS", noticias = "NOTICIAS",
    calendario = "CALENDARIO", set = "MERCADO", ficha = "CARTA", encargos = "ENCARGOS", mejoras = "MEJORAS", logros = "LOGROS" }

-- dibujos de los iconos, 9x9
local ICONOS = {
    cartera = { ".........", "......##.", ".....#.#.", "..#.#....", ".#.#.....", "#........", "#########", ".........", "........." },
    mercado = { "#########", "#.#.#.#.#", "#########", ".#.....#.", ".#.###.#.", ".#.#.#.#.", ".#.#.#.#.", ".#######.", "........." },
    ventas  = { "....####.", "...#...#.", "..#..#.#.", ".#.....#.", "#......#.", ".#....#..", "..#..#...", "...##....", "........." },
    noticias = { "########.", "#......##", "#.####.##", "#......##", "#.##.#.##", "#......##", "#.####.##", "#########", "........." },
    mejoras = { "....#....", "...###...", "..#####..", ".#######.", "...###...", "...###...", "...###...", "...###...", "........." },
    encargos = { "...###...", "..#...#..", "#########", "#.......#", "#...#...#", "#..###..#", "#...#...#", "#########", "........." },
    logros = { "#.#####.#", "#.#####.#", ".#######.", "..#####..", "...###...", "....#....", "....#....", "..#####..", "........." },
    calendario = { ".#....#..", "#########", "#.......#", "#.#.#.#.#", "#.......#", "#.#.#.#.#", "#.......#", "#########", "........." },
}

local function notificar(texto, color)
    table.insert(avisos, 1, { texto = texto, color = color or p.amarillo, t = 0 })
    while #avisos > 4 do table.remove(avisos) end
    sonido.tocar("nueva")
end

-- avisos desde fuera del movil (premios...)
movil.avisar = function(texto, color) notificar(texto, color) end

local function colorTono(n)
    if n.tono == "sube" then return p.lima end
    if n.tono == "baja" then return p.rojo end
    return p.cian
end

function movil.pasarDia()
    local antes = partida.ofertasTotales()
    local noticias = partida.pasarDia()
    local despues = partida.ofertasTotales()
    partida.guardar()
    sinLeer = sinLeer + #noticias
    for i = math.min(3, #noticias), 1, -1 do
        notificar(noticias[i].texto, colorTono(noticias[i]))
    end
    if despues > antes then notificar((despues - antes) .. " OFERTAS NUEVAS EN VENTAS", p.amarillo) end
    local avisadas = 0
    for _, id in ipairs(partida.listaBuscadas()) do
        if avisadas < 2 and movil.laVenden(id) then
            notificar("HOY VENDEN UNA QUE BUSCAS: " .. rarezas.nombre(mercado.carta(id)):upper(), p.amarillo)
            avisadas = avisadas + 1
        end
    end
    if #noticias == 0 and despues <= antes then sonido.tocar("giro") end
end

local ofertasTotales = partida.ofertasTotales

-- navegacion

local function ir(destino, desde)
    if destino ~= app then table.insert(volver, app) end
    app = destino
    scroll[destino] = scroll[destino] or 0
    if desde then abriendo = { t = 0, x = desde.x, y = desde.y, w = desde.w, h = desde.h } end
    if destino == "noticias" then sinLeer = 0 end
    if destino ~= "ventas" then elegido = nil end
end

local function atras()
    app = table.remove(volver) or "inicio"
    if app == "noticias" then sinLeer = 0 end
end

local function inicio()
    app = "inicio"
    volver = {}
    elegido = nil
end

-- al empezar o cargar una partida el movil vuelve al inicio (lo que estaba
-- abierto puede no existir en la otra partida)
function movil.reiniciar()
    inicio()
    scroll = {}
    avisos = {}
    sinLeer = 0
end

function movil.abrirFicha(id, primera)
    if app ~= "ficha" then table.insert(volver, app) end
    app = "ficha"
    fichaId = id
    fichaPrimera = primera
    scroll.ficha = 0
end

-- dibujo del telefono

local BAYER = { { 0, 8, 2, 10 }, { 12, 4, 14, 6 }, { 3, 11, 1, 9 }, { 15, 7, 13, 5 } }

local function pintarFondo()
    local w, h = PANT.w, PANT.h
    for y = 0, h - 1 do
        local t = y / h * 16
        for x = 0, w - 1 do
            lg.setColor(t > BAYER[y % 4 + 1][x % 4 + 1] + 0.5 and p.morado or p.azulosc)
            lg.rectangle("fill", x, y, 1, 1)
        end
    end
    -- el rombo del dorso de las cartas, grande y apagado
    local cx, cy = w / 2, h * 0.62
    lg.setColor(1, 1, 1, 0.05)
    lg.polygon("fill", cx, cy - 70, cx + 58, cy, cx, cy + 70, cx - 58, cy)
    lg.setColor(1, 1, 1, 0.07)
    lg.polygon("line", cx, cy - 62, cx + 50, cy, cx, cy + 62, cx - 50, cy)
    lg.setColor(1, 1, 1)
end

function movil.preparar()
    fondo = lg.newCanvas(PANT.w, PANT.h)
    fondo:setFilter("nearest", "nearest")
    lg.setCanvas(fondo)
    lg.clear(0, 0, 0, 0)
    pintarFondo()
    lg.setCanvas()
end

local function marco()
    -- sombra, botones laterales, canto metalico y cuerpo negro
    lg.setColor(0, 0, 0, 0.4)
    lg.rectangle("fill", TEL.x + 4, TEL.y + 6, TEL.w, TEL.h, 22, 22)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", TEL.x - 3, TEL.y + 64, 4, 20, 1, 1)
    lg.rectangle("fill", TEL.x - 3, TEL.y + 90, 4, 20, 1, 1)
    lg.rectangle("fill", TEL.x + TEL.w - 1, TEL.y + 78, 4, 34, 1, 1)
    lg.setColor(p.gris)
    lg.rectangle("fill", TEL.x - 1, TEL.y - 1, TEL.w + 2, TEL.h + 2, 22, 22)
    lg.setColor(p.negro)
    lg.rectangle("fill", TEL.x, TEL.y, TEL.w, TEL.h, 21, 21)
    lg.setColor(1, 1, 1, 0.1)
    lg.rectangle("fill", TEL.x + 22, TEL.y + 1, TEL.w - 44, 1)
    lg.setColor(1, 1, 1)
end

-- esquinas redondeadas de la pantalla: se tapan con el negro del marco
local RADIO = 12
local TAPA = {}
for i = 0, RADIO - 1 do
    local dy = RADIO - i - 0.5
    TAPA[i + 1] = math.ceil(RADIO - math.sqrt(RADIO * RADIO - dy * dy) - 0.3)
end

local function esquinasPantalla()
    lg.setColor(p.negro)
    local x2, y2 = PANT.x + PANT.w, PANT.y + PANT.h
    for i, w in ipairs(TAPA) do
        if w > 0 then
            lg.rectangle("fill", PANT.x, PANT.y + i - 1, w, 1)
            lg.rectangle("fill", x2 - w, PANT.y + i - 1, w, 1)
            lg.rectangle("fill", PANT.x, y2 - i, w, 1)
            lg.rectangle("fill", x2 - w, y2 - i, w, 1)
        end
    end
    lg.setColor(1, 1, 1)
end

local function barraEstado()
    local x, y = PANT.x, PANT.y
    lg.setColor(0, 0, 0, app == "inicio" and 0.25 or 1)
    lg.rectangle("fill", x, y, PANT.w, BARRA)
    fuentes.texto("DÍA " .. mercado.dia(), x + 12, y + 3, 1, p.blanco)
    -- camara en la pantalla
    lg.setColor(p.grisosc)
    lg.circle("fill", x + PANT.w / 2, y + 5, 3.5)
    lg.setColor(p.negro)
    lg.circle("fill", x + PANT.w / 2, y + 5, 2.5)
    -- bateria y dinero
    local bx = x + PANT.w - 22
    lg.setColor(p.blanco)
    lg.rectangle("line", bx + 0.5, y + 3.5, 9, 5)
    lg.rectangle("fill", bx + 10, y + 5, 1, 2)
    lg.setColor(p.lima)
    lg.rectangle("fill", bx + 2, y + 5, 6, 2)
    fuentes.texto(ui.dinero(partida.dinero), x, y + 3, 1, p.amarillo, "right", PANT.w - 26)
end

local function barraInicio()
    local y = PANT.y + PANT.h - INICIO
    lg.setColor(0, 0, 0, app == "inicio" and 0.25 or 1)
    lg.rectangle("fill", PANT.x, y, PANT.w, INICIO)
    local encima = ui.encima == "m_inicio"
    lg.setColor(encima and p.blanco or p.grisclaro)
    lg.rectangle("fill", PANT.x + PANT.w / 2 - 22, y + 4, 44, 2, 1, 1)
    if app ~= "inicio" then ui.zona("m_inicio", PANT.x, y, PANT.w, INICIO) end
end

local function cabecera(titulo)
    local y = PANT.y + BARRA
    lg.setColor(p.negro)
    lg.rectangle("fill", PANT.x, y, PANT.w, CABECERA)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", PANT.x, y + CABECERA - 1, PANT.w, 1)
    local encima = ui.encima == "m_atras"
    fuentes.texto("<", PANT.x + 6, y + 4, 1, encima and p.amarillo or p.blanco)
    ui.zona("m_atras", PANT.x, y, 24, CABECERA)
    fuentes.texto(titulo, PANT.x, y + 4, 1, p.blanco, "center", PANT.w)
end

local function chip(texto, x, y, color)
    local w = fuentes.ancho(texto) + 6
    lg.setColor(color)
    lg.rectangle("fill", x, y, w, 9)
    fuentes.texto(texto, x + 3, y + 2, 1, p.negro)
    return w
end

-- nombre y color de la fase de un set para enseñar
local function nombreFase(setId)
    local fase, i = mercado.fase(setId)
    if fase == "impresion" then
        if i.quedan < datosCalendario.ultimos then return "ÚLTIMOS DÍAS", p.amarillo end
        if calendario.lanzando(setId, mercado.dia()) then return "¡NOVEDAD!", p.lima end
        return "EN TIENDA", p.verde
    elseif fase == "reimpresion" then
        if i.quedan < datosCalendario.ultimos then return "ÚLTIMOS DÍAS", p.amarillo end
        return "REIMPRESIÓN", p.celeste
    elseif fase == "anunciado" then
        return "SALE EL DÍA " .. (mercado.dia() + i.faltan), p.amarillo
    elseif fase == "futuro" then
        return "???", p.gris
    end
    return "AGOTADO", p.grisclaro
end

-- scroll de las apps: el contenido se pinta desplazado y recortado
local function empezarLista()
    local s = scroll[app] or 0
    ui.recorte = { x = CONT.x, y = CONT.y, w = CONT.w, h = CONT.h }
    lg.setScissor(CONT.x, CONT.y + mano.dy, CONT.w, CONT.h)
    return CONT.y - s
end

local function acabarLista(yFinal)
    altoContenido[app] = yFinal + (scroll[app] or 0) - CONT.y
    local maximo = math.max(0, altoContenido[app] - CONT.h + 6)
    scroll[app] = math.max(0, math.min(maximo, scroll[app] or 0))
    if maximo > 0 then
        local alto = math.max(12, CONT.h * CONT.h / (altoContenido[app] + 6))
        local y = CONT.y + (CONT.h - alto) * (scroll[app] / maximo)
        lg.setColor(1, 1, 1, 0.25)
        lg.rectangle("fill", CONT.x + CONT.w - 3, y, 2, alto)
    end
    ui.recorte = nil
    lg.setScissor()
end

local function botonesRango(x, y)
    for i, r in ipairs({ { 7, "7D" }, { 30, "30D" }, { 999, "TODO" } }) do
        ui.boton("m_rango" .. r[1], r[2], x + (i - 1) * 26, y, 24, 10, rango == r[1] and p.azul or p.grisosc)
    end
end

-- edicion mas valiosa que tienes de una carta
local function mejorEdicion(id)
    return partida.deEdicion(id, true) > 0 and mercado.hayNormales(mercado.carta(id).set)
end

-- fila de una carta en una lista: gema, nombre, linea y precio
local function filaCarta(id, x, y, w, idZona, primera, tenue)
    local def = mercado.carta(id)
    local r = rarezas.de(def)
    local nombre = rarezas.nombre(def)
    local encima = ui.encima == idZona
    if encima then
        lg.setColor(1, 1, 1, 0.06)
        lg.rectangle("fill", x, y, w, 18)
    end
    carta.gema(def.rareza, x + 7, y + 8)
    fuentes.texto(nombre, x + 15, y + 3, 1, tenue and p.gris or r.color)
    -- la que buscas: estrella y, si alguien la vende hoy, se dice
    local buscada = partida.buscada(id)
    if buscada then ui.estrella(x + 18 + fuentes.ancho(nombre), y + 2, p.amarillo) end
    local sub = sets[def.set].codigo
    local n = partida.copias(id)
    if n > 0 then sub = sub .. "  X" .. n end
    if primera then sub = sub .. "  1ª ED" end
    if def.chase then sub = sub .. "  CHASE" end
    fuentes.texto(sub, x + 15, y + 11, 1, p.gris)
    if buscada and movil.laVenden(id) then
        fuentes.texto("A LA VENTA", x + 19 + fuentes.ancho(sub), y + 11, 1, p.lima)
        sub = sub .. "  A LA VENTA"
    end
    local _, h = mercado.historial(id, primera)
    local precio = ui.dinero(mercado.valor(id, primera))
    local gx = x + w - 4 - math.max(fuentes.ancho(precio), 28) - 40
    if h and gx > x + 19 + math.max(fuentes.ancho(nombre), fuentes.ancho(sub)) then grafica.mini(h, gx, y + 4, 36, 10) end
    local cambio = mercado.cambio(id, 7, primera)
    fuentes.texto(precio, x, y + 3, 1, p.amarillo, "right", w - 4)
    fuentes.texto(ui.porcentaje(cambio), x, y + 11, 1, ui.colorCambio(cambio), "right", w - 4)
    ui.zona(idZona, x, y, w, 18)
end

-- inicio

local function posIcono(i)
    local col = (i - 1) % 3
    local fila = math.floor((i - 1) / 3)
    local enFila = math.min(3, #apps() - fila * 3)
    local paso = 60
    local x0 = PANT.x + PANT.w / 2 - (enFila - 1) * paso / 2
    return x0 + col * paso, PANT.y + 88 + fila * 50
end

local function icono(a, cx, cy)
    local id = "m_app_" .. a.id
    local alza = ui.anim(id, ui.encima == id and 1 or 0)
    cy = cy - math.floor(alza * 2 + 0.5)
    local x, y = cx - 13, cy - 13
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", x + 1, y + 2, 26, 26, 6, 6)
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 1, y - 1, 28, 28, 7, 7)
    lg.setColor(a.color[1] * 0.6, a.color[2] * 0.6, a.color[3] * 0.6)
    lg.rectangle("fill", x, y, 26, 26, 6, 6)
    lg.setColor(a.color)
    lg.rectangle("fill", x, y, 26, 23, 6, 6)
    lg.setColor(p.blanco)
    for fy, fila in ipairs(ICONOS[a.id]) do
        for fxx = 1, #fila do
            if fila:sub(fxx, fxx) == "#" then lg.rectangle("fill", x + 4 + fxx * 2 - 2, y + 2 + fy * 2 - 2, 2, 2) end
        end
    end
    fuentes.texto(a.nombre, cx - 30, cy + 17, 1, p.blanco, "center", 60)
    local badge = (a.id == "noticias" and sinLeer) or (a.id == "ventas" and ofertasTotales())
        or (a.id == "encargos" and #partida.ofertasEncargo) or 0
    if badge > 0 then
        local t = tostring(badge)
        local w = math.max(9, fuentes.ancho(t) + 5)
        lg.setColor(p.negro)
        lg.rectangle("fill", x + 26 - w + 3, y - 4, w + 2, 11, 4, 4)
        lg.setColor(p.rojo)
        lg.rectangle("fill", x + 26 - w + 4, y - 3, w, 9, 4, 4)
        fuentes.texto(t, x + 26 - w + 4, y - 1, 1, p.blanco, "center", w)
    end
    -- app nueva sin abrir: punto rojo a la izquierda (a la derecha va el numero)
    if guia.puntoApp(a.id) then guia.dibujarPunto(x + 1, y + 1) end
    ui.zona(id, x - 4, y - 4, 34, 46)
end

local function appInicio()
    lg.setColor(1, 1, 1)
    lg.draw(fondo, PANT.x, PANT.y)
    fuentes.texto("DÍA " .. mercado.dia(), PANT.x, PANT.y + 22, 4, p.blanco, "center", PANT.w)
    local enTienda = {}
    for _, tipo in ipairs(sobres.lista) do
        if mercado.enTienda(tipo) then table.insert(enTienda, sets[tipo.set].codigo) end
    end
    local linea = #enTienda > 0 and ("EN LA TIENDA: " .. table.concat(enTienda, ", ")) or "LA TIENDA ESTÁ VACÍA"
    fuentes.texto(linea, PANT.x + 8, PANT.y + 48, 1, p.grisclaro, "center", PANT.w - 16)

    local lista = apps()
    for i, a in ipairs(lista) do
        icono(a, posIcono(i))
    end
    if #lista == 0 then
        fuentes.texto("AÚN NO TIENES APPS: SE DESBLOQUEAN JUGANDO", PANT.x + 10, PANT.y + 110, 1, p.grisclaro, "center", PANT.w - 20)
    end

    -- widget de la cartera
    local y = PANT.y + 236
    if not desbloqueos.app("cartera") then
        fuentes.texto("PASA EL DÍA EN EL PANEL DE LA IZQUIERDA", PANT.x + 10, y + 46, 1, p.grisclaro, "center", PANT.w - 20)
        return
    end
    ui.caja(PANT.x + 12, y, PANT.w - 24, 34, p.negro)
    fuentes.texto("TU COLECCIÓN", PANT.x + 18, y + 5, 1, p.grisclaro)
    local h = partida.cartera.h
    local valor = partida.valorColeccion()
    fuentes.texto(ui.dinero(valor), PANT.x + 18, y + 15, 2, p.amarillo)
    if #h >= 2 then grafica.mini(h, PANT.x + PANT.w - 70, y + 8, 50, 18, 30) end
    ui.zona("m_app_cartera", PANT.x + 12, y, PANT.w - 24, 34)
    -- el dia solo se pasa con el boton de la izquierda
    fuentes.texto("PASA EL DÍA EN EL PANEL DE LA IZQUIERDA", PANT.x + 10, y + 46, 1, p.grisclaro, "center", PANT.w - 20)
end

-- cartera

local function calcularCartera()
    local lista = {}
    if pestanaCartera == "seguidas" then
        for id in pairs(partida.seguidas) do
            if mercado.disponible(id) then table.insert(lista, { id = id, primera = mejorEdicion(id) }) end
        end
    else
        for id in pairs(partida.inv) do
            table.insert(lista, { id = id, primera = mejorEdicion(id) })
        end
    end
    for _, x in ipairs(lista) do
        x.valor = mercado.valorExacto(x.id, x.primera)
        x.cambio = mercado.cambio(x.id, 7, x.primera)
    end
    local orden = {
        top = function(a, b) return a.valor > b.valor end,
        seguidas = function(a, b) return a.valor > b.valor end,
        suben = function(a, b) return a.cambio > b.cambio end,
        bajan = function(a, b) return a.cambio < b.cambio end,
    }
    table.sort(lista, function(a, b)
        if a.valor == b.valor and a.cambio == b.cambio then return a.id < b.id end
        return orden[pestanaCartera](a, b)
    end)
    if pestanaCartera == "suben" or pestanaCartera == "bajan" then
        local filtrada = {}
        local signo = pestanaCartera == "suben" and 1 or -1
        for _, x in ipairs(lista) do
            if x.cambio * signo > 0.005 then table.insert(filtrada, x) end
        end
        lista = filtrada
    end
    return lista
end

-- se ordena solo cuando cambia algo, no cada frame
local function listaCartera()
    return (partida.memo("cartera_" .. pestanaCartera, calcularCartera))
end

local function appCartera()
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    fuentes.texto("VALOR DE TU COLECCIÓN", x, y, 1, p.grisclaro)
    local valor = partida.valorColeccion()
    fuentes.texto(ui.dinero(valor), x, y + 10, 2, p.amarillo)
    local h = partida.cartera.h
    local k = math.max(1, #h - 7)
    local cambio = (h[k] and h[k] > 0) and (valor / h[k] - 1) or 0
    fuentes.texto(ui.porcentaje(cambio) .. " EN 7 DÍAS", x, y + 10, 1, ui.colorCambio(cambio), "right", w)
    y = y + 26
    fuentes.texto("GRÁFICA", x, y + 3, 1, p.gris)
    botonesRango(x + w - 76, y)
    y = y + 14
    if #h >= 2 then
        grafica.dibujar({ x = x, y = y, w = w, h = 56, series = { { datos = h, color = p.lima, nombre = "" } },
            rango = rango, dia0 = partida.cartera.h0, formato = ui.dinero, id = "cartera" })
    else
        fuentes.texto("PASA UN DÍA PARA VER LA GRÁFICA", x, y + 24, 1, p.gris, "center", w)
    end
    y = y + 62

    local tabs = { { "top", "TOP" }, { "suben", "SUBEN" }, { "bajan", "BAJAN" }, { "seguidas", "SIGUES" } }
    local tw = math.floor((w + 2) / #tabs)
    for i, t in ipairs(tabs) do
        ui.boton("m_tab_" .. t[1], t[2], x + (i - 1) * tw, y, tw - 2, 12, pestanaCartera == t[1] and p.azul or p.grisosc)
    end
    y = y + 16

    local lista = listaCartera()
    if #lista == 0 then
        local vacio = {
            top = "AÚN NO TIENES CARTAS",
            suben = "NADA DE LO TUYO SUBE ESTA SEMANA",
            bajan = "NADA DE LO TUYO BAJA ESTA SEMANA",
            seguidas = "SIGUE CARTAS DESDE SU FICHA",
        }
        fuentes.texto(vacio[pestanaCartera], x, y + 10, 1, p.gris, "center", w)
        y = y + 24
    end
    for i, c in ipairs(lista) do
        if i > 60 then break end
        filaCarta(c.id, x - 2, y, w + 4, "m_carta_" .. c.id .. "_" .. (c.primera and 1 or 0), c.primera, partida.copias(c.id) == 0)
        y = y + 19
    end
    acabarLista(y)
end

-- mercado

local function appMercado()
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    fuentes.texto("SETS Y SOBRES CERRADOS", x, y, 1, p.grisclaro)
    y = y + 10
    for _, s in ipairs(sets.lista) do
        if calendario.conocido(s.id, mercado.dia()) then
            local tipo = sobres[s.sobre]
            local id = "m_set_" .. tipo.id
            local salido = mercado.salido(s.id)
            local encima = ui.encima == id
            ui.caja(x, y, w, 40, encima and p.azulosc or p.grisosc)
            lg.setColor(1, 1, 1)
            lg.draw(sobre.imagen(tipo.id), x + 5, y + 4, 0, 0.7, 0.7)
            fuentes.texto(s.nombre:upper(), x + 30, y + 5, 1, p.blanco)
            local fase, color = nombreFase(s.id)
            chip(fase, x + 30, y + 14, color)
            if salido then
                local enTienda = mercado.enTienda(tipo)
                local texto = enTienda and ("TIENDA " .. ui.dinero(tipo.precio)) or "SOLO REVENTA"
                fuentes.texto(texto, x + 30, y + 28, 1, p.grisclaro)
                local precio = mercado.sellado(tipo, true)
                if precio then
                    fuentes.texto("1ª ED " .. ui.dinero(precio), x, y + 5, 1, p.amarillo, "right", w - 6)
                end
                local _, h1 = mercado.historialSellado(tipo)
                if h1 then grafica.mini(h1, x + w - 50, y + 18, 44, 14, 30) end
                ui.zona(id, x, y, w, 40)
            else
                fuentes.texto(#mercado.cartasDe(s.id) .. " CARTAS", x + 30, y + 28, 1, p.gris)
            end
            y = y + 44
        end
    end
    acabarLista(y)
end

-- vendedores: las ofertas que se ven ahora, para saber cual compra cada boton
local ofertasVista = {}
local ESTRELLA = { "..#..", ".###.", "#####", ".###.", "#.#.#" }

local function textoCosa(c)
    local ed = c.primera and "1ª ED" or "REIMPR."
    if c.que == "sobre" then return "SOBRE " .. ed end
    if c.que == "caja" then return "CAJA " .. ed end
    if c.que == "prod" then return productos[c.prod].nombre .. " " .. ed end
    return c.primera and "1ª EDICIÓN" or "NORMAL"
end

local function filaOferta(o, x, y, w)
    local i = #ofertasVista + 1
    ofertasVista[i] = o
    ui.caja(x, y, w, 30, p.grisosc)
    local g = o.vendedor
    fuentes.texto(g.nombre, x + 4, y + 3, 1, p.blanco)
    local ex = x + 8 + fuentes.ancho(g.nombre)
    lg.setColor(p.amarillo)
    for fy, fila in ipairs(ESTRELLA) do
        for fx0 = 1, 5 do
            if fila:sub(fx0, fx0) == "#" then lg.rectangle("fill", ex + fx0 - 1, y + 2 + fy - 1, 1, 1) end
        end
    end
    fuentes.texto((string.format("%.1f", g.estrellas):gsub("%.", ",")), ex + 7, y + 3, 1, p.amarillo)
    fuentes.texto(textoCosa(o.cosa) .. "  X" .. o.quedan, x + 4, y + 12, 1, p.grisclaro)
    fuentes.texto(ui.numero(vendedores.ventas(g)) .. " VENTAS", x + 4, y + 21, 1, p.gris)
    local dif = o.precio / o.ref - 1
    local color = dif <= -0.05 and p.lima or (dif >= 0.08 and p.naranja or p.blanco)
    fuentes.texto(ui.dinero(o.precio), x, y + 3, 1, color, "right", w - 4)
    -- con cartas de centimos el porcentaje no dice nada
    if o.ref >= 20 then fuentes.texto(ui.porcentaje(dif), x, y + 21, 1, color, "right", w - 54) end
    ui.boton("m_of" .. i, "COMPRAR", x + w - 50, y + 13, 46, 13, p.verde, partida.dinero >= o.precio)
    return y + 32
end

-- titulo, las ofertas y una linea que explica el porcentaje
local function listaOfertas(lista, x, y, w, titulo, vacia)
    fuentes.texto(titulo, x, y, 1, p.grisclaro)
    y = y + 10
    if #lista == 0 then
        fuentes.texto(vacia, x, y, 1, p.gris)
        return y + 14
    end
    for _, o in ipairs(lista) do y = filaOferta(o, x, y, w) end
    fuentes.texto("%: FRENTE A LA TIENDA O AL MERCADO", x, y, 1, p.gris)
    return y + 14
end

-- lo que se puede mirar de un set; las de reimpresion solo si ya ha habido una
local SECCIONES = {
    { "s1", "SOBRES 1ª ED" }, { "c1", "SELLADO 1ª ED" },
    { "sr", "SOBRES REIMPR." }, { "cr", "SELLADO REIMPR." },
    { "cartas", "CARTAS DEL SET" },
}

local function seccionesDe(tipo)
    local reimpr = mercado.sellado(tipo, false) ~= nil
    local lista = {}
    for _, sec in ipairs(SECCIONES) do
        if reimpr or (sec[1] ~= "sr" and sec[1] ~= "cr") then table.insert(lista, sec) end
    end
    return lista
end

local function seccionSobres(tipo, primera, x, y, w)
    local precio = mercado.sellado(tipo, primera)
    local tengo = partida.sobres(tipo.id, primera)
    fuentes.texto("UN SOBRE VALE", x, y, 1, p.grisclaro)
    fuentes.texto("TIENES " .. tengo, x, y, 1, p.grisclaro, "right", w)
    fuentes.texto(precio and ui.dinero(precio) or "-", x, y + 9, 2, primera and p.amarillo or p.blanco)
    y = y + 24
    local sufijo = primera and "1" or "r"
    ui.boton("m_vender1" .. sufijo, "VENDER 1", x, y, 64, 13, p.naranja, tengo > 0 and precio ~= nil)
    ui.boton("m_venderT" .. sufijo, "VENDER TODOS", x + 68, y, w - 68, 13, p.naranja, tengo > 0 and precio ~= nil)
    y = y + 17
    fuentes.texto("LA APP SE QUEDA UN " .. math.floor(mercado.comision() * 100 + 0.5) .. "%", x, y, 1, p.gris)
    y = y + 10
    if primera then
        local tirada = ui.tirada(mercado.tirada(tipo.set))
        local _, l = fuentes.envolver(tirada, w)
        fuentes.texto(tirada, x, y, 1, p.grisclaro, "left", w)
        y = y + #l * fuentes.linea() + 2
    end
    return listaOfertas(vendedores.deSobre(tipo, primera), x, y + 4, w, "SE VENDEN HOY", "NADIE VENDE SOBRES HOY")
end

-- lo sellado del set: una fila por producto (caja, ETB, tin, blister)
local function seccionCajas(tipo, primera, x, y, w)
    local suf = primera and "1" or "r"
    fuentes.texto("VENDER UNO TE DA (CON COMISIÓN)", x, y, 1, p.gris)
    y = y + 11
    local ofertas = {}
    for _, prod in ipairs(mercado.productosDe(tipo)) do
        local tengo = partida.prodDe(prod.id, tipo.id, primera)
        local valor = mercado.trasComision(mercado.valorProd(prod, tipo, primera))
        ui.caja(x, y, w, 28, p.grisosc)
        fuentes.texto(prod.nombre, x + 4, y + 3, 1, p.blanco)
        fuentes.texto("TIENES " .. tengo, x + 4, y + 11, 1, p.grisclaro)
        fuentes.texto(ui.dinero(valor), x, y + 3, 1, primera and p.amarillo or p.blanco, "right", w - 54)
        -- su mercado: como ha ido la ultima semana y la linea del ultimo mes
        local cambio = mercado.cambioProd(prod, tipo, primera, 7)
        if cambio then
            local pc = math.floor(cambio * 100 + (cambio >= 0 and 0.5 or -0.5))
            local txt = (pc > 0 and "+" or "") .. pc .. "% 7D"
            fuentes.texto(txt, x, y + 11, 1, pc > 0 and p.lima or (pc < 0 and p.rojo or p.grisclaro), "right", w - 54)
        end
        local _, h1, hr = mercado.historialProd(prod, tipo)
        local h = primera and h1 or hr
        if h and #h >= 2 then
            local desde = math.max(1, #h - 29)
            local mn, mx = math.huge, 0
            for i = desde, #h do if h[i] > 0 then mn, mx = math.min(mn, h[i]), math.max(mx, h[i]) end end
            if mx > 0 then
                local lw, ly, lh = w - 58, y + 19, 6
                local pts = {}
                for i = desde, #h do
                    if h[i] > 0 then
                        table.insert(pts, x + 4 + (i - desde) / math.max(1, #h - desde) * lw)
                        table.insert(pts, ly + lh - (mx > mn and (h[i] - mn) / (mx - mn) or 0.5) * lh + 0.5)
                    end
                end
                if #pts >= 4 then
                    lg.setColor(primera and p.amarillo or p.blanco)
                    lg.setLineWidth(1)
                    lg.line(pts)
                end
            end
        end
        ui.boton("m_vp_" .. prod.id .. "_" .. suf, "VENDER", x + w - 50, y + 8, 46, 12, p.morado, tengo > 0)
        y = y + 30
        for _, o in ipairs(vendedores.deProd(prod, tipo, primera)) do table.insert(ofertas, o) end
    end
    return listaOfertas(ofertas, x, y + 4, w, "SE VENDEN HOY", "NADIE VENDE NADA SELLADO HOY")
end

local function seccionCartas(s, x, y, w)
    local lista = {}
    for _, def in ipairs(mercado.cartasDe(s.id)) do table.insert(lista, def) end
    table.sort(lista, function(a, b)
        local ba, bb = partida.buscada(a.id), partida.buscada(b.id)
        if ba ~= bb then return ba end
        local va, vb = mercado.valorExacto(a.id), mercado.valorExacto(b.id)
        if va ~= vb then return va > vb end
        return a.id < b.id
    end)
    for _, def in ipairs(lista) do
        filaCarta(def.id, x - 2, y, w + 4, "m_carta_" .. def.id .. "_0", false, partida.copias(def.id) == 0)
        y = y + 19
    end
    return y
end

local function appSet()
    ofertasVista = {}
    local tipo = sobres[setVista]
    local s = sets[tipo.set]
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    fuentes.texto(s.nombre:upper(), x, y, 2, p.blanco)
    local fase, color = nombreFase(s.id)
    chip(fase, x + w - fuentes.ancho(fase) - 6, y + 1, color)
    y = y + 16

    if mercado.enTienda(tipo) then
        fuentes.texto("EN TIENDA " .. ui.dinero(tipo.precio) .. "  QUEDAN " .. mercado.stock(tipo), x, y, 1, p.verde)
    else
        fuentes.texto("NO HAY EN TIENDAS: SOLO REVENTA", x, y, 1, p.grisclaro)
    end
    y = y + 11
    fuentes.texto("PRECIO SELLADO", x, y + 3, 1, p.grisclaro)
    botonesRango(x + w - 76, y)
    y = y + 13
    local h0, h1, hr = mercado.historialSellado(tipo)
    local series = { { datos = h1, color = p.amarillo, nombre = "1ª ED" } }
    if mercado.sellado(tipo, false) then table.insert(series, { datos = hr, color = p.blanco, nombre = "REIMPR." }) end
    grafica.dibujar({ x = x, y = y, w = w, h = 44, series = series, rango = rango, dia0 = h0, formato = ui.dinero, id = "sellado" })
    y = y + 50

    -- que mirar: sobres o cajas de cada edicion, o las cartas
    local lista = seccionesDe(tipo)
    local hay = false
    for _, sec in ipairs(lista) do hay = hay or sec[1] == seccionSet end
    if not hay then seccionSet = "s1" end
    local bw = math.floor((w - 4) / 2)
    for i, sec in ipairs(lista) do
        local ancho = (i == #lista and i % 2 == 1) and w or bw
        local bx = x + ((i - 1) % 2) * (bw + 4)
        ui.boton("m_sec_" .. sec[1], sec[2], bx, y, ancho, 13, seccionSet == sec[1] and p.azul or p.grisosc)
        if i % 2 == 0 or i == #lista then y = y + 16 end
    end
    y = y + 4
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x, y - 3, w, 1)

    if seccionSet == "cartas" then
        y = seccionCartas(s, x, y, w)
    elseif seccionSet:sub(1, 1) == "s" then
        y = seccionSobres(tipo, seccionSet == "s1", x, y, w)
    else
        y = seccionCajas(tipo, seccionSet == "c1", x, y, w)
    end
    acabarLista(y)
end

-- ficha de una carta

local function appFicha()
    local def = mercado.carta(fichaId)
    local r = rarezas.de(def)
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    local normales = mercado.hayNormales(def.set)
    -- antes de la primera reimpresion todas las copias son de 1ª edicion
    local primera = not normales or fichaPrimera

    fuentes.texto(rarezas.nombre(def), x, y, 2, r.color)
    local datos = r.nombre:upper() .. "  " .. sets[def.set].codigo .. " #" .. def.num .. "/" .. #mercado.baseDe(def.set)
    fuentes.texto(datos, x, y + 14, 1, p.grisclaro)
    -- la estrella: marcarla como buscada
    local buscada = partida.buscada(def.id)
    local enc = ui.encima == "m_buscar"
    ui.caja(x + w - 15, y, 15, 13, buscada and p.naranja or (enc and p.gris or p.grisosc))
    ui.estrella(x + w - 11, y + 3, buscada and p.amarillo or p.grisclaro)
    ui.zona("m_buscar", x + w - 15, y, 15, 13)
    if enc then
        ui.tooltip(buscada and "La buscas" or "Buscar esta carta", p.amarillo,
            { { buscada and "Toca para dejar de buscarla" or "Te aviso si sale o si alguien la vende" } })
    end
    if def.chase then chip("CHASE", x + w - 52, y + 1, p.naranja) end
    y = y + 26

    local cambio = mercado.cambio(def.id, 7, primera)
    fuentes.texto(ui.dinero(mercado.valor(def.id, primera)), x, y, 2, p.amarillo)
    fuentes.texto(ui.porcentaje(cambio) .. " EN 7 DÍAS", x, y + 2, 1, ui.colorCambio(cambio), "right", w)
    y = y + 16
    if normales then
        ui.boton("m_ed0", "NORMAL", x, y, 40, 11, not primera and p.azul or p.grisosc)
        ui.boton("m_ed1", "1ª ED", x + 44, y, 40, 11, primera and p.amarillo or p.grisosc)
    else
        fuentes.texto("TODAS DE 1ª ED", x, y + 3, 1, p.gris)
    end
    botonesRango(x + w - 76, y)
    y = y + 15

    -- la 1ª edicion existe desde el primer dia; las normales, desde la primera reimpresion
    local h0, h1, v = mercado.historial(def.id, true)
    local _, hn = mercado.historial(def.id, false)
    local h = primera and h1 or hn
    local series = { { datos = h1, color = p.amarillo, nombre = normales and "1ª ED" or "" } }
    if normales then
        local sn = { datos = hn, color = p.blanco, nombre = "NORMAL" }
        series = primera and { series[1], sn } or { sn, series[1] }
    end
    grafica.dibujar({ x = x, y = y, w = w, h = 78, series = series, volumen = v, rango = rango, dia0 = h0,
        marcas = mercado.diasNoticia(def.id), formato = ui.dinero, id = "ficha" })
    y = y + 82
    fuentes.texto("BARRAS: VENTAS DE CADA DÍA", x, y, 1, p.gris)
    fuentes.texto("LÍNEA AMARILLA: NOTICIA", x, y + 8, 1, p.gris)
    y = y + 20

    local i0 = math.max(1, #h - 29)
    local max, min = 0, math.huge
    for i = i0, #h do
        local valor = series[1].datos[i]
        if valor > 0 then
            max = math.max(max, valor)
            min = math.min(min, valor)
        end
    end
    if min == math.huge then min = 0 end
    fuentes.texto("MÁX 30D " .. ui.dinero(max), x, y, 1, p.grisclaro)
    fuentes.texto("MÍN 30D " .. ui.dinero(min), x, y, 1, p.grisclaro, "right", w)
    y = y + 12

    local n = partida.copias(def.id)
    local texto = "NO LA TIENES"
    if n > 0 then
        texto = "TIENES " .. n
        local p1 = partida.deEdicion(def.id, true)
        if normales and p1 > 0 then texto = texto .. " (" .. p1 .. " DE 1ª ED)" end
    end
    fuentes.texto(texto, x, y, 1, n > 0 and p.blanco or p.gris)
    y = y + 12

    local sigue = partida.seguidas[def.id]
    ui.boton("m_seguir", sigue and "SIGUIENDO" or "SEGUIR", x, y, math.floor((w - 8) / 3), 13, sigue and p.verde or p.grisosc)
    local libres = partida.libres(def.id, primera)
    local lleno = #partida.anuncios >= partida.maxAnuncios()
    local bw = math.floor((w - 8) / 3)
    ui.boton("m_publicar", lleno and "LLENO" or "PUBLICAR", x + bw + 4, y, bw, 13, p.celeste, libres > 0 and not lleno)
    ui.boton("m_armario", "ARMARIO", x + 2 * bw + 8, y, w - 2 * bw - 8, 13, p.azul, n > 0)
    y = y + 20
    ofertasVista = {}
    y = listaOfertas(vendedores.deCarta(def.id, primera), x, y, w,
        "LA VENDEN HOY (" .. (primera and "1ª ED" or "NORMAL") .. ")", "NADIE LA VENDE HOY")
    acabarLista(y)
end

-- ventas

local function appVentas()
    local x, w = CONT.x + 4, CONT.w - 8
    local y = empezarLista() + 4
    local max = partida.maxAnuncios()
    fuentes.texto("MIS ANUNCIOS " .. #partida.anuncios .. "/" .. max, x + 2, y, 1, p.grisclaro)
    fuentes.texto("COMISIÓN " .. math.floor(mercado.comision() * 100 + 0.5) .. "%", x, y, 1, p.gris, "right", w - 2)
    y = y + 11

    if #partida.anuncios == 0 then
        fuentes.texto("NO TIENES NADA PUBLICADO", x, y + 40, 1, p.grisclaro, "center", w)
        fuentes.texto("ELIGE UNA CARTA EN EL ARMARIO", x, y + 54, 1, p.gris, "center", w)
        fuentes.texto("O EN SU FICHA Y PULSA PUBLICAR", x, y + 62, 1, p.gris, "center", w)
        ui.boton("m_ir_armario", "IR AL ARMARIO", x + 30, y + 80, w - 60, 14, p.azul)
        acabarLista(y + 100)
        return
    end

    for i, a in ipairs(partida.anuncios) do
        local def = partida.carta(a.id)
        local r = rarezas.de(def)
        local id = "anuncio" .. i
        local alto = 36
        local sel = elegido == i
        lg.setColor(sel and p.azulosc or p.grisosc)
        lg.rectangle("fill", x, y, w, alto - 2)
        if ui.encima == id and not sel then
            lg.setColor(1, 1, 1, 0.06)
            lg.rectangle("fill", x, y, w, alto - 2)
        end
        carta.gema(def.rareza, x + 8, y + 9)
        fuentes.texto(rarezas.nombre(def) .. (a.primera and "  1ª ED" or ""), x + 16, y + 4, 1, r.color)
        fuentes.texto("VALOR " .. ui.dinero(mercado.valor(a.id, a.primera)), x + 16, y + 13, 1, p.grisclaro)
        if #a.ofertas == 0 then
            fuentes.texto("ESPERANDO OFERTAS...", x + 16, y + 22, 1, p.gris)
        else
            local o = a.ofertas[1]
            local texto = #a.ofertas == 1 and "1 OFERTA" or (#a.ofertas .. " OFERTAS")
            fuentes.texto(texto, x + 16, y + 22, 1, p.lima)
            fuentes.texto(ui.dinero(o.precio), x, y + 4, 2, p.amarillo, "right", w - 4)
        end
        ui.zona(id, x, y, w, alto - 2)
        y = y + alto
    end
    fuentes.texto("PULSA UN ANUNCIO PARA VER SUS OFERTAS", x, y + 2, 1, p.gris, "center", w)
    acabarLista(y + 14)
end

-- mejoras (datos/mejoras.lua): suerte, venta y directo

local GRUPOS = {
    { "suerte", "SUERTE", "PARA TODOS LOS SOBRES QUE ABRAS DESDE YA" },
    { "venta", "VENTA", "PARA LO QUE VENDES POR EL MÓVIL" },
    { "directo", "DIRECTO", "PARA TUS DIRECTOS EN LA MESA" },
    { "tienda", "TIENDA", "LO QUE COMPRAS Y CÓMO TE LLEGA" },
    { "mesa", "MESA", "PARA CUANDO ABRES SOBRES" },
}

local function decimal(v)
    return (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ","))
end

local function efectoMejora(m, v)
    if m.formato == "veces" then return "X" .. decimal(v) end
    if m.formato == "comision" then return decimal((datosMercado.comision - v) * 100) .. "%" end
    if m.formato == "huecos" then return tostring(datosMercado.anuncios.maximo + v) end
    -- curva: probabilidad de que una oferta sea de un 20% o mas sobre el valor
    if m.formato == "curva" then return math.floor((1 - 0.5 ^ (1 / v)) * 100 + 0.5) .. "%" end
    if m.formato == "rebaja" then return (v > 0 and "-" or "") .. decimal(v * 100) .. "%" end
    if m.formato == "stock" then return "+" .. v .. "/DÍA" end
    if m.formato == "nombres" then return m.nombres[v] end
    return math.floor(v * 100 + 0.5) .. "%"
end

local function appMejoras()
    local x, w = CONT.x + 4, CONT.w - 8
    local y = empezarLista() + 4
    local tw = math.floor((w + 2) / #GRUPOS)
    local subtitulo
    for i, g in ipairs(GRUPOS) do
        ui.boton("m_mtab_" .. g[1], g[2], x + (i - 1) * tw, y, tw - 2, 13, pestanaMejoras == g[1] and p.violeta or p.grisosc)
        if pestanaMejoras == g[1] then subtitulo = g[3] end
    end
    y = y + 18
    fuentes.texto(subtitulo, x, y, 1, p.grisclaro, "center", w)
    y = y + 12
    for _, m in ipairs(datosMejoras) do
        if m.grupo == pestanaMejoras then
            local n = partida.nivelMejora(m.id)
            local _, lineas = fuentes.envolver(m.texto, w - 12)
            local alto = 40 + #lineas * fuentes.linea()
            lg.setColor(p.grisosc)
            lg.rectangle("fill", x, y, w, alto - 2)
            fuentes.texto(m.nombre, x + 5, y + 4, 1, p.blanco)
            fuentes.parrafo(m.texto, x + 5, y + 13, p.grisclaro, w - 12)
            local py = y + 15 + #lineas * fuentes.linea()
            -- un cuadradito por nivel (mas estrechos si hay muchos)
            local paso = math.min(10, math.floor((w - 72) / #m.valores))
            for k = 1, #m.valores do
                lg.setColor(k <= n and p.lima or p.negro)
                lg.rectangle("fill", x + 5 + (k - 1) * paso, py, paso - 2, 5)
            end
            local cad = "AHORA " .. efectoMejora(m, partida.efecto(m.id))
            if m.valores[n + 1] then cad = cad .. " > " .. efectoMejora(m, m.valores[n + 1]) end
            fuentes.texto(cad, x + 5, py + 9, 1, p.cian)
            local coste = partida.costeMejora(m)
            if coste then
                ui.boton("m_mej_" .. m.id, ui.dinero(coste), x + w - 62, py + 2, 58, 14, p.verde, partida.dinero >= coste)
            else
                fuentes.texto("AL MÁXIMO", x + w - 62, py + 6, 1, p.amarillo, "center", 58)
            end
            y = y + alto + 2
        end
    end
    acabarLista(y + 4)
end

-- encargos: gente que te paga por abrir sobres concretos

-- lo que pide cada clase de encargo, y su icono
local function queEncargo(e)
    if e.clase == "enfundar" then
        return "ENFUNDA " .. e.n .. (e.n == 1 and " CARTA" or " CARTAS"), p.grisclaro, p.cian
    elseif e.clase == "top" then
        return "PON TOP LOADER A " .. e.n .. (e.n == 1 and " CARTA" or " CARTAS"), p.grisclaro, p.celeste
    elseif e.clase == "rareza" then
        local r = rarezas[e.rareza]
        local nombre = r.nombre:upper() .. (e.n == 1 and "" or (r.nombre:sub(-1) == "n" and "ES" or "S"))
        return "SACA " .. e.n .. " " .. nombre .. " DE TUS SOBRES", r.color, r.color
    end
    local tipo = sobres[e.tipo]
    return "ABRE " .. e.n .. (e.n == 1 and " SOBRE " or " SOBRES ") .. sets[tipo.set].codigo .. (e.primera and " DE 1ª ED" or ""),
        e.primera and p.amarillo or p.grisclaro
end

local function filaEncargo(e, x, y, w, oferta, i)
    local alto = oferta and 44 or 34
    lg.setColor(oferta and p.azulosc or p.grisosc)
    lg.rectangle("fill", x, y, w, alto - 2)
    local que, color, marca = queEncargo(e)
    if marca then
        lg.setColor(p.negro)
        lg.rectangle("fill", x + 4, y + 4, 8, 11)
        lg.setColor(marca)
        lg.rectangle("fill", x + 5, y + 5, 6, 9)
    else
        local tipo = sobres[e.tipo]
        lg.setColor(tipo.colores.base)
        lg.rectangle("fill", x + 4, y + 4, 8, 11)
        lg.setColor(tipo.colores.rayas)
        lg.rectangle("fill", x + 4, y + 8, 8, 3)
    end
    fuentes.texto(e.nombre:upper(), x + 16, y + 4, 1, p.blanco)
    fuentes.texto("+" .. ui.dinero(e.pago), x, y + 4, 1, p.lima, "right", w - 4)
    fuentes.texto(que, x + 16, y + 13, 1, color)
    if oferta then
        fuentes.texto("PLAZO " .. e.dias .. " DÍAS", x + 16, y + 22, 1, p.gris)
        ui.boton("m_enc_si" .. i, "ACEPTAR", x + w - 96, y + 26, 46, 12, p.verde, #partida.encargos < 3)
        ui.boton("m_enc_no" .. i, "NO", x + w - 46, y + 26, 42, 12, p.gris)
    else
        fuentes.texto("HECHOS " .. e.hechos .. "/" .. e.n .. "   QUEDAN " .. e.dias .. (e.dias == 1 and " DÍA" or " DÍAS"),
            x + 16, y + 22, 1, e.dias <= 1 and p.naranja or p.lima)
    end
    return y + alto
end

local function appEncargos()
    local x, w = CONT.x + 4, CONT.w - 8
    local y = empezarLista() + 4
    fuentes.texto("EN MARCHA " .. #partida.encargos .. "/3", x + 2, y, 1, p.grisclaro)
    y = y + 10
    if #partida.encargos == 0 then
        fuentes.texto("NINGUNO: ACEPTA UNO DE ABAJO", x, y + 4, 1, p.gris, "center", w)
        y = y + 16
    end
    for i, e in ipairs(partida.encargos) do y = filaEncargo(e, x, y, w, false, i) end
    y = y + 6
    fuentes.texto("TE OFRECEN", x + 2, y, 1, p.grisclaro)
    y = y + 10
    if #partida.ofertasEncargo == 0 then
        fuentes.texto("NADIE POR AHORA", x, y + 10, 1, p.gris, "center", w)
        fuentes.texto("CADA DÍA PUEDE LLEGAR UNO NUEVO", x, y + 20, 1, p.gris, "center", w)
        y = y + 34
    end
    for i, e in ipairs(partida.ofertasEncargo) do y = filaEncargo(e, x, y, w, true, i) end
    fuentes.texto("TE PAGAN Y TE QUEDAS LAS CARTAS", x, y + 4, 1, p.gris, "center", w)
    acabarLista(y + 16)
end

-- noticias

local function appNoticias()
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    local lista = mercado.estado.noticias
    if #lista == 0 then
        fuentes.texto("SIN NOTICIAS", x, y + 60, 1, p.grisclaro, "center", w)
        fuentes.texto("PASA DÍAS PARA QUE PASEN COSAS", x, y + 70, 1, p.gris, "center", w)
    end
    for _, n in ipairs(lista) do
        local _, lineas = fuentes.envolver(n.texto, w - 12)
        local lineasExp = {}
        if n.explica then _, lineasExp = fuentes.envolver(n.explica, w - 16) end
        local alto = #lineas * fuentes.linea() + 15 + (#lineasExp > 0 and (#lineasExp * fuentes.linea() + 8) or 0)
        lg.setColor(p.grisosc)
        lg.rectangle("fill", x - 2, y - 2, w + 4, alto)
        lg.setColor(colorTono(n))
        lg.rectangle("fill", x - 2, y - 2, 2, alto)
        fuentes.texto("DÍA " .. n.dia, x + 3, y + 1, 1, p.gris)
        if n.carta then
            fuentes.texto("VER CARTA >", x, y + 1, 1, ui.encima == "m_not_" .. n.carta and p.amarillo or p.celeste, "right", w - 2)
            ui.zona("m_not_" .. n.carta, x + w - 50, y - 2, 52, 10)
        end
        fuentes.texto(n.texto, x + 3, y + 10, 1, p.blanco, "left", w - 12)
        if #lineasExp > 0 then
            local ey = y + 12 + #lineas * fuentes.linea()
            lg.setColor(0, 0, 0, 0.3)
            lg.rectangle("fill", x + 3, ey, w - 6, #lineasExp * fuentes.linea() + 4)
            fuentes.texto(n.explica, x + 6, ey + 3, 1, p.amarillo, "left", w - 16)
        end
        y = y + alto + 4
    end
    acabarLista(y)
end

-- calendario

local COLORES_FASE = { impresion = p.verde, reimpresion = p.celeste, agotado = p.gris, rumor = p.gris, anunciado = p.amarillo }

-- lo que se sabe de un set un dia futuro: la fase (o nil) y si es seguro
local function faseConocida(setId, d, hoy)
    if d <= hoy then
        local f = calendario.fase(setId, d)
        if f == "futuro" then return nil end
        return f, true
    end
    local f, i = calendario.fase(setId, hoy)
    if f == "anunciado" then
        if d < hoy + i.faltan then return "anunciado", true end
        return "impresion", false
    elseif f == "impresion" or f == "reimpresion" then
        if i.quedan < datosCalendario.ultimos then
            if d <= hoy + i.quedan then return f, true end
            return "agotado", d <= hoy + i.quedan + 3
        end
        return f, false
    elseif f == "agotado" or f == "rumor" then
        return "agotado", false
    end
end

local function appCalendario()
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    local hoy = mercado.dia()
    local dias = 30
    local d0 = math.max(1, hoy - 6)
    local col = math.floor((w - 22) / dias)
    local gx = x + 20

    fuentes.texto("LOS PRÓXIMOS DÍAS", x, y, 1, p.grisclaro)
    y = y + 11
    for d = d0, d0 + dias - 1 do
        if d % 5 == 0 then fuentes.texto(tostring(d), gx + (d - d0) * col - 2, y, 1, d == hoy and p.blanco or p.gris) end
    end
    y = y + 9
    local filas = 0
    for _, s in ipairs(sets.lista) do
        if calendario.conocido(s.id, hoy) then
            filas = filas + 1
            fuentes.texto(s.codigo, x, y + 3, 1, p.blanco)
            for d = d0, d0 + dias - 1 do
                local f, seguro = faseConocida(s.id, d, hoy)
                if f then
                    local c = COLORES_FASE[f]
                    local bx = gx + (d - d0) * col
                    if seguro then
                        lg.setColor(c)
                        lg.rectangle("fill", bx, y, col, 10)
                    else
                        lg.setColor(c[1], c[2], c[3], 0.45)
                        for yy = 0, 9, 2 do lg.rectangle("fill", bx + (yy / 2) % 2, y + yy, col - 1, 1) end
                    end
                end
            end
            local fase = mercado.fase(s.id)
            if fase == "rumor" then fuentes.texto("RUMOR", gx + (hoy - d0 + 1) * col + 2, y + 3, 1, p.amarillo) end
            y = y + 13
        end
    end
    -- la funda de temporada del MIX: hasta cuando esta
    local tem = partida.fundaTemporada()
    if tem then
        filas = filas + 1
        fuentes.texto("MIX", x, y + 3, 1, p.morado)
        lg.setColor(datosFundas[tem].color)
        for d = hoy, math.min(d0 + dias - 1, partida.temporada.hasta) do lg.rectangle("fill", gx + (d - d0) * col, y + 2, col, 6) end
        y = y + 13
    end
    lg.setColor(p.blanco)
    lg.rectangle("fill", gx + (hoy - d0) * col + math.floor(col / 2), y - filas * 13 - 3, 1, filas * 13 + 1)
    y = y + 4

    local leyenda = { { "EN TIENDA", p.verde }, { "REIMPRESIÓN", p.celeste }, { "AGOTADO", p.gris }, { "ANUNCIADO", p.amarillo } }
    local lx = x
    for _, l in ipairs(leyenda) do
        -- si no cabe en la linea, a la siguiente
        if lx + 8 + fuentes.ancho(l[1]) > x + w then
            lx = x
            y = y + 9
        end
        lg.setColor(l[2])
        lg.rectangle("fill", lx, y + 1, 5, 5)
        fuentes.texto(l[1], lx + 8, y, 1, p.grisclaro)
        lx = lx + fuentes.ancho(l[1]) + 14
    end
    y = y + 10
    local rayas = "A RAYAS: AÚN NO SE SABE CUÁNDO CAMBIA"
    local _, lr = fuentes.envolver(rayas, w)
    fuentes.texto(rayas, x, y, 1, p.gris, "left", w)
    y = y + #lr * fuentes.linea() + 6

    for _, s in ipairs(sets.lista) do
        if calendario.conocido(s.id, hoy) then
            local fase, i = calendario.fase(s.id, hoy)
            local texto
            if fase == "anunciado" then
                texto = "SALE EN " .. i.faltan .. (i.faltan == 1 and " DÍA" or " DÍAS")
            elseif fase == "impresion" or fase == "reimpresion" then
                texto = (fase == "impresion" and "1ª ED EN TIENDA" or "REIMPR. EN TIENDA")
                if i.quedan < datosCalendario.ultimos then texto = texto .. ": ÚLTIMOS" end
            else
                texto = "AGOTADO DESDE DÍA " .. (hoy - i.e + 1)
                if fase == "rumor" then texto = texto .. " (RUMOR)" end
            end
            fuentes.texto(s.nombre:upper(), x, y, 1, p.blanco)
            fuentes.texto(texto, x + 44, y, 1, p.grisclaro)
            y = y + 10
        end
    end
    if tem then
        fuentes.texto("FUNDA DEL MIX", x, y, 1, p.morado)
        fuentes.texto(datosFundas[tem].nombre .. " HASTA EL DÍA " .. partida.temporada.hasta, x + 56, y, 1, p.grisclaro)
        y = y + 10
    end
    y = y + 6
    local ayuda = "CADA " .. datosCalendario.cada .. " DÍAS MÁS O MENOS SALE UN SET NUEVO. CUANDO UNO SE AGOTA, " ..
        "TARDE O TEMPRANO VUELVE COMO REIMPRESIÓN."
    fuentes.texto(ayuda, x, y, 1, p.gris, "left", w)
    local _, l = fuentes.envolver(ayuda, w)
    acabarLista(y + #l * fuentes.linea() + 4)
end

-- lados del escritorio

local function ladoIzquierdo()
    if app == "ficha" and fichaId then
        local def = mercado.carta(fichaId)
        local r = rarezas.de(def)
        local cx, cy = 98, 168
        local primera
        if mercado.hayNormales(def.set) then primera = fichaPrimera else primera = partida.deEdicion(def.id, true) > 0 end
        local h = ui.hoverCarta("fichaGrande", cx, cy, carta.ANCHO * 3, carta.ALTO * 3)
        if r.nivel >= 3 then fx.aura(cx, cy, r.color, 90, 0.18) end
        carta.dibujar(def, cx, cy, 3, 3, 0, true, h, partida.enfundadas(def.id) > 0, { primera = primera })
        ui.zona("fichaGrande", cx - 54, cy - 75, 108, 150)
        if r.nivel >= 5 then fx.chispas(cx, cy, 120, 160, r.color, r.nivel >= 6 and 14 or 6) end
        fuentes.texto("PASA EL RATÓN POR ENCIMA", 8, 258, 1, p.gris, "center", 180)
        return
    end
    ui.caja(14, 40, 168, 104)
    fuentes.texto("DÍA", 14, 50, 2, p.grisclaro, "center", 168)
    fuentes.texto(tostring(mercado.dia()), 14, 66, 4, p.blanco, "center", 168)
    ui.boton("pasarDia", "PASAR DÍA", 34, 102, 128, 22, p.verde)
    fuentes.texto("O PULSA D", 14, 130, 1, p.gris, "center", 168)

    local y = 158
    fuentes.texto("HOY EN LA TIENDA", 18, y, 1, p.blanco)
    y = y + 10
    local alguno = false
    for _, tipo in ipairs(sobres.lista) do
        local precio, primera = mercado.enTienda(tipo)
        if precio then
            alguno = true
            local texto = sets[tipo.set].codigo .. (primera and " 1ª ED" or " REIMPR.") .. "  QUEDAN " .. mercado.stock(tipo)
            fuentes.texto(texto, 22, y, 1, p.grisclaro)
            y = y + 9
        end
    end
    if not alguno then
        fuentes.texto("NADA", 22, y, 1, p.gris)
        y = y + 9
    end
    y = y + 8
    fuentes.texto("TUYO", 18, y, 1, p.blanco)
    y = y + 10
    fuentes.texto("SOBRES SIN ABRIR " .. partida.sobresSinAbrir(), 22, y, 1, p.grisclaro)
    fuentes.texto("CARTAS " .. partida.totalCartas(), 22, y + 9, 1, p.grisclaro)
end

local function ladoDerecho()
    local a = app == "ventas" and elegido and partida.anuncios[elegido]
    if not a then
        elegido = nil
        local lineas = {
            "CADA DÍA QUE PASA:",
            "- LLEGAN SOBRES A LA TIENDA",
            "- LLEGAN OFERTAS A TUS ANUNCIOS",
            "- LOS PRECIOS SE MUEVEN",
            "- PUEDEN SALIR NOTICIAS",
            "",
            "LOS SETS SALEN, SE AGOTAN",
            "Y A VECES SE REIMPRIMEN.",
            "MIRA EL CALENDARIO.",
            "",
            "VENDER MUCHO DE UNA CARTA",
            "HUNDE SU PRECIO UNOS DÍAS.",
        }
        for i, l in ipairs(lineas) do
            fuentes.texto(l, 456, 40 + i * 9, 1, i == 1 and p.blanco or p.grisclaro)
        end
        return
    end
    local def = partida.carta(a.id)
    local r = rarezas.de(def)
    local cx, cy = 545, 92
    -- la copia que se vende, con su funda y su top
    local c = partida.copia(a.id, a.u)
    local funda = c and c.f or (not c and partida.enfundadas(a.id) > 0)
    carta.dibujar(def, cx, cy, 2, 2, 0, true, ui.hoverCarta("verCarta", cx, cy, 72, 100), funda, { primera = a.primera, top = c and c.t })
    ui.zona("verCarta", cx - 36, cy - 50, 72, 100)
    fuentes.texto(rarezas.nombre(def), 450, 148, 2, p.blanco, "center", 190)
    fuentes.texto(r.nombre .. (a.primera and "  1ª EDICIÓN" or ""), 450, 162, 1, r.color, "center", 190)
    fuentes.texto("VALOR " .. ui.dinero(mercado.valor(a.id, a.primera)), 450, 172, 1, p.amarillo, "center", 190)

    local y = 186
    if #a.ofertas == 0 then
        fuentes.texto("AÚN NO HAY OFERTAS", 450, y + 10, 1, p.grisclaro, "center", 190)
        fuentes.texto("PASA EL DÍA Y ESPERA", 450, y + 18, 1, p.gris, "center", 190)
    end
    for j, o in ipairs(a.ofertas) do
        if j > 3 then break end
        local relacion = o.precio / mercado.valorExacto(a.id, a.primera) - 1
        ui.caja(450, y, 186, 46)
        fuentes.texto(o.nombre, 456, y + 5, 1, p.blanco)
        fuentes.texto(o.dias == 1 and "CADUCA HOY" or ("CADUCA EN " .. o.dias .. " DÍAS"), 456, y + 13, 1, p.gris)
        fuentes.texto(ui.dinero(o.precio), 450, y + 4, 2, p.amarillo, "right", 180)
        fuentes.texto(ui.porcentaje(relacion) .. " DEL VALOR", 450, y + 15, 1, ui.colorCambio(relacion), "right", 180)
        fuentes.texto("TE LLEGAN " .. ui.dinero(mercado.trasComision(o.precio)), 456, y + 22, 1, p.grisclaro)
        ui.boton("aceptar" .. j, "ACEPTAR", 456, y + 30, 56, 12, p.verde)
        ui.boton("mas" .. j, o.subida and "YA SUBIÓ" or "PEDIR +15%", 516, y + 30, 58, 12, p.naranja, not o.subida)
        ui.boton("rechazar" .. j, "NO", 578, y + 30, 52, 12, p.gris)
        y = y + 50
    end
    ui.boton("retirar", "QUITAR ANUNCIO", 478, 340, 130, 14, p.rojo)
end

-- envio de una carta vendida

local function dibujarEnvio()
    if not envio then return end
    local t = envio.t
    local def = envio.def
    local cx, cy = 320, 170

    lg.setColor(0, 0, 0, math.min(0.75, t * 3))
    lg.rectangle("fill", ui.izq, 0, ui.der - ui.izq, 360)

    local vuelo = math.max(0, t - 1.5)
    local x = cx + vuelo * vuelo * 2400
    local giro = vuelo * 2

    local sobreP = math.min(1, math.max(0, (t - 0.9) / 0.4))
    if sobreP < 1 then
        carta.dibujar(def, x, cy, 3, 3, giro, true, nil, t > 0.35, { primera = envio.primera })
        -- toploader: plastico rigido que baja sobre la carta
        local tl = math.min(1, math.max(0, (t - 0.45) / 0.3))
        if tl > 0 then
            local w, h = carta.ANCHO * 3 + 12, carta.ALTO * 3 + 16
            local y = cy - h / 2 - (1 - fx.salidaSuave(tl)) * 200
            lg.setColor(1, 1, 1, 0.12)
            lg.rectangle("fill", x - w / 2, y, w, h)
            lg.setColor(p.blanco[1], p.blanco[2], p.blanco[3], 0.7)
            lg.rectangle("line", x - w / 2 + 0.5, y + 0.5, w - 1, h - 1)
            lg.rectangle("line", x - w / 2 + 2.5, y + 2.5, w - 5, h - 5)
        end
    end
    if sobreP > 0 then
        local w, h = 150, 190
        local alto = h * fx.salidaSuave(sobreP)
        lg.setColor(p.negro)
        lg.rectangle("fill", x - w / 2 - 1, cy + h / 2 - alto - 1, w + 2, alto + 2)
        lg.setColor(0.78, 0.6, 0.38)
        lg.rectangle("fill", x - w / 2, cy + h / 2 - alto, w, alto)
        if sobreP >= 1 then
            lg.setColor(0.66, 0.48, 0.3)
            lg.polygon("fill", x - w / 2, cy - h / 2, x + w / 2, cy - h / 2, x, cy - h / 2 + 50)
            lg.setColor(1, 1, 1)
            ui.caja(x - 50, cy + 10, 100, 30, p.blanco)
            fuentes.texto("PARA:", x - 46, cy + 14, 1, p.gris)
            fuentes.texto(envio.nombre, x - 46, cy + 24, 1, p.negro)
            local sello = math.min(1, (t - 1.3) / 0.1)
            if sello > 0 then
                fuentes.texto("ENVIADO", x - 60, cy - 40, 3, { p.rojo[1], p.rojo[2], p.rojo[3], sello }, "center", 120)
            end
        end
    end
    fuentes.texto("CLICK PARA SALTAR", 0, 340, 1, p.gris, "center", 640)
end

local function terminarEnvio()
    if not envio then return end
    sonido.tocar("moneda")
    fx.texto(320, 120, "+" .. ui.dinero(envio.cobrado), p.amarillo)
    fx.explosion(320, 150, p.amarillo, 40, 140)
    envio = nil
end

-- notificaciones

local function dibujarAvisos()
    local y = PANT.y + BARRA + 2
    local dt = love.timer.getDelta()
    for i = #avisos, 1, -1 do
        avisos[i].t = avisos[i].t + dt
        if avisos[i].t > 4.5 then table.remove(avisos, i) end
    end
    lg.setScissor(PANT.x, PANT.y + BARRA + mano.dy, PANT.w, PANT.h - BARRA - INICIO)
    for i, a in ipairs(avisos) do
        if i > 3 then break end
        local _, lineas = fuentes.envolver(a.texto, PANT.w - 24)
        local alto = #lineas * fuentes.linea() + 8
        local bajada = math.min(1, a.t / 0.25)
        if a.t > 4 then bajada = 1 - (a.t - 4) / 0.5 end
        local ay = y - (1 - fx.salidaSuave(math.max(0, bajada))) * (alto + 14)
        lg.setColor(0, 0, 0, 0.4)
        lg.rectangle("fill", PANT.x + 6, ay + 2, PANT.w - 10, alto, 4, 4)
        lg.setColor(p.negro)
        lg.rectangle("fill", PANT.x + 4, ay, PANT.w - 8, alto, 4, 4)
        lg.setColor(a.color)
        lg.rectangle("fill", PANT.x + 8, ay + 4, 2, alto - 8)
        fuentes.texto(a.texto, PANT.x + 14, ay + 4, 1, p.blanco, "left", PANT.w - 24)
        y = y + alto + 3
    end
    lg.setScissor()
end

-- aviso pequeño arriba a la derecha cuando no tienes el movil en la mano
function movil.dibujarToast()
    local a = avisos[1]
    if not a then return end
    a.t = a.t + love.timer.getDelta()
    if a.t > 4.5 then
        table.remove(avisos, 1)
        return
    end
    local w = 230
    local _, lineas = fuentes.envolver(a.texto, w - 16)
    local alto = #lineas * fuentes.linea() + 8
    local entra = math.min(1, a.t / 0.25)
    if a.t > 4 then entra = 1 - (a.t - 4) / 0.5 end
    local x = ui.der - (w + 6) * fx.salidaSuave(math.max(0, entra))
    ui.caja(x, 26, w, alto, p.negro)
    lg.setColor(a.color)
    lg.rectangle("fill", x + 3, 29, 2, alto - 6)
    fuentes.texto(a.texto, x + 9, 30, 1, p.blanco, "left", w - 16)
end

-- sacar y guardar

function movil.sacar()
    mano.t, mano.entrando, mano.alAcabar = 0, true, nil
    sonido.tocar("giro", 1.3)
end

function movil.guardar(alAcabar)
    if not mano.entrando then return end
    mano.t, mano.entrando, mano.alAcabar = 0, false, alAcabar
    sonido.tocar("giro", 0.9)
end

local function animarMano(dt)
    mano.t = mano.t + dt
    if mano.entrando then
        local q = math.min(1, mano.t / SACAR)
        mano.y = (1 - fx.salidaRebote(q)) * 340
    else
        local q = math.min(1, mano.t / GUARDAR)
        mano.y = q * q * 340
        if q >= 1 and mano.alAcabar then
            local f = mano.alAcabar
            mano.alAcabar = nil
            mano.entrando = true
            mano.y = 0
            f()
        end
    end
end

function movil.update(dt)
    animarMano(dt)
    if abriendo then
        abriendo.t = abriendo.t + dt
        if abriendo.t > 0.2 then abriendo = nil end
    end
    if not envio then return end
    local antes = envio.t
    envio.t = envio.t + dt
    if antes < 0.35 and envio.t >= 0.35 then sonido.tocar("giro") end
    if antes < 0.75 and envio.t >= 0.75 then sonido.tocar("click") end
    if antes < 1.3 and envio.t >= 1.3 then
        sonido.tocar("latido")
        fx.sacudir(3)
    end
    if antes < 1.5 and envio.t >= 1.5 then sonido.tocar("rasgar", 1.6) end
    if envio.t > 1.9 then terminarEnvio() end
end

-- la app abierta ("inicio" en la pantalla de inicio)
function movil.appActual()
    return app
end

-- quieto: ni sacandolo, ni guardandolo, ni abriendo una app, ni enviando
function movil.quieto()
    return not (envio or abriendo or mano.alAcabar or (mano.entrando and mano.t < SACAR))
end

-- algun vendedor tiene hoy esta carta (de cualquier edicion)
function movil.laVenden(id)
    local def = mercado.carta(id)
    if #vendedores.deCarta(id, true) > 0 then return true end
    return mercado.hayNormales(def.set) and #vendedores.deCarta(id, false) > 0
end

function movil.ocupado()
    return envio ~= nil or mano.alAcabar ~= nil
end

local function appLogros()
    local x, w = CONT.x + 6, CONT.w - 12
    local y = empezarLista() + 4
    local n, total = logros.cuantos()
    fuentes.texto("CONSEGUIDOS " .. n .. " DE " .. total, x, y, 1, p.grisclaro)
    y = y + 12
    for _, l in ipairs(logros.lista) do
        local dia = logros.hecho(l.id)
        ui.caja(x, y, w, 20, dia and p.grisosc or p.negro)
        fuentes.texto(l.nombre, x + 4, y + 4, 1, dia and p.lima or p.gris)
        fuentes.texto(l.texto:upper(), x + 4, y + 12, 1, dia and p.grisclaro or p.gris)
        if dia then fuentes.texto("DÍA " .. dia, x, y + 4, 1, p.amarillo, "right", w - 4) end
        y = y + 22
    end
    acabarLista(y)
end

local DIBUJAR = {
    logros = appLogros,
    cartera = appCartera, mercado = appMercado, set = appSet, ficha = appFicha,
    ventas = appVentas, noticias = appNoticias, calendario = appCalendario, encargos = appEncargos, mejoras = appMejoras,
}

function movil.dibujar()
    ladoIzquierdo()
    ladoDerecho()
    mano.dy = math.floor(mano.y)
    lg.push()
    lg.translate(0, mano.dy)
    marco()
    lg.setColor(p.negro)
    lg.rectangle("fill", PANT.x, PANT.y, PANT.w, PANT.h)
    if app == "inicio" then
        appInicio()
    else
        -- al abrir una app crece desde su icono
        local recorte
        if abriendo then
            local q = fx.salidaSuave(math.min(1, abriendo.t / 0.2))
            recorte = {
                x = fx.lerp(abriendo.x, PANT.x, q), y = fx.lerp(abriendo.y, PANT.y, q),
                w = fx.lerp(abriendo.w, PANT.w, q), h = fx.lerp(abriendo.h, PANT.h, q),
            }
            ui.sinZonas = true
            lg.draw(fondo, PANT.x, PANT.y)
            lg.setColor(p.negro)
            lg.rectangle("fill", recorte.x, recorte.y, recorte.w, recorte.h, 6, 6)
        end
        if not recorte then
            cabecera(TITULOS[app] or "")
            DIBUJAR[app]()
        end
        ui.sinZonas = false
    end
    barraEstado()
    barraInicio()
    dibujarAvisos()
    esquinasPantalla()
    lg.pop()
    if envio then
        dibujarEnvio()
        -- mientras se empaqueta, todo el click va a saltarlo
        ui.zona("saltarEnvio", ui.izq, 0, ui.der - ui.izq, 360)
    end
end

-- acciones

local function aceptar(j)
    local a = partida.anuncios[elegido]
    local nombre = a.ofertas[j].nombre
    local primera = a.primera
    local def, precio, cobrado = partida.aceptar(elegido, j)
    elegido = nil
    envio = { def = def, precio = precio, cobrado = cobrado, nombre = nombre, primera = primera, t = 0 }
    partida.guardar()
end

local function pedirMas(j)
    local a = partida.anuncios[elegido]
    local nombre = a.ofertas[j].nombre
    if partida.pedirMas(elegido, j) then
        sonido.tocar("moneda")
        notificar(nombre .. " ACEPTA: AHORA " .. ui.dinero(a.ofertas[j].precio), p.lima)
    else
        sonido.tocar("latido")
        notificar(nombre .. " SE HA IDO", p.rojo)
    end
    table.sort(a.ofertas, function(x, y) return x.precio > y.precio end)
    partida.guardar()
end

local function cobro(total, texto)
    if total <= 0 then return end
    sonido.tocar("moneda")
    notificar(texto .. ": +" .. ui.dinero(total), p.lima)
    partida.guardar()
end

function movil.click(id)
    if id == "saltarEnvio" then
        terminarEnvio()
    elseif id == "pasarDia" then
        nav.pasarDia()
    elseif id == "m_ir_armario" then
        nav.ir("armario")
    elseif id == "m_inicio" then
        inicio()
    elseif id == "m_atras" then
        atras()
    elseif id:match("^m_app_") then
        local destino = id:sub(7)
        for i, a in ipairs(apps()) do
            if a.id == destino then
                local cx, cy = posIcono(i)
                ir(destino, { x = cx - 13, y = cy - 13, w = 26, h = 26 })
            end
        end
    elseif id:match("^m_mej_") then
        for _, m in ipairs(datosMejoras) do
            if id == "m_mej_" .. m.id then
                local coste = partida.comprarMejora(m)
                if coste then
                    sonido.tocar("moneda")
                    sonido.tocar("nueva")
                    fx.texto(ui.mx, ui.my - 12, "-" .. ui.dinero(coste), p.rojo)
                    fx.confeti(ui.mx, ui.my, 30, 120)
                    partida.guardar()
                end
            end
        end
    elseif id:match("^m_enc_si") then
        if partida.aceptarEncargo(tonumber(id:sub(9))) then
            sonido.tocar("moneda")
            partida.guardar()
        end
    elseif id:match("^m_enc_no") then
        partida.rechazarEncargo(tonumber(id:sub(9)))
        partida.guardar()
    elseif id:match("^m_rango") then
        rango = tonumber(id:sub(8))
    elseif id:match("^m_mtab_") then
        pestanaMejoras = id:sub(8)
        scroll.mejoras = 0
    elseif id:match("^m_sec_") then
        seccionSet = id:sub(7)
    elseif id:match("^m_tab_") then
        pestanaCartera = id:sub(7)
        scroll.cartera = 0
    elseif id:match("^m_carta_") then
        local cid, ed = id:match("^m_carta_(%d+)_(%d)")
        movil.abrirFicha(tonumber(cid), ed == "1")
    elseif id:match("^m_not_") then
        movil.abrirFicha(tonumber(id:sub(7)), false)
    elseif id:match("^m_set_") then
        setVista = id:sub(7)
        seccionSet = "s1"
        scroll.set = 0
        ir("set")
    elseif id == "m_ed0" or id == "m_ed1" then
        fichaPrimera = id == "m_ed1"
    elseif id == "m_buscar" then
        local antes = partida.buscada(fichaId)
        if partida.buscar(fichaId) == nil then
            notificar("YA BUSCAS " .. partida.MAX_BUSCADAS .. ": QUITA ALGUNA", p.naranja)
        else
            sonido.tocar(antes and "giro" or "nueva")
            partida.guardar()
        end
    elseif id == "m_seguir" then
        partida.seguir(fichaId)
        partida.guardar()
    elseif id == "m_publicar" then
        local primera = not mercado.hayNormales(mercado.carta(fichaId).set) or fichaPrimera
        if partida.publicar(fichaId, primera) then
            notificar("PUBLICADA EN VENTAS", p.celeste)
            partida.guardar()
        end
    elseif id == "m_armario" then
        nav.verCarta(fichaId)
    elseif id:match("^m_of%d") then
        local o = ofertasVista[tonumber(id:sub(5))]
        local pagado = o and vendedores.comprar(o)
        if pagado then
            sonido.tocar("moneda")
            local que = o.cosa.que == "carta" and rarezas.nombre(mercado.carta(o.cosa.id)):upper() or textoCosa(o.cosa)
            notificar(que .. " DE " .. o.vendedor.nombre .. ": -" .. ui.dinero(pagado), p.amarillo)
        end
    elseif id:match("^m_comprar") then
        local tipo = sobres[setVista]
        local pagado = partida.comprarReventa(tipo, id:sub(-1) == "1")
        if pagado then
            sonido.tocar("moneda")
            notificar("SOBRE COMPRADO: -" .. ui.dinero(pagado), p.amarillo)
            partida.guardar()
        end
    elseif id:match("^m_vp_") then
        local tipo = sobres[setVista]
        local pid, ed = id:match("^m_vp_(.+)_(%w)$")
        local prod = productos[pid]
        cobro(partida.venderProd(prod, tipo, ed == "1") or 0, prod.nombre .. " VENDIDA")
    elseif id:match("^m_vender") then
        local tipo = sobres[setVista]
        local primera = id:sub(-1) == "1"
        local todos = id:sub(9, 9) == "T"
        local n = todos and partida.sobres(tipo.id, primera) or 1
        cobro(partida.venderSobres(tipo, n, primera), n == 1 and "SOBRE VENDIDO" or (n .. " SOBRES VENDIDOS"))
    elseif id:match("^anuncio%d") then
        elegido = tonumber(id:sub(8))
    elseif id:match("^aceptar%d") then
        aceptar(tonumber(id:sub(8)))
    elseif id:match("^mas%d") then
        pedirMas(tonumber(id:sub(4)))
    elseif id:match("^rechazar%d") then
        partida.rechazar(elegido, tonumber(id:sub(9)))
        partida.guardar()
    elseif id == "retirar" then
        partida.retirar(elegido)
        elegido = nil
        partida.guardar()
    elseif id == "verCarta" then
        local a = partida.anuncios[elegido]
        movil.abrirFicha(a.id, a.primera)
    end
end

-- en el movil (pantalla tactil) no hay rueda: se arrastra el contenido.
-- Lo que se pulsa dentro de una lista se resuelve al soltar, si no se ha arrastrado
local toque

local function enLista(x, y)
    return app ~= "inicio" and not envio and x >= CONT.x and x < CONT.x + CONT.w and y >= CONT.y and y < CONT.y + CONT.h
end

function movil.presionar(id, x, y)
    if not enLista(x, y) then return false end
    toque = { id = id, y0 = y, s0 = scroll[app] or 0, movido = false }
    return true
end

function movil.arrastrar(_, y)
    if not toque then return end
    local dy = y - toque.y0
    if math.abs(dy) > 4 then toque.movido = true end
    if toque.movido then scroll[app] = math.max(0, toque.s0 - dy) end
end

function movil.soltar()
    local t = toque
    toque = nil
    if t and not t.movido and t.id then
        sonido.tocar("click")
        movil.click(t.id)
    end
end

function movil.rueda(dy)
    if app == "inicio" then return end
    if ui.mx < PANT.x or ui.mx > PANT.x + PANT.w or ui.my < PANT.y or ui.my > PANT.y + PANT.h then return end
    scroll[app] = math.max(0, (scroll[app] or 0) - dy * 18)
end

function movil.tecla(tecla)
    if tecla == "backspace" then atras() end
end

return movil
