// Offline interpretations of actual research captures, without any transport or network calls.
const { parseDeviceInfo } = require('../watch/device-info');
function frame(hex) {
  const b = Buffer.from(hex, 'hex');
  if (b.length < 9 || ![0xdf,0xfd].includes(b[0])) throw Error('Invalid normal frame');
  if ((b[0] === 0xfd ? 9 : b.readUInt16BE(1)+4) !== b.length) throw Error('Outer frame length mismatch');
  if (b.reduce((s,v,i)=>i===3?s:(s+v)&255,0) !== b[3]) throw Error('Checksum mismatch');
  if (b[0] === 0xfd) return { type:'ack',command:b[4],key:b[5],status:b[8],auxHex:b.subarray(6,8).toString('hex') };
  const declared=b.readUInt16BE(7),actual=b.length-9,warnings=[];
  if(declared!==actual){
    if(b[4]===15&&b[6]===5&&declared===11&&actual===17)warnings.push('Firmware custom-face quirk: inner length 11, actual 17; outer length and checksum verified');
    else throw Error('Inner payload length mismatch');
  }
  return {type:'data',command:b[4],key:b[6],payload:b.subarray(9),declaredBytes:declared,actualBytes:actual,warnings};
}
function windowData(b){return{switchRaw:b[0],startMinutes:b.readUInt16BE(1),endMinutes:b.readUInt16BE(3)};}
function settings(b){
  if(b.length<5)throw Error('Truncated settings prefix');
  const result={unknownPrefixHex:b.subarray(0,5).toString('hex'),records:[],warnings:[]};
  const sizes={2:5,3:9,5:6,6:5,7:6,8:9,9:6,10:8,11:2,12:2,13:2,14:2,15:2,17:2,18:2};
  let offset=5;
  while(offset<b.length){
    const tag=b[offset];let size=sizes[tag];
    if(tag===4){size=12;if(offset+12<b.length&&[0,1].includes(b[offset+12]))size=13;}
    if(!size){result.unparsedTailHex=b.subarray(offset).toString('hex');break;}
    if(offset+size>b.length)throw Error('Truncated settings record '+tag);
    const value=b.subarray(offset+1,offset+size),record={tag,offset,hex:value.toString('hex')};
    if(tag===2)record.data={stepTarget:value.readUInt32BE(0)};
    if(tag===3)record.data={lunchBreakRaw:value[0],switchRaw:value[1],threshold:value.readUInt16BE(2),intervalMinutes:value[4]*15+30,startHour:value[5],endHour:value[6],repeatMask:value[7]&127};
    if(tag===4)record.data={legacyNotifyFlags:[...value],note:'Legacy list; use command 18 for current detailed flags'};
    if([5,7,9].includes(tag))record.data=windowData(value);
    if(tag===6)record.data={wearOnLeft:(value[0]&2)!==2,androidFlag:(value[1]&2)===2,languageCode:value[2],language:value[2]===4?'es':null,vibration:(value[3]&1)===1};
    if(tag===8)record.data={switchRaw:value[0],sleepRaw:value[1],cycle:value.readUInt16BE(2),startMinutes:value.readUInt16BE(4),endMinutes:value.readUInt16BE(6)};
    if(tag===11)record.data={hour24:(value[0]&1)!==1};
    if(tag===14)record.data={temperatureUnitRaw:value[0]};
    result.records.push(record);offset+=size;
  }
  return result;
}
function notifications(b){
  const names=[['calls','sms'],['wechat','qq'],['dingding','weibo'],['alipay','teams'],['facebook','twitter'],['whatsapp','snapchat'],['instagram','messenger'],['linkedin','skype'],['kakaotalk','telegram'],['vk','zalo'],['viber','line'],['other','outlook']];
  const channels={};
  for(let i=0;i<names.length&&i<b.length;i++)for(let j=0;j<2;j++){const nibble=(b[i]>>(j*4))&15;channels[names[i][j]]={show:(nibble&1)===1,enabled:(nibble&2)===2,raw:nibble};}
  if(b.length>13)channels.max={show:(b[13]&16)===16,enabled:(b[13]&32)===32,raw:(b[13]>>4)&15};
  return{channels,trailingHex:b.subarray(14).toString('hex'),meaning:'APK visibility/enabled flags; no notification was pushed as a test'};
}
function interpret(id,payload,key){
  if(id==='ota-info'){
    if(payload.length<6)throw Error('Truncated update identity');
    return{opaqueIdentifierHex:payload.subarray(0,4).toString('hex'),...parseDeviceInfo(payload.subarray(4)),otaUniqueCode:payload.toString('hex').toUpperCase()};
  }
  if(id==='settings-info')return settings(payload);
  if(id==='alarms-info')return{recordBytes:5,recordCount:Math.floor(payload.length/5),empty:payload.length===0,rawHex:payload.toString('hex'),note:'Empty response is zero returned alarm records; maximum slot count unknown'};
  if(id==='custom-face-info'){
    if(payload.length!==17)throw Error('Unknown custom-face layout');
    return{faceCode:payload.subarray(0,8).toString('hex'),x:payload.readUInt16BE(8),y:payload.readUInt16BE(10),color:payload.readUInt16BE(12),aboveTimeRaw:payload[14],belowTimeRaw:payload[15],backgroundUpdateRaw:payload[16]};
  }
  if(id==='drink-reminder-info'){
    if(payload.length<6)throw Error('Truncated drink reminder');
    return{lunchBreakRaw:payload[0],switchRaw:payload[1],intervalMinutes:payload[2]*15,startHour:payload[3],endHour:payload[4],repeatMask:payload[5]&127};
  }
  if(id==='sedentary-reminder-info'){
    if(payload.length<8)throw Error('Truncated sedentary reminder');
    return{lunchBreakRaw:payload[0],switchRaw:payload[1],threshold:payload.readUInt16BE(2),intervalMinutes:payload[4]*15+30,startHour:payload[5],endHour:payload[6],repeatMask:payload[7]&127};
  }
  if(id==='notification-settings-info')return notifications(payload);
  if(id==='today-summary'){
    if(key===2){
      if(payload.length!==194)throw Error('Unknown hourly activity layout');
      const hours=Array.from({length:24},(_,hour)=>{const offset=2+hour*8;return{hour,stepsRaw:payload.readUInt16BE(offset),distanceRaw:payload.readUInt16BE(offset+2),calorieRaw:payload.readUInt32BE(offset+4)};});
      return{date:{year:2000+((payload[0]&127)>>1),month:((payload[0]&1)<<3)+(payload[1]>>5),day:payload[1]&31},hours,meaning:'APK StepUtils.getSportBy1Hour layout; raw zero bins do not independently prove no activity'};
    }
    return{responseKey:key,payloadHex:payload.toString('hex'),meaning:key===8?'History synchronization end marker':key===7?'History synchronization start marker':'Uninterpreted activity response'};
  }
  if(id==='watch-faces')return require('../watch/device-profile').watchInfo(payload,key,{is8Bytes:true,resolutionId:1});
  return{payloadHex:payload.toString('hex'),key};
}
function analyzeQuery(query){
  const result={id:query.id,request:query.request,runnerSuccess:query.success,runnerError:query.error,frames:[],interpretationSource:'Local APK + validated recorded frames'};
  for(const item of query.frames||[]){try{const decoded=frame(item.hex);result.frames.push({...decoded,payload:undefined,payloadHex:decoded.payload?.toString('hex')});}catch(error){result.frames.push({error:error.message,hex:item.hex});}}
  const response=result.frames.filter(f=>f.type==='data'&&f.command===query.request.command).at(-1);
  if(response){result.outcome='data';result.key=response.key;result.payloadHex=response.payloadHex;result.warnings=response.warnings;try{result.data=interpret(query.id,Buffer.from(response.payloadHex,'hex'),response.key);result.responses=result.frames.filter(f=>f.type==='data'&&f.command===query.request.command).map(f=>({key:f.key,payloadHex:f.payloadHex,data:interpret(query.id,Buffer.from(f.payloadHex,'hex'),f.key)}));}catch(error){result.interpretationError=error.message;}}
  else result.outcome=result.frames.some(f=>f.type==='ack'&&f.command===query.request.command)?'ack-only':'no-matching-response';
  return result;
}
module.exports={frame,settings,notifications,interpret,analyzeQuery};
