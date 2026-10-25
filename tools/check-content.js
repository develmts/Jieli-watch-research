// Structural publication checks; deliberately not a complete natural-language classifier.
const fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const ignored = new Set(['node_modules', 'private', 'output', '.git', '.venv', '__pycache__']);
function files(directory) { return fs.readdirSync(directory, { withFileTypes: true }).flatMap(item => ignored.has(item.name) ? [] : item.isDirectory() ? files(path.join(directory, item.name)) : [path.join(directory, item.name)]); }
const all = files(root), failures = [];
const forbiddenExtensions = new Set(['.apk','.dex','.java','.class','.so','.dll','.bin','.sqlite','.zip','.png','.jpg','.jpeg']);
const register = JSON.parse(fs.readFileSync(path.join(root,'docs/sources.json'),'utf8'));
const identifiers = new Set();
for (const source of register.sources) {
  for (const key of ['id','title','credit','url','role','reuse','licenseStatus','verificationStatus','usedBy']) assert(source[key], `Missing source field ${key}`);
  assert(!identifiers.has(source.id), `Duplicate source ${source.id}`); identifiers.add(source.id);
  assert(/^https:\/\//.test(source.url), `Invalid source URL ${source.id}`);
  for (const local of source.usedBy) assert(fs.existsSync(path.join(root,local)), `Missing attributed file ${local}`);
}
const bannedTokens = [[105, 110, 102, 111, 114, 109, 97, 99, 105, 243], [105, 110, 118, 101, 115, 116, 105, 103, 97, 99, 105, 243], [99, 97, 112, 97, 99, 105, 116, 97, 116, 115], [99, 111, 110, 115, 117, 108, 116, 97], [99, 111, 110, 115, 117, 108, 116, 101, 115], [114, 101, 108, 108, 111, 116, 103, 101], [100, 101, 115, 99, 114, 105, 112, 99, 105, 243], [99, 111, 109, 112, 114, 111, 118, 97, 99, 105, 243], [112, 101, 110, 100, 101, 110, 116], [115, 101, 103, 252, 101, 110, 116, 115], [100, 101, 115, 99, 111, 110, 101, 103, 117, 116], [118, 101, 114, 115, 105, 243], [114, 101, 115, 117, 108, 116, 97, 116], [100, 97, 100, 101, 115], [101, 110, 99, 97, 114, 97], [100, 111, 99, 117, 109, 101, 110, 116, 97, 99, 105, 243]].map(codepoints => String.fromCodePoint(...codepoints));
const languagePattern = new RegExp('(?:^|[^a-zA-Z])(?:' + bannedTokens.join('|') + ')(?=$|[^a-zA-Z])','iu');
for (const file of all) {
  const relative = path.relative(root,file).split(path.sep).join('/');
  if (forbiddenExtensions.has(path.extname(file).toLowerCase()) || /^(src\/(app|catalog)|data|analysis)\//.test(relative)) failures.push(`${relative}: excluded artifact`);
  if (!/\.(?:js|json|ps1|cs|py|sh|md|txt)$/.test(file)) continue;
  const content = fs.readFileSync(file,'utf8').replace(/^\uFEFF/,'');
  if (relative !== 'package-lock.json' && languagePattern.test(content)) failures.push(`${relative}: possible non-English project prose`);
  if (/\b(?:[a-f0-9]{2}:){5}[a-f0-9]{2}\b|[CD]:[\\/]Users[\\/]/i.test(content)) failures.push(`${relative}: private identifier/path`);
  if (file.endsWith('.md')) {
    if ((content.match(/^```/gm)||[]).length % 2) failures.push(`${relative}: unmatched code fence`);
    for (const match of content.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
      const target = match[1]; if (/^(https?:|mailto:|#)/.test(target)) continue;
      if (!fs.existsSync(path.resolve(path.dirname(file),target.split('#')[0]))) failures.push(`${relative}: missing local link ${target}`);
    }
  }
}
assert.equal(failures.length,0,failures.join('\n'));
console.log(`PASS: ${all.length} authored files; English-content heuristic, ${identifiers.size} attributed sources, local links and publication exclusions.`);
