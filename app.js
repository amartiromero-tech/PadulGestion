
const SUPABASE_URL="https://gjwxsaczasfprwochzyw.supabase.co";
const SUPABASE_KEY="sb_publishable_zH89akxkPVSGUg6BSjtjjg_vl06k6oB";
const sb=supabase.createClient(SUPABASE_URL,SUPABASE_KEY);

let pacientes=[], citas=[], consentimientos=[], firmasSesiones=[], historias=[], facturas=[];
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
 setupFirma();
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
 const [p,c,co,fs,h,f]=await Promise.all([
   sb.from("pacientes").select("*").order("id"),
   sb.from("citas").select("*").order("fecha"),
   sb.from("consentimientos").select("*").order("created_at",{ascending:false}),
   sb.from("firmas_sesiones").select("*").order("created_at",{ascending:false}),
   sb.from("historias_clinicas").select("*").order("updated_at",{ascending:false}),
   sb.from("facturas").select("*").order("id",{ascending:false})
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
 if(id==="legal")setTimeout(setupFirma,100);
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
async function saveCita(){const data={paciente_id:Number(citaPaciente.value),fecha:citaFecha.value,hora:citaHora.value,motivo:citaMotivo.value,precio:Number(citaPrecio.value||0),estado:citaEstado.value}; if(!data.paciente_id)return alert("Selecciona paciente"); const r=citaId.value?await sb.from("citas").update(data).eq("id",Number(citaId.value)):await sb.from("citas").insert(data); if(r.error)return alert(r.error.message); await loadCloud();}
async function deleteCita(id){if(confirm("¿Borrar cita?")){await sb.from("citas").delete().eq("id",id); await loadCloud()}}

function renderPacientes(){const q=(buscarPaciente?.value||"").toLowerCase(); pacientesList.innerHTML=pacientes.filter(p=>p.nombre.toLowerCase().includes(q)).map(p=>`<div class="item"><b>${p.nombre}</b><p>${p.telefono||""} · ${p.nif||""}</p><div class="row"><button class="btn light" onclick="editPaciente(${p.id})">Editar</button><button class="btn ghost" onclick="deletePaciente(${p.id})">Borrar</button></div></div>`).join("")||"<p>Sin pacientes.</p>"}
function editPaciente(id){const p=paciente(id);selectedPacienteId=id;pacienteId.value=p.id;pacNombre.value=p.nombre||"";pacTelefono.value=p.telefono||"";pacNif.value=p.nif||"";pacDireccion.value=p.direccion||"";pacNotas.value=p.notas||""}
async function savePaciente(){const data={nombre:pacNombre.value,telefono:pacTelefono.value,nif:pacNif.value,direccion:pacDireccion.value,notas:pacNotas.value}; if(!data.nombre)return alert("Pon nombre"); const r=pacienteId.value?await sb.from("pacientes").update(data).eq("id",Number(pacienteId.value)):await sb.from("pacientes").insert(data); if(r.error)return alert(r.error.message); pacienteId.value=""; await loadCloud();}
async function deletePaciente(id){if(confirm("¿Borrar paciente?")){await sb.from("pacientes").delete().eq("id",id); await loadCloud()}}

function loadHistoriaToForm(){const pid=Number(histPaciente.value||selectedPacienteId||0); const h=historias.find(x=>x.paciente_id==pid)||{}; histMotivo.value=h.motivo||"";histExploracion.value=h.exploracion||"";histDiagnostico.value=h.diagnostico||"";histObjetivos.value=h.objetivos||"";histEjercicios.value=h.ejercicios||"";renderEvoluciones(h.evoluciones||[])}
function renderEvoluciones(evos){evolucionesList.innerHTML=(evos||[]).map(e=>`<div class="item"><b>${new Date(e.fecha).toLocaleString("es-ES")}</b><p>${e.texto}</p></div>`).join("")||"<p>Sin evoluciones.</p>"}
async function saveHistoria(){const pid=Number(histPaciente.value||0); if(!pid)return alert("Selecciona paciente"); const old=historias.find(x=>x.paciente_id==pid); const data={paciente_id:pid,motivo:histMotivo.value,exploracion:histExploracion.value,diagnostico:histDiagnostico.value,objetivos:histObjetivos.value,ejercicios:histEjercicios.value,evoluciones:old?.evoluciones||[],updated_at:new Date().toISOString()}; const r=old?await sb.from("historias_clinicas").update(data).eq("id",old.id):await sb.from("historias_clinicas").insert(data); if(r.error)return alert("Error: "+r.error.message); await loadCloud(); alert("Historia guardada")}
async function addEvolucion(){const pid=Number(histPaciente.value||0); const txt=nuevaEvolucion.value.trim(); if(!pid||!txt)return alert("Selecciona paciente y escribe evolución"); let old=historias.find(x=>x.paciente_id==pid); let evos=old?.evoluciones||[]; evos.unshift({fecha:new Date().toISOString(),texto:txt}); if(!old){await sb.from("historias_clinicas").insert({paciente_id:pid,evoluciones:evos,updated_at:new Date().toISOString()})}else{await sb.from("historias_clinicas").update({evoluciones:evos,updated_at:new Date().toISOString()}).eq("id",old.id)} nuevaEvolucion.value=""; await loadCloud();}

function renderLegalDoc(){const d=legalDocs[legalTipo.value]||legalDocs.rgpd; legalTitulo.textContent=d[0]; legalTexto.textContent=d[1];}
function setupFirma(){const c=document.getElementById("firmaCanvas"); if(!c||c.dataset.ready)return; c.dataset.ready=1; const ctx=c.getContext("2d"); const resize=()=>{const r=c.getBoundingClientRect();c.width=r.width;c.height=230;ctx.lineWidth=3;ctx.lineCap="round";ctx.strokeStyle="#111827"}; resize(); let drawing=false; const pos=e=>{const r=c.getBoundingClientRect();const p=e.touches?e.touches[0]:e;return{x:p.clientX-r.left,y:p.clientY-r.top}}; const start=e=>{drawing=true;const p=pos(e);ctx.beginPath();ctx.moveTo(p.x,p.y);e.preventDefault()}; const move=e=>{if(!drawing)return;const p=pos(e);ctx.lineTo(p.x,p.y);ctx.stroke();e.preventDefault()}; const end=()=>drawing=false; c.addEventListener("mousedown",start);c.addEventListener("mousemove",move);window.addEventListener("mouseup",end);c.addEventListener("touchstart",start,{passive:false});c.addEventListener("touchmove",move,{passive:false});c.addEventListener("touchend",end)}
function clearFirma(){const c=firmaCanvas;c.getContext("2d").clearRect(0,0,c.width,c.height)}
function firmaData(){return firmaCanvas.toDataURL("image/png")}
async function saveLegal(){const pid=Number(legalPaciente.value); if(!pid)return alert("Selecciona paciente"); if(!legalAcepta.checked)return alert("Marca aceptación"); const tipo=legalTipo.value; const firma=firmaData(); const notas=legalNotas.value; const r= tipo==="sesion" ? await sb.from("firmas_sesiones").insert({paciente_id:pid,fecha:localISO(new Date()),hora:"",motivo:"Firma de sesión",importe:0,notas,firma,confirmado:true,created_at:new Date().toISOString()}) : await sb.from("consentimientos").insert({paciente_id:pid,tipo,profesional:"Antonio Javier Martí Romero",centro:"AMR Clínicas de Fisioterapia",notas,firma,aceptado:true,fecha:new Date().toISOString()}); if(r.error)return alert(r.error.message); alert("Documento guardado"); clearFirma(); legalAcepta.checked=false; await loadCloud();}
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
    sb.from("facturas").insert({
      numero,
      paciente_id:p.id || null,
      fecha:localISO(new Date()),
      concepto,
      cantidad,
      precio,
      total
    });
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

