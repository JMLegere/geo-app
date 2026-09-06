const {test} = require('node:test');
const assert = require('node:assert/strict');
const {validateExecution} = require('../../scripts/validate-ui596-execution.cjs');
const record = () => ({id:'Q001', owners:['RET'], slice:'S05', implementation_status:'partial',
  consumers:['lib/toolbar.dart'], evidence:[{kind:'widget_test', path:'test/toolbar_test.dart'}]});
const existing = new Set(['lib/toolbar.dart','test/toolbar_test.dart']);
test('partial evidence is accepted without asserting final acceptance', () => {
  assert.deepEqual(validateExecution([record()], existing), []);
});
test('every decision requires an owner and an execution slice', () => {
  assert.match(validateExecution([{...record(),owners:[],slice:''}], existing).join('\n'), /owner/);
});
test('dead consumers and evidence cannot masquerade as coverage', () => {
  assert.match(validateExecution([record()], new Set()).join('\n'), /missing/);
});
test('verified decisions require both a consumer and executable or reviewed evidence', () => {
  assert.match(validateExecution([{...record(),implementation_status:'verified',evidence:[]}],existing).join('\n'), /evidence/);
});

test('an unapproved render cannot verify a decision', () => {
  const r={...record(),implementation_status:'verified',evidence:[{kind:'review_candidate',path:'test/toolbar_test.dart'}]};
  assert.match(validateExecution([r],existing).join('\n'), /evidence/);
});
