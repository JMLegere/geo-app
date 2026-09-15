const test = require('node:test');
const assert = require('node:assert/strict');
const { violations, validate } = require('../../scripts/check-design-boundaries.cjs');

test('new raw presentation values fail outside the library', () => {
  const files = {'lib/features/a.dart': 'const surface = Color(0xff000000);'};
  assert.equal(validate(files, []).length, 1);
});
test('the foundation owns raw presentation values', () => {
  assert.deepEqual(violations({'lib/ui/design_system/foundations/palette.dart': 'Color(0xff000000)'}), []);
});
test('exact existing debt does not admit another occurrence', () => {
  const files = {'lib/features/a.dart': 'TextStyle(fontSize: 12)'};
  const baseline = violations(files);
  assert.deepEqual(validate(files, baseline), []);
  assert.equal(validate({'lib/features/a.dart': files['lib/features/a.dart']+'\n'+files['lib/features/a.dart']}, baseline).length, 1);
});
test('stale and duplicated exceptions are rejected', () => {
  const files = {'lib/features/a.dart': 'TextStyle(fontSize: 12)'};
  const baseline = violations(files);
  assert.equal(validate({}, baseline).length, 1);
  assert.equal(validate(files, [...baseline, ...baseline]).length, 1);
});
test('geometry and nonvisual retry timing are not presentation debt', () => {
  assert.deepEqual(violations({'lib/core/retry.dart': 'Duration(milliseconds: 200); final x = 3;'}), []);
});
test('direct styled Shad controls outside the library are owned exceptions', () => {
  assert.equal(violations({'lib/features/a.dart': 'return ShadButton(child: Text("Run"));'}).length, 1);
});
