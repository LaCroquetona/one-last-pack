-- Chat real de Twitch por IRC. Solo se lee, sin iniciar sesion: entra con un
-- nombre anonimo (justinfan) al canal que pongas en OPCIONES. La conexion va en
-- un hilo aparte para que el juego no se pare; las lineas llegan por un canal
-- y aqui se convierten en mensajes { nombre, color, texto, emotes, ... }.
local p = require "datos.paleta"
local emojis = require "src.emojis"
local utf8 = require "utf8"

local twitch = {}

-- apagado, conectando, conectado o error
twitch.estado = "apagado"
twitch.canal = nil

local HILO = [[
local canal, entrada, salida = ...
require "love.timer"
local socket = require "socket"
local function enviar(s, l) s:send(l .. "\r\n") end
local function parar()
    local orden = entrada:pop()
    return orden == "parar"
end
while true do
    local s = socket.tcp()
    s:settimeout(8)
    local ok, err = s:connect("irc.chat.twitch.tv", 6667)
    if not ok then
        salida:push("!error " .. tostring(err))
    else
        s:settimeout(0.3)
        enviar(s, "CAP REQ :twitch.tv/tags twitch.tv/commands")
        enviar(s, "PASS SCHMOOPIIE")
        enviar(s, "NICK justinfan" .. math.random(10000, 99999))
        enviar(s, "JOIN #" .. canal)
        while true do
            if parar() then s:close() return end
            local linea, e = s:receive("*l")
            if linea then
                if linea:sub(1, 4) == "PING" then enviar(s, "PONG" .. linea:sub(5))
                else salida:push(linea) end
            elseif e ~= "timeout" then
                break
            end
        end
        s:close()
        salida:push("!caido")
    end
    -- se vuelve a intentar a los 5 segundos
    for _ = 1, 50 do
        if parar() then return end
        love.timer.sleep(0.1)
    end
end
]]

local hilo, entrada, salida

-- antispam: como mucho estos mensajes por segundo en pantalla, un mensaje
-- por persona cada tanto y nada de repetir lo mismo enseguida
local POR_SEGUNDO = 3
local ESPERA_USUARIO = 2
local MEMORIA_REPETIDOS = 12
local MAX_LETRAS = 90

local ultimoDe = {}       -- nombre -> segundo en que escribio
local vistos = {}         -- texto -> segundo en que salio
local hueco = POR_SEGUNDO -- mensajes que aun caben este segundo
local reloj = 0

