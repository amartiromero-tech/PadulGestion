-- Additive migration: does not rewrite or backfill existing invoices.
SET LOCAL lock_timeout='5s';
ALTER TABLE public.facturas ADD COLUMN datos_fiscales jsonb;
CREATE UNIQUE INDEX amr_facturas_numero_clinica_unique ON public.facturas(clinica_id,lower(btrim(numero))) WHERE nullif(btrim(numero),'') IS NOT NULL;
CREATE FUNCTION amr_private.factura_datos_fiscales() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE receptor jsonb; emisor jsonb;
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.datos_fiscales IS DISTINCT FROM OLD.datos_fiscales THEN
   RAISE EXCEPTION 'Los datos fiscales guardados no se pueden modificar.' USING ERRCODE='23514';
  END IF;
  IF OLD.datos_fiscales IS NOT NULL AND (NEW.numero IS DISTINCT FROM OLD.numero OR NEW.paciente_id IS DISTINCT FROM OLD.paciente_id) THEN
   RAISE EXCEPTION 'El número y el paciente de una factura guardada no se pueden modificar.' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
 END IF;
 IF NOT amr_private.has_role(NEW.clinica_id,ARRAY['admin','recepcion']::text[]) THEN
  RAISE EXCEPTION 'Sin permiso para crear facturas en esta clínica.' USING ERRCODE='42501';
 END IF;
 NEW.numero=btrim(NEW.numero);
 IF nullif(NEW.numero,'') IS NULL OR NEW.clinica_id IS NULL OR NEW.paciente_id IS NULL THEN
  RAISE EXCEPTION 'Indica clínica, paciente y número de factura.' USING ERRCODE='23514';
 END IF;
 SELECT jsonb_build_object('nombre',p.nombre,'nif',p.nif,'direccion',p.direccion)
 INTO receptor FROM public.pacientes p WHERE p.id=NEW.paciente_id AND p.clinica_id=NEW.clinica_id;
 IF receptor IS NULL THEN RAISE EXCEPTION 'Paciente ajeno a la clínica o no disponible.' USING ERRCODE='23503'; END IF;
 -- Only fiscal fields are copied; clinical notes never enter the invoice.
 SELECT jsonb_build_object(
 'nombre',CASE WHEN nullif(btrim(c.cif),'') IS NULL THEN 'Antonio Javier Martí Romero' ELSE c.nombre END,
 'comercial',coalesce(nullif(c.nombre,''),'AMR Clínicas de Fisioterapia'),
 'nif',coalesce(nullif(btrim(c.cif),''),'74671815S'),
 'direccion',coalesce(nullif(c.direccion,''),E'Calle Pósito, 14. Padul. Granada\nCalle Ruiseñor, 9 Bajo. Granada\nCalle Señor de la Expiración 6, Bajo. Lanjarón'),
 'telefono',coalesce(nullif(c.telefono,''),'958773665 - 698344334'))
 INTO emisor FROM public.clinicas c WHERE c.id=NEW.clinica_id;
 NEW.datos_fiscales=jsonb_build_object('version',1,'receptor',receptor,'emisor',emisor);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION amr_private.factura_datos_fiscales() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER amr_factura_datos_fiscales BEFORE INSERT OR UPDATE ON public.facturas FOR EACH ROW EXECUTE FUNCTION amr_private.factura_datos_fiscales();
COMMENT ON COLUMN public.facturas.datos_fiscales IS 'Server-captured fiscal snapshot for new invoices only. NULL means legacy invoice with no historical snapshot.';
