-- Desbloqueos por hitos (los mira src/desbloqueos.lua). Al empezar solo hay
-- sobres del S1, la mesa y el directo de apertura; lo demas sale jugando.
-- Dos clases de aviso:
--   texto: panel de la mascota en la mesa (apunta: boton al que senala,
--          pose: la de la mascota). inmediato: sale nada mas acabar el sobre
--          que lo ha desbloqueado, sin esperar a otros avisos.
--   toast: aviso corto que no para nada + punto rojo en lo nuevo (src/guia.lua);
--          la explicacion larga sale al entrar ahi (datos/guia.lua).
-- apps: las del movil que abre; tops: top loaders de regalo.
-- Los que no abren nada (tienda, dia, sinDinero) son solo avisos.
return {
    -- cuando: primera rara o mejor
    fundas = { texto = "¡TU PRIMERA RARA! YA PUEDES ENFUNDAR: ARRASTRA UNA FUNDA DE LA CAJA A LA CARTA. TE DOY 20, Y EN LA TIENDA HAY MÁS.",
               apunta = "caja_funda", inmediato = true, pose = "pulgar" },
    -- primera full art o secreta
    tops = { texto = "¡MENUDA CARTA! TOMA 3 TOP LOADERS DE REGALO: ARRÁSTRALOS A TUS CARTAS BUENAS PARA PROTEGERLAS MÁS.",
             apunta = "caja_top", tops = 3, inmediato = true, pose = "pulgar" },
    -- repetidas tras unos sobres, o sin dinero
    mercado = { abiertos = 6, toast = "¡NUEVAS APPS EN EL MÓVIL: CARTERA, MERCADO, VENTAS Y LOGROS!",
                apps = { "cartera", "mercado", "ventas", "logros" } },
    -- tras unos directos
    encargos = { directos = 2, toast = "¡NUEVA APP EN EL MÓVIL: ENCARGOS!", apps = { "encargos" } },
    -- al tener este dinero a la vez (centimos)
    mejoras = { toast = "¡NUEVA APP EN EL MÓVIL: MEJORAS!", apps = { "mejoras" }, dinero = 2500 },
    -- con los seguidores de datos/directo.lua > venta.desbloqueo
    venta = { texto = "¡YA TIENES SEGUIDORES PARA VENDER! NUEVO DIRECTO: VENTA DE SOBRES. ELÍGELO ANTES DE EMPEZAR EL DIRECTO.",
              apunta = "dir_tipo_venta", inmediato = true, pose = "pulgar" },
    -- cuando se anuncia el S2
    noticias = { toast = "SE ACERCA UN SET NUEVO. ¡NUEVAS APPS: NOTICIAS Y CALENDARIO!", apps = { "noticias", "calendario" } },
    -- cuando sale el S2
    cajas = { toast = "¡YA HAY CAJAS EN LA TIENDA!" },

    -- solo avisos
    tienda = { texto = "TE HAS QUEDADO SIN SOBRES. ¡A LA TIENDA A POR MÁS!", apunta = "ir_tienda", pose = "piensa" },
    -- tras estos sobres abiertos, o al vaciar la tienda
    dia = { texto = "CUANDO QUIERAS, PASA EL DÍA DESDE EL MÓVIL: LLEGAN SOBRES A LA TIENDA Y LOS PRECIOS SE MUEVEN.",
            apunta = "ir_movil", abiertos = 15, pose = "piensa" },
    -- sale como mucho una vez al dia
    sinDinero = { texto = "SIN DINERO PARA SOBRES. VENDE ALGUNA CARTA: EN LA MESA, EN EL ARMARIO O EN EL MÓVIL, QUE ES DONDE MÁS PAGAN.",
                  apunta = "ir_movil", pose = "piensa" },

    -- segundos de juego entre un aviso y el siguiente (y tras el tutorial):
    -- de uno en uno, para que de tiempo a probar cada cosa (los inmediatos no esperan)
    espera = 25,
    -- el primero tras acabar el tutorial
    esperaTutorial = 6,

    -- orden en que se miran
    orden = { "fundas", "tops", "mercado", "sinDinero", "tienda", "encargos", "mejoras", "venta", "dia", "noticias", "cajas" },
}
