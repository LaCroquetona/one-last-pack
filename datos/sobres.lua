-- precio: lo que cuesta en la tienda mientras se imprime, en centimos
-- (200 = 2,00 €). Cuando se agota solo se consigue de reventa, a precio de mercado.
-- Cada hueco del sobre: cuantas cartas y con que peso sale cada rareza.
-- Los pesos no tienen que sumar 100, se reparten en proporcion.
-- godpack: probabilidad de que TODO el sobre use los pesos del ultimo hueco
-- piedad: sobres seguidos sin holo o mejor antes de que el ultimo hueco la garantice
-- colores: los del dibujo del sobre (base, rayas, borde y letras)
local p = require "datos.paleta"

local lista = {
    {
        id = "set1",
        set = "s1",
        nombre = "Sobre Set 1",
        precio = 200,
        godpack = 1 / 200,
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
        godpack = 1 / 500,
        piedad = 20,
        colores = { base = p.azulosc, rayas = p.azul, borde = p.negro, letras = p.cian },
        huecos = {
            { cantidad = 4, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 3, nombre = "Infrecuentes", rarezas = { infrecuente = 90, rara = 10 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 55, infrecuente = 30, rara = 12.5, holo = 2, fullart = 0.4, secreta = 0.1 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 85, holo = 11.5, fullart = 3, secreta = 0.5 } },
        },
    },
    {
        id = "set3",
        set = "s3",
        nombre = "Sobre Set 3",
        precio = 500,
        godpack = 1 / 300,
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
        godpack = 1 / 250,
        piedad = 10,
        colores = { base = p.negro, rayas = p.violeta, borde = p.azulosc, letras = p.cian },
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 80, rara = 20 } },
            { cantidad = 2, nombre = "Comodín",      rarezas = { comun = 45, infrecuente = 32, rara = 17, holo = 4.5, fullart = 1.2, secreta = 0.3 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 66, holo = 26, fullart = 6.5, secreta = 1.5 } },
        },
    },
}

local sobres = {
    lista = lista,
    inicio = { dinero = 2000, sobres = {} },
}
for _, s in ipairs(lista) do
    sobres[s.id] = s
end
return sobres
