// Offline audit of externally supplied captures; no Bluetooth or network access.
const fs=require('node:fs'),path=require('node:path');
const {validateGuardedCapture}=require('./guarded-capture-policy');
const {analyzeQuery}=require('./watch-observations');
if(!process.argv[2]) throw Error('Usage: node src/research/analyze-guarded-sessions.js <private-session-directory> [output.json]');
const aliases={identity:'device-info',features:'capabilities',settings:'settings-info',faces:'watch-faces',today:'today-summary',alarms:'alarms-info','custom-face':'custom-face-info','ota-identity':'ota-info'};
const sessions=fs.readdirSync(process.argv[2]).filter(n=>n.endsWith('.json')).map(name=>{
 const report=JSON.parse(fs.readFileSync(path.join(process.argv[2],name),'utf8').replace(/^\uFEFF/,''));
 return {file:name,audit:validateGuardedCapture(report),queries:(report.queries||[]).map(q=>analyzeQuery({...q,id:aliases[q.id]||q.id}))};
});
const output=process.argv[3]||'output/guarded-analysis.json';fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify({sessions},null,2)+'\n');console.log('Audited sessions: '+sessions.length);
