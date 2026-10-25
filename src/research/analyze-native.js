// ELF64 LE / ARM64 reader and Capstone WASM; executes no APK code.
const fs = require('node:fs'), path = require('node:path');
const Zip = require('adm-zip'), capstone = require('@alexaltea/capstone-js');
function functions(bytes) {
  const range = (offset, size) => {
    if (!Number.isSafeInteger(offset) || !Number.isSafeInteger(size) || offset < 0 || size < 0 || offset + size > bytes.length) throw new Error('ELF range outside file');
    return bytes.subarray(offset, offset + size);
  };
  if (bytes.length < 64 || bytes.subarray(0, 4).toString('hex') !== '7f454c46' || bytes[4] !== 2 || bytes[5] !== 1 || bytes.readUInt16LE(18) !== 183) throw new Error('Expected ELF64 LE ARM64');
  const u64 = at => { range(at, 8); const n = Number(bytes.readBigUInt64LE(at)); if (!Number.isSafeInteger(n)) throw new Error('ELF integer too large'); return n; };
  const start = u64(40), size = bytes.readUInt16LE(58), count = bytes.readUInt16LE(60);
  if (size < 64 || !count) throw new Error('Unsupported ELF section table');
  const sections = [];
  for (let i = 0; i < count; i++) {
    const at = start + i * size; range(at, 64);
    sections.push({ type: bytes.readUInt32LE(at + 4), address: u64(at + 16), offset: u64(at + 24), size: u64(at + 32), link: bytes.readUInt32LE(at + 40), entrySize: u64(at + 56) });
  }
  const result = [];
  for (const s of sections.filter(s => s.type === 11)) {
    if (s.entrySize < 24 || !sections[s.link]) throw new Error('Invalid ELF symbol table');
    const strings = range(sections[s.link].offset, sections[s.link].size); range(s.offset, s.size);
    for (let at = s.offset; at + 24 <= s.offset + s.size; at += s.entrySize) {
      const index = bytes.readUInt16LE(at + 6), length = u64(at + 16);
      if ((bytes[at + 4] & 15) !== 2 || !length || index === 0) continue;
      const target = sections[index]; if (!target) throw new Error('Invalid ELF symbol section');
      const address = u64(at + 8), nameAt = bytes.readUInt32LE(at), end = strings.indexOf(0, nameAt);
      if (end < nameAt) throw new Error('Invalid ELF symbol name');
      result.push({ name: strings.toString('utf8', nameAt, end), address, code: range(target.offset + address - target.address, length) });
    }
  }
  return result;
}
async function analyze(apkPath, output = path.resolve('output/native')) {
  if (!apkPath) throw Error('Usage: node src/research/analyze-native.js <private-apk-path> [output-directory]');
  const zip = new Zip(path.resolve(apkPath)), cs = await capstone();
  const decoder = new cs.Capstone(cs.ARCH_ARM64, cs.MODE_ARM); fs.mkdirSync(output, { recursive: true });
  try {
    for (const name of ['libbmp_rle.so', 'libhello-libs.so']) {
      const bytes = zip.readFile(`lib/arm64-v8a/${name}`), lines = [];
      if (!bytes) throw new Error(`APK library missing: ${name}`);
      for (const fn of functions(bytes)) {
        lines.push(`\n${fn.name} @ ${fn.address.toString(16)}:`);
        for (const ins of decoder.disasm([...fn.code], fn.address)) lines.push(`${ins.address.toString(16).padStart(6, '0')} ${ins.mnemonic.padEnd(8)} ${ins.op_str}`);
      }
      fs.writeFileSync(path.join(output, name), bytes);
      fs.writeFileSync(path.join(output, name.replace(/\.so$/, '.asm.txt')), lines.join('\n'));
      console.log(`${name}: statically disassembled in JavaScript/WASM`);
    }
  } finally { decoder.close(); }
}
if (require.main === module) analyze(process.argv[2], process.argv[3]).catch(e => { console.error(e); process.exitCode = 1; });
module.exports = { functions, analyze };
