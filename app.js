
async function asegurarClinicaActiva(){
  try{
    const {data:sessionData}=await sb.auth.getSession();
    const user=sessionData?.session?.user || null;

    if(user){
      const rel=await sb.from("usuarios_clinica").select("*, clinicas(*)").eq("auth_user_id",user.id).maybeSingle();
      if(rel.data && rel.data.clinicas){
        usuarioClinica=rel.data;
        clinicaActiva=rel.data.clinicas;
        localStorage.setItem("clinica_id", String(clinicaActiva.id));
        aplicarBrandingClinica();
        return clinicaActiva;
      }
    }

    const saved=localStorage.getItem("clinica_id");
    if(saved){
      const c=await sb.from("clinicas").select("*").eq("id",Number(saved)).maybeSingle();
      if(c.data){
        clinicaActiva=c.data;
        aplicarBrandingClinica();
        return clinicaActiva;
      }
    }

    const first=await sb.from("clinicas").select("*").order("id",{ascending:true}).limit(1).maybeSingle();
    if(first.data){
      clinicaActiva=first.data;
      localStorage.setItem("clinica_id", String(clinicaActiva.id));
      aplicarBrandingClinica();
      return clinicaActiva;
    }

    const nueva={nombre:"AMR Clínicas de Fisioterapia",telefono:"698344334",email:"amrclinicasfisio@hotmail.com",direccion:"Granada",cif:"74671815S",color_principal:"#14b8a6",logo:window.AMR_LOGO||""};
    const ins=await sb.from("clinicas").insert(nueva).select().single();
    clinicaActiva=ins.data||nueva;
    if(clinicaActiva.id)localStorage.setItem("clinica_id", String(clinicaActiva.id));
    aplicarBrandingClinica();
    return clinicaActiva;
  }catch(e){
    clinicaActiva={id:Number(localStorage.getItem("clinica_id")||1),nombre:"AMR Clínicas de Fisioterapia",telefono:"698344334",email:"amrclinicasfisio@hotmail.com",direccion:"Granada",cif:"74671815S",color_principal:"#14b8a6",logo:window.AMR_LOGO||""};
    aplicarBrandingClinica();
    return clinicaActiva;
  }
}
function clinicaId(){return Number(clinicaActiva?.id || localStorage.getItem("clinica_id") || 1)}
function withClinica(data){return {...data, clinica_id:clinicaId()}}
function aplicarBrandingClinica(){
  if(!clinicaActiva)return;
  document.documentElement.style.setProperty("--teal", clinicaActiva.color_principal||"#14b8a6");
  const logo=clinicaActiva.logo||window.AMR_LOGO||"";
  document.querySelectorAll(".logo,.loginLogo").forEach(img=>{if(logo)img.src=logo});
  document.title=(clinicaActiva.nombre||"Clínica")+" PRO";
  if(document.getElementById("cfgNombre"))rellenarConfigClinica();
}
function rellenarConfigClinica(){
  if(!clinicaActiva||!document.getElementById("cfgNombre"))return;
  cfgNombre.value=clinicaActiva.nombre||"";
  cfgTelefono.value=clinicaActiva.telefono||"";
  cfgEmail.value=clinicaActiva.email||"";
  cfgCif.value=clinicaActiva.cif||"";
  cfgDireccion.value=clinicaActiva.direccion||"";
  cfgColor.value=clinicaActiva.color_principal||"#14b8a6";
  cfgLogo.value=clinicaActiva.logo||"";
  cfgLogoPreview.src=clinicaActiva.logo||window.AMR_LOGO||"";
  cfgNombrePreview.textContent=clinicaActiva.nombre||"Clínica";
  cfgDatosPreview.textContent=`${clinicaActiva.direccion||""}\n${clinicaActiva.telefono||""} · ${clinicaActiva.email||""}\nCIF/NIF: ${clinicaActiva.cif||""}`;
  cfgClinicaIdText.textContent=`ID clínica: ${clinicaActiva.id||"local"} · Rol: ${usuarioClinica?.rol||"admin/local"}`;
}
async function guardarClinicaConfig(){
  const data={nombre:cfgNombre.value,telefono:cfgTelefono.value,email:cfgEmail.value,cif:cfgCif.value,direccion:cfgDireccion.value,color_principal:cfgColor.value,logo:cfgLogo.value||window.AMR_LOGO||""};
  let r;
  if(clinicaActiva?.id)r=await sb.from("clinicas").update(data).eq("id",clinicaActiva.id).select().single();
  else r=await sb.from("clinicas").insert(data).select().single();
  if(r.error)return alert("Error guardando clínica: "+r.error.message);
  clinicaActiva=r.data;
  localStorage.setItem("clinica_id", String(clinicaActiva.id));
  aplicarBrandingClinica();
  alert("Configuración guardada.");
}


const SUPABASE_URL="https://gjwxsaczasfprwochzyw.supabase.co";
const SUPABASE_KEY="sb_publishable_zH89akxkPVSGUg6BSjtjjg_vl06k6oB";
const sb=supabase.createClient(SUPABASE_URL,SUPABASE_KEY);

