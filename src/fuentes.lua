-- Fuente de pixel de 3x5 dibujada aqui mismo, como la de Bitlatro.
-- Solo tiene mayusculas: las minusculas y las tildes usan el dibujo de la mayuscula.
local utf8 = require "utf8"

local lg = love.graphics

local fuentes = {}

local GLIFOS = {
    A = {".#.", "#.#", "###", "#.#", "#.#"},
    B = {"##.", "#.#", "##.", "#.#", "##."},
    C = {".##", "#..", "#..", "#..", ".##"},
    D = {"##.", "#.#", "#.#", "#.#", "##."},
    E = {"###", "#..", "##.", "#..", "###"},
    F = {"###", "#..", "##.", "#..", "#.."},
    G = {".##", "#..", "#.#", "#.#", ".##"},
    H = {"#.#", "#.#", "###", "#.#", "#.#"},
    I = {"###", ".#.", ".#.", ".#.", "###"},
    J = {"..#", "..#", "..#", "#.#", ".#."},
    K = {"#.#", "#.#", "##.", "#.#", "#.#"},
    L = {"#..", "#..", "#..", "#..", "###"},
    M = {"#...#", "##.##", "#.#.#", "#...#", "#...#"},
    N = {"#..#", "##.#", "#.##", "#..#", "#..#"},
    ["Ñ"] = {"####", "....", "##.#", "#.##", "#..#"},
    O = {".#.", "#.#", "#.#", "#.#", ".#."},
    P = {"##.", "#.#", "##.", "#..", "#.."},
    Q = {".#.", "#.#", "#.#", "##.", ".##"},
    R = {"##.", "#.#", "##.", "#.#", "#.#"},
    S = {".##", "#..", ".#.", "..#", "##."},
    T = {"###", ".#.", ".#.", ".#.", ".#."},
    U = {"#.#", "#.#", "#.#", "#.#", "###"},
    V = {"#.#", "#.#", "#.#", "#.#", ".#."},
    W = {"#...#", "#...#", "#.#.#", "##.##", "#...#"},
    X = {"#.#", "#.#", ".#.", "#.#", "#.#"},
    Y = {"#.#", "#.#", ".#.", ".#.", ".#."},
    Z = {"###", "..#", ".#.", "#..", "###"},
    ["0"] = {"###", "#.#", "#.#", "#.#", "###"},
    ["1"] = {".#.", "##.", ".#.", ".#.", "###"},
    ["2"] = {"##.", "..#", ".#.", "#..", "###"},
    ["3"] = {"##.", "..#", ".#.", "..#", "##."},
    ["4"] = {"#.#", "#.#", "###", "..#", "..#"},
    ["5"] = {"###", "#..", "##.", "..#", "##."},
    ["6"] = {".##", "#..", "###", "#.#", "###"},
    ["7"] = {"###", "..#", ".#.", ".#.", ".#."},
    ["8"] = {"###", "#.#", "###", "#.#", "###"},
    ["9"] = {"###", "#.#", "###", "..#", "##."},
    [" "] = {"..", "..", "..", "..", ".."},
    ["."] = {".", ".", ".", ".", "#"},
    [","] = {".", ".", ".", "#", "#"},
    [":"] = {".", "#", ".", "#", "."},
    ["!"] = {"#", "#", "#", ".", "#"},
    ["¡"] = {"#", ".", "#", "#", "#"},
    ["?"] = {"##.", "..#", ".#.", "...", ".#."},
    ["¿"] = {".#.", "...", ".#.", "#..", ".##"},
    ["-"] = {"...", "...", "###", "...", "..."},
    ["+"] = {"...", ".#.", "###", ".#.", "..."},
    ["="] = {"...", "###", "...", "###", "..."},
    ["*"] = {"...", "#.#", ".#.", "#.#", "..."},
    ["/"] = {"..#", "..#", ".#.", "#..", "#.."},
    ["#"] = {".#.#.", "#####", ".#.#.", "#####", ".#.#."},
    ["$"] = {".##", "##.", ".#.", ".##", "##."},
    ["€"] = {".###", "#...", "###.", "#...", ".###"},
    ["_"] = {"...", "...", "...", "...", "###"},
    ["%"] = {"#.#", "..#", ".#.", "#..", "#.#"},
    ["("] = {".#", "#.", "#.", "#.", ".#"},
    [")"] = {"#.", ".#", ".#", ".#", "#."},
    ["'"] = {"#", "#", ".", ".", "."},
    ["<"] = {"..#", ".#.", "#..", ".#.", "..#"},
    [">"] = {"#..", ".#.", "..#", ".#.", "#.."},
    ["ª"] = {"##", "##", "..", "##", ".."},
}

local ORDEN = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ0123456789 .,:!¡?¿-+=*/#$€_%()'<>ª"

