local p = require "datos.paleta"
local mercado = require "src.mercado"
local fuentes = require "src.fuentes"
local carta = require "src.carta"
local sobre = require "src.sobre"
local caja = require "src.caja"
local encima = require "src.encima"
local logros = require "src.logros"
local sonido = require "src.sonido"
local fx = require "src.fx"
local ui = require "src.ui"
local nav = require "src.nav"
local partida = require "src.partida"
local dev = require "src.dev"
local tutorial = require "src.tutorial"
local apertura = require "src.apertura"
local tienda = require "src.tienda"
local armario = require "src.armario"
local movil = require "src.movil"
local menu = require "src.menu"
local intro = require "src.firma"
local escritorio = require "src.escritorio"
local mesa = require "src.mesa"
local directo = require "src.directo"
local transicion = require "src.transicion"

local lg = love.graphics

-- el juego se dibuja en 640x360; en pantallas mas alargadas (moviles de
-- 20:9) se ve mas mesa a los lados: VISTO es el ancho que se ve y OX lo que
-- sobra a cada lado. El lienzo va al triple para que el texto del movil
-- (x4/3) quede nitido
local ANCHO, ALTO = 640, 360
local VISTO, OX = ANCHO, 0
local DOBLE = 3
local pantalla
local escena = "intro"
local escenas = { tienda = tienda, mesa = mesa, armario = armario, movil = movil, menu = menu }
local dineroVisto = 0
-- margen de la camara o la muesca del movil, en pixeles del juego
local margenIzq, margenDer = 0, 0

-- escala para llenar la ventana sin deformar: puede no ser entera (pantallas
-- que no son 1080p, o Windows con el escalado al 125%)
local function escalaVentana()
    local w, h = lg.getDimensions()
    local e = math.min(w / VISTO, h / ALTO)
    return e, math.floor((w - VISTO * e) / 2 + 0.5), math.floor((h - ALTO * e) / 2 + 0.5)
end

-- ancho visible segun la forma de la pantalla (16:9 = 640, 20:9 = 800)
local function medirPantalla()
    local w, h = lg.getDimensions()
    local visto = math.floor(ALTO * w / h / 2) * 2
    visto = math.max(ANCHO, math.min(900, visto))
    if visto ~= VISTO or not pantalla then
        VISTO, OX = visto, (visto - ANCHO) / 2
        pantalla = lg.newCanvas(VISTO * DOBLE, ALTO * DOBLE)
        fuentes.lienzo = pantalla
        encima.escala = DOBLE
    end
    ui.izq, ui.der = -OX, ANCHO + OX
    -- la zona segura (camara en la pantalla, barras del sistema)
    margenIzq, margenDer = 0, 0
    local sx, _, sw = love.window.getSafeArea()
    local mw = love.window.getMode()
    if sx and mw and mw > 0 then
        local e = escalaVentana()
        local px = w / mw
        margenIzq = math.max(0, sx * px / e - (w / e - VISTO) / 2)
        margenDer = math.max(0, (mw - sx - sw) * px / e - (w / e - VISTO) / 2)
    end
end

-- de pixeles de la ventana a coordenadas del juego (0-640 es el centro)
local function aJuego(x, y)
    local e, ox, oy = escalaVentana()
    return (x - ox) / e - OX, (y - oy) / e
end

-- los recortes (listas con scroll) se piden en coordenadas del juego; en el
-- lienzo grande hay que pasarlos a sus pixeles
local recorteOriginal = lg.setScissor
lg.setScissor = function(x, y, w, h)
    if not x then return recorteOriginal() end
    if lg.getCanvas() == pantalla then
        return recorteOriginal((x + OX) * DOBLE, y * DOBLE, w * DOBLE, h * DOBLE)
    end
    return recorteOriginal(x, y, w, h)
end

-- para las pruebas: ancho visible y lo que sobra a cada lado
function nav.vista()
    return VISTO, OX
end

local function raton()
    return aJuego(love.mouse.getPosition())
end

-- se guarda aparte de la partida: es del ordenador, no de la partida
local ARCHIVO_PANTALLA = "pantalla.txt"

function nav.pantallaCompleta()
    return (love.window.getFullscreen())
end

function nav.alternarPantalla()
    local completa = not love.window.getFullscreen()
    love.window.setFullscreen(completa, "desktop")
    love.filesystem.write(ARCHIVO_PANTALLA, completa and "completa" or "ventana")
end

local function bloqueado()
    return transicion.activa() or (escena == "mesa" and apertura.bloqueada()) or (escena == "movil" and movil.ocupado())
end

