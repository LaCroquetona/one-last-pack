-- Directos desde la mesa: el movil en un tripode graba mientras abres sobres.
-- Espectadores, chat, seguidores y propinas. Los numeros, en datos/directo.lua.
-- La apertura avisa de lo que pasa (rasgar, suspense, carta, fin del sobre) y
-- el chat reacciona segun cuanta gente haya.
local datos = require "datos.directo"
local V = datos.venta
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
local productos = require "datos.productos"
local twitch = require "src.twitch"
local opciones = require "src.opciones"

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
    if N.enteros and r < 0.22 then
        nombre = azar(N.enteros)
        if love.math.random() < 0.25 then nombre = nombre .. love.math.random(1, 99) end
        return nombre
    end
    r = love.math.random()
    if r < 0.3 then
        nombre = azar(N.a) .. "_" .. azar(N.b)
    elseif r < 0.7 then
        nombre = azar(N.b) .. azar(N.c)
    else
        nombre = azar(N.b) .. "_" .. azar(N.c)
    end
    if love.math.random() < 0.45 then nombre = nombre .. love.math.random(1, 99) end
    -- sin espacios (los trozos vacios de la lista dejan huecos) ni guiones sueltos
    nombre = nombre:gsub("%s", ""):gsub("€", ""):gsub("__+", "_"):gsub("^_", ""):gsub("_$", "")
    if nombre == "" or nombre:match("^%d+$") then nombre = "ANON" .. nombre end
    return nombre
end

local function colorAlAzar()
    return p[azar(datos.colores)]
end

-- abrir muy rapido no multiplica el directo: por encima de ritmo.normal
-- sobres por minuto, cada sobre da menos (propinas y seguidores de lo
-- normal, el subidon de las holo). Lo viral (full art o mas) cuenta entero
local function factorRitmo()
    if not d then return 1 end
    local R = datos.ritmo
    local n = 0
    for _, t in ipairs(d.marcas or {}) do
        if d.t - t < R.ventana then n = n + 1 end
    end
    return math.min(1, R.normal * R.ventana / 60 / math.max(1, n))
end

local function marcarSobre()
    d.marcas = d.marcas or {}
    table.insert(d.marcas, d.t)
    while #d.marcas > 0 and d.t - d.marcas[1] > datos.ritmo.ventana do table.remove(d.marcas, 1) end
end

-- conseguir seguidores cuesta mas cuantos mas tienes
local function cansancio()
    local A = datos.seguir.arranque
    local c = 1 + partida.canal.seguidores / datos.seguir.cansancio
    if partida.canal.seguidores < A.hasta then c = c / A.mult end
    return c
end

-- espectadores "de base" con estos seguidores
local function base(seguidores)
    local E = datos.espectadores
    if seguidores > E.umbral then seguidores = E.umbral + (seguidores - E.umbral) * E.despues end
    return E.base + math.sqrt(seguidores) * E.raiz + seguidores * E.lineal
end

function directo.activo()
    return d ~= nil
end

function directo.tipo()
    return d and d.tipo
end

function directo.vendiendo()
    return d and d.vendiendo
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

-- tienes algo de ese producto (en la mesa, guardado o empezado)
local function tienesProd(pid)
    local a = partida.cajaAbierta
    if a and (a.prod or "caja") == pid then return true end
    local t = pid == "caja" and partida.cajas or partida.prods
    for k, n in pairs(t) do
        if n > 0 and (pid == "caja" or k:match("^" .. pid .. ":")) then return true end
    end
    return false
end

local function hayReimpresion()
    for _, s in ipairs(mercado.setsSalidos()) do
        if mercado.fase(s.id) == "reimpresion" then return true end
    end
    return false
end

local function hayPrimera()
    for _, t in ipairs(sobres.lista) do
        if partida.sobres(t.id, true) > 0 then return true end
    end
    local a = partida.cajaAbierta
    return a and a.primera or false
end

-- las frases que dependen de algo solo salen cuando toca
local CONTEXTO = {
    { "%f[%a]caja", function() return tienesProd("caja") end }, { "%f[%a]box%f[%A]", function() return tienesProd("caja") end },
    { "bl[ií]ster", function() return tienesProd("blister") end },
    { "%f[%a]tin%f[%A]", function() return tienesProd("tin") end }, { "%f[%a]lata%f[%A]", function() return tienesProd("tin") end },
    { "%f[%a]etb", function() return tienesProd("etb") end },
    { "1ª ed", hayPrimera }, { "1st ed", hayPrimera }, { "reimpresi", hayReimpresion },
    { "set 2", function() return mercado.salido(sets.lista[2] and sets.lista[2].id) end },
    { "esa carta", function() return partida.propiasEnMesa() > 0 end },
    { "vale esa", function() return partida.propiasEnMesa() > 0 end },
    { "buena carta", function() return partida.propiasEnMesa() > 0 end },
    { "bicho ese", function() return partida.propiasEnMesa() > 0 end },
    { "that one", function() return partida.propiasEnMesa() > 0 end },
    { "that a good", function() return partida.propiasEnMesa() > 0 end },
    { "esa la", function() return partida.propiasEnMesa() > 0 end },
}

function directo.encaja(texto)
    local t = texto:lower()
    for _, c in ipairs(CONTEXTO) do
        if t:find(c[1]) and not c[2]() then return false end
    end
    return true
end

-- las de relleno son las que se filtran (las de reaccion ya van con lo que pasa)
local FILTRADAS = { pregunta = true, charla = true, espera = true }

-- una frase de esa situacion que no haya salido hace poco (y que venga a cuento)
local function frase(idioma, categoria)
    local lista = datos.textos[idioma][categoria]
    if not lista then return nil end
    local texto
    for i = 1, 16 do
        texto = azar(lista)
        local vale = not FILTRADAS[categoria] or directo.encaja(texto)
        if vale and (i > 8 or not recientes[texto]) then break end
        if not vale and i == 16 then return nil end
    end
    recordar(texto)
    return limpiar(variar(texto, idioma))