let pacientes=[], citas=[], consentimientos=[], firmasSesiones=[], historias=[], facturas=[];
let clinicaActiva=null, usuarioClinica=null;
let usuariosClinica=[];
let weekOffset=0, selectedDate=localISO(new Date()), selectedPacienteId=null;

const legalDocs={
 rgpd:["Protección de datos RGPD","El paciente autoriza el tratamiento de sus datos personales y sanitarios para prestación de fisioterapia, gestión de citas, historia clínica, facturación y comunicaciones necesarias. Podrá ejercer sus derechos conforme al RGPD y LOPDGDD."],
 fisio:["Consentimiento informado de fisioterapia","El paciente declara haber sido informado de objetivos, beneficios, alternativas y riesgos del tratamiento fisioterapéutico, como molestias transitorias, agujetas, hematomas leves, mareo o aumento temporal del dolor."],
 whatsapp:["Autorización WhatsApp","El paciente autoriza comunicaciones por WhatsApp, teléfono, SMS o email para recordatorios de citas, cambios de agenda, justificantes, facturas e indicaciones relacionadas con el tratamiento."],
 puncion:["Consentimiento específico de punción seca","La punción seca es una técnica invasiva con aguja estéril. Puede producir dolor, hematoma, pequeño sangrado, inflamación local, mareo o cansancio temporal."],
 ondas:["Consentimiento para ondas de choque","Las ondas de choque pueden producir dolor local, enrojecimiento, hematoma o aumento temporal de síntomas durante 24-72 horas. El paciente declara haber sido informado."],
 sesion:["Firma de sesión","El paciente confirma haber recibido la sesión indicada y firma su asistencia y conformidad con la prestación del servicio."]
};

function localISO(d){const x=new Date(d);return `${x.getFullYear()}-${String(x.getMonth()+1).padStart(2,"0")}-${String(x.getDate()).padStart(2,"0")}`}
function addDays(d,n){const x=new Date(d);x.setDate(x.getDate()+n);return x}
function monday(d){const x=new Date(d);const day=x.getDay();x.setDate(x.getDate()-day+(day===0?-6:1));x.setHours(0,0,0,0);return x}
function paciente(id){return pacientes.find(p=>p.id==id)||{}}
function eur(n){return `${Number(n||0).toFixed(0)}€`}

async function init(){
 await checkLogin();
 await loadCloud();
 setTimeout(setupFirma,500);
 renderLegalDoc();
}
document.addEventListener("DOMContentLoaded",init);

async function checkLogin(){
 const bypass=localStorage.getItem("amr_bypass")==="1";
 try{
   const {data}=await sb.auth.getSession();
   document.getElementById("loginOverlay").style.display=(data.session||bypass)?"none":"flex";
 }catch(e){document.getElementById("loginOverlay").style.display=bypass?"none":"flex";}
}
async function login(){loginMsg.textContent="";const {error}=await sb.auth.signInWithPassword({email:loginEmail.value.trim(),password:loginPassword.value});if(error){loginMsg.textContent=error.message;return} await checkLogin(); await loadCloud();}
async function signup(){loginMsg.textContent="";const {error}=await sb.auth.signUp({email:loginEmail.value.trim(),password:loginPassword.value});loginMsg.textContent=error?error.message:"Usuario creado. Revisa tu correo si pide confirmación."}
function bypassLogin(){localStorage.setItem("amr_bypass","1");checkLogin()}
async function logout(){localStorage.removeItem("amr_bypass");try{await sb.auth.signOut()}catch(e){} checkLogin()}

async function loadCloud(){
 await asegurarClinicaActiva();
 await cargarUsuariosClinica();
 const id=clinicaId();
 const [p,c,co,fs,h,f]=await Promise.all([
   sb.from("pacientes").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("id"),
   sb.from("citas").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("fecha"),
   sb.from("consentimientos").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("created_at",{ascending:false}),
   sb.from("firmas_sesiones").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("created_at",{ascending:false}),
   sb.from("historias_clinicas").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("updated_at",{ascending:false}),
   sb.from("facturas").select("*").or(`clinica_id.eq.${id},clinica_id.is.null`).order("id",{ascending:false})
 ]);
 pacientes=p.data||[]; citas=c.data||[]; consentimientos=co.data||[]; firmasSesiones=fs.data||[]; historias=h.data||[]; facturas=f.data||[];
 selectedPacienteId=selectedPacienteId||pacientes[0]?.id||null;
 render();
}

function showSection(id, btn){
 document.querySelectorAll(".section").forEach(s=>s.classList.remove("active"));
 document.getElementById(id)?.classList.add("active");
 if(btn){document.querySelectorAll("nav button").forEach(b=>b.classList.remove("active"));btn.classList.add("active")}
 render();
 if(id==="legal"){setTimeout(setupFirma,250);setTimeout(setupFirma,700);}
}

