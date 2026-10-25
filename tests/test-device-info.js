const assert = require('node:assert/strict');
const { parseDeviceInfo } = require('../src/watch/device-info');
const profile = require('../src/watch/device-profile');
const { run } = require('../src/watch/research-queries');
const strings = (version, name) => { const v = Buffer.from(version), n = Buffer.from(name); return Buffer.concat([Buffer.from([v.length]),v,Buffer.from([n.length]),n]); };
const build = 'E06B_T27_LC[Smartwatch]_RStyle2_240x240_HryFine-V1.5';
const payload = strings('V1.5', build);
assert.deepEqual(parseDeviceInfo(payload), { firmwareVersion:'V1.5',projectName:build,trailingHex:'' });
assert.deepEqual(parseDeviceInfo(Buffer.from([0,0])), { firmwareVersion:null,projectName:null,trailingHex:'' });
assert.equal(parseDeviceInfo(Buffer.concat([payload,Buffer.from([0xaa])])).trailingHex,'aa');
for (const b of [Buffer.alloc(0),Buffer.from([5,65]),Buffer.from([1,65]),Buffer.from([1,65,10,66])]) assert.throws(()=>parseDeviceInfo(b),/Truncated/);
assert.throws(()=>parseDeviceInfo(Buffer.from([1,0xff,0])),/UTF-8/);
assert.throws(()=>parseDeviceInfo(Buffer.from([1,1,0])),/control/);
(async()=>{
  let listener, stopped=false;const writes=[];
  const rx={addEventListener:(_,fn)=>{listener=fn;},removeEventListener(){},startNotifications:async()=>{},stopNotifications:async()=>{stopped=true;}};
  const tx={writeValueWithoutResponse:async bytes=>{
    writes.push(Buffer.from(bytes)); if(bytes[0]===0xfd)return;
    assert.equal(bytes[4],0xf3);assert.equal(bytes[6],0);assert.equal(bytes.length,9);
    const frame=Buffer.alloc(payload.length+9);frame[0]=0xdf;frame.writeUInt16BE(payload.length+5,1);frame[4]=0xf3;frame[5]=1;frame[6]=0xf3;frame.writeUInt16BE(payload.length,7);payload.copy(frame,9);frame[3]=frame.reduce((s,b)=>(s+b)&255,0);
    for(const part of [frame.subarray(0,20),frame.subarray(20)])listener({target:{value:new DataView(part.buffer,part.byteOffset,part.byteLength)}});
  }};
  const server={connected:true,getPrimaryService:async()=>({getCharacteristic:async uuid=>uuid===profile.NORMAL.notify?rx:tx})};
  const result=await run('device-info',server);
  assert.equal(result.success,true);assert.equal(result.response.key,243);assert.equal(result.data.projectName,build);assert.equal(result.response.payloadHex,payload.toString('hex'));assert(stopped);
  assert.equal(writes.length,2);assert.equal(writes[1][0],0xfd);assert.equal(writes[1][4],0xf3);
  assert(result.trace.some(t=>t.normalAckTx));
  const original=profile.query;
  try{profile.query=async()=>({key:0,payload:Buffer.from([10,65])});const partial=await run('device-info',{connected:true});assert.equal(partial.success,true);assert.equal(partial.response.payloadHex,'0a41');assert(partial.interpretationError);assert.equal(partial.data,undefined);}
  finally{profile.query=original;}
  console.log('PASS: bounded F3 identification parsing, fragmented response with only query+ACK writes, raw preservation and consolidated profile provenance.');
})().catch(error=>{console.error(error);process.exitCode=1;});
