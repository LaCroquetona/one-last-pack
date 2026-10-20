-- cielo y horizonte pintan el fondo del dibujo (degradado de uno a otro);
-- suelo y trama, la franja de abajo donde se apoya el bicho
-- cuerpo, luz y sombra son los colores del bicho
local p = require "datos.paleta"

return {
    fuego  = { nombre = "Fuego",  cielo = p.morado,   horizonte = p.rojo,      suelo = p.negro,    trama = "llamas",    cuerpo = p.naranja,   luz = p.amarillo, sombra = p.rojo },
    agua   = { nombre = "Agua",   cielo = p.azulosc,  horizonte = p.azul,      suelo = p.azulosc,  trama = "olas",      cuerpo = p.celeste,   luz = p.cian,     sombra = p.azul },
    planta = { nombre = "Planta", cielo = p.verdeosc, horizonte = p.verde,     suelo = p.negro,    trama = "hojas",     cuerpo = p.lima,      luz = p.blanco,   sombra = p.verde },
    rayo   = { nombre = "Rayo",   cielo = p.grisosc,  horizonte = p.gris,      suelo = p.negro,    trama = "rayas",     cuerpo = p.amarillo,  luz = p.blanco,   sombra = p.naranja },
    sombra = { nombre = "Sombra", cielo = p.negro,    horizonte = p.morado,    suelo = p.negro,    trama = "puntos",    cuerpo = p.grisclaro, luz = p.blanco,   sombra = p.gris },
    hielo  = { nombre = "Hielo",  cielo = p.azul,     horizonte = p.grisclaro, suelo = p.blanco,   trama = "cristales", cuerpo = p.cian,      luz = p.blanco,   sombra = p.celeste },
    metal  = { nombre = "Metal",  cielo = p.negro,    horizonte = p.grisosc,   suelo = p.gris,     trama = "rejilla",   cuerpo = p.naranja,   luz = p.amarillo, sombra = p.morado },
    tierra = { nombre = "Tierra", cielo = p.naranja,  horizonte = p.amarillo,  suelo = p.morado,   trama = "rocas",     cuerpo = p.rojo,      luz = p.naranja,  sombra = p.morado },
    astral = { nombre = "Astral", cielo = p.negro,    horizonte = p.azulosc,   suelo = p.azulosc,  trama = "estrellas", cuerpo = p.violeta,   luz = p.blanco,   sombra = p.morado },
    veneno = { nombre = "Veneno", cielo = p.morado,   horizonte = p.verdeosc,  suelo = p.negro,    trama = "burbujas",  cuerpo = p.violeta,   luz = p.lima,     sombra = p.morado },
    viento = { nombre = "Viento", cielo = p.celeste,  horizonte = p.blanco,    suelo = p.grisclaro, trama = "rafagas", cuerpo = p.blanco,    luz = p.cian,     sombra = p.grisclaro },
    dragon = { nombre = "Dragón", cielo = p.rojo,     horizonte = p.naranja,   suelo = p.negro,    trama = "escamas",   cuerpo = p.verde,     luz = p.lima,     sombra = p.verdeosc },
    luz    = { nombre = "Luz",    cielo = p.amarillo, horizonte = p.blanco,    suelo = p.naranja,  trama = "destellos", cuerpo = p.amarillo,  luz = p.blanco,   sombra = p.naranja },
}