function render(){
 fillSelects(); renderDashboard(); renderCalendar(); renderToday(); renderCitas(); renderPacientes(); renderLegalHistory(); loadHistoriaToForm(); renderFacturas();
}
function fillSelects(){
 const opts=pacientes.map(p=>`<option value="${p.id}">${p.nombre}</option>`).join("");
 ["citaPaciente","histPaciente","legalPaciente","facPaciente"].forEach(id=>{const el=document.getElementById(id); if(el){const old=el.value; el.innerHTML='<option value="">Seleccionar paciente</option>'+opts; if(old)el.value=old; else if(selectedPacienteId)el.value=selectedPacienteId;}});
 if(!citaFecha.value)citaFecha.value=selectedDate;
}
function renderDashboard(){
 const today=localISO(new Date());
 const weekDays=[0,1,2,3,4,5,6].map(i=>localISO(addDays(monday(new Date()),i)));
 kpiHoy.textContent=citas.filter(c=>c.fecha===today).length;
 kpiPacientes.textContent=pacientes.length;
 kpiIngresos.textContent=eur(citas.filter(c=>weekDays.includes(c.fecha)).reduce((a,c)=>a+Number(c.precio||0),0));
 kpiFirmas.textContent=consentimientos.length+firmasSesiones.length;
}
function prevWeek(){weekOffset--;renderCalendar()}
function nextWeek(){weekOffset++;renderCalendar()}
function goToday(){weekOffset=0;selectedDate=localISO(new Date());renderCalendar();renderToday()}
function renderCalendar(){
 const start=monday(addDays(new Date(),weekOffset*7)); const days=[0,1,2,3,4,5,6].map(i=>addDays(start,i));
 weekLabel.textContent=`${days[0].toLocaleDateString("es-ES",{day:"2-digit",month:"short"})} - ${days[6].toLocaleDateString("es-ES",{day:"2-digit",month:"short",year:"numeric"})}`;
 const hours=[]; for(let h=8;h<=20;h++)hours.push(String(h).padStart(2,"0")+":00");
 let out='<div class="calHead"></div>'; const today=localISO(new Date());
 days.forEach(d=>{const iso=localISO(d); out+=`<div class="calHead ${iso===today?'today':''}">${d.toLocaleDateString("es-ES",{weekday:"short",day:"2-digit",month:"short"})}<small>${iso}</small></div>`});
 hours.forEach(h=>{out+=`<div class="time">${h}</div>`; days.forEach((d,di)=>{const iso=localISO(d); const arr=citas.filter(c=>c.fecha===iso&&String(c.hora||"").slice(0,2)===h.slice(0,2)); out+=`<div class="cell" onclick="newCita('${iso}','${h}')">`; arr.forEach((c,idx)=>{const p=paciente(c.paciente_id); out+=`<div class="event" onclick="event.stopPropagation();editCita(${c.id})"><b>${c.hora} · ${p.nombre||'Paciente'}</b><span>${c.motivo||'Tratamiento'}</span></div>`}); out+='</div>'})});
 weeklyCalendar.innerHTML=out;
}
function renderToday(){const today=selectedDate; const arr=citas.filter(c=>c.fecha===today).sort((a,b)=>String(a.hora).localeCompare(String(b.hora))); todayList.innerHTML=arr.map(c=>citaItem(c)).join("")||"<p>No hay citas.</p>"}
function citaItem(c){const p=paciente(c.paciente_id);return `<div class="item"><b>${c.hora} · ${p.nombre||"Paciente"}</b><p>${c.fecha} · ${c.motivo||""} · ${eur(c.precio)} · ${c.estado||""}</p><div class="row"><button class="btn light" onclick="editCita(${c.id})">Editar</button><button class="btn ghost" onclick="deleteCita(${c.id})">Borrar</button></div></div>`}
function renderCitas(){allCitas.innerHTML=[...citas].sort((a,b)=>(b.fecha+b.hora).localeCompare(a.fecha+a.hora)).slice(0,80).map(citaItem).join("")||"<p>Sin citas.</p>"}
function newCita(fecha=localISO(new Date()), hora="09:00"){showSection("agenda");citaId.value="";citaFecha.value=fecha;citaHora.value=hora;citaPaciente.value=selectedPacienteId||""}
function editCita(id){const c=citas.find(x=>x.id==id);if(!c)return;showSection("agenda");citaId.value=c.id;citaPaciente.value=c.paciente_id;citaFecha.value=c.fecha;citaHora.value=c.hora;citaMotivo.value=c.motivo||"";citaPrecio.value=c.precio||35;citaEstado.value=c.estado||"Confirmada"}
async function saveCita(){const data={paciente_id:Number(citaPaciente.value),fecha:citaFecha.value,hora:citaHora.value,motivo:citaMotivo.value,precio:Number(citaPrecio.value||0),estado:citaEstado.value}; if(!data.paciente_id)return alert("Selecciona paciente"); const r=citaId.value?await sb.from("citas").update(data).eq("id",Number(citaId.value)):await sb.from("citas").insert(withClinica(data)); if(r.error)return alert(r.error.message); await loadCloud();}
async function deleteCita(id){if(confirm("¿Borrar cita?")){await sb.from("citas").delete().eq("id",id); await loadCloud()}}

