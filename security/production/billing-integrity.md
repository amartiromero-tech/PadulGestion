# Facturas: unicidad y datos fiscales

Aplicar security/production/billing-integrity.sql antes de publicar app.js. La aplicación anterior es compatible: el trigger captura los datos en el servidor también para clientes con caché antigua.

La migración añade datos_fiscales y un índice único por clínica y número normalizado (sin espacios exteriores ni diferencia entre mayúsculas y minúsculas). No actualiza ni rellena facturas existentes. Si hay duplicados anteriores, la transacción falla sin eliminar ninguno; resolverlos con el responsable antes de volver a intentar.

El trigger privado verifica el rol admin/recepción y el paciente de la misma clínica antes de leer únicamente nombre, NIF y dirección. Copia los datos del emisor configurados en la clínica, con los valores de la plantilla existente como respaldo cuando no hay configuración. Descarta cualquier copia fiscal enviada por el cliente. Se revoca su ejecución directa a PUBLIC, anon y authenticated. SECURITY DEFINER permite copiar los campos fiscales con la misma operación para recepción sin conceder lectura directa de notas clínicas.

Los datos fiscales guardados, el paciente y el número de las nuevas facturas no se pueden modificar. Las antiguas permanecen sin copia histórica y la interfaz lo indica tanto en pantalla como en el archivo descargado. No se inventa su información anterior.

Validación: 57 pruebas automáticas; grupos de pacientes y caché. tests/billing-integrity-staging.sql comprueba duplicados normalizados, copia del servidor frente a una copia falsificada, inmutabilidad, cambios posteriores en paciente y emisor, perfiles y clínicas. Usa exclusivamente datos ficticios con ROLLBACK.

Reversión operativa: volver a publicar la versión anterior de app.js conservando la columna, el índice y el trigger. No borrar datos_fiscales: perdería información de facturas creadas después de la migración. No cambia la política tributaria de la plantilla ni implanta numeración automática.