function nav.ir(nombre)
    sonido.carga(0)
    -- el movil del directo es el mismo: si lo coges, se acaba el directo
    if nombre == "movil" then directo.terminar() end
    if nombre == "menu" then directo.terminar(true) end
    if escena == "movil" and nombre ~= "movil" then
        -- primero se guarda el movil y luego se cambia de pantalla
        movil.guardar(function() escena = nombre end)
        return
    end
    if nombre == "movil" and escena ~= "movil" then movil.sacar() end
    escena = nombre
end

function nav.empezar()
    dineroVisto = partida.dinero
    transicion.empezarDia()
    movil.reiniciar()
    armario.reiniciar()
    directo.reiniciar()
    mesa.reiniciar()
    nav.ir("mesa")
end

-- los sobres ya solo se abren en la mesa
function nav.abrir()
    nav.ir("mesa")
end

function nav.lote(n)
    if apertura.lote(n) then escena = "mesa" end
end

-- pasar el dia corta el directo: fundido a negro y se ve el dia nuevo
-- (directo: sin el fundido, para las pruebas y los bots)
function nav.pasarDia(directoYa)
    if transicion.activa() then return end
    directo.terminar()
    if directoYa then
        movil.pasarDia()
        return
    end
    transicion.pasarDia(movil.pasarDia)
end

function nav.verCarta(id)
    armario.seleccionar(id)
    nav.ir("armario")
end

function nav.ficha(id, primera)
    movil.abrirFicha(id, primera)
    nav.ir("movil")
end

function love.load()
    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("rough")
    -- en el movil el texto va mas grande (OLP_MOVIL=1 lo prueba en el PC)
    if love._os == "Android" or love._os == "iOS" or os.getenv("OLP_MOVIL") then fuentes.factor = 4 / 3 end
    medirPantalla()
    if love.filesystem.read(ARCHIVO_PANTALLA) == "completa" then
        love.window.setFullscreen(true, "desktop")
    end
    fuentes.preparar()
    carta.preparar()
    sobre.preparar()
    caja.preparar()
    sonido.preparar()
    escritorio.preparar()
    movil.preparar()
    mesa.preparar()
    partida.cargar()
    if partida.logrosSinAviso then logros.revisar(1, true) end
    menu.preparar()
    dineroVisto = partida.dinero
    intro.empezar(function() escena = "menu" end)
end

function love.resize()
    medirPantalla()
end

function love.update(dt)
    dt = math.min(dt, 1 / 20)
    transicion.update(dt)
    fx.update(dt)
    dineroVisto = fx.lerp(dineroVisto, partida.dinero, math.min(1, dt * 8))
    partida.update(dt)
    -- premios por completar sets: aviso, confeti y monedas
    local premio = table.remove(partida.premiosNuevos, 1)
    if premio then
        local texto = "PREMIO: " .. premio.texto .. " +" .. premio.sobres .. " SOBRES"
        if premio.dinero then texto = texto .. " Y " .. ui.dinero(premio.dinero) end
        movil.avisar(texto, p.amarillo)
        fx.confeti(320, 40, 60, 160)
        sonido.tocar("moneda")
        partida.guardar()
    end
    -- encargos del movil terminados o caducados
    local hecho = table.remove(partida.encargosHechos, 1)
    if hecho then
        logros.marcar("encargo")
        movil.avisar("ENCARGO DE " .. hecho.nombre:upper() .. " HECHO: +" .. ui.dinero(hecho.pago), p.lima)
        fx.monedas(320, 40, 30, 160, 200)
        sonido.tocar("moneda")
        partida.guardar()
    end
    local caducado = table.remove(partida.encargosCaducados, 1)
    if caducado then movil.avisar("SE ACABÓ EL PLAZO DEL ENCARGO DE " .. caducado.nombre:upper(), p.naranja) end
    -- logros nuevos
    if escena ~= "menu" and escena ~= "intro" then logros.revisar(dt) end
    local logro = logros.siguiente()
    if logro then
        movil.avisar("LOGRO: " .. logro.nombre .. " - " .. logro.texto:upper(), p.lima)
        fx.confeti(320, 40, 30, 120)
    end
    local dtJuego = dt * fx.escalaTiempo()
    if escena == "intro" then
        intro.update(dt)
    elseif escena == "mesa" then
        mesa.update(dtJuego)
    end
    directo.update(dt, escena == "mesa")
    -- con la pantalla en negro los avisos del movil esperan
    if not transicion.activa() then movil.update(dt) end
end

