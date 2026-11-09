-- Desbloqueos por hitos (los mira src/desbloqueos.lua). Al empezar solo hay
-- sobres del S1, la mesa y el directo de apertura; lo demas sale jugando.
-- Dos clases de aviso:
--   texto: panel de la mascota en la mesa (apunta: boton al que senala,
--          pose: la de la mascota). inmediato: sale nada mas acabar el sobre
--          que lo ha desbloqueado, sin esperar a otros avisos.
--   corto: lo que sale sin tutorial (OPCIONES), como toast
--   toast: aviso corto que no para nada + punto rojo en lo nuevo (src/guia.lua);
--          la explicacion larga sale al entrar ahi (datos/guia.lua).
-- apps: las del movil que abre; tops: top loaders de regalo.
-- Los que no abren nada (tienda, dia, sinDinero) son solo avisos.
return {
    -- cuando: primera rara o mejor
    fundas = { corto = "¡YA PUEDES ENFUNDAR! +20 FUNDAS", texto = "¡TU PRIMERA RARA! YA PUEDES ENFUNDAR: ARRASTRA UNA FUNDA DE LA CAJA A LA CARTA. TE DOY 20, Y EN LA TIENDA HAY MÁS.",
               apunta = "caja_funda", inmediato = true, pose = "pulgar" },
    -- primera full art o secreta antes que ninguna rara: un solo aviso con las dos cosas
    fundasTops = { corto = "¡YA PUEDES ENFUNDAR! +20 FUNDAS Y 3 TOPS", texto = "¡MENUDA CARTA! PROTÉGELA: ARRASTRA UNA FUNDA DE LA CAJA A LA CARTA Y LUEGO UN TOP LOADER ENCIMA. TE DOY 20 FUNDAS Y 3 TOPS; EN LA TIENDA HAY MÁS.",
                   apunta = "caja_funda", inmediato = true, pose = "pulgar" },
    -- primera full art o secreta
    tops = { corto = "¡TOP LOADERS! +3 DE REGALO", texto = "¡MENUDA CARTA! TOMA 3 TOP LOADERS DE REGALO: ARRÁSTRALOS A TUS CARTAS BUENAS PARA PROTEGERLAS MÁS.",
             apunta = "caja_top", tops = 3, inmediato = true, pose = "pulgar" },
    -- repetidas tras unos sobres, o sin dinero
    mercado = { abiertos = 6, toast = "¡NUEVAS APPS EN EL MÓVIL: CARTERA, MERCADO, VENTAS Y LOGROS!",
                apps = { "cartera", "mercado", "ventas", "logros" } },
    -- tras unos directos
    encargos = { directos = 2, toast = "¡NUEVA APP EN EL MÓVIL: ENCARGOS!", apps = { "encargos" } },
    -- al tener este dinero a la vez (centimos)
    mejoras = { toast = "¡NUEVA APP EN EL MÓVIL: MEJORAS!", apps = { "mejoras" }, dinero = 2500 },
    -- con los seguidores de datos/directo.lua > venta.desbloqueo
    venta = { corto = "¡NUEVO DIRECTO: VENTA DE SOBRES!", texto = "¡YA TIENES SEGUIDORES PARA VENDER! NUEVO DIRECTO: VENTA DE SOBRES. ELÍGELO ANTES DE EMPEZAR EL DIRECTO.",
              apunta = "dir_tipo_venta", inmediato = true, pose = "pulgar" },
    -- cuando se anuncia el S2
    noticias = { toast = "SE ACERCA UN SET NUEVO. ¡NUEVAS APPS: NOTICIAS Y CALENDARIO!", apps = { "noticias", "calendario" } },
    -- tras estos sobres abiertos: lo descubre el jugador, sin pagar nada
    cajas = { abiertos = 30, corto = "¡ALGO NUEVO EN LA TIENDA!", texto = "¡HA LLEGADO ALGO NUEVO A LA TIENDA! PÁSATE A VERLO.",
              apunta = "ir_tienda", pose = "pulgar" },

    -- solo avisos
    tienda = { corto = "SIN SOBRES: ¡A LA TIENDA!", texto = "TE HAS QUEDADO SIN SOBRES. ¡A LA TIENDA A POR MÁS!", apunta = "ir_tienda", inmediato = true, pose = "piensa" },
    -- sin nada que abrir y la tienda vacia (una vez al dia como mucho)
    mercadoSobres = { corto = "LA TIENDA ESTÁ VACÍA: MIRA EL MERCADO DEL MÓVIL", texto = "EN LA TIENDA NO QUEDAN SOBRES, PERO EN EL MERCADO DEL MÓVIL LA GENTE VENDE LOS SUYOS. ¡ÉCHALE UN OJO!",
                      apunta = "ir_movil", inmediato = true, pose = "piensa" },
    -- tras estos sobres abiertos, sin nada que abrir y con la tienda acabada
    -- (vacia o sin dinero)
    dia = { corto = "NADA QUE ABRIR: PASA EL DÍA DESDE EL MÓVIL", texto = "¿NADA MÁS QUE ABRIR? PASA EL DÍA DESDE EL MÓVIL: LLEGAN SOBRES A LA TIENDA Y LOS PRECIOS SE MUEVEN.",
            apunta = "ir_movil", abiertos = 1, pose = "piensa" },
    -- sale como mucho una vez al dia
    sinDinero = { corto = "SIN DINERO: VENDE ALGUNA CARTA", texto = "SIN DINERO PARA SOBRES. VENDE ALGUNA CARTA: EN LA MESA, EN EL ARMARIO O EN EL MÓVIL, QUE ES DONDE MÁS PAGAN.",
                  apunta = "ir_movil", pose = "piensa" },

    -- segundos de juego entre un aviso y el siguiente (y tras el tutorial):
    -- de uno en uno, para que de tiempo a probar cada cosa (los inmediatos no esperan)
    espera = 25,
    -- el primero tras acabar el tutorial
    esperaTutorial = 6,

    -- orden en que se miran
    orden = { "fundas", "tops", "mercado", "sinDinero", "mercadoSobres", "tienda", "encargos", "mejoras", "venta", "dia", "noticias", "cajas" },
}
