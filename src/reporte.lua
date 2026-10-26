-- Reportes de bugs. El jugador cuenta que ha pasado y se guarda un archivo
-- de texto con su partida, la version, el dispositivo y lo ultimo que ha
-- hecho; tambien se copia al portapapeles para pegarlo en un correo o
-- mensaje. herramientas/reporte.sh lo abre y saca la partida para probarla.
-- Si el juego peta, src/errores.lua guarda uno solo con el error.
local utf8 = require "utf8"
local p = require "datos.paleta"
local fuentes = require "src.fuentes"
local ui = require "src.ui"

local lg = love.graphics

local reporte = {}

-- lo pone src/menu.lua; main.lua pone contexto (dia y pantalla)
reporte.version = "?"
reporte.contexto = function() return "" end

local CARPETA = "reportes"
local MAX_ACCIONES = 200
local MAX_TEXTO = 300

-- ultimas acciones del jugador (clicks, teclas, pantallas, sobres)
local acciones = {}

function reporte.apuntar(que)
    local ok, ctx = pcall(reporte.contexto)
    table.insert(acciones, string.format("%8.1f %s %s", love.timer.getTime(), ok and ctx or "", tostring(que)))
    if #acciones > MAX_ACCIONES then table.remove(acciones, 1) end
end

-- en lineas de 76 para que se pueda pegar en cualquier sitio
local function trocear(cad)
    local lineas = {}
    for i = 1, #cad, 76 do lineas[#lineas + 1] = cad:sub(i, i + 75) end
    return table.concat(lineas, "\n")
end

local function dispositivo()
    local w, h = love.graphics.getDimensions()
    local mayor, menor, rev = love.getVersion()
    return string.format("%s, pantalla %dx%d, LOVE %d.%d.%d, %d nucleos", love.system.getOS(), w, h,
        mayor, menor, rev, love.system.getProcessorCount())
end

-- partidaTexto: la partida (si no, la guardada en el archivo)
function reporte.contenido(texto, error, partidaTexto)
    local partes = {
        "ONE LAST PACK - REPORTE DE BUG",
        "version: " .. tostring(reporte.version),
        "fecha: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "dispositivo: " .. dispositivo(),
    }
    local ok, ctx = pcall(reporte.contexto)
    if ok then table.insert(partes, "donde: " .. ctx) end
    table.insert(partes, "")
    table.insert(partes, "--- QUE HA PASADO ---")
    table.insert(partes, (texto and texto ~= "") and texto or "(sin texto)")
    if error then
        table.insert(partes, "")
        table.insert(partes, "--- ERROR ---")
        table.insert(partes, error)
    end
    table.insert(partes, "")
    table.insert(partes, "--- ULTIMAS ACCIONES ---")
    for _, a in ipairs(acciones) do table.insert(partes, a) end
    table.insert(partes, "")
    table.insert(partes, "--- PARTIDA ---")
    if partidaTexto then
        local bien, codigo = pcall(function()
            local comprimida = love.data.compress("string", "zlib", partidaTexto, 9)
            return love.data.encode("string", "base64", comprimida)
        end)
        table.insert(partes, bien and trocear(codigo) or "(no se pudo comprimir)")
    else
        table.insert(partes, "(sin partida)")
    end
    table.insert(partes, "--- FIN ---")
    return table.concat(partes, "\n") .. "\n"
end

-- guarda el reporte: devuelve el nombre del archivo y el texto
function reporte.guardar(texto, error, partidaTexto)
    local contenido = reporte.contenido(texto, error, partidaTexto)
    love.filesystem.createDirectory(CARPETA)
    local nombre = CARPETA .. "/reporte_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    love.filesystem.write(nombre, contenido)
    return nombre, contenido
end

function reporte.copiar(contenido)
    return (pcall(love.system.setClipboardText, contenido))
end

-- en el PC se abre la carpeta de los reportes; en el movil no se puede
function reporte.puedeAbrirCarpeta()
    local so = love.system.getOS()
    return so == "Windows" or so == "OS X" or so == "Linux"
end

function reporte.abrirCarpeta()
    love.filesystem.createDirectory(CARPETA)
    pcall(love.system.openURL, "file://" .. love.filesystem.getSaveDirectory() .. "/" .. CARPETA)
end

-- pantalla para escribirlo (desde el menu)

local escrito          -- lo que lleva escrito (nil: no se esta escribiendo)
local hecho            -- { nombre, copiado } cuando ya se ha guardado
local leerPartida      -- de donde sale la partida (la pone quien lo abre)

function reporte.escribiendo()
    return ui.overlay ~= nil and escrito ~= nil and not hecho
end

local function cerrar()
    love.keyboard.setTextInput(false)
    escrito, hecho = nil, nil
    ui.overlay = nil
