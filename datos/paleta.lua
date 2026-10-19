-- Sweetie 16, la misma paleta que Bitlatro (la de serie de TIC-80)
local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

return {
    negro     = hex("1a1c2c"),
    morado    = hex("5d275d"),
    rojo      = hex("b13e53"),
    naranja   = hex("ef7d57"),
    amarillo  = hex("ffcd75"),
    lima      = hex("a7f070"),
    verde     = hex("38b764"),
    verdeosc  = hex("257179"),
    azulosc   = hex("29366f"),
    azul      = hex("3b5dc9"),
    celeste   = hex("41a6f6"),
    cian      = hex("73eff7"),
    blanco    = hex("f4f4f4"),
    grisclaro = hex("94b0c2"),
    gris      = hex("566c86"),
    grisosc   = hex("333c57"),
    -- fuera de Sweetie, solo para la holo
    violeta   = hex("c870e0"),
}
