const fs = require('node:fs');
function validateExecution(records, existing) {
  const errors = [];
  for (const r of records) {
    if (!r.owners?.length || !r.owners.every(x => typeof x === 'string' && x.trim())) errors.push(`${r.id}: missing owner`);
    if (!/^S0[1-9]$/.test(r.slice ?? '')) errors.push(`${r.id}: missing execution slice`);
    if (!['unassessed','partial','verified','conditional_omission'].includes(r.implementation_status)) errors.push(`${r.id}: invalid implementation status`);
    for (const path of [...(r.consumers ?? []), ...(r.evidence ?? []).map(e => e.path)]) {
      if (!existing.has(path)) errors.push(`${r.id}: missing consumer/evidence ${path}`);
    }
    if (r.implementation_status === 'verified' && (!r.consumers?.length || !r.evidence?.some(e => ['widget_test','unit_test','integration_test','review_accepted','device_measurement'].includes(e.kind)))) errors.push(`${r.id}: verified requires consumer and evidence`);
    if (r.implementation_status === 'conditional_omission' && (!r.disposition || !r.evidence?.length)) errors.push(`${r.id}: omission requires rationale and evidence`);
  }
  return errors;
}
module.exports = {validateExecution};
if (require.main === module) {
  const m=JSON.parse(fs.readFileSync('docs/specifications/ui596/decisions.json'));
  const records=[...m.questions,...m.baseline,...m.direction];
  const paths=records.flatMap(r=>[...(r.consumers??[]),...(r.evidence??[]).map(e=>e.path)]);
  const errors=validateExecution(records,new Set(paths.filter(p=>fs.existsSync(p))));
  if(errors.length){errors.forEach(e=>console.error(e));process.exitCode=1;}
  else console.log(`Execution ownership and evidence paths validated for ${records.length} decisions; verification status remains explicit.`);
}
