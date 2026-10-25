// Independent audit of what the native runner actually recorded as transmitted.
const { frame } = require('./watch-observations');
const getters = new Set(['10/16','243/0','25/0','9/0','15/1','5/10','14/3','8/0','15/4','19/1']);
function validateGuardedCapture(report) {
  let requests=0,acks=0;
  for(const query of report.queries || []) {
    const dataFrames=(query.frames||[]).map(f=>frame(f.hex)).filter(f=>f.type==='data');
    for(const event of query.trace || []) {
      if(event.normalTx) {
        const bytes=Buffer.from(event.normalTx,'hex'),decoded=frame(event.normalTx);
        if(decoded.type!=='data'||bytes.length!==9||bytes[5]!==1||!getters.has(`${decoded.command}/${decoded.key}`)) throw Error('Non-allowlisted request');
        const timestamp=Date.parse(event.at);
        const battery=(report.battery||[]).filter(b=>Date.parse(b.observedAt)<=timestamp).at(-1);
        if(!battery||!Number.isInteger(battery.percent)||battery.percent<=15||battery.percent>100||timestamp-Date.parse(battery.observedAt)>30000) throw Error('Missing, low or stale battery authorization');
        requests++;
      }
      if(event.normalAckTx) {
        const decoded=frame(event.normalAckTx);
        if(decoded.type!=='ack'||decoded.status!==1||decoded.auxHex!=='0000'||!dataFrames.some(f=>f.command===decoded.command&&f.key===decoded.key)) throw Error('ACK without matching captured data');
        acks++;
      }
    }
  }
  return {requests,acks};
}
module.exports={validateGuardedCapture};
