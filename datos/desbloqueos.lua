-- Desbloqueos por hitos (los mira src/desbloqueos.lua). Al empezar solo hay
-- sobres del S1, la mesa y el directo de apertura; lo demas sale jugando,
-- cada cosa con un aviso corto. texto: el aviso; apunta: boton al que senala
-- la flecha; apps: las del movil que abre; tops: top loaders de regalo.
-- Los que no abren nada (tienda, dia, sinDinero) son solo avisos.
return {
    -- cuando: primera rara o mejor
    fundas = { texto = "¡TU PRIMERA RARA! YA PUEDES ENFUNDAR: ARRASTRA UNA FUNDA DE LA CAJA A LA CARTA. TIENES 20 Y EN LA TIENDA VENDEN MÁS.",
               apunta = "caja_funda" },
    -- primera full art o secreta
    tops = { texto = "¡MENUDA CARTA! TE REGALAN 3 TOP LOADERS: ARRÁSTRALOS A TUS CARTAS BUENAS PARA PROTEGERLAS MÁS.",
             apunta = "caja_top", tops = 3 },
    -- repetidas tras unos sobres, o sin dinero
    mercado = { abiertos = 6, texto = "NUEVAS APPS EN EL MÓVIL: EN VENTAS PUBLICAS TUS CARTAS Y TE HACEN OFERTAS (PAGAN MÁS QUE LA VENTA RÁPIDA). MERCADO Y CARTERA TE DICEN LO QUE VALE TODO.",
                apunta = "ir_movil", apps = { "cartera", "mercado", "ventas", "logros" } },
    -- tras unos directos
    encargos = { directos = 2, texto = "NUEVA APP: ENCARGOS. GENTE QUE TE PAGA POR ABRIR SOBRES CONCRETOS, Y LAS CARTAS SON PARA TI.",
                 apunta = "ir_movil", apps = { "encargos" } },
    -- al tener este dinero a la vez (centimos)
    mejoras = { texto = "NUEVA APP: MEJORAS. SUERTE, VENTAS, DIRECTO Y TIENDA: CADA NIVEL SE NOTA UN POCO.",
                apunta = "ir_movil", apps = { "mejoras" }, dinero = 2500 },
    -- con los seguidores de datos/directo.lua > venta.desbloqueo
    venta = { texto = "¡YA TIENES SEGUIDORES PARA VENDER! NUEVO DIRECTO: VENTA DE SOBRES. EL CHAT TE COMPRA SOBRES Y LOS ABRES PARA ELLOS.",
              apunta = "dir_tipo_venta" },
    -- cuando se anuncia el S2
    noticias = { texto = "SE ACERCA UN SET NUEVO. NUEVAS APPS: NOTICIAS Y CALENDARIO, PARA SABER QUÉ SALE Y CÓMO SE MUEVE EL MERCADO.",
                 apunta = "ir_movil", apps = { "noticias", "calendario" } },
    -- cuando sale el S2
    cajas = { texto = "YA HAY CAJAS EN LA TIENDA: 18 SOBRES MÁS BARATOS. SE PUEDEN ABRIR O GUARDAR CERRADAS PARA REVENDER.",
              apunta = "ir_tienda" },

    -- solo avisos
    tienda = { texto = "TE HAS QUEDADO SIN SOBRES: VE A LA TIENDA A POR MÁS.", apunta = "ir_tienda" },
    -- tras estos sobres abiertos, o al vaciar la tienda
    dia = { texto = "CUANDO QUIERAS, PASA EL DÍA DESDE EL MÓVIL: LLEGAN MÁS SOBRES A LA TIENDA Y LOS PRECIOS SE MUEVEN.",
            apunta = "ir_movil", abiertos = 15 },
    -- sale como mucho una vez al dia
    sinDinero = { texto = "SIN DINERO PARA SOBRES: VENDE CARTAS (EN LA MESA, EL ARMARIO O EL MÓVIL > VENTAS). LO QUE MÁS VALE, POR EL MÓVIL.",
                  apunta = "ir_movil" },

    -- segundos de juego entre un aviso y el siguiente (y tras el tutorial):
    -- de uno en uno, para que de tiempo a probar cada cosa
    espera = 25,
    -- el primero tras acabar el tutorial
    esperaTutorial = 6,

    -- orden en que se miran
    orden = { "fundas", "tops", "mercado", "sinDinero", "tienda", "encargos", "mejoras", "venta", "dia", "noticias", "cajas" },
}
