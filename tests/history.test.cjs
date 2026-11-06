const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs"),path=require("node:path"),vm=require("node:vm");
const source=fs.readFileSync(path.join(__dirname,"../app.js"),"utf8");
const clone=x=>x==null?x:JSON.parse(JSON.stringify(x));
function setup(){
 const previous={fecha:"2026-11-01T10:00:00Z",texto:"Anterior"};
 const initial={id:77,paciente_id:7,clinica_id:3,updated_at:"2026-11-01T10:00:00Z",evoluciones:[previous],motivo:"Anterior motivo"};
 const state={row:clone(initial),readError:null,writeError:null,throwWrite:false,waitRead:null,waitWrite:null,conflict:false,renderError:false};
 const calls=[],alerts=[],rendered=[],elements={};
 for(const id of ["histPaciente","histMotivo","histExploracion","histDiagnostico","histObjetivos","histEjercicios","nuevaEvolucion","iaPaciente","iaResultado"])elements[id]={value:""};
 elements.histPaciente.value="7";elements.iaPaciente.value="7";
 elements.nuevaEvolucion.value="Nueva evolución";
 const client={from(table){
   assert.equal(table,"historias_clinicas");
   const call={table,filters:[]};calls.push(call);
   const q={select(s){call.select=s;return q},eq(k,v){call.filters.push([k,v]);return q},is(k,v){call.filters.push([k,v]);return q},update(d){call.op="update";call.data=clone(d);return q},insert(d){call.op="insert";call.data=clone(d);return q},
   async maybeSingle(){if(state.waitRead)await state.waitRead;return {data:clone(state.row),error:state.readError}},
   async single(){
     if(state.waitWrite)await state.waitWrite;
     if(state.throwWrite)throw Error("Sin conexión");
     if(state.writeError)return {error:state.writeError};
     if(state.conflict)return {error:{code:"PGRST116",message:"zero rows"}};
     const row=call.op==="insert"?{id:88,evoluciones:[],...call.data}:{...state.row,...call.data};
     state.row=clone(row);return {data:clone(row),error:null};
   }};return q;
 }};
 const ctx={document:{addEventListener(){},getElementById:id=>elements[id]||null},supabase:{createClient:()=>client},localStorage:{getItem:()=>null},alert:m=>alerts.push(m),Date,console,...elements};
 vm.createContext(ctx);vm.runInContext(source,ctx);
 ctx.initial=clone(initial);
 vm.runInContext('historias=[initial];clinicaActiva={id:3};usuarioClinica={rol:"admin",activo:true,clinica_id:3};selectedPacienteId=7;',ctx);
 ctx.renderEvoluciones=evos=>{if(state.renderError)throw Error("render");rendered.push(clone(evos))};
 return {ctx,state,calls,alerts,rendered,elements,run:s=>vm.runInContext(s,ctx)};
}
test("existing evolution saved, confirmed and draft cleared",async()=>{const s=setup();await s.ctx.addEvolucion();assert.equal(s.calls.at(-1).op,"update");assert.equal(s.state.row.evoluciones.length,2);assert.equal(s.state.row.evoluciones[1].texto,"Anterior");assert.equal(s.ctx.nuevaEvolucion.value,"");assert.equal(s.run("historias[0].evoluciones.length"),2);assert.ok(s.calls.at(-1).filters.some(([k,v])=>k==="updated_at"&&v==="2026-11-01T10:00:00Z"));assert.ok(s.alerts.includes("Evolución guardada"))});
test("missing history inserts with authorized clinic and patient",async()=>{const s=setup();s.state.row=null;s.run("historias=[]");await s.ctx.addEvolucion();const c=s.calls.at(-1);assert.equal(c.op,"insert");assert.equal(c.data.clinica_id,3);assert.equal(c.data.paciente_id,7);assert.equal(s.state.row.evoluciones[0].texto,"Nueva evolución")});
test("Supabase error preserves draft and original cache",async()=>{const s=setup();s.state.writeError={message:"RLS denied"};await s.ctx.addEvolucion();assert.equal(s.ctx.nuevaEvolucion.value,"Nueva evolución");assert.equal(s.run("historias[0].evoluciones.length"),1);assert.equal(s.state.row.evoluciones.length,1);assert.match(s.alerts[0],/RLS denied.*texto se conserva/);assert.equal(s.rendered.length,0)});
test("network rejection preserves draft and permits retry",async()=>{const s=setup();s.state.throwWrite=true;await s.ctx.addEvolucion();assert.equal(s.ctx.nuevaEvolucion.value,"Nueva evolución");s.state.throwWrite=false;await s.ctx.addEvolucion();assert.equal(s.state.row.evoluciones.length,2);assert.equal(s.ctx.nuevaEvolucion.value,"")});
test("read error including duplicate histories prevents any write",async()=>{const s=setup();s.state.readError={code:"PGRST116",message:"multiple rows"};await s.ctx.addEvolucion();assert.equal(s.calls.filter(c=>c.op).length,0);assert.equal(s.ctx.nuevaEvolucion.value,"Nueva evolución")});
test("zero affected rows / conflict preserves draft without cached append",async()=>{const s=setup();s.state.conflict=true;await s.ctx.addEvolucion();assert.match(s.alerts[0],/otra sesión/);assert.equal(s.ctx.nuevaEvolucion.value,"Nueva evolución");assert.equal(s.run("historias[0].evoluciones.length"),1)});
test("fresh server evolutions retained even if cache is older",async()=>{const s=setup();s.state.row.evoluciones.unshift({fecha:"now",texto:"Otra sesión"});await s.ctx.addEvolucion();assert.deepEqual(s.state.row.evoluciones.map(e=>e.texto),["Nueva evolución","Otra sesión","Anterior"])});
test("clinical form save never sends cached evolutions",async()=>{const s=setup();s.ctx.histMotivo.value="Nuevo motivo";s.state.row.evoluciones.unshift({fecha:"now",texto:"Otra sesión"});await s.ctx.saveHistoria();assert.equal("evoluciones" in s.calls.at(-1).data,false);assert.equal(s.state.row.evoluciones.length,2);assert.equal(s.state.row.motivo,"Nuevo motivo");assert.ok(s.alerts.includes("Historia guardada"))});
test("double click and simultaneous AI save produce one write; pending cache untouched",async()=>{const s=setup();let release;s.state.waitWrite=new Promise(r=>release=r);const pending=s.ctx.addEvolucion();await new Promise(r=>setImmediate(r));s.ctx.iaResultado.value="IA";await s.ctx.addEvolucion();await s.ctx.guardarIAComoEvolucion();assert.equal(s.calls.filter(c=>c.op).length,1);assert.equal(s.run("historias[0].evoluciones.length"),1);release();await pending;assert.equal(s.state.row.evoluciones.length,2)});
test("new typing or a different selected patient is never erased after save",async()=>{for(const changePatient of [false,true]){const s=setup();let release;s.state.waitWrite=new Promise(r=>release=r);const p=s.ctx.addEvolucion();await new Promise(r=>setImmediate(r));if(changePatient)s.ctx.histPaciente.value="8";else s.ctx.nuevaEvolucion.value="Siguiente borrador";release();await p;assert.equal(s.ctx.nuevaEvolucion.value,changePatient?"Nueva evolución":"Siguiente borrador")}});
test("AI evolution uses same checks and retains output after error",async()=>{const s=setup();s.ctx.iaResultado.value="Texto revisado";s.state.writeError={message:"denied"};await s.ctx.guardarIAComoEvolucion();assert.equal(s.ctx.iaResultado.value,"Texto revisado");assert.equal(s.run("historias[0].evoluciones.length"),1);s.state.writeError=null;await s.ctx.guardarIAComoEvolucion();assert.equal(s.state.row.evoluciones[0].texto,"Texto revisado")});
test("reception and supervisor cannot read or write histories",async()=>{for(const rol of ["recepcion","supervisor"]){const s=setup();s.role=rol;s.ctx.role=rol;s.run("usuarioClinica.rol=role");await s.ctx.addEvolucion();assert.equal(s.calls.length,0);assert.match(s.alerts[0],/perfil/)}});
test("logout during read prevents write; during write never restores cache",async()=>{for(const phase of ["Read","Write"]){const s=setup();let release;s.state["wait"+phase]=new Promise(r=>release=r);const p=s.ctx.addEvolucion();await new Promise(r=>setImmediate(r));s.run("accessEpoch++;historias=[];usuarioClinica=null;clinicaActiva=null");release();await p;assert.equal(s.run("historias.length"),0);assert.equal(s.alerts.length,0);if(phase==="Read")assert.equal(s.calls.filter(c=>c.op).length,0)}});
test("legacy null timestamp guarded with IS NULL",async()=>{const s=setup();s.state.row.updated_at=null;await s.ctx.addEvolucion();assert.ok(s.calls.at(-1).filters.some(([k,v])=>k==="updated_at"&&v===null))});
test("render failure after confirmed persistence is reported as saved",async()=>{const s=setup();s.state.renderError=true;await s.ctx.addEvolucion();assert.match(s.alerts[0],/^Historia guardada, pero/);assert.equal(s.state.row.evoluciones.length,2);assert.equal(s.ctx.nuevaEvolucion.value,"")});