end

local function enviar()
    local partidaTexto
    if leerPartida then
        local ok, t = pcall(leerPartida)
        if ok then partidaTexto = t end
    end
    local nombre, contenido = reporte.guardar(escrito, nil, partidaTexto)
    love.keyboard.setTextInput(false)
    hecho = { nombre = nombre, copiado = reporte.copiar(contenido) }
end

local function dibujar(ancho, alto)
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", -ancho, -alto, ancho * 3, alto * 3)
    local w, h = 360, 176
    local x, y = 320 - w / 2, 172 - h / 2
    ui.caja(x, y, w, h)
    fuentes.texto("REPORTAR UN BUG", x, y + 8, 2, p.amarillo, "center", w)
    if hecho then
        local lineas = {
            { "REPORTE GUARDADO", p.lima },
            { hecho.nombre:upper(), p.blanco },
            { "", p.blanco },
            { hecho.copiado and "TAMBIÉN ESTÁ COPIADO: PÉGALO EN UN CORREO O UN MENSAJE" or "NO SE HA PODIDO COPIAR AL PORTAPAPELES", p.grisclaro },
            { "Y MÁNDASELO AL DESARROLLADOR. ¡GRACIAS!", p.grisclaro },
        }
        local ly = y + 34
        for _, l in ipairs(lineas) do
            fuentes.texto(l[1], x, ly, 1, l[2], "center", w)
            ly = ly + 10
        end
        if reporte.puedeAbrirCarpeta() then
            ui.boton("rep_carpeta", "ABRIR CARPETA", x + w / 2 - 94, y + h - 24, 90, 16, p.azul)
            ui.boton("rep_vale", "VALE", x + w / 2 + 4, y + h - 24, 90, 16, p.verde)
        else
            ui.boton("rep_vale", "VALE", x + w / 2 - 45, y + h - 24, 90, 16, p.verde)
        end
        return
    end
    fuentes.texto("CUENTA QUÉ HA PASADO Y QUÉ ESTABAS HACIENDO:", x + 12, y + 30, 1, p.grisclaro)
    -- la caja de texto: al tocarla sale el teclado (en el movil)
    local bx, by, bw, bh = x + 12, y + 40, w - 24, 84
    lg.setColor(p.negro)
    lg.rectangle("fill", bx, by, bw, bh)
    lg.setColor(p.gris)
    lg.rectangle("line", bx + 0.5, by + 0.5, bw - 1, bh - 1)
    local visto = fuentes.limpiar(escrito:upper())
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then visto = visto .. "_" end
    if escrito == "" then
        fuentes.texto("TOCA AQUÍ PARA ESCRIBIR", bx + 4, by + 4, 1, p.grisosc)
    else
        fuentes.parrafo(visto, bx + 4, by + 4, p.blanco, bw - 8)
    end
    ui.zona("rep_caja", bx, by, bw, bh)
    fuentes.texto(utf8.len(escrito) .. "/" .. MAX_TEXTO, bx, by + bh + 3, 1, p.gris, "right", bw)
    fuentes.texto("SE GUARDA TU PARTIDA PARA PODER VER EL FALLO", x + 12, by + bh + 3, 1, p.gris)
    ui.boton("rep_cancelar", "CANCELAR", x + w / 2 - 94, y + h - 24, 90, 16, p.gris)
    ui.boton("rep_enviar", "GUARDAR REPORTE", x + w / 2 + 4, y + h - 24, 90, 16, p.verde, escrito ~= "")
end

local function click(id)
    if id == "rep_caja" then
        love.keyboard.setTextInput(true)
    elseif id == "rep_cancelar" or id == "rep_vale" then
        cerrar()
    elseif id == "rep_enviar" then
        if escrito ~= "" then enviar() end
    elseif id == "rep_carpeta" then
        reporte.abrirCarpeta()
    end
end

-- de: funcion que devuelve la partida en texto
function reporte.abrir(de)
    escrito, hecho, leerPartida = "", nil, de
    ui.overlay = { dibujar = dibujar, click = click }
    love.keyboard.setTextInput(true)
end

function reporte.texto(t)
    if not reporte.escribiendo() then return false end
    for _, cp in utf8.codes(t) do
        local c = utf8.char(cp)
        if utf8.len(escrito) < MAX_TEXTO and c ~= "\n" then escrito = escrito .. c end
    end
    return true
end

function reporte.tecla(tecla)
    if not reporte.escribiendo() then return false end
    if tecla == "backspace" then
        local n = utf8.len(escrito)
        if n > 0 then escrito = escrito:sub(1, utf8.offset(escrito, n) - 1) end
    elseif tecla == "escape" then
        cerrar()
    end
    return true
end

return reporte
