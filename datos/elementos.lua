-- fondo y patron pintan el recuadro del dibujo; cuerpo, luz y sombra, al bicho
-- dibujo: trama del fondo (llamas, olas, hojas, rayas, puntos)
local p = require "datos.paleta"

return {
    fuego  = { nombre = "Fuego",  fondo = p.morado,   patron = p.rojo,    dibujo = "llamas", cuerpo = p.naranja,  luz = p.amarillo,  sombra = p.rojo },
    agua   = { nombre = "Agua",   fondo = p.azulosc,  patron = p.azul,    dibujo = "olas",   cuerpo = p.celeste,  luz = p.cian,      sombra = p.azul },
    planta = { nombre = "Planta", fondo = p.verdeosc, patron = p.verde,   dibujo = "hojas",  cuerpo = p.lima,     luz = p.blanco,    sombra = p.verde },
    rayo   = { nombre = "Rayo",   fondo = p.grisosc,  patron = p.gris,    dibujo = "rayas",  cuerpo = p.amarillo, luz = p.blanco,    sombra = p.naranja },
    sombra = { nombre = "Sombra", fondo = p.negro,    patron = p.morado,  dibujo = "puntos", cuerpo = p.grisclaro, luz = p.blanco, sombra = p.gris },
}
