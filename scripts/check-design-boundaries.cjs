const fs = require('node:fs');
const path = require('node:path');

// Exact source fingerprints are migration debt, never a wildcard exemption.
function violations(files) {
  const result = [];
  for (const [file, source] of Object.entries(files)) {
    if (file.startsWith('lib/shared/design/')) continue;
    const presentation = /extends\s+(StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget|CustomPainter)/.test(source)
      || file.includes('/presentation/');
    for (const original of source.split(/\r?\n/)) {
      const line = original.trim();
      if (line.startsWith('//') || line.startsWith('*')) continue;
      if (/\b(?:Color\(0x|Colors\.|TextStyle\(|EdgeInsets\.|Shad(?:Button|Card|Input|Select|Dialog|Sheet)\b)/.test(line)
        || (presentation && /Duration\(milliseconds:/.test(line))) {
        result.push({path: file, source: line});
      }
    }
  }
  return result;
}
function validate(files, baseline) {
  const remaining = baseline.map(e => JSON.stringify({path:e.path, source:e.source}));
  const errors = [];
  for (const occurrence of violations(files)) {
    const key = JSON.stringify(occurrence);
    const i = remaining.indexOf(key);
    if (i < 0) errors.push('New presentation debt: '+key);
    else remaining.splice(i, 1);
  }
  for (const key of remaining) errors.push('Stale or duplicated exception: '+key);
  return errors;
}
function sources(root = 'lib') {
  const files = {};
  for (const e of fs.readdirSync(root, {withFileTypes:true})) {
    const name = path.posix.join(root, e.name);
    if (e.isDirectory()) Object.assign(files, sources(name));
    else if (e.name.endsWith('.dart')) files[name] = fs.readFileSync(name, 'utf8');
  }
  return files;
}
module.exports = {violations, validate, sources};
if (require.main === module) {
  const baseline = JSON.parse(fs.readFileSync('docs/specifications/ui596/presentation-debt.json', 'utf8'));
  const errors = validate(sources(), baseline);
  if (errors.length) { errors.forEach(e=>console.error(e)); process.exitCode=1; }
  else console.log(`Design boundary passed; ${baseline.length} exact existing occurrences remain to migrate.`);
}
