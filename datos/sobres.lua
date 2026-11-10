-- precio: lo que cuesta en la tienda mientras se imprime, en centimos
-- (200 = 2,00 €). Cuando se agota solo se consigue de reventa, a precio de mercado.
-- Cada hueco del sobre: cuantas cartas y con que peso sale cada rareza.
-- Los pesos no tienen que sumar 100, se reparten en proporcion.
-- godpack: probabilidad de que TODO el sobre use los pesos del ultimo hueco
-- (holo o mejor). En el S1 sale uno cada 20 cajas; en los demas, en proporcion
-- a lo que cuesta su secreta (dificultad: lo que cuesta sacar la secreta de
-- este set comparado con el S1)
-- variantes: 1 de cada cuantos sobres sale cada carta de fuera de set
-- (datos/variantes.lua). Salen cambiando una carta normal por su variante
-- piedad: sobres seguidos sin holo o mejor antes de que el ultimo hueco la garantice
-- colores: los del dibujo del sobre (base, rayas, borde y letras)
local p = require "datos.paleta"

local lista = {
    {
        id = "set1",
        set = "s1",
        nombre = "Sobre Set 1",
        precio = 200,
        godpack = 1 / 360,
        dificultad = 1,
        variantes = { alt_holo = 14, alt_fullart = 33, alt_secreta = 300, silver = 900, golden = 2200 },
        piedad = 12,
        colores = { base = p.rojo, rayas = p.naranja, borde = p.morado, letras = p.amarillo },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 85, rara = 15 } },
            { cantidad = 1, nombre = "Comodín",      rarezas = { comun = 50, infrecuente = 30, rara = 14, holo = 4, fullart = 1.5, secreta = 0.5 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 72, holo = 20, fullart = 6, secreta = 2 } },
        },
    },
    {
        id = "set2",
        set = "s2",
        nombre = "Sobre Set 2",
        precio = 800,
        godpack = 1 / 817,
        dificultad = 2.27,
        variantes = { alt_holo = 17, alt_fullart = 72, alt_secreta = 681, silver = 2043, golden = 4994 },
        piedad = 20,
        colores = { base = p.azulosc, rayas = p.azul, borde = p.negro, letras = p.cian },
        huecos = {
            { cantidad = 4, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 3, nombre = "Infrecuentes", rarezas = { infrecuente = 90, rara = 10 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 55, infrecuente = 29, rara = 12.5, holo = 2.8, fullart = 0.55, secreta = 0.15 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 80, holo = 15, fullart = 4.2, secreta = 0.8 } },
        },
    },
    {
        id = "set3",
        set = "s3",
        nombre = "Sobre Set 3",
        precio = 500,
        godpack = 1 / 562,
        dificultad = 1.56,
        variantes = { alt_holo = 16, alt_fullart = 77, alt_secreta = 468, silver = 1404, golden = 3432 },
        piedad = 15,
        colores = { base = p.morado, rayas = p.naranja, borde = p.negro, letras = p.amarillo },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 85, rara = 15 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 50, infrecuente = 30, rara = 15, holo = 3.5, fullart = 1.2, secreta = 0.3 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 80, holo = 15, fullart = 4, secreta = 1 } },
        },
    },
    {
        id = "set4",
        set = "s4",
        nombre = "Sobre Set 4",
        precio = 1200,
        godpack = 1 / 428,
        dificultad = 1.19,
        variantes = { alt_holo = 11, alt_fullart = 57, alt_secreta = 357, silver = 1071, golden = 2618 },
        piedad = 10,
        colores = { base = p.negro, rayas = p.violeta, borde = p.azulosc, letras = p.cian },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 80, rara = 20 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 45, infrecuente = 32, rara = 17, holo = 4.5, fullart = 1.2, secreta = 0.3 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 66, holo = 26, fullart = 6.5, secreta = 1.5 } },
        },
    },
    {
        id = "set5",
        set = "s5",
        nombre = "Sobre Set 5",
        precio = 600,
        godpack = 1 / 500,
        dificultad = 1.39,
        variantes = { alt_holo = 15, alt_fullart = 68, alt_secreta = 417, silver = 1251, golden = 3058 },
        piedad = 15,
        colores = { base = p.violeta, rayas = p.lima, borde = p.morado, letras = p.lima },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 85, rara = 15 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 50, infrecuente = 30, rara = 15, holo = 3.5, fullart = 1.2, secreta = 0.3 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 78, holo = 16, fullart = 4.8, secreta = 1.2 } },
        },
    },
    {
        id = "set6",
        set = "s6",
        nombre = "Sobre Set 6",
        precio = 300,
        godpack = 1 / 450,
        dificultad = 1.25,
        variantes = { alt_holo = 19, alt_fullart = 38, alt_secreta = 375, silver = 1125, golden = 2750 },
        piedad = 12,
        colores = { base = p.celeste, rayas = p.blanco, borde = p.azul, letras = p.azulosc },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 85, rara = 15 } },
            { cantidad = 1, nombre = "Comodín",      rarezas = { comun = 50, infrecuente = 30, rara = 14, holo = 4, fullart = 1.5, secreta = 0.5 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 74, holo = 19, fullart = 5.5, secreta = 1.5 } },
        },
    },
    {
        id = "set7",
        set = "s7",
        nombre = "Sobre Set 7",
        precio = 1500,
        godpack = 1 / 346,
        dificultad = 0.96,
        variantes = { alt_holo = 11, alt_fullart = 50, alt_secreta = 288, silver = 864, golden = 2112 },
        piedad = 10,
        colores = { base = p.verdeosc, rayas = p.verde, borde = p.negro, letras = p.naranja },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 80, rara = 20 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 45, infrecuente = 32, rara = 17, holo = 4.5, fullart = 1.2, secreta = 0.3 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 64, holo = 27, fullart = 7, secreta = 2 } },
        },
    },
    {
        id = "set8",
        set = "s8",
        nombre = "Sobre Set 8",
        precio = 900,
        godpack = 1 / 450,
        dificultad = 1.25,
        variantes = { alt_holo = 14, alt_fullart = 37, alt_secreta = 375, silver = 1125, golden = 2750 },
        piedad = 16,
        colores = { base = p.amarillo, rayas = p.blanco, borde = p.naranja, letras = p.rojo },
        huecos = {
            { cantidad = 4, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 3, nombre = "Infrecuentes", rarezas = { infrecuente = 88, rara = 12 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 52, infrecuente = 30, rara = 13.5, holo = 3.4, fullart = 0.85, secreta = 0.25 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 75, holo = 18, fullart = 5.5, secreta = 1.5 } },
        },
    },
}

local sobres = {
    lista = lista,
    -- cajas selladas: 36 sobres mas baratos. Se compran mientras el set esta en
    -- la tienda (llegan "porDia" al dia); se guardan cerradas, se abren o se
    -- venden a la tienda por "valor" veces lo que valen sus sobres cerrados
    caja = { sobres = 36, descuento = 0.1, porDia = 2, valor = 0.85 },
    -- con lo que se empieza: dinero y sobres (de 1ª edicion) para abrir ya
    inicio = { dinero = 2000, sobres = { set1 = 3 } },
}
for _, s in ipairs(lista) do
    sobres[s.id] = s
end
return sobres
