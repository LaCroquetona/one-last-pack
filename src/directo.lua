-- Directos desde la mesa: el movil en un tripode graba mientras abres sobres.
-- Espectadores, chat, seguidores y propinas. Los numeros, en datos/directo.lua.
-- La apertura avisa de lo que pasa (rasgar, suspense, carta, fin del sobre) y
-- el chat reacciona segun cuanta gente haya.
local datos = require "datos.directo"
local datosEncargos = require "datos.encargos"
local sobres = require "datos.sobres"
local sets = require "datos.sets"
local mercado = require "src.mercado"
local rarezas = require "datos.rarezas"
local p = require "datos.paleta"
local partida = require "src.partida"
local fuentes = require "src.fuentes"
local sonido = require "src.sonido"
local fx = require "src.fx"
local ui = require "src.ui"
local emojis = require "src.emojis"

local lg = love.graphics
local utf8 = require "utf8"

local directo = {}

local d             -- el directo de ahora (nil si no hay)
local chat = {}     -- mensajes en pantalla, el ultimo al final
local cola = {}     -- mensajes que aun no han salido (para que no salgan todos de golpe)
local editando      -- nombre del canal mientras se escribe
local tipoElegido = "apertura"

-- quita lo que la fuente no sabe pintar
local function limpiar(cad)
    return (cad:gsub("[\"@&;~`^{}%[%]|\\]", ""))
end

