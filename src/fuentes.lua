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
    ["Ñ"] = {"####", "#..#", "##.#", "#.##", "#..#"},
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
    ["%"] = {"#.#", "..#", ".#.", "#..", "#.#"},
    ["("] = {".#", "#.", "#.", "#.", ".#"},
    [")"] = {"#.", ".#", ".#", ".#", "#."},
    ["'"] = {"#", "#", ".", ".", "."},
    ["<"] = {"..#", ".#.", "#..", ".#.", "..#"},
    [">"] = {"#..", ".#.", "..#", ".#.", "#.."},
}

local ORDEN = "ABCDEFGHIJKLMNÑOPQRSTUVWXYZ0123456789 .,:!¡?¿-+=*/#$%()'<>"

local ALIAS = {
    ["á"] = "A", ["Á"] = "A", ["é"] = "E", ["É"] = "E", ["í"] = "I", ["Í"] = "I",
    ["ó"] = "O", ["Ó"] = "O", ["ú"] = "U", ["Ú"] = "U", ["ü"] = "U", ["ñ"] = "Ñ",
}
for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    ALIAS[c] = c:upper()
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

function fuentes.ancho(cad, escala)
    return fuentes.pixel:getWidth(cad) * (escala or 1)
end

-- alinear: nil, "left", "center" o "right" (con ancho)
function fuentes.texto(cad, x, y, escala, color, alinear, ancho)
    escala = escala or 1
    lg.setFont(fuentes.pixel)
    lg.setColor(color or {1, 1, 1})
    if alinear then
        lg.printf(cad, math.floor(x), math.floor(y), ancho / escala, alinear, 0, escala, escala)
    else
        lg.print(cad, math.floor(x), math.floor(y), 0, escala, escala)
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
