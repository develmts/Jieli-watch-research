// Rebuild interpretations from immutable native Bluetooth captures. No Bluetooth access.
const fs = require('fs');
const crypto = require('crypto');
const { analyzeQuery } = require('./watch-observations');
const directory = process.argv[2] || 'output/sessions';
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const sessions = fs.readdirSync(directory).filter(name => name.endsWith('_winrt_information.json')).sort().map(name => {
  const file = `${directory}/${name}`;
  return { file, sha256: crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'), queries: read(file).queries.map(analyzeQuery) };
});
const queries = sessions.flatMap(s => s.queries);
const result = { scope: 'offline interpretation of real Bluetooth information requests', summary: { executions: queries.length, distinctQueries: new Set(queries.map(q => q.id)).size, dataResponses: queries.filter(q => q.outcome === 'data').length, ackOnly: queries.filter(q => q.outcome === 'ack-only').length }, sessions };
fs.mkdirSync('output', { recursive: true });
fs.writeFileSync('output/information-analysis.json', JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result.summary));