end

local function idiomaMensaje()
    local idioma = partida.canal.idioma
    if love.math.random() < datos.chat.otroIdioma then idioma = idioma == "es" and "en" or "es" end
    return idioma
end

-- con SOLO TWITCH en opciones (y conectado) el chat del juego no habla
local function callado()
    return opciones.soloTwitch()
end

local function decir(categoria, retraso, extra)
    if callado() then return end
    local texto = frase(idiomaMensaje(), categoria)
    if not texto then return end
    local m = { t = retraso or 0, nombre = nombreAlAzar(), color = colorAlAzar(), texto = texto, extra = extra }
    -- las palabras mas tipicas (xd, F, GG, illo, salseo...) a veces salen como emoji
    local resto, lista = emojis.deChat(texto)
    if #lista > 0 and love.math.random() < 0.6 then m.texto, m.emotes = resto, lista end
    table.insert(cola, m)
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

-- cadena: varios del chat copian lo mismo seguido (un texto o un emoji)
local EMOJI_CADENA = { holo = "fuego", fullart = "flipa", secreta = "corona", chase = "diamante", godpack = "cohete", mal = "calavera" }
local function cadena(cat)
    if callado() or not d or d.esp < 6 then return end
    local idioma = partida.canal.idioma
    local lista = datos.textos[idioma].cadena[cat]
    if not lista then return end
    local n = math.min(7, 3 + cuantos(d.esp * 0.04))
    local texto, emote = nil, nil
    if love.math.random() < 0.5 then texto = azar(lista) else emote = EMOJI_CADENA[cat] end
    for i = 1, n do
        local m = { t = 0.3 + i * 0.25 + love.math.random() * 0.15, nombre = nombreAlAzar(), color = colorAlAzar() }
        if texto then
            m.texto = texto
        else
            m.texto = ""
            m.emotes = {}
            for _ = 1, love.math.random(1, 3) do table.insert(m.emotes, emote) end
        end
        table.insert(cola, m)
    end
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

-- cuantas propinas caen con estos espectadores y este multiplicador.
-- viral: algo gordo, da propina toda la gente (si no, se satura)
local function tirarPropinas(espectadores, mult, viral)
    local P = datos.propinas
    local prob = math.min(P.probMax, P.prob * mult * partida.efecto("micro"))
    local dan = espectadores
    if not viral and dan > P.tope then dan = P.tope + (dan - P.tope) * P.despuesTope end
    local lista = {}
    for _ = 1, math.floor(dan + 0.5) do
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
        if rarezas.rango(def) > rarezas.rango(mejor) then mejor = def end
    end
    local chase = false
    for _, def in ipairs(defs) do
        if def.chase or rarezas.de(def).especial then chase = true end
    end
    return mejor, chase, godpack
end

-- seguidores y propinas de un sobre entero, sin chat (lo usan los bots).
-- Devuelve seguidores ganados (decimal) y centimos de propinas
-- seguidores que trae un sobre; f: factor del ritmo (lo de las holo y lo
-- normal baja si abres muy rapido, lo viral no)
function directo.seguidoresSobre(espectadores, mejor, chase, godpack, f)
    local S = datos.seguir
    local viral = datos.propinas.viral[mejor.rareza] or chase or godpack
    local extra = (S.mejor[mejor.rareza] or 0) + (chase and S.chase or 0) + (godpack and S.godpack or 0)
    return ((S.porSobre + espectadores * S.porEspectador) * f + extra * (1 + espectadores * 0.02) * (viral and 1 or f))
        / cansancio()
end

-- f: factor del ritmo (1 si no se abre mas rapido de lo normal)
function directo.simularSobre(espectadores, defs, godpack, f)
    f = f or 1
    local P = datos.propinas
    local mejor, chase = mejorDe(defs, godpack)
    local seguidores = directo.seguidoresSobre(espectadores, mejor, chase, godpack, f) * partida.efecto("camara")
    local total = 0
    for _, v in ipairs(tirarPropinas(espectadores, f)) do total = total + v end
    for _, def in ipairs(defs) do
        local viral = P.viral[def.rareza] or def.chase
        local mult = ((P.rareza[def.rareza] or 0) + (def.chase and P.chase or 0)) * (viral and 1 or f)
        if mult > 0 then
            for _, v in ipairs(tirarPropinas(espectadores, mult, viral)) do total = total + v end
        end
    end
    if godpack then
        for _, v in ipairs(tirarPropinas(espectadores, P.godpack, true)) do total = total + v end
    end
    return seguidores, total
end

function directo.espectadoresBase(seguidores)
    return base(seguidores)
end

-- empezar y acabar

function directo.empezar()
    if d then return end
    if tipoElegido == "venta" and partida.canal.seguidores < V.desbloqueo then tipoElegido = "apertura" end
    d = { t = 0, esp = 0, pico = 0, objetivo = base(partida.canal.seguidores), ruido = 0, subidon = 1,
          quieto = 0, sobres = 0, propinas = 0, seguidores = 0, acumulado = 0, tipo = tipoElegido, sueltos = 0,
          pedidos = {}, ventas = 0, ingresos = 0, hype = 0, vendiendo = true }
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
    if r.venta then table.insert(filas, { "SOBRES VENDIDOS " .. r.ventas, ui.dinero(r.ingresos), p.lima }) end
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
    directo.resumenUltimo = { t = d.t, sobres = d.sobres, pico = d.pico, seguidores = d.seguidores, propinas = d.propinas,
                              venta = d.tipo == "venta", ventas = d.ventas, ingresos = d.ingresos }
    d = nil
    chat = {}
    partida.guardar()
    if not silencioso then
        ui.overlay = { dibujar = dibujarResumen, click = function(id) if id == "dir_vale" then ui.overlay = nil end end }
    end