function renderPacientes(){const q=(buscarPaciente?.value||"").toLowerCase(); pacientesList.innerHTML=pacientes.filter(p=>p.nombre.toLowerCase().includes(q)).map(p=>`<div class="item"><b>${p.nombre}</b><p>${p.telefono||""} · ${p.nif||""}</p><div class="row"><button class="btn light" onclick="editPaciente(${p.id})">Editar</button><button class="btn ghost" onclick="deletePaciente(${p.id})">Borrar</button></div></div>`).join("")||"<p>Sin pacientes.</p>"}
function editPaciente(id){const p=paciente(id);selectedPacienteId=id;pacienteId.value=p.id;pacNombre.value=p.nombre||"";pacTelefono.value=p.telefono||"";pacNif.value=p.nif||"";pacDireccion.value=p.direccion||"";pacNotas.value=p.notas||""}
async function savePaciente(){const data={nombre:pacNombre.value,telefono:pacTelefono.value,nif:pacNif.value,direccion:pacDireccion.value,notas:pacNotas.value}; if(!data.nombre)return alert("Pon nombre"); const r=pacienteId.value?await sb.from("pacientes").update(data).eq("id",Number(pacienteId.value)):await sb.from("pacientes").insert(withClinica(data)); if(r.error)return alert(r.error.message); pacienteId.value=""; await loadCloud();}
async function deletePaciente(id){if(confirm("¿Borrar paciente?")){await sb.from("pacientes").delete().eq("id",id); await loadCloud()}}

function loadHistoriaToForm(){const pid=Number(histPaciente.value||selectedPacienteId||0); const h=historias.find(x=>x.paciente_id==pid)||{}; histMotivo.value=h.motivo||"";histExploracion.value=h.exploracion||"";histDiagnostico.value=h.diagnostico||"";histObjetivos.value=h.objetivos||"";histEjercicios.value=h.ejercicios||"";renderEvoluciones(h.evoluciones||[])}
function renderEvoluciones(evos){evolucionesList.innerHTML=(evos||[]).map(e=>`<div class="item"><b>${new Date(e.fecha).toLocaleString("es-ES")}</b><p>${e.texto}</p></div>`).join("")||"<p>Sin evoluciones.</p>"}
async function saveHistoria(){const pid=Number(histPaciente.value||0); if(!pid)return alert("Selecciona paciente"); const old=historias.find(x=>x.paciente_id==pid); const data={paciente_id:pid,motivo:histMotivo.value,exploracion:histExploracion.value,diagnostico:histDiagnostico.value,objetivos:histObjetivos.value,ejercicios:histEjercicios.value,evoluciones:old?.evoluciones||[],updated_at:new Date().toISOString()}; const r=old?await sb.from("historias_clinicas").update(data).eq("id",old.id):await sb.from("historias_clinicas").insert(withClinica(data)); if(r.error)return alert("Error: "+r.error.message); await loadCloud(); alert("Historia guardada")}
async function addEvolucion(){const pid=Number(histPaciente.value||0); const txt=nuevaEvolucion.value.trim(); if(!pid||!txt)return alert("Selecciona paciente y escribe evolución"); let old=historias.find(x=>x.paciente_id==pid); let evos=old?.evoluciones||[]; evos.unshift({fecha:new Date().toISOString(),texto:txt}); if(!old){await sb.from("historias_clinicas").insert(withClinica({paciente_id:pid,evoluciones:evos,updated_at:new Date().toISOString()}))}else{await sb.from("historias_clinicas").update({evoluciones:evos,updated_at:new Date().toISOString()}).eq("id",old.id)} nuevaEvolucion.value=""; await loadCloud();}