local function azar(lista)
    return lista[love.math.random(#lista)]
end

local function nombreAlAzar()
    local N = datos.nombres
    local r = love.math.random()
    local nombre
    if r < 0.3 then
        nombre = azar(N.a) .. "_" .. azar(N.b)
    elseif r < 0.7 then
        nombre = azar(N.b) .. azar(N.c)
    else
        nombre = azar(N.b) .. "_" .. azar(N.c)
    end
    if love.math.random() < 0.45 then nombre = nombre .. love.math.random(1, 99) end
    return (nombre:gsub("_$", ""))
end

local function colorAlAzar()
    return p[azar(datos.colores)]
end

-- conseguir seguidores cuesta mas cuantos mas tienes
local function cansancio()
    return 1 + partida.canal.seguidores / datos.seguir.cansancio
end

-- espectadores "de base" con estos seguidores
local function base(seguidores)
    local E = datos.espectadores
    return E.base + math.sqrt(seguidores) * E.raiz + seguidores * E.lineal
end

function directo.activo()
    return d ~= nil
end

function directo.espectadores()
    return d and math.floor(d.esp + 0.5) or 0
end

-- chat

local function poner(msg)
    if msg.propina and love.math.random() < 0.5 then emojis.lanzar({ "moneda", "moneda", "stonks" }, 1, 0) end
    table.insert(chat, msg)
    while #chat > datos.chat.max do table.remove(chat, 1) end
end

-- categoria: clave de los textos; retraso: segundos hasta que sale
-- las ultimas frases que han salido, para no repetirlas enseguida
local recientes, ordenRecientes = {}, {}
local MEMORIA = 60

local function recordar(texto)
    recientes[texto] = true
    table.insert(ordenRecientes, texto)
    if #ordenRecientes > MEMORIA then recientes[table.remove(ordenRecientes, 1)] = nil end
end

-- a veces se cambia un poco: se alarga la ultima letra o se añade una coletilla
local function variar(texto, idioma)
    local r = love.math.random()
    if r < 0.2 then
        return texto .. azar(datos.textos.coletillas[idioma])
    elseif r < 0.32 then
        local ultima = texto:match("([aeiouAEIOUsS])[!?]*$")
        if ultima then
            local extra = ultima:rep(love.math.random(1, 3))
            return (texto:gsub("([aeiouAEIOUsS])([!?]*)$", "%1" .. extra .. "%2"))
        end
    end
    return texto
end

-- una frase de esa situacion que no haya salido hace poco
local function frase(idioma, categoria)
    local lista = datos.textos[idioma][categoria]
    if not lista then return nil end
    local texto
    for _ = 1, 8 do
        texto = azar(lista)
        if not recientes[texto] then break end
    end
    recordar(texto)
    return limpiar(variar(texto, idioma))
end

local function idiomaMensaje()
    local idioma = partida.canal.idioma
    if love.math.random() < datos.chat.otroIdioma then idioma = idioma == "es" and "en" or "es" end
    return idioma
end

local function decir(categoria, retraso, extra)
    local texto = frase(idiomaMensaje(), categoria)
    if not texto then return end
    table.insert(cola, { t = retraso or 0, nombre = nombreAlAzar(), color = colorAlAzar(), texto = texto, extra = extra })
end

-- varios mensajes repartidos en "durante" segundos
local function rafaga(categoria, n, durante)
    for _ = 1, n do decir(categoria, love.math.random() * (durante or 1.5)) end
end

-- cuantos mensajes salen para un numero esperado (puede ser decimal)
local function cuantos(esperado)
    local n = math.floor(esperado)
    if love.math.random() < esperado - n then n = n + 1 end
    return n
end

-- propinas y seguidores

local function cantidadPropina(espectadores)
    local posibles, total = {}, 0
    for _, c in ipairs(datos.propinas.cantidades) do
        if espectadores >= (c[4] or 0) then
            table.insert(posibles, c)
            total = total + c[3]
        end
    end
    local r = love.math.random() * total
    for _, c in ipairs(posibles) do
        r = r - c[3]
        if r <= 0 then
            -- de 10 en 10 centimos, para que parezcan de verdad
            return math.floor((c[1] + love.math.random() * (c[2] - c[1])) / 10 + 0.5) * 10
        end
    end
    return 100
end

-- cuantas propinas caen con estos espectadores y este multiplicador
local function tirarPropinas(espectadores, mult)
    local prob = math.min(0.6, datos.propinas.prob * mult * partida.efecto("micro"))
    local lista = {}
    for _ = 1, math.floor(espectadores + 0.5) do
        if love.math.random() < prob then table.insert(lista, cantidadPropina(espectadores)) end
    end
    return lista
end

local function cobrarPropinas(lista, retraso)
    for i, v in ipairs(lista) do
        local texto = frase(idiomaMensaje(), "propina")
        table.insert(cola, { t = (retraso or 0) + i * 0.35, nombre = nombreAlAzar(), color = p.amarillo, texto = texto, propina = v })
    end
end

local function ganarSeguidores(n)
    if not d then return end
    n = n * partida.efecto("camara")
    d.acumulado = d.acumulado + n
    local enteros = math.floor(d.acumulado)
    if enteros <= 0 then return end
    d.acumulado = d.acumulado - enteros
    if enteros <= 3 then
        for _ = 1, enteros do
            table.insert(cola, { t = love.math.random() * 2, nombre = nombreAlAzar(), color = p.lima, sigue = 1 })
        end
    else
        -- muchos de golpe: una sola linea para no tapar el chat
        table.insert(cola, { t = 0.8, sistema = true, texto = "+" .. enteros .. " " .. datos.textos[partida.canal.idioma].muchos, color = p.lima, sigue = enteros })
    end
end

-- lo que da la mejor carta de un sobre (para seguir, propinas y subidon)
local function mejorDe(defs, godpack)
    local mejor = defs[1]
    for _, def in ipairs(defs) do
        if rarezas[def.rareza].nivel > rarezas[mejor.rareza].nivel then mejor = def end
    end
    local chase = false
    for _, def in ipairs(defs) do
        if def.chase then chase = true end
    end
    return mejor, chase, godpack
end

-- seguidores y propinas de un sobre entero, sin chat (lo usan los bots).
-- Devuelve seguidores ganados (decimal) y centimos de propinas
function directo.simularSobre(espectadores, defs, godpack)
    local S, P = datos.seguir, datos.propinas
    local mejor, chase = mejorDe(defs, godpack)
    local extra = (S.mejor[mejor.rareza] or 0) + (chase and S.chase or 0) + (godpack and S.godpack or 0)
    local seguidores = (S.porSobre + espectadores * S.porEspectador + extra * (1 + espectadores * 0.02)) / cansancio()
        * partida.efecto("camara")
    local total = 0
    for _, v in ipairs(tirarPropinas(espectadores, 1)) do total = total + v end
    for _, def in ipairs(defs) do
        local mult = (P.rareza[def.rareza] or 0) + (def.chase and P.chase or 0)
        if mult > 0 then
            for _, v in ipairs(tirarPropinas(espectadores, mult)) do total = total + v end
        end
    end
    if godpack then
        for _, v in ipairs(tirarPropinas(espectadores, P.godpack)) do total = total + v end
    end
    return seguidores, total
end

function directo.espectadoresBase(seguidores)
    return base(seguidores)
end

-- empezar y acabar

function directo.empezar()
    if d then return end
    d = { t = 0, esp = 0, pico = 0, objetivo = base(partida.canal.seguidores), ruido = 0, subidon = 1,
          quieto = 0, sobres = 0, propinas = 0, seguidores = 0, acumulado = 0, tipo = tipoElegido, sueltos = 0 }
    chat, cola = {}, {}
    emojis.limpiar()
    sonido.tocar("nueva")
    poner({ sistema = true, texto = "EMPIEZA EL DIRECTO", color = p.rojo })
end

local function dibujarResumen(ancho, alto)
    local r = directo.resumenUltimo
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", ui.izq, 0, ui.der - ui.izq, alto)
    local w, h = 260, 150
    local x, y = math.floor((ancho - w) / 2), math.floor((alto - h) / 2)
    ui.caja(x, y, w, h, p.negro)
    lg.setColor(p.rojo)
    lg.rectangle("fill", x + 1, y + 1, w - 2, 16)
    fuentes.texto("FIN DEL DIRECTO", x, y + 5, 1, p.blanco, "center", w)
    local m = math.floor(r.t / 60)
    local filas = {
        { "DURACIÓN", string.format("%d:%02d", m, math.floor(r.t % 60)), p.blanco },
        { "SOBRES ABIERTOS", tostring(r.sobres), p.blanco },
        { "PICO DE ESPECTADORES", tostring(r.pico), p.celeste },
        { "SEGUIDORES NUEVOS", "+" .. r.seguidores .. "  (" .. ui.numero(partida.canal.seguidores) .. ")", p.lima },
        { "PROPINAS", ui.dinero(r.propinas), p.amarillo },
    }
    for i, f in ipairs(filas) do
        local fy = y + 16 + i * 14
        fuentes.texto(f[1], x + 14, fy, 1, p.grisclaro)
        fuentes.texto(f[2], x + 14, fy, 1, f[3], "right", w - 28)
    end
    ui.boton("dir_vale", "VALE", x + w / 2 - 40, y + h - 26, 80, 16, p.verde)
end

-- silencioso: sin resumen (al salir al menu o cerrar el juego)
function directo.terminar(silencioso)
    if not d then return end
    -- los mensajes pendientes con dinero o seguidores se cobran ya
    for _, m in ipairs(cola) do
        if m.propina then
            partida.dinero = partida.dinero + m.propina
            d.propinas = d.propinas + m.propina
            partida.canal.propinas = partida.canal.propinas + m.propina
        elseif m.sigue then
            partida.canal.seguidores = partida.canal.seguidores + m.sigue
            d.seguidores = d.seguidores + m.sigue
        end
    end
    cola = {}
    local c = partida.canal
    c.directos = c.directos + 1
    c.record = math.max(c.record, d.pico)
    directo.resumenUltimo = { t = d.t, sobres = d.sobres, pico = d.pico, seguidores = d.seguidores, propinas = d.propinas }
    d = nil
    chat = {}
    partida.guardar()
    if not silencioso then
        ui.overlay = { dibujar = dibujarResumen, click = function(id) if id == "dir_vale" then ui.overlay = nil end end }
    end
end

-- avisos de la apertura

function directo.rasgar(godpack)
    if not d then return end
    d.quieto = 0
    if d.esp >= 3 then rafaga("rasgar", cuantos(math.min(6, d.esp * 0.08)), 1) end
    if godpack then
        d.subidon = d.subidon + datos.subidon.godpack
        rafaga("godpack", math.min(datos.chat.maxReaccion, 2 + cuantos(d.esp * 0.5)), 2)
        if d.esp >= 1 then emojis.lanzar({ "fuego", "estrella", "corona", "67", "GG", "flipa", "cohete", "OMG", "POG" }, 4 + math.floor(d.esp * 0.2), 2.5) end
    end
end

-- abres una caja en directo: el chat se anima y llega algo de gente
function directo.caja()
    if not d then return end
    d.quieto = 0
    d.subidon = d.subidon + 0.3
    if d.esp >= 1 then
        rafaga("caja", math.min(datos.chat.maxReaccion, 1 + cuantos(d.esp * 0.25)), 2)
        emojis.lanzar({ "fuego", "W", "ojos", "flipa", "rana" }, 2 + math.floor(d.esp * 0.1), 2)
    end
end

function directo.suspense()
    if not d or d.esp < 3 then return end
    rafaga("suspense", cuantos(math.min(5, d.esp * 0.06)), 0.8)
end

function directo.carta(def, nueva)
    if not d then return end
    d.quieto = 0
    local r = rarezas[def.rareza]
    local C = datos.chat
    -- reacciones: con poca gente solo a lo bueno
    local n
    if d.esp < 4 then
        n = (r.nivel >= 4 and d.esp >= 1 and love.math.random() < 0.6) and 1 or 0
    else
        n = math.min(C.maxReaccion, cuantos(d.esp * (C.reaccion[def.rareza] or 0)))
    end
    if n > 0 then rafaga(def.rareza, n, r.nivel >= 5 and 2.5 or 1.2) end
    -- emojis: de rara para arriba, mas cuanta mas gente y mejor la carta
    if r.nivel >= 3 and d.esp >= 1 then
        local tipos = ({ { "corazon", "fuego", "rana" }, { "fuego", "corazon", "ojos", "flipa", "diamante" },
                         { "fuego", "estrella", "67", "POG", "flipa", "cohete" },
                         { "estrella", "fuego", "67", "W", "corona", "OMG", "flipa", "diamante" } })[r.nivel - 2]
        emojis.lanzar(tipos, 1 + math.floor(d.esp * 0.05 * (r.nivel - 2)), r.nivel >= 5 and 2 or 1)
    end
    if def.chase and d.esp >= 1 then emojis.lanzar({ "corona", "estrella", "diamante", "100" }, 3, 1.5) end
    if def.chase and d.esp >= 1 then rafaga("chase", math.min(C.maxReaccion, 1 + cuantos(d.esp * 0.3)), 2) end
    if nueva and d.esp >= 6 and love.math.random() < 0.3 then decir("nueva", 0.8) end
    -- las buenas traen mirones y propinas al momento
    local S = datos.subidon
    d.subidon = d.subidon + (S[def.rareza] or 0) + (def.chase and S.chase or 0)
    local P = datos.propinas
    local mult = (P.rareza[def.rareza] or 0) + (def.chase and P.chase or 0)
    if mult > 0 then cobrarPropinas(tirarPropinas(d.esp, mult), 0.8) end
end

-- peticiones del chat: alguien paga por que abras un sobre concreto

local function nuevaPeticion()
    local C = datosEncargos.chat
    local tuyos, todos = {}, {}
    for _, t in ipairs(sobres.lista) do
        if mercado.salido(t.set) then
            table.insert(todos, t)
            if partida.sobres(t.id) > 0 then table.insert(tuyos, t) end
        end
    end
    if #todos == 0 then return end
    local lista = (#tuyos > 0 and love.math.random() < C.tuyos) and tuyos or todos
    local t = lista[love.math.random(#lista)]
    local pago = t.precio * (C.pago[1] + love.math.random() * (C.pago[2] - C.pago[1])) * (1 + d.esp * C.porEspectador2) * partida.efecto("aro")
    local idioma = partida.canal.idioma
    local texto = azar(datosEncargos.textos[idioma]):gsub("{s}", sets[t.set].codigo)
    d.peticion = { tipo = t.id, codigo = sets[t.set].codigo, pago = math.floor(pago / 10 + 0.5) * 10, t = C.segundos,
                   nombre = nombreAlAzar(), color = colorAlAzar(), texto = texto }
    table.insert(cola, { t = 0, nombre = d.peticion.nombre, color = d.peticion.color, texto = texto })
    sonido.tocar("nueva", 1.4)
end

local function revisarPeticion(tipoId)
    local pe = d.peticion
    if not pe or pe.tipo ~= tipoId then return end
    d.peticion = nil
    local idioma = partida.canal.idioma
    table.insert(cola, { t = 0.6, nombre = pe.nombre, color = p.amarillo, texto = azar(datosEncargos.textos.cumplida[idioma]),
                         propina = pe.pago })
    rafaga("holo", math.min(6, 1 + cuantos(d.esp * 0.1)), 1.5)
    ganarSeguidores(datosEncargos.chat.seguidores)
    d.cumplidas = (d.cumplidas or 0) + 1
end

function directo.peticion()
    return d and d.peticion
end

function directo.forzarPeticion()
    if d then nuevaPeticion() end
end

function directo.finSobre(defs, godpack, tipoId)
    if not d then return end
    if tipoId then revisarPeticion(tipoId) end
    d.sobres = d.sobres + 1
    d.quieto = 0
    local S = datos.seguir
    local mejor, chase = mejorDe(defs, godpack)
    if rarezas[mejor.rareza].nivel <= 2 and d.esp >= 4 and love.math.random() < 0.5 then emojis.lanzar({ "calavera", "payaso", "L", "risa" }, 2, 1) end
    local extra = (S.mejor[mejor.rareza] or 0) + (chase and S.chase or 0) + (godpack and S.godpack or 0)
    ganarSeguidores((S.porSobre + d.esp * S.porEspectador + extra * (1 + d.esp * 0.02)) / cansancio())
    cobrarPropinas(tirarPropinas(d.esp, 1), 0.5)
    if godpack then cobrarPropinas(tirarPropinas(d.esp, datos.propinas.godpack), 1) end
    if d.esp <= 3 then
        if love.math.random() < datos.chat.finSobre then decir("finSobre", 0.6 + love.math.random()) end
    elseif love.math.random() < 0.3 then
        decir("finSobre", 0.5 + love.math.random())
    end
end

-- cada frame (tambien fuera de la mesa: el directo sigue)
function directo.update(dt, enMesa)
    if not d then return end
    emojis.update(dt)
    d.t = d.t + dt
    d.quieto = d.quieto + dt
    local seguidores = partida.canal.seguidores

    -- cuanta gente deberia haber ahora mismo
    local animo = 1
    local A = enMesa and datos.aburrimiento or datos.fuera
    local desde = enMesa and A.desde or 5
    if d.quieto > desde then
        animo = math.max(A.queda, math.exp(-(d.quieto - desde) * A.ritmo))
    end
    d.subidon = 1 + (d.subidon - 1) * math.exp(-datos.subidon.baja * dt * 10)
    -- el ruido cambia despacio, para que el numero suba y baje solo
    d.ruido = d.ruido + ((love.math.random() * 2 - 1) * datos.espectadores.ruido - d.ruido) * math.min(1, dt * 0.3)
    d.objetivo = base(seguidores) * animo * d.subidon * (1 + d.ruido)
    local antes = math.floor(d.esp + 0.5)
    d.esp = d.esp + (d.objetivo - d.esp) * math.min(1, dt * datos.llegada)
    local ahora = math.floor(d.esp + 0.5)
    d.pico = math.max(d.pico, ahora)
    if ahora > antes and love.math.random() < 0.5 then decir("saludo", love.math.random()) end

    -- peticiones del chat: mas cuanta mas gente; caducan si no las cumples
    local C = datosEncargos.chat
    if d.peticion then
        d.peticion.t = d.peticion.t - dt
        if d.peticion.t <= 0 then
            local pe = d.peticion
            d.peticion = nil
            table.insert(cola, { t = 0, nombre = pe.nombre, color = pe.color,
                                 texto = azar(datosEncargos.textos.caducada[partida.canal.idioma]) })
        end
    elseif d.esp >= C.espectadoresMin and d.t > 20 then
        local porMinuto = math.min(C.maxPorMinuto, C.porMinuto + d.esp * C.porEspectador)
        if love.math.random() < porMinuto * dt / 60 then nuevaPeticion() end
    end

    -- seguidores que llegan solo por estar mirando
    ganarSeguidores(d.esp * datos.seguir.porMinuto * dt / 60 / cansancio())

    -- charla suelta (preguntas, slang); si llevas rato sin abrir, que abras
    local ritmo = math.min(datos.chat.maxRitmo, d.esp * datos.chat.ritmo)
    if love.math.random() < ritmo * dt then
        local r = love.math.random()
        local cat
        if d.quieto > 25 and enMesa then
            cat = r < 0.6 and "espera" or "pregunta"
        else
            cat = r < 0.45 and "pregunta" or (r < 0.85 and "charla" or "saludo")
        end
        decir(cat)
    end

    -- los mensajes pendientes van saliendo
    for i = #cola, 1, -1 do
        local m = cola[i]
        m.t = m.t - dt
        if m.t <= 0 then
            table.remove(cola, i)
            m.t = 0
            if m.propina then
                partida.dinero = partida.dinero + m.propina
                d.propinas = d.propinas + m.propina
                partida.canal.propinas = partida.canal.propinas + m.propina
                sonido.tocar("moneda", 1.2)
                if enMesa then fx.monedas(570, 200, math.min(30, 4 + m.propina / 100), 120, 200) end
                partida.guardar()
            elseif m.sigue then
                partida.canal.seguidores = partida.canal.seguidores + m.sigue
                d.seguidores = d.seguidores + m.sigue
                if enMesa then sonido.tocar("encima", 1.6) end
                partida.guardar()
            end
            m.nace = d.t
            -- sin nadie mirando no escribe nadie
            if m.sistema or m.sigue or m.propina or directo.espectadores() > 0 then poner(m) end
        end
    end
end

-- nombre del canal

function directo.editando()
    return editando ~= nil
end

local MAX_NOMBRE = 16

local function acabarEdicion()
    local n = editando and editando:gsub("^%s+", ""):gsub("%s+$", "")
    if n and #n > 0 then partida.canal.nombre = n end
    editando = nil
    love.keyboard.setTextInput(false)
    partida.guardar()
end

function directo.texto(t)
    if not editando then return end
    for _, cp in utf8.codes(t) do
        local c = utf8.char(cp):upper()
        if utf8.len(editando) < MAX_NOMBRE and (c:match("^[A-Z0-9_]$") or c == "Ñ" or c == "ñ") then
            editando = editando .. (c == "ñ" and "Ñ" or c)
        end
    end
end

function directo.tecla(tecla)
    if not editando then return false end
    if tecla == "backspace" then
        local n = utf8.len(editando)
        if n > 0 then editando = editando:sub(1, utf8.offset(editando, n) - 1) end
    elseif tecla == "return" or tecla == "kpenter" or tecla == "escape" then
        acabarEdicion()
    end
    return true
end

-- dibujo: tripode con el movil y el chat (o el panel para empezar)

local function dibujarTripode(cx, y0)
    -- patas
    lg.setColor(p.grisosc)
    lg.setLineWidth(2)
    lg.line(cx, y0 + 66, cx - 22, y0 + 98)
    lg.line(cx, y0 + 66, cx + 22, y0 + 98)
    lg.line(cx, y0 + 66, cx, y0 + 100)
    lg.setLineWidth(1)
    lg.setColor(p.negro)
    lg.rectangle("fill", cx - 3, y0 + 60, 6, 8)
    -- movil
    local w, h = 34, 60
    local x, y = cx - w / 2, y0
    lg.setColor(p.negro)
    lg.rectangle("fill", x - 1, y - 1, w + 2, h + 2)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x, y, w, h)
    lg.setColor(d and p.azulosc or p.negro)
    lg.rectangle("fill", x + 2, y + 5, w - 4, h - 10)
    lg.setColor(p.gris)
    lg.rectangle("fill", cx - 4, y + 2, 8, 1)
    if d then
        local parpadeo = math.floor(d.t * 2) % 2 == 0
        if parpadeo then
            lg.setColor(p.rojo)
            lg.rectangle("fill", x + 5, y + 8, 4, 4)
        end
        fuentes.texto("REC", x + 11, y + 8, 1, p.blanco)
        fuentes.texto(tostring(directo.espectadores()), x + 2, y + 22, 2, p.blanco, "center", w - 4)
        fuentes.texto("VIENDO", x + 2, y + 36, 1, p.grisclaro, "center", w - 4)
    else
        -- apagado: llama la atencion para que se vea que se puede emitir
        local t = love.timer.getTime()
        if math.floor(t * 2) % 2 == 0 then
            lg.setColor(p.rojo)
            lg.circle("fill", cx, y + 20, 6)
            lg.setColor(p.blanco)
            lg.circle("fill", cx, y + 20, 2)
        end
        fuentes.texto("LIVE", x + 2, y + 32, 1, p.blanco, "center", w - 4)
        fuentes.texto("TOCA", x + 2, y + 41, 1, p.gris, "center", w - 4)
        if not editando then ui.zona("dir_empezar", x, y, w, h) end
    end
end

-- aviso de que se esta abriendo un sobre sin directo (unos segundos)
local avisoSinDirecto = 0
-- a quien aun no ha hecho casi directos se le recuerda que existen
function directo.sugerir()
    return not d and partida.canal.directos < datos.avisarHasta
end

function directo.avisarSinDirecto()
    if directo.sugerir() then avisoSinDirecto = 2.5 end
end

-- boton de empezar: late, brilla y tiene un bocadillo encima
local function botonEmpezar(x, by, w)
    local t = love.timer.getTime()
    local dt = love.timer.getDelta()
    avisoSinDirecto = math.max(0, avisoSinDirecto - dt)
    local aviso = avisoSinDirecto > 0
    local pulso = 0.75 + math.sin(t * 5) * 0.25
    local temblor = aviso and math.floor(math.sin(t * 40) * 2 + 0.5) or 0
    fx.aura(x + w / 2, by + 11, p.rojo, 70, (aviso and 0.5 or 0.28) * pulso)
    ui.boton("dir_empezar", "EMPEZAR DIRECTO", x + temblor, by, w, 22,
        { p.rojo[1] * (0.8 + pulso * 0.3), p.rojo[2] * pulso, p.rojo[3] * pulso }, not editando)
    if math.floor(t * 2) % 2 == 0 then
        lg.setColor(p.blanco)
        lg.circle("fill", x + temblor + 10, by + 10, 3)
    end
    if editando then return end
    -- bocadillo que bota
    local texto = aviso and "¡ESTÁS SIN DIRECTO!" or "¡GANA PROPINAS!"
    local bw = fuentes.ancho(texto) + 10
    local bx = math.floor(x + (w - bw) / 2)
    local bot = math.floor(math.abs(math.sin(t * 4)) * 3)
    local yb = by - 17 - bot
    local fondo = aviso and p.rojo or p.amarillo
    lg.setColor(p.negro)
    lg.rectangle("fill", bx - 1, yb - 1, bw + 2, 13)
    lg.setColor(fondo)
    lg.rectangle("fill", bx, yb, bw, 11)
    lg.polygon("fill", x + w / 2 - 4, yb + 11, x + w / 2 + 4, yb + 11, x + w / 2, yb + 15)
    fuentes.texto(texto, bx, yb + 3, 1, aviso and p.blanco or p.negro, "center", bw)
end

-- texto partido en lineas que caben en w
local function partir(cad, w)
    local lineas, actual = {}, ""
    for palabra in cad:gmatch("%S+") do
        local prueba = actual == "" and palabra or (actual .. " " .. palabra)
        if fuentes.ancho(prueba) <= w or actual == "" then
            actual = prueba
        else
            table.insert(lineas, actual)
            actual = palabra
        end
    end
    if actual ~= "" then table.insert(lineas, actual) end
    return lineas
end

local function lineasMensaje(m, w)
    if m.sistema then return { { { m.texto, m.color } } } end
    if m.sigue then
        local suyo = datos.textos[partida.canal.idioma].sigue
        return { { { m.nombre, m.color }, { " " .. suyo, p.lima } } }
    end
    local cabeza = m.nombre .. ":"
    local cuerpo = m.texto
    if m.propina then cuerpo = ui.dinero(m.propina) .. " " .. cuerpo end
    local todas = partir(cabeza .. " " .. cuerpo, w)
    -- la primera linea lleva el nombre de color
    local res = {}
    for i, l in ipairs(todas) do
        if i == 1 then
            local resto = l:sub(#cabeza + 1)
            res[i] = { { cabeza, m.color }, { resto, m.propina and p.amarillo or p.blanco } }
        else
            res[i] = { { l, m.propina and p.amarillo or p.blanco } }
        end
    end
    return res
end

local function dibujarChat(x, y, w, h)
    ui.caja(x, y, w, h, p.negro)
    -- cabecera
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 1, y + 1, w - 2, 20)
    lg.setColor(math.floor(d.t * 2) % 2 == 0 and p.rojo or p.morado)
    lg.rectangle("fill", x + 5, y + 5, 5, 5)
    fuentes.texto("EN DIRECTO " .. directo.espectadores(), x + 13, y + 5, 1, p.blanco)
    fuentes.texto(ui.numero(partida.canal.seguidores) .. " SEG.  " .. ui.dinero(d.propinas), x + 5, y + 13, 1, p.grisclaro)
    ui.boton("dir_parar", "PARAR", x + w - 36, y + 4, 32, 11, p.rojo)

    -- peticion del chat, fija arriba
    local tope = y + 23
    local pe = d.peticion
    if pe then
        local parpadeo = pe.t < 20 and math.floor(pe.t * 3) % 2 == 0
        lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.18)
        lg.rectangle("fill", x + 2, y + 23, w - 4, 26)
        lg.setColor(parpadeo and p.rojo or p.amarillo)
        lg.rectangle("line", x + 2.5, y + 23.5, w - 5, 25)
        fuentes.texto("PETICIÓN: ABRE UN " .. pe.codigo, x + 6, y + 27, 1, p.amarillo)
        fuentes.texto("+" .. ui.dinero(pe.pago), x + 6, y + 36, 1, p.lima)
        fuentes.texto(string.format("%d:%02d", math.floor(pe.t / 60), math.floor(pe.t % 60)), x, y + 36, 1,
            parpadeo and p.rojo or p.blanco, "right", w - 8)
        tope = y + 51
    end

    -- mensajes de abajo arriba
    local fondo = y + h - 4
    local ancho = w - 8
    for i = #chat, 1, -1 do
        local m = chat[i]
        local lineas = lineasMensaje(m, ancho)
        local alto = #lineas * 7 + 2
        if fondo - alto < tope then break end
        fondo = fondo - alto
        local entra = m.nace and math.min(1, (d.t - m.nace) / 0.15) or 1
        local dx = math.floor((1 - entra) * 8)
        if m.propina then
            lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.15)
            lg.rectangle("fill", x + 2, fondo - 1, w - 4, alto)
        end
        for k, l in ipairs(lineas) do
            fuentes.trozos(l, x + 4 + dx, fondo + (k - 1) * 7, 1)
        end
    end
    emojis.dibujar(x, tope, w, y + h - tope)
end

local function dibujarPanel(x, y, w, h)
    ui.caja(x, y, w, h, p.negro)
    lg.setColor(p.grisosc)
    lg.rectangle("fill", x + 1, y + 1, w - 2, 12)
    fuentes.texto("TU CANAL", x, y + 4, 1, p.blanco, "center", w)

    local c = partida.canal
    local ny = y + 18
    -- nombre (se toca para cambiarlo)
    local nombre = editando or c.nombre
    local cursor = editando and math.floor(love.timer.getTime() * 2) % 2 == 0 and "_" or ""
    ui.caja(x + 4, ny, w - 8, 14, editando and p.azulosc or p.grisosc)
    fuentes.texto(nombre .. cursor, x + 8, ny + 5, 1, editando and p.cian or p.blanco)
    if not editando then
        fuentes.texto("CAMBIAR", x + 4, ny + 5, 1, p.gris, "right", w - 12)
    end
    ui.zona("dir_nombre", x + 4, ny, w - 8, 14)
    if editando then
        ui.boton("dir_ok", "OK", x + w - 26, ny + 16, 22, 10, p.verde)
    end

    fuentes.texto(ui.numero(c.seguidores) .. " SEGUIDORES", x + 6, ny + 30, 1, p.lima)
    if c.record > 0 then fuentes.texto("RÉCORD: " .. c.record .. " A LA VEZ", x + 6, ny + 38, 1, p.grisclaro) end

    -- idioma del chat
    local iy = ny + 50
    fuentes.texto("IDIOMA DEL CHAT", x + 6, iy, 1, p.grisclaro)
    ui.boton("dir_idioma_es", "ESPAÑOL", x + 6, iy + 8, 56, 11, c.idioma == "es" and p.azul or p.grisosc)
    ui.boton("dir_idioma_en", "INGLÉS", x + 66, iy + 8, w - 72, 11, c.idioma == "en" and p.azul or p.grisosc)

    -- tipo de directo
    local ty = iy + 26
    fuentes.texto("TIPO DE DIRECTO", x + 6, ty, 1, p.grisclaro)
    for i, t in ipairs(datos.tipos) do
        local by = ty + 8 + (i - 1) * 13
        if t.proximamente then
            ui.caja(x + 6, by, w - 12, 11, p.negro)
            fuentes.texto(t.nombre, x + 10, by + 3, 1, p.gris)
            -- con el texto grande no cabe la palabra larga
            local pronto = "PRÓXIMAMENTE"
            if fuentes.ancho(t.nombre) + fuentes.ancho(pronto) + 10 > w - 16 then pronto = "PRONTO" end
            fuentes.texto(pronto, x + 6, by + 3, 1, p.grisosc, "right", w - 16)
        else
            ui.boton("dir_tipo_" .. t.id, t.nombre, x + 6, by, w - 12, 11, tipoElegido == t.id and p.morado or p.grisosc)
        end
    end

    botonEmpezar(x + 6, y + h - 28, w - 12)
end

-- la columna del directo (x, y, w, h: todo su hueco)
function directo.dibujar(x, y, w, h)
    dibujarTripode(x + w / 2, y + 2)
    local cy = y + 104
    if d then
        dibujarChat(x, cy, w, h - 104)
    else
        dibujarPanel(x, cy, w, h - 104)
    end
end

function directo.click(id)
    if id == "dir_empezar" then
        directo.empezar()
    elseif id == "dir_parar" then
        directo.terminar()
    elseif id == "dir_nombre" then
        if not editando then
            editando = partida.canal.nombre
            love.keyboard.setTextInput(true)
        end
    elseif id == "dir_ok" then
        acabarEdicion()
    elseif id == "dir_idioma_es" or id == "dir_idioma_en" then
        partida.canal.idioma = id:sub(-2)
        partida.guardar()
    elseif id:match("^dir_tipo_") then
        tipoElegido = id:sub(10)
    else
        return false
    end
    return true
end

-- indicador para la barra de arriba cuando no estas en la mesa
function directo.indicador(x, y)
    if not d then return 0 end
    local cad = "EN DIRECTO " .. directo.espectadores()
    lg.setColor(math.floor(d.t * 2) % 2 == 0 and p.rojo or p.morado)
    lg.rectangle("fill", x, y + 1, 4, 4)
    fuentes.texto(cad, x + 7, y, 1, p.rojo)
    return 7 + fuentes.ancho(cad)
end

-- al empezar o cargar otra partida
function directo.reiniciar()
    d = nil
    chat, cola = {}, {}
    editando = nil
end

return directo
