-- Todos los sonidos se generan al arrancar, asi el prototipo no necesita archivos.
-- Cuando haya .ogg de verdad se cargan con love.audio.newSource y listo.
local rarezas = require "datos.rarezas"

local sonido = {}
local fuentes = {}
-- volumen de 0 a 1 (src/opciones.lua los cambia)
sonido.vol = { musica = 0.6, efectos = 1 }
-- musica: la que suena, a que volumen va y hacia donde
local musica, musicaNivel, musicaHacia, musicaVel = nil, 0, 0, 1
local bucleCarga
local TASA = 44100

local function crear(duracion, onda)
    local n = math.floor(duracion * TASA)
    local datos = love.sound.newSoundData(n, TASA, 16, 1)
    for i = 0, n - 1 do
        local v = onda(i / TASA, i / n)
        datos:setSample(i, math.max(-1, math.min(1, v)))
    end
    return love.audio.newSource(datos, "static")
end

local function cuadrada(f, t)
    return math.sin(2 * math.pi * f * t) >= 0 and 1 or -1
end

local function ruido()
    return love.math.random() * 2 - 1
end

function sonido.preparar()
    fuentes.giro = crear(0.06, function(_, p)
        return ruido() * (1 - p) ^ 3 * 0.25
    end)

    local previo = 0
    fuentes.rasgar = crear(0.45, function(_, p)
        previo = previo + (ruido() - previo) * 0.35
        return previo * (1 - p) ^ 1.5 * 0.8
    end)

    fuentes.latido = crear(0.18, function(t, p)
        return math.sin(2 * math.pi * (70 - 35 * p) * t) * (1 - p) ^ 2 * 0.9
    end)

    fuentes.nueva = crear(0.16, function(t, p)
        local f = p < 0.5 and 1568 or 2093
        return cuadrada(f, t) * (1 - p) * 0.08
    end)

    fuentes.encima = crear(0.025, function(t, p)
        return cuadrada(1800, t) * (1 - p) * 0.03
    end)

    fuentes.click = crear(0.05, function(t, p)
        return cuadrada(900 - 400 * p, t) * (1 - p) * 0.09
    end)

    fuentes.moneda = crear(0.2, function(t, p)
        local f = p < 0.3 and 1318.5 or 1975.5
        return cuadrada(f, t) * (1 - p) * 0.09
    end)

    -- arpegio que sube mas notas cuanto mas rara es la carta
    local notas = {523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0}
    for _, r in ipairs(rarezas.lista) do
        local n = r.nivel
        local paso = 0.065
        local cola = n >= 3 and 0.4 or 0.08
        fuentes[r.id] = crear(paso * (n - 1) + cola, function(t)
            local i = math.min(n, math.floor(t / paso) + 1)
            local largo = i == n and cola or paso
            local env = math.max(0, 1 - (t - (i - 1) * paso) / largo)
            local f = notas[i]
            return (cuadrada(f, t) * 0.15 + math.sin(math.pi * f * t) * 0.15) * env
        end)
    end

    -- 110 Hz * 0.5 s = ciclos exactos, el bucle no hace clic
    bucleCarga = crear(0.5, function(t)
        return (2 * ((110 * t) % 1) - 1) * 0.2
    end)
    bucleCarga:setLooping(true)
end

function sonido.tocar(nombre, tono)
    if sonido.vol.efectos <= 0 then return end
    local s = fuentes[nombre]:clone()
    s:setPitch(tono or 1)
    s:setVolume(sonido.vol.efectos)
    s:play()
end

-- musica en bucle (archivo .ogg); si ya suena esa, sigue. Entra con fundido
function sonido.musica(archivo, fundido)
    if musica and musica.archivo == archivo then
        musicaHacia = 1
        return
    end
    if musica then musica.fuente:stop() end
    musica = nil
    if not archivo or not love.filesystem.getInfo(archivo) then return end
    local ok, fuente = pcall(love.audio.newSource, archivo, "stream")
    if not ok then return end
    fuente:setLooping(true)
    musica = { archivo = archivo, fuente = fuente }
    musicaNivel, musicaHacia, musicaVel = 0, 1, 1 / (fundido or 1)
    fuente:setVolume(0)
    fuente:play()
end

-- la musica se apaga poco a poco y se para
function sonido.pararMusica(fundido)
    if not musica then return end
    musicaHacia, musicaVel = 0, 1 / (fundido or 1.5)
end

function sonido.musicaSonando()
    return musica and musica.archivo
end

function sonido.update(dt)
    if not musica then return end
    if musicaNivel < musicaHacia then
        musicaNivel = math.min(musicaHacia, musicaNivel + dt * musicaVel)
    elseif musicaNivel > musicaHacia then
        musicaNivel = math.max(musicaHacia, musicaNivel - dt * musicaVel)
    end
    if musicaNivel <= 0 and musicaHacia <= 0 then
        musica.fuente:stop()
        musica = nil
        return
    end
    musica.fuente:setVolume(musicaNivel * sonido.vol.musica)
end

function sonido.carga(nivel)
    if nivel <= 0 then
        bucleCarga:stop()
        return
    end
    if not bucleCarga:isPlaying() then bucleCarga:play() end
    bucleCarga:setVolume(nivel * 0.6 * sonido.vol.efectos)
    bucleCarga:setPitch(1 + nivel * 1.5)
end

return sonido