function love.mousepressed(x, y, boton)
    if escena == "intro" then
        intro.saltar()
        return
    end
    if boton ~= 1 then return end
    if transicion.activa() then
        transicion.saltar()
        return
    end
    local mx, my = aJuego(x, y)
    local id = ui.click(mx, my)
    if ui.clickModal(id) or ui.clickOverlay(id) then
        if id then sonido.tocar("click") end
        return
    end
    -- en las listas del movil el click se resuelve al soltar (se puede arrastrar)
    if escena == "movil" and movil.presionar(id, mx, my) then return end
    if id then sonido.tocar("click") end

    if id and id:match("^tut_") then
        tutorial.click(id)
    elseif id and id:match("^dev_") then
        dev.click(id)
    elseif id == "ir_dev" then
        dev.abierto = not dev.abierto
    elseif id == "ir_tienda" or id == "ir_mesa" or id == "ir_armario" or id == "ir_movil" then
        nav.ir(id:sub(4))
    elseif id and id:match("^set_") then
        armario.click(id)
    elseif escena == "mesa" then
        mesa.presionar(id, mx, my)
    elseif escena == "armario" then
        if not armario.coger(id, mx, my) and id then armario.click(id) end
    elseif id and escenas[escena] then
        escenas[escena].click(id)
    end
end

function love.mousereleased(x, y, boton)
    if boton ~= 1 then return end
    movil.soltar()
    armario.acabarBarrido()
    if escena == "mesa" then mesa.soltar(aJuego(x, y)) end
    if not ui.cogida then return end
    local mx, my = aJuego(x, y)
    armario.soltar(ui.soltar(), mx, my)
end

function love.mousemoved(x, y)
    local mx, my = aJuego(x, y)
    ui.moverRaton(mx, my)
    if escena == "armario" then armario.mover(mx, my) end
    if escena == "mesa" then mesa.mover(mx, my) end
    if escena == "movil" then movil.arrastrar(mx, my) end
end

function love.wheelmoved(_, y)
    if escena == "movil" then movil.rueda(y) end
end

function love.textinput(t)
    directo.texto(t)
end

local ORDEN = { "tienda", "mesa", "armario", "movil" }

