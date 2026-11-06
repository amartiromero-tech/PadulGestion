# WhatsApp: preparación desactivada

Esta entrega NO conecta con Meta, no contiene tokens, no instala cron y no envía WhatsApp. Las únicas acciones nuevas registran el permiso explícito o generan simulaciones. La tabla solo admite estados simulado/cancelado y ningún cliente puede escribir directamente en ella.

Aplicar whatsapp-preparacion.sql antes de publicar la interfaz. No actualiza pacientes, citas, facturas ni autorizaciones anteriores. Las nuevas tablas quedan vacías; no se presume autorización por el mero hecho de disponer del teléfono o de un documento legal antiguo.

El personal admin/fisio/recepción puede registrar permiso o retirada con referencia y fecha en fuente. Se guarda el actor y momento del registro y se vincula al teléfono normalizado actual. Supervisor solo consulta. Se exige volver a registrar el permiso si cambia el teléfono. Estos registros administrativos no sustituyen el documento o evidencia de autorización.

Solo admin puede simular. Se examinan citas confirmadas/pendientes de las próximas 24 horas, con fecha/hora interpretadas en Europe/Madrid y recordatorio previsto 24 horas antes. Las citas canceladas/pasadas, horas no válidas y teléfonos sin permiso se omiten. Se invalidan las simulaciones al detectar cambios de cita, teléfono o permiso; la retirada cancela inmediatamente sus simulaciones. La unicidad por clínica/cita/inicio evita filas repetidas aun con peticiones simultáneas. Reautorizar un número puede reactivar la misma simulación.

La simulación guarda un mensaje genérico de cita (sin motivo, notas ni diagnósticos), y se identifica siempre como no enviado. La pantalla muestra los últimos 50 registros de la clínica. No existen estados enviados/entregados porque aún no hay integración real.

Las funciones con SECURITY DEFINER están en amr_private, tienen search_path vacío y verifican rol/clínica antes de leer únicamente los campos necesarios. Las tablas tienen RLS por clínica, SELECT para personal autorizado y DML directo revocado. Los wrappers públicos son invoker; los permisos privados permiten invocarlos pero no omiten las comprobaciones de autorización.

Pruebas: 76 pruebas automáticas, pacientes y caché; tests/whatsapp-staging.sql verifica permiso, cambio de teléfono, retirada, repetición, citas inválidas, roles, aislamiento y ausencia de texto clínico usando solo datos ficticios y ROLLBACK.

Pendiente para activar: cuenta empresarial de Meta, número compatible/conectado, plantilla aprobada y coste revisado; integración de servidor con secretos privados, programador, firma de webhooks, recepción de bajas, entrega/errores y control idempotente de reintentos. Debe volver a validarse cita, teléfono y permiso justo antes del envío. No debe activarse esta tabla como cola de envío sin implementar y probar esas piezas.