function renderLegalDoc(){const d=legalDocs[legalTipo.value]||legalDocs.rgpd; legalTitulo.textContent=d[0]; legalTexto.textContent=d[1];}
function setupFirma(){
 const c=document.getElementById("firmaCanvas");
 if(!c)return;

 const ctx=c.getContext("2d");

 function resize(){
   const r=c.getBoundingClientRect();
   const w=Math.max(300, Math.floor(r.width || c.parentElement?.clientWidth || 500));
   const h=230;
   const old=c.toDataURL && c.width>0 ? c.toDataURL("image/png") : null;

   c.width=w;
   c.height=h;

   ctx.lineWidth=3;
   ctx.lineCap="round";
   ctx.lineJoin="round";
   ctx.strokeStyle="#111827";

   if(old){
     const img=new Image();
     img.onload=()=>ctx.drawImage(img,0,0,w,h);
     img.src=old;
   }
 }

 resize();

 if(c.dataset.ready)return;
 c.dataset.ready="1";

 let drawing=false;

 function pos(e){
   const r=c.getBoundingClientRect();
   const p=e.touches?e.touches[0]:e;
   return {
     x:(p.clientX-r.left)*(c.width/r.width),
     y:(p.clientY-r.top)*(c.height/r.height)
   };
 }

 function start(e){
   drawing=true;
   const p=pos(e);
   ctx.beginPath();
   ctx.moveTo(p.x,p.y);
   e.preventDefault();
 }

 function move(e){
   if(!drawing)return;
   const p=pos(e);
   ctx.lineTo(p.x,p.y);
   ctx.stroke();
   e.preventDefault();
 }

 function end(){
   drawing=false;
 }

 c.addEventListener("mousedown",start);
 c.addEventListener("mousemove",move);
 window.addEventListener("mouseup",end);

 c.addEventListener("touchstart",start,{passive:false});
 c.addEventListener("touchmove",move,{passive:false});
 c.addEventListener("touchend",end,{passive:false});
 c.addEventListener("touchcancel",end,{passive:false});

 window.addEventListener("resize",()=>setTimeout(resize,150));
}
function clearFirma(){const c=firmaCanvas;c.getContext("2d").clearRect(0,0,c.width,c.height)}
function firmaData(){return firmaCanvas.toDataURL("image/png")}
async function saveLegal(){const pid=Number(legalPaciente.value); if(!pid)return alert("Selecciona paciente"); if(!legalAcepta.checked)return alert("Marca aceptación"); const tipo=legalTipo.value; const firma=firmaData(); const notas=legalNotas.value; const r= tipo==="sesion" ? await sb.from("firmas_sesiones").insert(withClinica({paciente_id:pid,fecha:localISO(new Date()),hora:"",motivo:"Firma de sesión",importe:0,notas,firma,confirmado:true,created_at:new Date().toISOString()})) : await sb.from("consentimientos").insert(withClinica({paciente_id:pid,tipo,profesional:"Antonio Javier Martí Romero",centro:clinicaActiva?.nombre||"Clínica",notas,firma,aceptado:true,fecha:new Date().toISOString()})); if(r.error)return alert(r.error.message); alert("Documento guardado"); clearFirma(); legalAcepta.checked=false; await loadCloud();}
function renderLegalHistory(){const pid=Number(legalPaciente.value||0); const docs=[...consentimientos.filter(x=>x.paciente_id==pid),...firmasSesiones.filter(x=>x.paciente_id==pid).map(x=>({...x,tipo:"sesion"}))]; legalHistory.innerHTML=docs.map(d=>`<div class="item"><b>${legalDocs[d.tipo]?.[0]||d.tipo}</b><p>${new Date(d.created_at||d.fecha).toLocaleString("es-ES")}</p></div>`).join("")||"<p>Sin documentos.</p>"}
function printLegal(){const p=paciente(Number(legalPaciente.value)); const d=legalDocs[legalTipo.value]; printArea.innerHTML=`<h1>AMR Clínicas Fisioterapia</h1><h2>${d[0]}</h2><p><b>Paciente:</b> ${p.nombre||""}</p><p>${d[1]}</p><p><b>Observaciones:</b> ${legalNotas.value}</p><img src="${firmaData()}" style="width:360px;border:1px solid #ddd;border-radius:12px">`; window.print();}


function crearFactura(){
  const p = paciente(Number(facPaciente.value));
  const numero = facNumero.value.trim() || "0001";
  const concepto = facConcepto.value.trim() || "TRATAMIENTOS DE FISIOTERAPIA";
  const cantidad = Number(facCantidad.value || 1);
  const precio = Number(facPrecio.value || 0);
  const total = cantidad * precio;
  const fecha = new Date().toLocaleDateString("es-ES");

  const html = `
  <div id="facturaAMR" class="facturaAMR">
    <div class="facturaHeader">
      <div>
        <img src="${window.AMR_LOGO || ""}" class="facturaLogo">
      </div>
      <div class="facturaEmpresa">
        <b>Antonio Javier Martí Romero</b><br>
        AMR Clínicas de Fisioterapia<br>
        Calle Pósito, 14. Padul. Granada<br>
        Calle Ruiseñor, 9 Bajo. Granada<br>
        Calle Señor de la Expiración 6, Bajo. Lanjarón<br>
        Teléfonos: 958773665 - 698344334<br>
        NIF: 74671815S
      </div>
    </div>

    <div class="facturaBar"></div>

    <div class="facturaDatos">
      <div>
        <b>${p.nombre || "Paciente"}</b><br>
        NIF: ${p.nif || ""}<br>
        ${p.direccion || ""}
      </div>
      <div class="facturaNumero">
        <h1>FACTURA Nº ${numero}</h1>
        <p>${fecha}</p>
      </div>
    </div>

    <table class="facturaTabla">
      <thead>
        <tr>
          <th>Descripción</th>
          <th>Cantidad</th>
          <th>Precio unitario</th>
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>${concepto}</td>
          <td>${cantidad}</td>
          <td>${precio}€</td>
          <td><b>${total}€</b></td>
        </tr>
      </tbody>
    </table>

    <div class="facturaTotales">
      <div><span>Subtotal:</span><b>${total} €</b></div>
      <div><span>IRPF (0%):</span><b>0 €</b></div>
      <div class="facturaTotalFinal"><span>Total a pagar:</span><b>${total} €</b></div>
    </div>

    <div class="facturaFooter">
      <img src="${window.AMR_LOGO || ""}">
      <div>AMR<br><span>Clínicas de Fisioterapia</span></div>
    </div>
  </div>

  <div class="row facturaActions">
    <button class="btn" onclick="imprimirFacturaAMR()">Imprimir / PDF</button>
    <button class="btn light" onclick="descargarFacturaAMR()">Guardar archivo</button>
  </div>
  `;

  facturaPreview.innerHTML = html;

  try{
    sb.from("facturas").insert(withClinica({
      numero,
      paciente_id:p.id || null,
      fecha:localISO(new Date()),
      concepto,
      cantidad,
      precio,
      total
    }));
  }catch(e){}
}