local ALIAS = {
    ["á"] = "A", ["Á"] = "A", ["é"] = "E", ["É"] = "E", ["í"] = "I", ["Í"] = "I",
    ["ó"] = "O", ["Ó"] = "O", ["ú"] = "U", ["Ú"] = "U", ["ü"] = "U", ["ñ"] = "Ñ",
}
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    ALIAS[c] = c:upper()
end

-- deja solo lo que la fuente sabe pintar (lo demas pasa a espacio)
function fuentes.limpiar(cad)
    local ok, res = pcall(function()
        local out = {}
        for _, cp in utf8.codes(cad) do
            local c = utf8.char(cp)
            out[#out + 1] = GLIFOS[ALIAS[c] or c] and c or " "
        end
        return table.concat(out)
    end)
    if ok then return res end
    return (cad:gsub("[^%w %.,:!%?%-%+=%*/#%$_%%%(%)'<>]", " "))
end

-- si la fuente tiene ese caracter
function fuentes.tiene(c)
    return GLIFOS[ALIAS[c] or c] ~= nil
end

function fuentes.preparar()
    local lista = {}
    for _, cp in utf8.codes(ORDEN) do
        table.insert(lista, utf8.char(cp))
    end
    for c in pairs(ALIAS) do
        table.insert(lista, c)
    end

    local ancho = 1
    for _, c in ipairs(lista) do
        ancho = ancho + #GLIFOS[ALIAS[c] or c][1] + 1
    end

    -- formato de newImageFont: cada glifo separado por una columna de un color fijo
    local datos = love.image.newImageData(ancho, 6)
    local x = 0
    local function separador()
        for y = 0, 5 do datos:setPixel(x, y, 1, 0, 1, 1) end
        x = x + 1
    end
    separador()
    for _, c in ipairs(lista) do
        local filas = GLIFOS[ALIAS[c] or c]
        for fy, fila in ipairs(filas) do
            for fx = 1, #fila do
                if fila:sub(fx, fx) == "#" then datos:setPixel(x + fx - 1, fy - 1, 1, 1, 1, 1) end
            end
        end
        x = x + #filas[1]
        separador()
    end

    fuentes.pixel = lg.newImageFont(datos, table.concat(lista), 1)
end

-- en el movil el texto se pinta mas grande (factor 4/3) en el lienzo de la
-- pantalla; lo que se pinta dentro de las cartas y los sobres no cambia
fuentes.factor = 1

local function factor()
    if fuentes.factor ~= 1 and fuentes.lienzo and lg.getCanvas() == fuentes.lienzo then
        return fuentes.factor
    end
    return 1
end

function fuentes.ancho(cad, escala)
    return fuentes.pixel:getWidth(cad) * (escala or 1) * factor()
end

-- alto de una linea de texto
function fuentes.alto(escala)
    return 5 * (escala or 1) * factor()
end

-- paso entre lineas de un texto largo (8 de siempre; 9 con el texto grande)
function fuentes.linea()
    return factor() > 1 and 9 or 8
end

-- lineas que ocupa un texto en ese ancho
function fuentes.envolver(cad, ancho)
    return fuentes.pixel:getWrap(cad, ancho / factor())
end

-- un parrafo partido en lineas como fuentes.envolver, todas al mismo tamaño
-- (fuentes.texto con ancho encoge una linea que cabria en pequeño)
function fuentes.parrafo(cad, x, y, color, ancho)
    local _, lineas = fuentes.envolver(cad, ancho)
    for i, l in ipairs(lineas) do
        fuentes.texto(l, x, y + (i - 1) * fuentes.linea(), 1, color)
    end
    return #lineas
end

-- alinear: nil, "left", "center" o "right" (con ancho)
function fuentes.texto(cad, x, y, escala, color, alinear, ancho)
    escala = escala or 1
    local f = factor()
    -- si no cabe en su hueco, a su tamaño de siempre
    if f ~= 1 and alinear and ancho then
        local w = fuentes.pixel:getWidth(cad) * escala
        if w <= ancho and w * f > ancho then f = 1 end
    end
    if f ~= 1 then
        -- crece desde el centro de la linea, asi lo centrado sigue centrado
        y = y - 5 * escala * (f - 1) / 2
        escala = escala * f
    end
    lg.setFont(fuentes.pixel)
    -- con el texto grande, las lineas de un texto largo van cada 9
    fuentes.pixel:setLineHeight(f > 1 and 9 / 8 or 1)
    lg.setColor(color or {1, 1, 1})
    if alinear then
        lg.printf(cad, math.floor(x), math.floor(y * 3) / 3, ancho / escala, alinear, 0, escala, escala)
    else
        lg.print(cad, math.floor(x), math.floor(y * 3) / 3, 0, escala, escala)
    end
    lg.setColor(1, 1, 1)
end

-- texto con trozos de colores: { {"RARA 72%", color}, {" ", nil}, ... }
function fuentes.trozos(trozos, x, y, escala)
    escala = escala or 1
    for _, t in ipairs(trozos) do
        fuentes.texto(t[1], x, y, escala, t[2])
        x = x + fuentes.ancho(t[1], escala) + escala
    end
end

return fuentes
