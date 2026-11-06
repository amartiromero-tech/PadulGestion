const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../app.js'),'utf8');
function setup(){
 const rows=[{id:1,paciente_id:7,fecha:'2026-11-06',hora:'10:00',motivo:'Original',precio:0}];
 const calls=[],alerts=[];let failure=null,delay=null;
 const client={from(table){assert.equal(table,'citas');let op,data,id;const q={insert(d){op='insert';data=d;return q},update(d){op='update';data=d;return q},eq(k,v){assert.equal(k,'id');id=v;return q},select(v){assert.equal(v,'id');return q},async single(){calls.push({op,data,id});if(delay)await delay;if(failure==='throw')throw Error('Red');if(failure)return {error:{message:failure}};if(op==='update'){const row=rows.find(r=>r.id===id);if(!row)return {error:{message:'0 rows'}};Object.assign(row,data);return {data:{id}}}const row={...data,id:rows.length+1};rows.push(row);return {data:{id:row.id}}}};return q}};
 const ctx={supabase:{createClient:()=>client},document:{addEventListener(){}},localStorage:{getItem:()=>null},alert:m=>alerts.push(m),console,Date,setTimeout};
 for(const k of ['citaId','citaPaciente','citaFecha','citaHora','citaMotivo','citaPrecio','citaEstado'])ctx[k]={value:''};
 vm.createContext(ctx);vm.runInContext(source,ctx);
 vm.runInContext('showSection=()=>{}; registrarLog=async()=>{}; loadCloud=async()=>{}; clinicaActiva={id:3}; selectedPacienteId=7;',ctx);
 ctx.seed=rows;vm.runInContext('citas=seed;',ctx);
 ctx.newCita();
 return {ctx,rows,calls,alerts,fail:v=>failure=v,wait:p=>delay=p};
}
test('two new appointments insert and survive a simulated reload',async()=>{const s=setup();await s.ctx.saveCita();s.ctx.citaHora.value='11:00';await s.ctx.saveCita();assert.deepEqual(s.calls.map(c=>c.op),['insert','insert']);assert.equal(s.rows.length,3);assert.equal(s.rows[0].motivo,'Original');assert.equal(s.calls[0].data.clinica_id,3);const reloaded=JSON.parse(JSON.stringify(s.rows));assert.equal(new Set(reloaded.map(r=>r.id)).size,3)});
test('edit updates only its id, including zero price; next save inserts',async()=>{const s=setup();s.ctx.editCita(1);assert.equal(s.ctx.citaPrecio.value,0);s.ctx.citaMotivo.value='Edited';await s.ctx.saveCita();assert.equal(s.calls[0].op,'update');assert.equal(s.calls[0].id,1);assert.equal(s.rows.length,1);assert.equal(s.rows[0].motivo,'Edited');assert.equal(s.ctx.citaId.value,'');await s.ctx.saveCita();assert.equal(s.calls[1].op,'insert')});
test('new appointment clears stale edit id and fields',async()=>{const s=setup();s.ctx.editCita(1);s.ctx.newCita('2026-11-08','12:00');assert.equal(s.ctx.citaId.value,'');assert.equal(s.ctx.citaMotivo.value,'');assert.equal(s.ctx.citaFecha.value,'2026-11-08');await s.ctx.saveCita();assert.equal(s.calls[0].op,'insert');assert.equal(s.rows[0].motivo,'Original')});
test('Supabase errors and rejected requests retain edit for retry',async()=>{for(const failure of ['RLS denied','throw']){const s=setup();s.ctx.editCita(1);s.fail(failure);await s.ctx.saveCita();assert.equal(s.ctx.citaId.value,1);assert.equal(s.rows[0].motivo,'Original');assert.match(s.alerts[0],/Error guardando cita/);s.fail(null);await s.ctx.saveCita();assert.equal(s.calls.length,2)}});
test('zero affected rows are reported',async()=>{const s=setup();s.ctx.editCita(1);s.rows.length=0;await s.ctx.saveCita();assert.match(s.alerts[0],/0 rows/);assert.equal(s.rows.length,0)});
test('double click produces only one write',async()=>{const s=setup();let release;s.wait(new Promise(r=>release=r));const first=s.ctx.saveCita();await s.ctx.saveCita();s.ctx.editCita(1);assert.equal(s.ctx.citaId.value,'');release();await first;assert.equal(s.calls.length,1)});
test('reload failure after save cannot leave form targeting old id',async()=>{const s=setup();s.ctx.editCita(1);vm.runInContext('loadCloud=async()=>{throw Error("offline")}',s.ctx);await s.ctx.saveCita();assert.equal(s.ctx.citaId.value,'');assert.match(s.alerts[0],/Cita guardada.*recargar/)});
test('all explicit new appointment buttons invoke reset',()=>{const html=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');const buttons=[...html.matchAll(/<button[^>]*onclick="([^"]*)"[^>]*>\+ Nueva cita<\/button>/g)];assert.equal(buttons.length,2);for(const b of buttons)assert.equal(b[1],'newCita()');assert.match(source,/onclick="newCita\('/);assert.match(source,/if\(c.error\)throw new Error\("Error cargando citas:/)});
test('stale hidden id cannot turn a new booking into an update',async()=>{const s=setup();s.ctx.citaId.value=52;await s.ctx.saveCita();assert.equal(s.calls[0].op,'insert');assert.equal(s.rows.length,2)});
test('Agenda menu leaves edit mode before a new booking',async()=>{const s=setup();s.ctx.editCita(1);const html=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');const handler=html.match(/onclick="([^"]*)">Agenda<\/button>/)[1];vm.runInContext(handler,s.ctx);s.ctx.citaMotivo.value='New';await s.ctx.saveCita();assert.equal(s.calls[0].op,'insert');assert.equal(s.rows[0].motivo,'Original')});