-- el color que pone Twitch, al mas parecido de la paleta del juego
local COLORES = { "rojo", "naranja", "amarillo", "lima", "verde", "celeste", "cian", "violeta", "blanco", "grisclaro" }
local function colorDe(hex)
    local r, g, b = (hex or ""):match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return p[COLORES[math.random(#COLORES)]] end
    r, g, b = tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
    local mejor, dist = p.blanco, math.huge
    for _, k in ipairs(COLORES) do
        local c = p[k]
        local dd = (c[1] - r) ^ 2 + (c[2] - g) ^ 2 + (c[3] - b) ^ 2
        if dd < dist then mejor, dist = c, dd end
    end
    return mejor
end

-- letras de fuera del ASCII que la fuente si sabe pintar
local VALEN = {}
for _, c in ipairs({ "Á", "É", "Í", "Ó", "Ú", "Ü", "Ñ", "á", "é", "í", "ó", "ú", "ü", "ñ", "¿", "¡", "€" }) do VALEN[c] = true end

-- lo que la fuente del juego no sabe pintar fuera (emojis de verdad, etc.)
local function limpiar(texto)
    texto = texto:gsub("[\"@&;~`^{}%[%]|\\]", "")
    local res = {}
    local ok = pcall(utf8.len, texto)
    if not ok or not utf8.len(texto) then return "" end
    for _, cp in utf8.codes(texto) do
        local c = utf8.char(cp)
        if (cp >= 32 and cp < 127) or VALEN[c] then table.insert(res, c) end
    end
    texto = table.concat(res):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if utf8.len(texto) > MAX_LETRAS then texto = texto:sub(1, utf8.offset(texto, MAX_LETRAS + 1) - 1) .. "..." end
    return texto
end

local function desescapar(v)
    return (v or ""):gsub("\\s", " "):gsub("\\:", ";"):gsub("\\\\", "\\")
end

-- una linea del IRC: devuelve un mensaje, un aviso (raid, sub) o nil
local function leer(linea)
    local tags, resto = {}, linea
    if linea:sub(1, 1) == "@" then
        local t
        t, resto = linea:match("^@(%S+) (.*)$")
        if not t then return nil end
        for k, v in t:gmatch("([^;=]+)=([^;]*)") do tags[k] = v end
    end
    local nick, cmd, args = resto:match("^:([^!%s]+)%S* (%u+) ?(.*)$")
    if not cmd then cmd, args = resto:match("^:%S+ (%w+) ?(.*)$") end
    if cmd == "ROOMSTATE" or cmd == "366" then
        return { estado = "conectado" }
    elseif cmd == "PRIVMSG" then
        local texto = args:match("^#%S+ :(.*)$")
        if not texto then return nil end
        -- /me
        texto = texto:gsub("^\1ACTION (.-)\1$", "%1")
        local nombre = tags["display-name"]
        if not nombre or nombre == "" then nombre = nick end
        local badges = tags.badges or ""
        return {
            real = true, nombre = limpiar(nombre), color = colorDe(tags.color), crudo = texto,
            mod = tags.mod == "1" or badges:find("broadcaster") ~= nil, sub = tags.subscriber == "1",
            vip = badges:find("vip") ~= nil,
        }
    elseif cmd == "USERNOTICE" then
        local id = tags["msg-id"]
        local nombre = tags["display-name"] or tags.login or "?"
        if id == "raid" then
            return { aviso = "raid", nombre = limpiar(nombre), cuantos = tonumber(tags["msg-param-viewerCount"]) or 1 }
        elseif id == "sub" or id == "resub" or id == "subgift" or id == "submysterygift" then
            return { aviso = "sub", nombre = limpiar(nombre), texto = limpiar(desescapar(tags["system-msg"])) }
        end
    end
    return nil
end

-- para las pruebas: leer una linea del IRC tal cual
twitch.leer = leer

-- canal: el nombre del canal de Twitch (sin #)
function twitch.conectar(canal)
    canal = (canal or ""):lower():gsub("[^%w_]", "")
    if canal == "" then return false end
    twitch.desconectar()
    entrada, salida = love.thread.newChannel(), love.thread.newChannel()
    hilo = love.thread.newThread(HILO)
    hilo:start(canal, entrada, salida)
    twitch.canal = canal
    twitch.estado = "conectando"
    return true
end

function twitch.desconectar()
    if entrada then entrada:push("parar") end
    hilo, entrada, salida = nil, nil, nil
    twitch.estado = "apagado"
end

function twitch.conectado()
    return twitch.estado == "conectado"
end

-- cada frame: devuelve los mensajes nuevos que pasan el antispam
function twitch.update(dt)
    local nuevos = {}
    if not salida then return nuevos end
    reloj = reloj + dt
    hueco = math.min(POR_SEGUNDO, hueco + POR_SEGUNDO * dt)
    if hilo and hilo:getError() then
        twitch.fallo = hilo:getError()
        twitch.estado = "error"
        hilo = nil
    end
    for _ = 1, 50 do
        local linea = salida:pop()
        if not linea then break end
        if linea:sub(1, 6) == "!error" then
            twitch.estado = "error"
        elseif linea == "!caido" then
            twitch.estado = "conectando"
        else
            local m = leer(linea)
            if m and m.estado then
                twitch.estado = m.estado
            elseif m and m.aviso then
                table.insert(nuevos, m)
            elseif m then
                local texto, lista = emojis.deTwitch(m.crudo)
                m.texto = limpiar(texto)
                m.emotes = #lista > 0 and lista or nil
                m.crudo = m.crudo:lower()
                local clave = m.texto .. "|" .. table.concat(lista, ",")
                local libre = reloj - (ultimoDe[m.nombre] or -99) >= ESPERA_USUARIO
                local nuevo = reloj - (vistos[clave] or -99) >= MEMORIA_REPETIDOS
                -- los mods y el dueño del canal siempre salen
                if (m.mod or (libre and nuevo and hueco >= 1)) and (m.texto ~= "" or m.emotes) then
                    hueco = hueco - 1
                    ultimoDe[m.nombre] = reloj
                    vistos[clave] = reloj
                    table.insert(nuevos, m)
                end
            end
        end
    end
    return nuevos
end

return twitch
