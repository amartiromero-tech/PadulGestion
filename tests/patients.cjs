const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = readFileSync(process.argv[2] || path.join(__dirname, '../app.js'), 'utf8');
const writes = [], alerts = [];
let fail = false;
const context = {
  document:{addEventListener(){}},
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
  clinicaActiva={id:3};
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

