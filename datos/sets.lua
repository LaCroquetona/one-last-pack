-- Cada set tiene sus cartas (datos/cartas.lua, campo set), su sobre
-- (datos/sobres.lua) y lo que vale cada rareza en el mercado, en centimos.
-- Ajustados para que un sobre valga de media (a precio base) el 80% de lo que
-- cuesta; el del S1, el 90% (las mejoras de suerte lo suben; lo demas sale del
-- movil, los directos, los encargos y la suerte).
-- alt_holo ... golden: las cartas de fuera de set (datos/variantes.lua). Cada
-- carta vale segun lo dificil que es sacarla: la ALT holo, entre la holo y la
-- full art; la ALT full art, entre la full art y la secreta; y por encima de la
-- secreta suben con la rareza (^0,7)
-- Salen en este orden, uno cada pocos dias (datos/calendario.lua)
local lista = {
    {
        id = "s1", codigo = "S1", nombre = "Set 1", sobre = "set1",
        valores = { comun = 1.48, infrecuente = 2.98, rara = 9.44, holo = 58.84, fullart = 386, secreta = 2019,
                    alt_holo = 150, alt_fullart = 883, alt_secreta = 8275, silver = 10991, golden = 20548 },
    },
    {
        id = "s2", codigo = "S2", nombre = "Set 2", sobre = "set2",
        valores = { comun = 2.54, infrecuente = 6.51, rara = 36.19, holo = 466, fullart = 2032, secreta = 11003,
                    alt_holo = 972, alt_fullart = 4728, alt_secreta = 45050, silver = 73185, golden = 84222 },
    },
    {
        id = "s3", codigo = "S3", nombre = "Set 3", sobre = "set3",
        valores = { comun = 2.47, infrecuente = 4.93, rara = 19.33, holo = 230, fullart = 1097, secreta = 5483,
                    alt_holo = 502, alt_fullart = 2452, alt_secreta = 22443, silver = 29810, golden = 55730 },
    },
    {
        id = "s4", codigo = "S4", nombre = "Set 4", sobre = "set4",
        valores = { comun = 5.05, infrecuente = 10.87, rara = 27.83, holo = 314, fullart = 2245, secreta = 11789,
                    alt_holo = 841, alt_fullart = 5145, alt_secreta = 48294, silver = 64144, golden = 119918 },
    },
    -- v0.8.0: cuatro sets nuevos, cada uno con su elemento
    {
        id = "s5", codigo = "S5", nombre = "Set 5", sobre = "set5",
        valores = { comun = 2.74, infrecuente = 5.47, rara = 21.38, holo = 254, fullart = 1216, secreta = 6077,
                    alt_holo = 556, alt_fullart = 2718, alt_secreta = 24915, silver = 33093, golden = 61866 },
    },
    {
        id = "s6", codigo = "S6", nombre = "Set 6", sobre = "set6",
        valores = { comun = 1.95, infrecuente = 3.9, rara = 12.47, holo = 78.24, fullart = 507, secreta = 2657,
                    alt_holo = 200, alt_fullart = 1160, alt_secreta = 10886, silver = 14459, golden = 27032 },
    },
    {
        id = "s7", codigo = "S7", nombre = "Set 7", sobre = "set7",
        valores = { comun = 2.59, infrecuente = 6.63, rara = 36.1, holo = 474, fullart = 2071, secreta = 11211,
                    alt_holo = 990, alt_fullart = 4818, alt_secreta = 45887, silver = 60947, golden = 113940 },
    },
    {
        id = "s8", codigo = "S8", nombre = "Set 8", sobre = "set8",
        valores = { comun = 4.03, infrecuente = 8.66, rara = 22.13, holo = 250, fullart = 1789, secreta = 9406,
                    alt_holo = 668, alt_fullart = 4102, alt_secreta = 38542, silver = 51192, golden = 95703 },
    },
}

local sets = { lista = lista }
for i, s in ipairs(lista) do
    s.orden = i
    sets[s.id] = s
end
return sets