end

-- avisos de la apertura

function directo.rasgar(godpack, primera)
    if not d then return end
    d.quieto = 0
    if d.esp >= 3 then rafaga("rasgar", cuantos(math.min(6, d.esp * 0.08)), 1) end
    if primera and d.esp >= 2 and love.math.random() < 0.5 then rafaga("primera", 1 + cuantos(d.esp * 0.03), 1) end
    if godpack then
        d.subidon = d.subidon + datos.subidon.godpack
        rafaga("godpack", math.min(datos.chat.maxReaccion, 2 + cuantos(d.esp * 0.5)), 2)
        if d.esp >= 1 then emojis.lanzar({ "fuego", "estrella", "corona", "67", "GG", "flipa", "cohete", "OMG", "POG", "OLE", "CLIP", "musculo", "GOD" }, 4 + math.floor(d.esp * 0.2), 2.5) end
        cadena("godpack")
    end
end

-- abres un producto sellado en directo (blister, tin, ETB): cada uno con lo suyo
local SUBIDON_PRODUCTO = { blister = 0.08, tin = 0.18, etb = 0.25 }
local EMOJIS_PRODUCTO = { blister = { "sobre", "manos", "dado", "regalo", "YOLO" }, tin = { "sobre", "estrella", "gafas", "W" },
    etb = { "sobre", "fuego", "flipa", "trofeo", "W", "cohete" } }
function directo.producto(pid)
    if pid == "caja" then return directo.caja() end
    if not d then return end
    d.quieto = 0
    d.subidon = d.subidon + (SUBIDON_PRODUCTO[pid] or 0.1)
    if d.esp >= 1 then
        local peso = pid == "etb" and 0.25 or (pid == "tin" and 0.18 or 0.1)
        rafaga(pid, math.min(datos.chat.maxReaccion, 1 + cuantos(d.esp * peso)), pid == "blister" and 1.2 or 2)
        emojis.lanzar(EMOJIS_PRODUCTO[pid] or { "sobre" }, 1 + math.floor(d.esp * peso * 0.4), 1.5)
    end
end

-- abres una caja en directo: el chat se anima y llega algo de gente
function directo.caja()
    if not d then return end
    d.quieto = 0
    d.subidon = d.subidon + 0.3
    if d.esp >= 1 then
        rafaga("caja", math.min(datos.chat.maxReaccion, 1 + cuantos(d.esp * 0.25)), 2)
        emojis.lanzar({ "fuego", "W", "ojos", "flipa", "rana", "ILLO", "OLE", "claqueta" }, 2 + math.floor(d.esp * 0.1), 2)
    end
end

function directo.suspense()
    if not d or d.esp < 3 then return end
    rafaga("suspense", cuantos(math.min(5, d.esp * 0.06)), 0.8)
end

