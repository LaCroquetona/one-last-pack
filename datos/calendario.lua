-- Ritmo de los sets, en dias de juego. Los rangos { a, b } se sortean al
-- empezar cada partida, asi no todas las partidas van igual.
return {
    -- dias entre que sale un set y sale el siguiente
    cada = 18,
    -- lo que dura la primera tirada en la tienda: con cada = 16 se pisa con
    -- el set siguiente unos 8 dias
    impresion = { 24, 28 },
    -- dias agotado antes de la primera reimpresion del primer set
    espera = { 14, 18 },
    -- las reimpresiones van en rueda: cuando acaba una empieza la siguiente
    -- (pisandose solape dias), asi la tienda nunca se queda vacia
    reimpresion = { 14, 18 },
    solape = { 0, 3 },
    -- primeros dias de un set: hype y menos sobres en la tienda
    lanzamiento = 5,
    -- avisos en las noticias
    anuncio = 4,       -- dias antes de que salga un set
    ultimos = 3,       -- dias antes de que acabe una tirada
    rumor = { 2, 4 },  -- dias antes de una reimpresion
    -- hasta que dia se planifica
    horizonte = 800,
}
