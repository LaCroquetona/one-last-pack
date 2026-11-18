-- Cartas de fuera de set que salen de otras (datos/cartas.lua). Cuantas salen
-- esta en datos/sobres.lua (variantes) y lo que valen en datos/sets.lua.
-- Salen al abrir: una carta de la rareza que toca se cambia por su variante.
local p = require "datos.paleta"

-- tope: como mucho esta parte de las copias de una carta sale en su variante
-- (una ALT nunca sale mas que su carta normal)
return {
    tope = 0.2,
    alt = { nombre = "Alt" },
    silver = { nombre = "Silver", color = p.grisclaro, brillo = "plata", suspense = 2.4 },
    golden = { nombre = "Golden", color = p.amarillo, brillo = "golden", suspense = 3.2 },
}
