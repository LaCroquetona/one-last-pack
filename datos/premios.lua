-- Premios por completar la colección de cada set. Se dan una sola vez.
-- parte: lo que tienes del set (cartas distintas, de 0 a 1)
-- sobres: sobres de ese set que te regalan (de la edicion que haya en la tienda)
-- dinero: en veces el precio del sobre
return {
    hitos = {
        { parte = 0.25, sobres = 2 },
        { parte = 0.5,  sobres = 3 },
        { parte = 0.75, sobres = 5 },
        { parte = 1,    sobres = 8, dinero = 10 },
    },
    -- el set entero en 1ª edicion
    primera = { sobres = 10, dinero = 25 },
}
