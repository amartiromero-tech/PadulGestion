const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = readFileSync(process.argv[2] || path.join(__dirname, '../app.js'), 'utf8');
const writes = [], alerts = [];
let fail = false;
let confirmRename=true;
const confirmations=[];
const title={textContent:""};
const context = {
  document:{addEventListener(){},getElementById:()=>title},
  confirm:message=>{confirmations.push(message);return confirmRename;},
  localStorage:{getItem:()=>null},
  alert:message=>alerts.push(message),
  supabase:{createClient:()=>({from:table=>({
    insert:data=>{writes.push({op:'insert',table,data});return Promise.resolve({error:fail?{message:'simulated'}:null});},
    update:data=>({eq:(key,id)=>{writes.push({op:'update',table,data,key,id});return Promise.resolve({error:fail?{message:'simulated'}:null});}})
  })})}
};
for(const id of ['pacienteId','pacNombre','pacTelefono','pacNif','pacDireccion','pacNotas']) context[id]={value:''};
vm.createContext(context);
vm.runInContext(source,context);
vm.runInContext(`
  pacientes=[{id:7,nombre:'Original',telefono:'600000000'}];
  clinicaActiva={id:3}; usuarioClinica={activo:true,rol:'admin',clinica_id:3};
  selectedPacienteId=7;
  loadCloud=async function(){selectedPacienteId=7;};
`,context);
(async()=>{
  // Loading the application selects an existing patient, while the form is new.
  context.pacNombre.value='Nuevo uno';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'insert');
  assert.equal(writes.at(-1).data.clinica_id,3);
  assert.equal(context.pacienteId.value,'');
  context.pacNombre.value='Nuevo dos';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'insert');
  console.log('PASS: consecutive new patients insert despite selected existing patient');

  context.editPaciente(7);
  assert.match(title.textContent,/Original/);
  context.pacNombre.value='Otra persona';
  confirmRename=false;
  const writesBeforeRename=writes.length;
  await context.savePaciente();
  assert.equal(writes.length,writesBeforeRename);
  assert.match(confirmations.at(-1),/Original.*Otra persona/);
  confirmRename=true;
  assert.equal(context.pacienteId.value,7);
  context.pacNombre.value='Original';
  assert.equal(context.pacNombre.value,'Original');
  context.pacNombre.value='Edited';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'update');
  assert.equal(writes.at(-1).id,7);
  context.pacNombre.value='Nuevo tras editar';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'insert');
  console.log('PASS: explicit edit updates its ID; next save inserts');

  context.editPaciente(7);
  // A selection in another section must not change the edit target.
  vm.runInContext('selectedPacienteId=99',context);
  await context.savePaciente();
  assert.equal(writes.at(-1).id,7);
  context.editPaciente(7);
  context.newPaciente();
  for(const id of ['pacienteId','pacNombre','pacTelefono','pacNif','pacDireccion','pacNotas']) assert.equal(context[id].value,'');
  context.pacNombre.value='Nueva ficha';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'insert');
  console.log('PASS: edit target independent of selection; New clears form and inserts');
  const html=readFileSync(path.join(__dirname,'../index.html'),'utf8');
  const handler=html.match(/onclick="([^"]*)">Pacientes<\/button>/)[1];
  context.showSection=()=>{};
  context.editPaciente(7);
  vm.runInContext(handler,context);
  assert.equal(context.pacienteId.value,'');
  assert.equal(title.textContent,'Nuevo paciente');
  context.pacNombre.value='Alta desde navegación';
  await context.savePaciente();
  assert.equal(writes.at(-1).op,'insert');
  console.log('PASS: navigation clears stale edit and saves a new patient');

  fail=true;
  context.editPaciente(7);
  context.pacNombre.value='Retry';
  await context.savePaciente();
  assert.equal(context.pacienteId.value,7);
  assert.equal(context.pacNombre.value,'Retry');
  assert.match(alerts.at(-1),/simulated/);
  const before=writes.length;
  context.pacNombre.value='';
  await context.savePaciente();
  assert.equal(writes.length,before);
  console.log('PASS: failed save preserves form; empty name never writes');
})().catch(error=>{console.error(error);process.exitCode=1;});