function imprimirFacturaAMR(){
  const factura = document.getElementById("facturaAMR");
  if(!factura) return alert("Primero crea la factura.");
  const ventana = window.open("", "_blank");
  ventana.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Factura AMR</title>
      <style>${document.querySelector("style")?.innerHTML || ""}</style>
      <link rel="stylesheet" href="styles.css">
    </head>
    <body style="background:white;padding:20px">
      ${factura.outerHTML}
      <script>window.onload=function(){window.print();}</script>
    </body>
    </html>
  `);
  ventana.document.close();
}

function descargarFacturaAMR(){
  const factura = document.getElementById("facturaAMR");
  if(!factura) return alert("Primero crea la factura.");
  const html = `<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8"><title>Factura AMR</title><link rel="stylesheet" href="styles.css"></head><body style="background:white;padding:20px">${factura.outerHTML}</body></html>`;
  const blob = new Blob([html], {type:"text/html;charset=utf-8"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "Factura_AMR_" + (facNumero.value.trim() || "0001") + ".html";
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}
function renderFacturas(){}



/* ===== WhatsApp PRO ===== */
function telefonoLimpio(t){
  let x=String(t||"").replace(/\D/g,"");
  if(x.startsWith("00"))x=x.slice(2);
  if((x.startsWith("6")||x.startsWith("7"))&&x.length===9)x="34"+x;
  return x;
}

function fillProSelects(){
  const opts=(pacientes||[]).map(p=>`<option value="${p.id}">${p.nombre}</option>`).join("");
  ["waPaciente","iaPaciente"].forEach(id=>{
    const el=document.getElementById(id);
    if(el){
      const old=el.value;
      el.innerHTML='<option value="">Seleccionar paciente</option>'+opts;
      if(old)el.value=old;
      else if(selectedPacienteId)el.value=selectedPacienteId;
    }
  });
  renderWaCitas();
}

function renderWaCitas(){
  const sel=document.getElementById("waCita");
  if(!sel)return;
  const pid=Number(document.getElementById("waPaciente")?.value||selectedPacienteId||0);
  const arr=(citas||[])
    .filter(c=>!pid||c.paciente_id==pid)
    .sort((a,b)=>(a.fecha+a.hora).localeCompare(b.fecha+b.hora));
  sel.innerHTML=arr.map(c=>`<option value="${c.id}">${c.fecha} · ${c.hora} · ${paciente(c.paciente_id).nombre||"Paciente"} · ${c.motivo||""}</option>`).join("") || '<option value="">Sin citas</option>';
}

function generarWhatsappPro(){
  const pid=Number(document.getElementById("waPaciente")?.value||selectedPacienteId||0);
  const p=paciente(pid);
  const cid=Number(document.getElementById("waCita")?.value||0);
  const c=(citas||[]).find(x=>x.id==cid)||{};
  const tipo=document.getElementById("waTipo")?.value||"recordatorio";
  const nombre=p.nombre||"";
  const fecha=c.fecha?new Date(c.fecha+"T12:00:00").toLocaleDateString("es-ES",{weekday:"long",day:"2-digit",month:"long"}):"";
  const hora=c.hora||"";
  const motivo=c.motivo||"tratamiento de fisioterapia";
  const ubicacion="AMR Clínicas de Fisioterapia. Calle Pósito 14, Padul / Calle Ruiseñor 9 Bajo, Granada / Calle Señor de la Expiración 6 Bajo, Lanjarón.";

  const textos={
    recordatorio:`Hola ${nombre}, te recordamos tu cita en AMR Clínicas de Fisioterapia el ${fecha} a las ${hora}. Motivo: ${motivo}. Si necesitas cambiarla, avísanos con antelación. Gracias.`,
    confirmacion:`Hola ${nombre}, tu cita queda confirmada para el ${fecha} a las ${hora} en AMR Clínicas de Fisioterapia. Muchas gracias.`,
    ubicacion:`Hola ${nombre}, te enviamos la ubicación/datos de AMR Clínicas de Fisioterapia: ${ubicacion}. Te esperamos en tu cita a las ${hora}.`,
    seguimiento:`Hola ${nombre}, ¿cómo te encuentras tras la sesión de fisioterapia? Si has notado algún cambio, molestia o mejora, respóndenos para ajustar el seguimiento.`,
    ejercicios:`Hola ${nombre}, te enviamos las indicaciones de ejercicios pautados. Realízalos sin dolor intenso, de forma controlada, y suspende si aparece molestia importante. Cualquier duda nos escribes.`,
    empresa:`Hola ${nombre}, desde AMR Clínicas seguimos trabajando para mejorar tu recuperación funcional y reducir el riesgo de recaídas o baja laboral. Si notas molestias en el puesto de trabajo, avísanos para adaptar el tratamiento.`
  };

  if(document.getElementById("waMensaje"))waMensaje.value=textos[tipo]||textos.recordatorio;
}

function abrirWhatsappPro(){
  const pid=Number(document.getElementById("waPaciente")?.value||selectedPacienteId||0);
  const p=paciente(pid);
  const tel=telefonoLimpio(p.telefono);
  if(!tel)return alert("Este paciente no tiene teléfono válido.");
  const msg=document.getElementById("waMensaje")?.value||"";
  window.open(`https://wa.me/${tel}?text=${encodeURIComponent(msg)}`,"_blank");
}

/* ===== IA Clínica local ===== */
function historiaPaciente(pid){
  return (historias||[]).find(h=>h.paciente_id==pid)||{};
}

function generarIAClinica(){
  const pid=Number(document.getElementById("iaPaciente")?.value||selectedPacienteId||0);
  const p=paciente(pid);
  const h=historiaPaciente(pid);
  const tipo=document.getElementById("iaTipo")?.value||"evolucion";
  const notas=document.getElementById("iaNotas")?.value||"";
  let texto="";

  if(tipo==="evolucion"){
    texto=`Evolución de sesión - ${p.nombre||"Paciente"}\n\nMotivo principal: ${h.motivo||"No especificado"}.\nExploración/estado actual: ${h.exploracion||"Pendiente de completar"}.\nTratamiento realizado: ${notas||"Tratamiento de fisioterapia adaptado a la evolución del paciente."}\nRespuesta del paciente: buena tolerancia, sin incidencias relevantes salvo las indicadas.\nPlan: continuar progresión según tolerancia, reforzar ejercicios domiciliarios y reevaluar en próxima sesión.`;
  }

  if(tipo==="ejercicios"){
    texto=`Ejercicios domiciliarios - ${p.nombre||"Paciente"}\n\nObjetivo: ${h.objetivos||"mejorar función, dolor y movilidad"}.\n\n1. Movilidad suave de la zona afectada: 2 series de 10 repeticiones.\n2. Activación muscular controlada: 2-3 series de 8-12 repeticiones.\n3. Ejercicio funcional progresivo según tolerancia.\n4. Estiramiento suave si no aumenta dolor.\n\nIndicaciones: realizar sin dolor intenso, respiración controlada y parar si aparece mareo, dolor agudo o empeoramiento claro.\n\nNotas: ${notas}`;
  }

  if(tipo==="informe"){
    texto=`Informe clínico breve\n\nPaciente: ${p.nombre||""}\nMotivo de consulta: ${h.motivo||""}\nExploración: ${h.exploracion||""}\nDiagnóstico fisioterapéutico: ${h.diagnostico||""}\nTratamiento realizado / plan: ${notas||h.objetivos||""}\nEjercicios pautados: ${h.ejercicios||""}\n\nSe recomienda continuar seguimiento fisioterapéutico y reevaluación según evolución clínica.`;
  }

  if(tipo==="empresa"){
    texto=`Informe orientado a empresa\n\nTrabajador/paciente: ${p.nombre||""}\nObjetivo: favorecer recuperación funcional, reducir limitaciones y prevenir recaídas que puedan aumentar el riesgo de baja laboral.\n\nSituación funcional: ${h.motivo||"en seguimiento fisioterapéutico"}.\nIntervención realizada: ${notas||"tratamiento de fisioterapia, educación terapéutica y ejercicios de readaptación"}.\nRecomendación: continuar plan de recuperación, adaptar cargas si procede y mantener seguimiento hasta estabilización funcional.\n\nEste informe no sustituye valoración médica laboral.`;
  }

  if(tipo==="justificante"){
    texto=`Justificante de asistencia\n\nSe hace constar que ${p.nombre||"el paciente"} ha asistido a sesión de fisioterapia en AMR Clínicas de Fisioterapia en la fecha indicada.\n\nMotivo/sesión: ${notas||"tratamiento de fisioterapia"}.\n\nAMR Clínicas de Fisioterapia\nAntonio Javier Martí Romero`;
  }

  iaResultado.value=texto;
}

function copiarIA(){
  const t=document.getElementById("iaResultado")?.value||"";
  navigator.clipboard?.writeText(t);
  alert("Texto copiado.");
}

async function guardarIAComoEvolucion(){
  const pid=Number(document.getElementById("iaPaciente")?.value||selectedPacienteId||0);
  const texto=document.getElementById("iaResultado")?.value||"";
  if(!pid||!texto)return alert("Selecciona paciente y genera texto.");
  let old=(historias||[]).find(x=>x.paciente_id==pid);
  let evos=old?.evoluciones||[];
  evos.unshift({fecha:new Date().toISOString(),texto});
  let r;
  if(!old) r=await sb.from("historias_clinicas").insert(withClinica({paciente_id:pid,evoluciones:evos,updated_at:new Date().toISOString()}));
  else r=await sb.from("historias_clinicas").update({evoluciones:evos,updated_at:new Date().toISOString()}).eq("id",old.id);
  if(r.error)return alert(r.error.message);
  alert("Guardado como evolución.");
  await loadCloud();
}

const __oldRenderPro = render;
render = function(){
  __oldRenderPro();
  fillProSelects();
};

document.addEventListener("change", e=>{
  if(e.target && e.target.id==="waPaciente"){
    selectedPacienteId=Number(e.target.value);
    renderWaCitas();
    generarWhatsappPro();
  }
});


/* ===== Usuarios / roles SaaS ===== */
function rolActual(){return usuarioClinica?.rol || "admin";}
function esAdmin(){return rolActual()==="admin";}
function esFisio(){return rolActual()==="fisio";}
function esRecepcion(){return rolActual()==="recepcion";}
function esSupervisor(){return rolActual()==="supervisor";}

async function cargarUsuariosClinica(){
  if(!clinicaActiva?.id){usuariosClinica=[];return;}
  try{
    const r=await sb.from("usuarios_clinica").select("*").eq("clinica_id",clinicaActiva.id).order("id",{ascending:true});
    usuariosClinica=r.data||[];
  }catch(e){usuariosClinica=[];}
}

function aplicarPermisosVisuales(){
  const rol=rolActual();
  document.querySelectorAll("[data-role='admin']").forEach(el=>{el.style.display=esAdmin()?"":"none";});
  document.querySelectorAll("nav button").forEach(btn=>{
    const txt=(btn.textContent||"").toLowerCase();
    btn.style.display="";
    if(rol==="recepcion" && (txt.includes("historia") || txt.includes("ia") || txt.includes("config") || txt.includes("usuarios"))) btn.style.display="none";
    if(rol==="fisio" && (txt.includes("config") || txt.includes("usuarios"))) btn.style.display="none";
  });
}

function renderUsuariosClinica(){
  const box=document.getElementById("usuariosList");
  if(!box)return;
  if(!esAdmin()){box.innerHTML="<p class='muted'>Solo el administrador puede gestionar usuarios.</p>";return;}
  box.innerHTML=(usuariosClinica||[]).map(u=>`
    <div class="item">
      <b>${u.nombre||"Usuario"}</b>
      <p>Rol: <span class="userBadge">${u.rol||"fisio"}</span> · Estado: <span class="userBadge ${u.activo===false?"off":""}">${u.activo===false?"Inactivo":"Activo"}</span></p>
      <p>Auth UUID: ${u.auth_user_id||"Pendiente"}</p>
      <div class="row">
        <button class="btn light" onclick="editarUsuarioClinica(${u.id})">Editar</button>
        <button class="btn ghost" onclick="toggleUsuarioClinica(${u.id})">${u.activo===false?"Activar":"Desactivar"}</button>
      </div>
    </div>`).join("") || "<p>No hay usuarios creados para esta clínica.</p>";
}

function editarUsuarioClinica(id){
  const u=(usuariosClinica||[]).find(x=>x.id==id);
  if(!u)return;
  usrNombre.value=u.nombre||"";
  usrAuthId.value=u.auth_user_id||"";
  usrRol.value=u.rol||"fisio";
  usrActivo.value=String(u.activo!==false);
  usrNombre.dataset.editId=id;
}

async function guardarUsuarioClinica(){
  if(!esAdmin())return alert("Solo el administrador puede crear usuarios.");
  if(!clinicaActiva?.id)return alert("No hay clínica activa.");
  const data={nombre:usrNombre.value,auth_user_id:usrAuthId.value||null,rol:usrRol.value,activo:usrActivo.value==="true",clinica_id:clinicaActiva.id};
  let r;
  const editId=usrNombre.dataset.editId;
  if(editId) r=await sb.from("usuarios_clinica").update(data).eq("id",Number(editId));
  else r=await sb.from("usuarios_clinica").insert(data);
  if(r.error)return alert("Error: "+r.error.message);
  usrNombre.value="";usrAuthId.value="";usrRol.value="fisio";usrActivo.value="true";delete usrNombre.dataset.editId;
  await cargarUsuariosClinica();renderUsuariosClinica();alert("Usuario guardado.");
}

async function toggleUsuarioClinica(id){
  if(!esAdmin())return alert("Solo admin.");
  const u=(usuariosClinica||[]).find(x=>x.id==id);
  if(!u)return;
  const r=await sb.from("usuarios_clinica").update({activo:!(u.activo!==false)}).eq("id",id);
  if(r.error)return alert(r.error.message);
  await cargarUsuariosClinica();renderUsuariosClinica();
}
