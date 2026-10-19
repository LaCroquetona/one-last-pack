-- Cada hueco del sobre: cuantas cartas y con que peso sale cada rareza.
-- Los pesos no tienen que sumar 100, se reparten en proporcion.
-- godpack: probabilidad de que TODO el sobre use los pesos del ultimo hueco
-- piedad: sobres seguidos sin holo o mejor antes de que el ultimo hueco la garantice
local lista = {
    {
        id = "set1",
        nombre = "Sobre Set 1",
        precio = 120,
        godpack = 1 / 200,
        piedad = 12,
        huecos = {
            { cantidad = 3, nombre = "Comunes",      rarezas = { comun = 1 } },
            { cantidad = 2, nombre = "Infrecuentes", rarezas = { infrecuente = 85, rara = 15 } },
            { cantidad = 1, nombre = "Comodín",      rarezas = { comun = 50, infrecuente = 30, rara = 14, holo = 4, fullart = 1.5, secreta = 0.5 } },
            { cantidad = 1, nombre = "Rara o mejor", rarezas = { rara = 72, holo = 20, fullart = 6, secreta = 2 } },
        },
    },
}

local sobres = {
    lista = lista,
    inicio = { dinero = 1000, sobres = { set1 = 1 } },
}
for _, s in ipairs(lista) do
    sobres[s.id] = s
end
return sobres
