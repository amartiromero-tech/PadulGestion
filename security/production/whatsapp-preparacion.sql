-- Preparation only. No provider, network request, cron or live delivery is installed.
SET LOCAL lock_timeout='5s';
CREATE TABLE public.whatsapp_permisos(
 clinica_id bigint NOT NULL REFERENCES public.clinicas(id),
 paciente_id bigint NOT NULL,
 permitido boolean NOT NULL DEFAULT false,
 telefono text NOT NULL,
 fuente text NOT NULL CHECK(length(btrim(fuente)) BETWEEN 1 AND 500),
 registrado_por uuid NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(clinica_id,paciente_id),
 FOREIGN KEY(clinica_id,paciente_id) REFERENCES public.pacientes(clinica_id,id)
);
CREATE TABLE public.whatsapp_recordatorios(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 clinica_id bigint NOT NULL REFERENCES public.clinicas(id),
 cita_id bigint NOT NULL REFERENCES public.citas(id),
 paciente_id bigint NOT NULL,
 inicio timestamptz NOT NULL,
 programado_para timestamptz NOT NULL,
 telefono text NOT NULL,
 mensaje text NOT NULL,
 estado text NOT NULL DEFAULT 'simulado' CHECK(estado IN ('simulado','cancelado')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(clinica_id,cita_id,inicio),
 FOREIGN KEY(clinica_id,paciente_id) REFERENCES public.pacientes(clinica_id,id)
);
ALTER TABLE public.whatsapp_permisos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.whatsapp_recordatorios ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.whatsapp_permisos,public.whatsapp_recordatorios FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.whatsapp_permisos,public.whatsapp_recordatorios TO authenticated;
CREATE POLICY amr_read ON public.whatsapp_permisos FOR SELECT TO authenticated USING(amr_private.has_role(clinica_id,ARRAY['admin','fisio','recepcion','supervisor']));
CREATE POLICY amr_read ON public.whatsapp_recordatorios FOR SELECT TO authenticated USING(amr_private.has_role(clinica_id,ARRAY['admin','fisio','recepcion','supervisor']));
CREATE INDEX amr_whatsapp_recordatorios_clinica_fecha ON public.whatsapp_recordatorios(clinica_id,created_at DESC);
CREATE FUNCTION amr_private.whatsapp_telefono(p_valor text) RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN n ~ '^[67][0-9]{8}$' THEN '34'||n ELSE n END
 FROM (SELECT regexp_replace(regexp_replace(coalesce(p_valor,''),'[^0-9]','','g'),'^00','') n) s;
$$;
REVOKE ALL ON FUNCTION amr_private.whatsapp_telefono(text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION amr_private.whatsapp_permiso(p_clinica_id bigint,p_paciente_id bigint,p_permitido boolean,p_fuente text)
RETURNS public.whatsapp_permisos LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE tel text;fila public.whatsapp_permisos;
BEGIN
 IF NOT amr_private.has_role(p_clinica_id,ARRAY['admin','fisio','recepcion']) THEN RAISE EXCEPTION 'Sin permiso para registrar la autorización.' USING ERRCODE='42501'; END IF;
 IF p_permitido IS NULL OR nullif(btrim(p_fuente),'') IS NULL OR length(p_fuente)>500 THEN RAISE EXCEPTION 'Indica cómo y cuándo se obtuvo o retiró el permiso.'; END IF;
 SELECT amr_private.whatsapp_telefono(telefono) INTO tel FROM public.pacientes WHERE id=p_paciente_id AND clinica_id=p_clinica_id;
 IF tel IS NULL THEN RAISE EXCEPTION 'Paciente no disponible en esta clínica.'; END IF;
 IF p_permitido AND tel !~ '^[1-9][0-9]{7,14}$' THEN RAISE EXCEPTION 'Revisa el teléfono, incluido el prefijo internacional.'; END IF;
 INSERT INTO public.whatsapp_permisos(clinica_id,paciente_id,permitido,telefono,fuente,registrado_por)
 VALUES(p_clinica_id,p_paciente_id,p_permitido,tel,btrim(p_fuente),auth.uid())
 ON CONFLICT(clinica_id,paciente_id) DO UPDATE SET permitido=excluded.permitido,telefono=excluded.telefono,fuente=excluded.fuente,registrado_por=excluded.registrado_por,updated_at=now()
 RETURNING * INTO fila;
 UPDATE public.whatsapp_recordatorios SET estado='cancelado' WHERE clinica_id=p_clinica_id AND paciente_id=p_paciente_id AND (NOT p_permitido OR telefono<>tel);
 RETURN fila;
END $$;
REVOKE ALL ON FUNCTION amr_private.whatsapp_permiso(bigint,bigint,boolean,text) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.amr_whatsapp_permiso(p_clinica_id bigint,p_paciente_id bigint,p_permitido boolean,p_fuente text)
RETURNS public.whatsapp_permisos LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT amr_private.whatsapp_permiso(p_clinica_id,p_paciente_id,p_permitido,p_fuente);
$$;
GRANT EXECUTE ON FUNCTION amr_private.whatsapp_permiso(bigint,bigint,boolean,text) TO authenticated;
REVOKE ALL ON FUNCTION public.amr_whatsapp_permiso(bigint,bigint,boolean,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.amr_whatsapp_permiso(bigint,bigint,boolean,text) TO authenticated;

CREATE FUNCTION amr_private.whatsapp_simular(p_clinica_id bigint)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE n integer;
BEGIN
 IF NOT amr_private.has_role(p_clinica_id,ARRAY['admin']) THEN RAISE EXCEPTION 'Solo administración puede generar la simulación.' USING ERRCODE='42501'; END IF;
 -- Cancel stale simulations after rescheduling, cancellation, withdrawal or contact change.
 UPDATE public.whatsapp_recordatorios r SET estado='cancelado'
 WHERE r.clinica_id=p_clinica_id AND r.estado='simulado' AND NOT EXISTS(
  SELECT 1 FROM public.citas c JOIN public.pacientes p ON p.id=c.paciente_id AND p.clinica_id=c.clinica_id
  JOIN public.whatsapp_permisos a ON a.clinica_id=p.clinica_id AND a.paciente_id=p.id
  WHERE c.id=r.cita_id AND c.clinica_id=r.clinica_id AND c.paciente_id=r.paciente_id
  AND c.hora ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$'
  AND CASE WHEN c.hora ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' THEN (c.fecha+c.hora::time) AT TIME ZONE 'Europe/Madrid' END=r.inicio
  AND lower(btrim(c.estado)) IN ('confirmada','pendiente')
  AND a.permitido AND a.telefono=amr_private.whatsapp_telefono(p.telefono) AND a.telefono=r.telefono
 );
 INSERT INTO public.whatsapp_recordatorios(clinica_id,cita_id,paciente_id,inicio,programado_para,telefono,mensaje)
 SELECT c.clinica_id,c.id,c.paciente_id,t.inicio,t.inicio-interval '24 hours',a.telefono,
 'Te recordamos tu cita en '||coalesce(nullif(cl.nombre,''),'la clínica')||' el '||to_char(c.fecha,'DD/MM/YYYY')||' a las '||left(c.hora,5)||'. Si necesitas cambiarla, contacta con la clínica.'
 FROM public.citas c
 JOIN public.pacientes p ON p.id=c.paciente_id AND p.clinica_id=c.clinica_id
 JOIN public.whatsapp_permisos a ON a.paciente_id=p.id AND a.clinica_id=p.clinica_id
 JOIN public.clinicas cl ON cl.id=c.clinica_id
 CROSS JOIN LATERAL (SELECT CASE WHEN c.hora ~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' THEN (c.fecha+c.hora::time) AT TIME ZONE 'Europe/Madrid' END inicio) t
 WHERE c.clinica_id=p_clinica_id AND a.permitido AND a.telefono=amr_private.whatsapp_telefono(p.telefono)
 AND lower(btrim(c.estado)) IN ('confirmada','pendiente') AND t.inicio>now() AND t.inicio<=now()+interval '24 hours'
 ON CONFLICT(clinica_id,cita_id,inicio) DO UPDATE SET estado='simulado',telefono=excluded.telefono,mensaje=excluded.mensaje
 WHERE whatsapp_recordatorios.estado<>'simulado' OR whatsapp_recordatorios.telefono<>excluded.telefono;
 GET DIAGNOSTICS n=ROW_COUNT;
 RETURN n;
END $$;
REVOKE ALL ON FUNCTION amr_private.whatsapp_simular(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION amr_private.whatsapp_simular(bigint) TO authenticated;
CREATE FUNCTION public.amr_whatsapp_simular(p_clinica_id bigint) RETURNS integer LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$
 SELECT amr_private.whatsapp_simular(p_clinica_id);
$$;
REVOKE ALL ON FUNCTION public.amr_whatsapp_simular(bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.amr_whatsapp_simular(bigint) TO authenticated;
COMMENT ON TABLE public.whatsapp_recordatorios IS 'Simulation only, no outbound messaging. Live sending requires a separate reviewed integration and migration.';