function directo.carta(def, nueva)
    if not d then return end
    d.quieto = 0
    local r = rarezas.de(def)
    -- las ALT reaccionan como la rareza de encima; SILVER y GOLDEN, como una chase
    local rid = rarezas.lista[r.nivel].id
    local chase = def.chase or r.especial
    local C = datos.chat
    -- reacciones: con poca gente solo a lo bueno
    local n
    if d.esp < 4 then
        n = (r.nivel >= 4 and d.esp >= 1 and love.math.random() < 0.6) and 1 or 0
    else
        n = math.min(C.maxReaccion, cuantos(d.esp * (C.reaccion[rid] or 0)))
    end
    if n > 0 then rafaga(rid, n, r.nivel >= 5 and 2.5 or 1.2) end
    if r.especial and d.esp >= 1 then
        rafaga("godpack", math.min(C.maxReaccion, 2 + cuantos(d.esp * 0.5)), 2)
        emojis.lanzar({ "corona", "diamante", "corona", "diamante", "OMG", "flipa" }, 6 + math.floor(d.esp * 0.1), 2.5)
    end
    -- emojis: de rara para arriba, mas cuanta mas gente y mejor la carta
    if r.nivel >= 3 and d.esp >= 1 then
        local tipos = ({ { "corazon", "fuego", "rana" }, { "fuego", "corazon", "ojos", "flipa", "diamante" },
                         { "fuego", "estrella", "67", "POG", "flipa", "cohete" },
                         { "estrella", "fuego", "67", "W", "corona", "OMG", "flipa", "diamante" } })[r.nivel - 2]
        emojis.lanzar(tipos, 1 + math.floor(d.esp * 0.05 * (r.nivel - 2)), r.nivel >= 5 and 2 or 1)
    end
    if chase and d.esp >= 1 then emojis.lanzar({ "corona", "estrella", "diamante", "100" }, 3, 1.5) end
    if chase and d.esp >= 1 then rafaga("chase", math.min(C.maxReaccion, 1 + cuantos(d.esp * 0.3)), 2) end
    if nueva and d.esp >= 6 and love.math.random() < 0.3 then decir("nueva", 0.8) end
    -- la que buscabas: el chat lo celebra
    local enc = partida.encontradas
    if enc and enc[#enc] == def.id and d.buscada ~= def.id and d.esp >= 1 then
        d.buscada = def.id
        rafaga("buscada", math.min(C.maxReaccion, 1 + cuantos(d.esp * 0.2)), 1.5)
        emojis.lanzar({ "trofeo", "estrella", "W" }, 2 + math.floor(d.esp * 0.05), 1.5)
    end
    -- repetidas de las de siempre: alguno se da cuenta
    if not nueva and r.nivel <= 3 and d.esp >= 5 and partida.copias(def.id) >= 3 and love.math.random() < 0.06 then
        decir("repetida", 0.6)
    end
    -- lo gordo: el chat se pone a copiar lo mismo
    local probCadena = chase and 1 or ({ holo = 0.2, fullart = 0.55, secreta = 0.9 })[rid]
    if probCadena and love.math.random() < probCadena then cadena(chase and "chase" or rid) end
    -- las buenas traen mirones y propinas al momento
    local S = datos.subidon
    local P = datos.propinas
    local viral = P.viral[rid] or chase
    local f = viral and 1 or factorRitmo()
    d.subidon = d.subidon + ((S[rid] or 0) + (chase and S.chase or 0)) * f
    local mult = ((P.rareza[rid] or 0) + (chase and P.chase or 0)) * f
    if mult > 0 then cobrarPropinas(tirarPropinas(d.esp, mult, viral), 0.8) end
    -- en la venta, lo bueno da ganas de comprar
    if d.tipo == "venta" then
        local H = V.hype
        d.hype = math.min(H.max, d.hype + (H[rid] or 0) + (chase and H.chase or 0))
    end
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

-- venta de sobres: el chat compra sobres que tienes y tu los abres


-- precio de mercado de un sobre de esa edicion
local function precioSobre(t, primera)
    return mercado.sellado(t, primera) or mercado.sellado(t, not primera) or t.precio
end

-- la edicion que sale al sacar un sobre (primero las normales, como la mesa)
local function edicionQueSale(t)
    -- ESPACIO saca primero de la caja abierta, luego de los guardados
    local caja = partida.cajaAbierta
    if caja and caja.tipo == t.id and caja.quedan > 0 then return caja.primera == true end
    if partida.sobres(t.id) > 0 then return partida.sobres(t.id, false) <= 0 end
    -- solo hay cajas cerradas: la que se abriria
    return partida.cajasDe(t.id, false) <= 0
end

local function sobresEnVenta()
    local lista = {}
    local caja = partida.cajaAbierta
    for _, t in ipairs(sobres.lista) do
        -- los de la caja abierta y los de las cajas cerradas tambien se venden
        if partida.disponibles(t.id) > 0 or partida.cajasDisponibles(t.id) > 0
            or (caja and caja.tipo == t.id and caja.quedan > 0) then table.insert(lista, t) end
    end
    return lista
end

-- lo que puedes vender ahora de un tipo de sobre: sobres sueltos (guardados,
-- de la caja abierta y de blisters) y productos enteros
local function sobresDe(t)
    local caja = partida.cajaAbierta
    local n = partida.disponibles(t.id) + partida.prodDisponibles("blister", t.id) * productos.blister.sobres
    if caja and caja.tipo == t.id then n = n + caja.quedan end
    return n + partida.cajasDisponibles(t.id) * sobres.caja.sobres
end

local function pedidoDe(nombre)
    for _, pe in ipairs(d.pedidos) do if pe.nombre == nombre then return pe end end
end

-- nombre: si lo pide alguien de tu chat de Twitch (!comprar)
local function nuevoPedido(nombre, color)
    local lista = sobresEnVenta()
    if #lista == 0 then return end
    -- que se puede pedir y con que peso
    local W = V.pedir
    local opciones_, total = {}, 0
    local function poner_(o, peso)
        table.insert(opciones_, { o = o, peso = peso })
        total = total + peso
    end
    for _, t in ipairs(lista) do
        poner_({ t = t, n = 1 }, W.sobre / #lista)
        local hay = sobresDe(t)
        if hay >= 2 then poner_({ t = t, n = love.math.random(2, math.min(V.maxVarios, hay)) }, W.varios / #lista) end
    end
    for _, t in ipairs(sobres.lista) do
        for _, pid in ipairs({ "blister", "etb" }) do
            if partida.prodDisponibles(pid, t.id) > 0 then poner_({ t = t, n = productos[pid].sobres, prod = pid }, W[pid]) end
        end
    end
    local r = love.math.random() * total
    local elegido = opciones_[#opciones_].o
    for _, x in ipairs(opciones_) do
        r = r - x.peso
        if r <= 0 then elegido = x.o break end
    end
    local t = elegido.t
    local margen = V.margen[1] + love.math.random() * (V.margen[2] - V.margen[1])
        + math.min(V.margenMax, d.esp * V.margenPorEspectador) + d.hype * V.hype.margen
    margen = 1 + (margen - 1) * partida.efecto("aro")
    local idioma = partida.canal.idioma
    local codigo = sets[t.set].codigo
    local clave = elegido.prod or (elegido.n > 1 and "varios" or "compra")
    local texto = azar(V.textos[idioma][clave]):gsub("{s}", codigo):gsub("{n}", tostring(elegido.n))
    local largo = elegido.n > 1
    local pe = { tipo = t.id, codigo = codigo, margen = margen, t = V.segundos * (largo and V.masTiempo or 1),
                 nombre = nombre or nombreAlAzar(), color = color or colorAlAzar(), n = elegido.n, hechos = 0,
                 prod = elegido.prod, real = nombre ~= nil }
    table.insert(d.pedidos, pe)
    if not nombre then table.insert(cola, { t = 0, nombre = pe.nombre, color = pe.color, texto = texto }) end
    sonido.tocar("nueva", 1.4)
    return pe
end

-- lo que pone en la lista: S1, 3X S1, BL S1, ETB S1
function directo.codigoPedido(pe)
    if pe.prod == "blister" then return "BL " .. pe.codigo end
    if pe.prod == "etb" then return "ETB " .. pe.codigo end
    if (pe.n or 1) > 1 then return (pe.n - (pe.hechos or 0)) .. "X " .. pe.codigo end
    return pe.codigo
end

-- precio que pagaria ahora un pedido (por sobre; un producto, entero)
function directo.precioPedido(pe, primera)
    local t
    for _, s_ in ipairs(sobres.lista) do if s_.id == pe.tipo then t = s_ end end
    if pe.prod then
        if primera == nil then primera = partida.sinApartar(pe.prod, t.id, false) <= 0 end
        local v = mercado.valorProd(productos[pe.prod], t, primera) / sobres.caja.valor
        return math.floor(v * pe.margen / 10 + 0.5) * 10
    end
    if primera == nil then primera = edicionQueSale(t) end
    return math.floor(precioSobre(t, primera) * pe.margen / 10 + 0.5) * 10
end

-- lo que pone en la lista: un producto, entero; varios sobres, lo que queda
function directo.totalPedido(pe)
    local precio = directo.precioPedido(pe)
    if pe.prod then return precio end
    return precio * ((pe.n or 1) - (pe.hechos or 0))
end

function directo.pedidos()
    return d and d.pedidos or {}
end

local function cobrar(pe, precio, texto)
    pe.cobrado = (pe.cobrado or 0) + precio
    partida.dinero = partida.dinero + precio
    partida.canal.ventas = (partida.canal.ventas or 0) + 1
    d.ventas, d.ingresos = d.ventas + 1, d.ingresos + precio
    poner({ sistema = true, texto = texto .. pe.nombre:upper() .. ": +" .. ui.dinero(precio), color = p.lima, nace = d.t })
    sonido.tocar("moneda", 1.1)
    fx.monedas(570, 200, 10, 120, 200)
end

-- abres un blister o una ETB que alguien ha comprado: se cobra entero y sus
-- sobres son del comprador
function directo.abrirProducto(pid, tipoId, primera)
    if not d or d.tipo ~= "venta" or not d.vendiendo then return nil end
    for _, pe in ipairs(d.pedidos) do
        if pe.prod == pid and pe.tipo == tipoId and not pe.empezado then
            pe.empezado = true
            pe.prepago = productos[pid].sobres
            cobrar(pe, directo.precioPedido(pe, primera), (pid == "etb" and "ETB" or "BLÍSTER") .. " VENDIDO A ")
            partida.guardar()
            return pe
        end
    end
end

-- la mesa empieza a abrir un sobre: si alguien lo ha comprado, cobras y las
-- cartas son suyas (devuelve el pedido o nil)
function directo.reservar(tipo, primera)
    if not d or d.tipo ~= "venta" or not d.vendiendo then return nil end
    -- primero los sobres de un blister o una ETB ya pagados
    for i, pe in ipairs(d.pedidos) do
        if pe.tipo == tipo.id and (pe.prepago or 0) > 0 then
            pe.prepago = pe.prepago - 1
            pe.hechos = pe.hechos + 1
            pe.acabado = pe.prepago <= 0
            pe.deUltimo = 0
            if pe.acabado then table.remove(d.pedidos, i) end
            d.comprador = pe
            return pe
        end
    end
    for i, pe in ipairs(d.pedidos) do
        if pe.tipo == tipo.id and not pe.prod then
            local precio = directo.precioPedido(pe, primera)
            pe.hechos = (pe.hechos or 0) + 1
            pe.empezado = true
            pe.acabado = pe.hechos >= (pe.n or 1)
            pe.deUltimo = precio
            if pe.acabado then table.remove(d.pedidos, i) end
            cobrar(pe, precio, "VENDIDO A ")
            d.comprador = pe
            partida.guardar()
            return pe
        end
    end
end

-- el sobre vendido se guarda sin abrir: se devuelve el dinero y el pedido
-- vuelve a la lista
function directo.anularReserva(pe)
    if not pe or not pe.deUltimo then return end
    local precio = pe.deUltimo
    pe.deUltimo = nil
    if pe.prepago then
        pe.prepago = pe.prepago + 1
    else
        pe.cobrado = (pe.cobrado or 0) - precio
        partida.dinero = partida.dinero - precio
        partida.canal.ventas = math.max(0, (partida.canal.ventas or 1) - 1)
    end
    pe.hechos = math.max(0, (pe.hechos or 1) - 1)
    if pe.hechos == 0 and not pe.prepago then pe.empezado = nil end
    local estaba = pe.acabado
    pe.acabado = nil
    if not d then return end
    if not pe.prepago then
        d.ventas, d.ingresos = math.max(0, d.ventas - 1), d.ingresos - precio
        poner({ sistema = true, texto = "VENTA ANULADA: -" .. ui.dinero(precio), color = p.naranja, nace = d.t })
    end
    d.comprador = nil
    if estaba then table.insert(d.pedidos, 1, pe) end
    partida.guardar()
end

function directo.forzarPedido()
    if d then nuevoPedido() end
end

function directo.forzarPeticion()
    if d then nuevaPeticion() end
end

function directo.finSobre(defs, godpack, tipoId)
    if not d then return end
    if tipoId then revisarPeticion(tipoId) end
    d.sobres = d.sobres + 1
    -- el comprador reacciona a lo que le ha tocado
    local comprador = d.comprador
    d.comprador = nil
    d.quieto = 0
    local mejor, chase = mejorDe(defs, godpack)
    local bueno = rarezas[mejor.rareza].nivel >= 4 or chase or godpack
    if rarezas[mejor.rareza].nivel <= 2 and d.esp >= 4 and love.math.random() < 0.5 then emojis.lanzar({ "calavera", "payaso", "L", "risa", "mueca", "XD", "chancla", "roto" }, 2, 1) end
    if rarezas[mejor.rareza].nivel <= 2 and d.esp >= 8 and love.math.random() < 0.08 then cadena("mal") end
    -- rachas: varios sobres buenos seguidos animan el directo
    d.racha = bueno and (d.racha or 0) + 1 or 0
    if d.racha >= 2 and d.esp >= 1 then
        rafaga("racha", math.min(datos.chat.maxReaccion, 1 + cuantos(d.esp * 0.12 * math.min(d.racha, 4))), 1.5)
        emojis.lanzar({ "rayo", "fuego", "cohete", "musculo", "OLE" }, 1 + d.racha, 1.2)
        d.subidon = d.subidon + 0.04 * math.min(d.racha, 4)
    end
    if comprador then
        local idioma = partida.canal.idioma
        comprador.suerte = comprador.suerte or bueno
        if comprador.acabado then
            local suerte = comprador.suerte
            table.insert(cola, { t = 0.4, nombre = comprador.nombre, color = comprador.color,
                                 texto = azar(V.textos[idioma][suerte and "bien" or "mal"]) })
            if suerte then
                ganarSeguidores(V.seguidoresSuerte)
                d.subidon = d.subidon + 0.2
            end
        else
            -- aun le quedan sobres
            table.insert(cola, { t = 0.4, nombre = comprador.nombre, color = comprador.color,
                                 texto = azar(V.textos[idioma][bueno and "bien" or "otro"]) })
        end
    end
    marcarSobre()
    local f = factorRitmo()
    ganarSeguidores(directo.seguidoresSobre(d.esp, mejor, chase, godpack, f))
    cobrarPropinas(tirarPropinas(d.esp, f), 0.5)
    if godpack then cobrarPropinas(tirarPropinas(d.esp, datos.propinas.godpack, true), 1) end
    if d.tipo == "venta" then d.hype = math.min(V.hype.max, d.hype + V.hype.sobre + (godpack and V.hype.godpack or 0)) end
    if d.esp <= 3 then
        if love.math.random() < datos.chat.finSobre then decir("finSobre", 0.6 + love.math.random()) end
    elseif love.math.random() < 0.3 then
        decir("finSobre", 0.5 + love.math.random())
    end
end

-- lo que el juego reconoce en tu chat de Twitch
local SALUDOS = { "^hola", "^buenas", "^holi", "^hi$", "^hi ", "^hello", "^hey", "^ey", "^wenas", "^saludos" }
local HYPE = { "pog", "vamo", "lets go", "omg", "gg", "aura", "w ", "^w$", "fire", "goat", "6.7", "brutal", "locura" }
local COMPRAR = { "^!comprar", "^!buy", "^!compro" }

local function tiene(texto, lista)
    for _, patron in ipairs(lista) do if texto:find(patron) then return true end end
    return false
end

-- un mensaje (o un aviso de raid o sub) de tu chat real
function directo.mensajeReal(m)
    if not d then return end
    if m.aviso == "raid" then
        poner({ sistema = true, texto = "RAID DE " .. m.nombre:upper() .. " CON " .. m.cuantos .. " PERSONAS", color = p.violeta, nace = d.t })
        emojis.lanzar({ "cohete", "fuego", "corazon", "flipa", "W" }, math.min(20, 6 + m.cuantos), 2)
        d.subidon = d.subidon + math.min(0.6, 0.1 + math.log(m.cuantos + 1) * 0.08)
        sonido.tocar("nueva")
        return
    elseif m.aviso == "sub" then
        poner({ sistema = true, texto = (m.texto ~= "" and m.texto or (m.nombre .. " SE SUSCRIBE")):upper(), color = p.violeta, nace = d.t })
        emojis.lanzar({ "corazon", "estrella", "corona" }, 5, 1.2)
        return
    end
    m.nace = d.t
    poner(m)
    d.quieto = 0
    local texto = m.crudo or ""
    -- emotes que suben por el chat
    if m.emotes then emojis.lanzar(m.emotes, math.min(3, #m.emotes), 0.5) end
    -- hype de tu chat: anima un poco el directo (con un tope)
    if (m.emotes or tiene(texto, HYPE)) and d.t - (d.ultimoHype or -99) > 3 then
        d.ultimoHype = d.t
        d.subidon = math.min(d.subidon + 0.02, 2.5)
        if d.tipo == "venta" then d.hype = math.min(V.hype.max, d.hype + 0.03) end
    end
    -- saludos: con el chat mezclado alguien del juego le contesta
    if tiene(texto, SALUDOS) and not callado() and d.esp >= 1 and love.math.random() < 0.5 then
        local idioma = partida.canal.idioma
        local hola = idioma == "es" and { "hola ", "buenas ", "ey ", "bienvenido " } or { "hi ", "welcome ", "hey " }
        table.insert(cola, { t = 1 + love.math.random() * 2, nombre = nombreAlAzar(), color = colorAlAzar(),
                             texto = azar(hola) .. m.nombre })
    end
    -- !comprar en un directo de venta: compra de verdad (lo que salga)
    if tiene(texto, COMPRAR) and d.tipo == "venta" and d.vendiendo and #d.pedidos < V.max + 2 and not pedidoDe(m.nombre) then
        local pe = nuevoPedido(m.nombre, m.color)
        if pe then
            poner({ sistema = true, texto = m.nombre:upper() .. " COMPRA " .. directo.codigoPedido(pe), color = p.lima, nace = d.t })
        end
    end
end

-- cada frame (tambien fuera de la mesa: el directo sigue)
function directo.update(dt, enMesa)
    -- el chat de Twitch se lee siempre (sin directo se tira)
    local reales = twitch.update(dt)
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
    if d.tipo == "venta" then
        d.hype = d.hype * math.exp(-V.hype.baja * dt)
        -- con las ventas paradas los pedidos esperan (no corre su tiempo)
        for i = #d.pedidos, 1, -1 do
            local pe = d.pedidos[i]
            if d.vendiendo and not pe.empezado then pe.t = pe.t - dt end
            if pe.t <= 0 then
                table.remove(d.pedidos, i)
                table.insert(cola, { t = 0, nombre = pe.nombre, color = pe.color,
                                     texto = azar(V.textos[partida.canal.idioma].caducada) })
            end
        end
        if d.vendiendo and #d.pedidos < V.max and d.esp >= V.espectadoresMin then
            if not d.primerPedido and d.t > V.primero then
                -- el primero llega pronto para que no estes parado
                d.primerPedido = true
                nuevoPedido()
            elseif d.t > 8 then
                local perfil = partida.efecto("perfil")
                local porMinuto = math.min(V.maxPorMinuto * (1 + (perfil - 1) * 0.5),
                    (V.porMinuto + d.esp * V.porEspectador) * (1 + d.hype) * perfil)
                if love.math.random() < porMinuto * dt / 60 then nuevoPedido() end
            end
        end
    elseif d.peticion then
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

    -- chat real de Twitch
    for _, m in ipairs(reales) do directo.mensajeReal(m) end

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
                -- las gordas salen destacadas arriba del chat un rato
                if m.propina >= datos.propinas.destacada then
                    d.destacada = { m = m, hasta = d.t + datos.propinas.segundosDestacada }
                    emojis.lanzar({ "moneda", "billete", "corazon", "regalo" }, 3, 0.8)
                end
                if enMesa then fx.monedas(570, 200, math.min(30, 4 + m.propina / 100), 120, 200) end
                partida.guardar()
            elseif m.sigue then
                partida.canal.seguidores = partida.canal.seguidores + m.sigue
                d.seguidores = d.seguidores + m.sigue
                if enMesa then sonido.tocar("encima", 1.6) end
                partida.guardar()
            end
            m.nace = d.t
            -- sin nadie mirando no escribe nadie (salvo tu chat de verdad)
            if m.sistema or m.sigue or m.propina or m.real or directo.espectadores() > 0 then poner(m) end
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
    -- con el tutorial ya lo señala la mascota
    return not d and partida.canal.directos < datos.avisarHasta and not partida.tutorial
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
    local tutorial = partida.tutorial
    if not tutorial then fx.aura(x + w / 2, by + 11, p.rojo, 70, (aviso and 0.5 or 0.28) * pulso) end
    ui.boton("dir_empezar", "EMPEZAR DIRECTO", x + temblor, by, w, 22,
        { p.rojo[1] * (0.8 + pulso * 0.3), p.rojo[2] * pulso, p.rojo[3] * pulso }, not editando)
    if math.floor(t * 2) % 2 == 0 then
        lg.setColor(p.blanco)
        lg.circle("fill", x + temblor + 10, by + 10, 3)
    end
    if editando or tutorial then return end
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

-- X roja para rechazar una compra: cuadrado de 9x9 con la X pintada a
-- pixeles (en el movil se toca en un hueco mas grande, sin crecer)
local function botonRechazar(id, x, y)
    local enc = ui.encima == id
    lg.setColor(p.negro)
    lg.rectangle("fill", x, y + 1, 9, 9)
    lg.setColor(enc and p.naranja or p.rojo)
    lg.rectangle("fill", x, y, 9, 9)
    lg.setColor(p.blanco)
    for i = 0, 4 do
        lg.rectangle("fill", x + 2 + i, y + 2 + i, 1, 1)
        lg.rectangle("fill", x + 6 - i, y + 2 + i, 1, 1)
    end
    lg.setColor(1, 1, 1)
    local m = ui.tactil and 3 or 1
    ui.zona(id, x - m, y - m, 9 + 2 * m, 9 + 2 * m)
end

local function lineasMensaje(m, w)
    if m.sistema then
        -- partidas, que las largas (VENDIDO A ...) se salian del chat
        local res = {}
        -- el euro va pegado a su cifra (que no se quede solo en otra linea)
        for i, l in ipairs(partir((m.texto:gsub(" €", "€")), w)) do res[i] = { { l, m.color } } end
        return res
    end
    if m.sigue then
        local suyo = datos.textos[partida.canal.idioma].sigue
        return { { { m.nombre, m.color }, { " " .. suyo, p.lima } } }
    end
    local cabeza = m.nombre .. ":"
    local cuerpo = m.texto or ""
    if m.propina then cuerpo = ui.dinero(m.propina) .. " " .. cuerpo end
    -- solo emojis: el nombre y los emojis en la misma fila
    if cuerpo == "" and m.emotes then return { { emotes = m.emotes, cabeza = { cabeza, m.color } } } end
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
    if m.emotes then table.insert(res, { emotes = m.emotes }) end
    return res
end

local function altoLinea(l)
    return l.emotes and 10 or 7
end

-- una fila de emojis (con el nombre delante si va solo)
local function pintarEmotes(l, x, y)
    if l.cabeza then
        fuentes.texto(l.cabeza[1], x, y + 2, 1, l.cabeza[2])
        x = x + fuentes.ancho(l.cabeza[1]) + 3
    end
    for _, k in ipairs(l.emotes) do
        emojis.pintar(k, x, y, 1)
        x = x + emojis.ancho(k) + 2
    end
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
    elseif d.tipo == "venta" then
        local n = #d.pedidos
        local alto = math.max(1, n) * 10 + 12
        lg.setColor(p.lima[1], p.lima[2], p.lima[3], 0.12)
        lg.rectangle("fill", x + 2, y + 23, w - 4, alto)
        -- vender o abrir para ti (el titulo se acorta si no cabe con el boton)
        local textoBoton = d.vendiendo and "VENDIENDO" or "PARA MÍ"
        local anchoBoton = fuentes.ancho("VENDIENDO") + 8
        local titulo = fuentes.ancho("COMPRAS DEL CHAT") + anchoBoton + 14 > w and "COMPRAS" or "COMPRAS DEL CHAT"
        fuentes.texto(titulo, x + 6, y + 26, 1, p.lima)
        ui.boton("dir_vender", textoBoton, x + w - anchoBoton - 4, y + 24, anchoBoton, 9, d.vendiendo and p.verdeosc or p.naranja)
        -- barra de hype: cuanto mas, mas compran y mas pagan
        if d.hype > 0.05 then
            local bw = math.floor((w - 12) * math.min(1, d.hype / V.hype.max))
            lg.setColor(p.naranja)
            lg.rectangle("fill", x + 6, y + 33, bw, 1)
        end
        if n == 0 then
            local hay = #sobresEnVenta() > 0
            -- cada texto con una version corta por si no cabe
            local texto, color = { "ESPERANDO COMPRADORES...", "ESPERANDO..." }, p.gris
            if not d.vendiendo then texto, color = { "VENTAS PARADAS: LOS SOBRES SON TUYOS", "PARADAS: SON TUYOS" }, p.naranja
            elseif not hay then texto, color = { "NO TIENES SOBRES QUE VENDER", "SIN SOBRES QUE VENDER" }, p.naranja end
            local t = fuentes.ancho(texto[1]) <= w - 12 and texto[1] or texto[2]
            fuentes.texto(t, x + 6, y + 35, 1, color)
        elseif not d.vendiendo then
            fuentes.texto("PARADO", x + 60, y + 35, 1, p.naranja)
        end
        -- con la mejora LISTA NEGRA, cada compra se puede rechazar con la X
        local rechazar = partida.efecto("rechazar") >= 1
        for i, pd in ipairs(d.pedidos) do
            local fy = y + 25 + i * 10
            local parpadeo = pd.t < 20 and math.floor(pd.t * 3) % 2 == 0
            local cod = directo.codigoPedido(pd)
            fuentes.texto(cod, x + 6, fy, 1, p.amarillo)
            fuentes.texto(ui.dinero(directo.totalPedido(pd)), x + 10 + math.max(14, fuentes.ancho(cod)), fy, 1, p.lima)
            if pd.empezado then
                local falta = pd.prepago and (pd.prepago .. " SOBRES") or "ABRIENDO"
                fuentes.texto(falta, x, fy, 1, p.cian, "right", w - 8)
            else
                fuentes.texto(string.format("%d:%02d", math.floor(pd.t / 60), math.floor(pd.t % 60)), x, fy, 1,
                    parpadeo and p.rojo or p.blanco, "right", w - (rechazar and 20 or 8))
                if rechazar then botonRechazar("dir_rechazar_" .. i, x + w - 14, fy - 2) end
            end
        end
        tope = y + 25 + alto
    end

    -- propina gorda destacada, fija arriba un rato
    local de = d.destacada
    if de and d.t < de.hasta then
        local m = de.m
        local lineas = partir(m.texto or "", w - 14)
        local alto = 12 + #lineas * 7
        lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.22)
        lg.rectangle("fill", x + 2, tope, w - 4, alto)
        lg.setColor(p.amarillo)
        lg.rectangle("line", x + 2.5, tope + 0.5, w - 5, alto - 1)
        fuentes.texto(m.nombre, x + 6, tope + 3, 1, m.color or p.blanco)
        fuentes.texto(ui.dinero(m.propina), x, tope + 3, 1, p.amarillo, "right", w - 8)
        for k, l in ipairs(lineas) do fuentes.texto(l, x + 6, tope + 3 + k * 7, 1, p.blanco) end
        tope = tope + alto + 2
    elseif de then
        d.destacada = nil
    end

    -- mensajes de abajo arriba
    local fondo = y + h - 4
    local ancho = w - 8
    for i = #chat, 1, -1 do
        local m = chat[i]
        local lineas = lineasMensaje(m, ancho)
        local alto = 2
        for _, l in ipairs(lineas) do alto = alto + altoLinea(l) end
        if fondo - alto < tope then break end
        fondo = fondo - alto
        local entra = m.nace and math.min(1, (d.t - m.nace) / 0.15) or 1
        local dx = math.floor((1 - entra) * 8)
        if m.propina then
            lg.setColor(p.amarillo[1], p.amarillo[2], p.amarillo[3], 0.15)
            lg.rectangle("fill", x + 2, fondo - 1, w - 4, alto)
        end
        local ly = fondo
        for _, l in ipairs(lineas) do
            if l.emotes then pintarEmotes(l, x + 4 + dx, ly) else fuentes.trozos(l, x + 4 + dx, ly, 1) end
            ly = ly + altoLinea(l)
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
        local falta = t.id == "venta" and partida.canal.seguidores < V.desbloqueo
        if t.proximamente or falta then
            ui.caja(x + 6, by, w - 12, 11, p.negro)
            fuentes.texto(t.nombre, x + 10, by + 3, 1, p.gris)
            -- con el texto grande no cabe la palabra larga
            local pronto = falta and (V.desbloqueo .. " SEG.") or "PRÓXIMAMENTE"
            if fuentes.ancho(t.nombre) + fuentes.ancho(pronto) + 10 > w - 16 then pronto = falta and tostring(V.desbloqueo) or "PRONTO" end
            fuentes.texto(pronto, x + 6, by + 3, 1, p.grisosc, "right", w - 16)
        else
            ui.boton("dir_tipo_" .. t.id, t.nombre, x + 6, by, w - 12, 11, tipoElegido == t.id and p.morado or p.grisosc)
        end
    end

    -- tu chat de Twitch (se conecta en OPCIONES)
    local twy = ty + 12 + #datos.tipos * 13
    local conectado = twitch.estado == "conectado"
    local txt = twitch.estado == "apagado" and "CONECTAR TWITCH" or ("TWITCH: " .. (conectado and "CONECTADO" or "..."))
    ui.boton("dir_twitch", txt, x + 6, twy, w - 12, 11, conectado and p.morado or p.grisosc)

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
    elseif id == "dir_vender" then
        if d then d.vendiendo = not d.vendiendo end
    elseif id:match("^dir_rechazar_") then
        local i = tonumber(id:sub(14))
        local pe = d and d.pedidos[i] and not d.pedidos[i].empezado and table.remove(d.pedidos, i)
        if pe then
            table.insert(cola, { t = 0, nombre = pe.nombre, color = pe.color,
                                 texto = azar(V.textos[partida.canal.idioma].rechazada) })
            sonido.tocar("latido")
        end
    elseif id == "dir_twitch" then
        opciones.abrir(function() require("src.tutorial").repetir() end)
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