function love.keypressed(tecla)
    -- escribiendo el nombre del canal las teclas son letras
    if directo.tecla(tecla) then return end
    if transicion.activa() then
        transicion.saltar()
        return
    end
    local alt = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
    if tecla == "f11" or (tecla == "return" and alt) then
        nav.alternarPantalla()
        return
    end
    if escena == "intro" and tecla ~= "escape" then
        intro.saltar()
        return
    end
    if ui.modal or ui.overlay then
        if tecla == "escape" then ui.modal, ui.overlay = nil, nil end
        return
    end
    if tecla == "f1" then
        dev.abierto = not dev.abierto
    elseif tecla == "escape" and escena == "armario" and armario.tecla("escape") then
        return
    elseif tecla == "escape" then
        if escena == "menu" then
            love.event.quit()
        elseif not bloqueado() then
            partida.guardarYa()
            nav.ir("menu")
        end
    elseif escena == "menu" then
        return
    elseif tecla == "d" and not bloqueado() then
        nav.pasarDia()
    elseif tecla == "space" then
        if escena == "mesa" then mesa.espacio() end
    elseif tecla == "tab" and not bloqueado() then
        for i, n in ipairs(ORDEN) do
            if n == escena then
                nav.ir(ORDEN[i % #ORDEN + 1])
                return
            end
        end
        nav.ir("armario")
    elseif escena == "armario" then
        armario.tecla(tecla)
    elseif escena == "movil" then
        movil.tecla(tecla)
    end
end

function love.quit()
    directo.terminar(true)
    if escena ~= "intro" and escena ~= "menu" then partida.guardarYa() end
end

local function dibujarBarra()
    local izq, der = -OX + margenIzq, ANCHO + OX - margenDer
    lg.setColor(p.negro)
    lg.rectangle("fill", -OX, 0, VISTO, 20)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", -OX, 20, VISTO, 1)

    -- botones pegados a la izquierda de la pantalla y el dinero a la derecha;
    -- en el movil un poco mas anchos para que se pulsen bien
    local x = izq + 6
    local extra = fuentes.factor > 1 and 8 or 0
    local function boton(id, texto, w, color)
        ui.boton(id, texto, x, 3, w + extra, 14, color)
        x = x + w + extra + 3
    end
    if not bloqueado() then
        boton("ir_tienda", "TIENDA", 38, escena == "tienda" and p.verde or p.gris)
        boton("ir_mesa", "MESA", 34, escena == "mesa" and p.verde or (directo.activo() and p.rojo or p.gris))
        boton("ir_armario", "ARMARIO", 42, escena == "armario" and p.verde or p.gris)
        local ofertas = partida.ofertasTotales()
        boton("ir_movil", ofertas > 0 and ("MÓVIL (" .. ofertas .. ")") or "MÓVIL", 50, escena == "movil" and p.verde or (ofertas > 0 and p.naranja or p.gris))
        if ui.encima == "ir_movil" and directo.activo() then
            ui.tooltip("Se acaba el directo", p.rojo, { { "El móvil es el que graba" } })
        end
    else
        x = x + 179 + extra * 4
    end
    boton("ir_dev", "DEV", 24, dev.abierto and p.naranja or p.grisosc)

    local dinero = ui.dinero(dineroVisto)
    local dx = der - 8 - fuentes.ancho(dinero, 2)
    fuentes.texto(dinero, dx, 4, 2, p.amarillo)
    local info = "DÍA " .. mercado.dia() .. "   SOBRES " .. partida.sobresGuardados()
    local ix = dx - 12 - fuentes.ancho(info)
    fuentes.texto(info, ix, 8, 1, p.grisclaro)
    if escena == "armario" then armario.pestanas(x + 4, ix - 6) end
    -- fuera de la mesa se ve que sigues en directo
    if escena ~= "mesa" and directo.activo() then
        local cad = "EN DIRECTO " .. directo.espectadores()
        directo.indicador(ix - 14 - fuentes.ancho(cad) - 7, 8)
    end
end

-- primero se amplia con pixeles duros al entero de arriba y luego se reduce
-- suavizado a la escala exacta: llena la pantalla y el pixel sigue nitido
local grande, factorGrande

-- conMesa: el escritorio de fondo por toda la ventana (si no, negro);
-- conBarra: la barra de arriba se alarga de lado a lado
local function presentar(conMesa, conBarra)
    lg.setCanvas()
    lg.origin()
    local e, ox, oy = escalaVentana()
    -- con pantallas de mucha resolucion (1080p o moviles) basta con ampliar
    -- con pixeles duros; si no, se pasa por el lienzo grande
    local r = e / DOBLE
    local directa = r >= 1.25 or math.abs(r - 1) < 0.01
    local k = directa and 1 or math.max(1, math.ceil(e / DOBLE - 0.001))
    local origen = pantalla
    if not directa then
        if not grande or factorGrande ~= k or grande:getWidth() ~= VISTO * DOBLE * k then
            grande = lg.newCanvas(VISTO * DOBLE * k, ALTO * DOBLE * k)
            grande:setFilter("linear", "linear")
            factorGrande = k
        end
        lg.setCanvas(grande)
        lg.clear(0, 0, 0, 0)
        lg.setBlendMode("alpha", "premultiplied")
        lg.draw(pantalla, 0, 0, 0, k, k)
        lg.setCanvas()
        origen = grande
    end

    lg.setBlendMode("alpha")
    lg.clear(p.negro[1], p.negro[2], p.negro[3])
    if conMesa then escritorio.dibujar(e, ox + OX * e, oy, fx.tinteMesa()) end
    if conBarra then
        local w = lg.getDimensions()
        lg.setColor(p.negro)
        lg.rectangle("fill", 0, 0, w, oy + 20 * e)
        lg.setColor(p.grisosc)
        lg.rectangle("fill", 0, oy + 20 * e, w, math.max(1, e))
        lg.setColor(1, 1, 1)
    end
    lg.setBlendMode("alpha", "premultiplied")
    lg.draw(origen, ox, oy, 0, e / DOBLE / k, e / DOBLE / k)
    lg.setBlendMode("alpha")
    -- lo que gira (la mano, la caja volando) va encima a la resolucion real
    encima.dibujar(e, ox, oy)
    transicion.dibujar(e, ox, oy, VISTO, OX)
end

function love.draw()
    ui.empezar(raton())

    lg.setCanvas(pantalla)
    lg.clear(0, 0, 0, 0)
    lg.origin()
    lg.scale(DOBLE)
    lg.translate(OX, 0)
    if escena == "intro" then
        intro.dibujar(ANCHO, ALTO)
        presentar(false, false)
        return
    end

    local dx, dy = fx.desplazamiento()
    lg.push()
    lg.translate(dx, dy)
    escenas[escena].dibujar()
    fx.dibujarParticulas()
    lg.pop()

    if escena ~= "menu" then
        dibujarBarra()
        if escena ~= "movil" then movil.dibujarToast() end
        tutorial.dibujar(escena)
        dev.dibujar()
    end
    fx.dibujarDestello(ANCHO, ALTO)
    ui.dibujarOverlay(ANCHO, ALTO)
    ui.dibujarTooltip(ANCHO + OX, ALTO)
    ui.dibujarModal(ANCHO, ALTO)
    presentar(true, escena ~= "menu")
end
