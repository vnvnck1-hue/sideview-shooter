// Standalone review: embedded metadata and PNGs, no installation or network needed.
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..');
const base=path.join(root,'Assets/Generated/CreatureProductionV1');
const ids=['CeilingBell','RingSpine','SeamAmbusher'];
const names={CeilingBell:'천장종',RingSpine:'환상척추',SeamAmbusher:'틈새꽃'};
const clipNames={idle:'대기',anticipate:'공격 예고',strike:'내려찍기',hold:'포획 유지',retract:'포획구 회수',close:'골판 닫기',hurt:'피격',death:'사망',roll:'구르기',uncoil:'고리 해제',lash:'채찍 공격',recoil:'공격 회수',coil:'다시 말기',dormant:'위장 대기',emerge:'출현',snap:'포획',release:'포획 해제',withdraw:'숨기'};
const png=file=>'data:image/png;base64,'+fs.readFileSync(file).toString('base64');
const data=ids.map(id=>{
 const dir=path.join(base,'processed',id),m=JSON.parse(fs.readFileSync(path.join(dir,'animation.json'),'utf8'));
 const marker=(clip,frame,type)=>({clip,frame,type});
 const events=id==='CeilingBell'?[marker('anticipate',1,'weak_open'),marker('strike',2,'damage_on'),marker('retract',0,'damage_off'),marker('close',2,'weak_closed')]:id==='RingSpine'?[marker('roll',0,'contact_damage_on'),marker('uncoil',0,'weak_open'),marker('lash',2,'damage_on'),marker('recoil',0,'damage_off'),marker('coil',4,'weak_closed')]:[marker('emerge',1,'weak_open'),marker('snap',2,'damage_on'),marker('release',0,'damage_off'),marker('withdraw',3,'weak_closed')];
 m.events=events.concat([marker('death',0,'disable_damage'),marker('death',3,'corpse_hold')]);
 m.defaultClip=m.clips[0].name;
 m.playback={frameIndexBase:0,death:'play once and hold last frame',rootMotion:'none; world movement belongs to game logic',hurtReturn:'resume previous state; hurt is a pose reaction, not a state controller',geometry:'bounds and green-organ centroids are visual authoring guides, not tested physics colliders'};
 m.runtime4x={scale:4,cell:m.cell.map(v=>v*4),pivot:m.pivot.map(v=>v*4),color:'runtime4x/frames/<clip>/<frame>.png',normal:'runtime4x/normals/<clip>/<frame>.png',filter:'nearest',mipmaps:false,normalConvention:'OpenGL Y+; derived luminance/bevel draft'};
 fs.writeFileSync(path.join(dir,'animation.json'),JSON.stringify(m,null,2));
 return {...m,title:names[id],sheets:Object.fromEntries(m.clips.map(c=>[c.name,png(path.join(dir,c.sheet))])),comparison:png(path.join(dir,'preview/source_native_comparison.png'))};
});
const player=png(path.join(root,'Assets/GameReady/Characters/HoodedMechanic/Frames/idle/idle_01.png'));
const html=`<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>괴생명체 3종 · 에셋 검토</title><style>
*{box-sizing:border-box}body{margin:0;background:#10151d;color:#ece8df;font:15px/1.6 system-ui,sans-serif}header,main{max-width:1560px;margin:auto;padding:24px}header{border-bottom:1px solid #354051}h1{font-size:29px;margin:0}p{color:#bac2cc;margin:8px 0}button,select,input{font:inherit}button,select{border:1px solid #526176;background:#253143;color:#f5f0e6;border-radius:6px;padding:6px 10px;cursor:pointer}button:hover{background:#374964}label{display:inline-flex;gap:8px;align-items:center;margin-right:15px}nav{display:flex;gap:12px;flex-wrap:wrap;margin-top:18px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}article{background:#1a222f;border:1px solid #364355;border-radius:12px;overflow:hidden}h2{margin:0;font-size:23px}.head,.controls,.details{padding:16px}.badge{color:#cbd77e;font-size:13px}.stage{width:100%;height:380px;display:block;background:#202731;image-rendering:pixelated}.controls{display:flex;gap:8px;flex-wrap:wrap}.controls select{width:100%}.timeline{width:100%}.status{font:13px monospace;color:#cfda9a;min-height:44px}.clips{display:grid;grid-template-columns:repeat(2,1fr);gap:5px}.clips button{font-size:13px;text-align:left}.note{font-size:13px;color:#abb5c3}.comparison{width:100%;display:block}.small{font-size:12px;color:#a8b5c3}details{margin-top:15px}summary{cursor:pointer;color:#cbd77e}.legend{padding:10px 16px;color:#b9c5d4;font-size:12px}@media(max-width:1050px){.grid{grid-template-columns:1fr}.stage{height:430px}}
</style><header><div class="badge">DESIGN 01 / 04 / 05 · PRODUCTION V1</div><h1>괴생명체 3종 · 애니메이션 검토</h1><p>24개 클립 · 109프레임 · 공통 16색/종 · 투명 PNG · Aseprite 편집원본. 게임 반입 전 에셋 패키지.</p><nav><label>배속 <select id="speed"><option value="0.25">0.25×</option><option value="0.5">0.5×</option><option value="1" selected>1×</option><option value="2">2×</option></select></label><label>배경 <select id="bg"><option value="dark">어두운 시설</option><option value="light">밝은 배경</option><option value="checker">투명 격자</option></select></label><label><input id="guides" type="checkbox">피벗·약점 표시</label><label><input id="player" type="checkbox" checked>기존 플레이어 크기 비교</label></nav><p class="small">파란 십자: 고정 피벗 · 노란 원: 황록색 기관의 시각적 중심. 물리 충돌 영역은 게임 연결 때 조정합니다. 사망 클립은 마지막 잔해에서 멈춥니다.</p></header><main><div class="grid" id="grid"></div><p class="note">생성 원본의 고밀도 질감을 네이티브 격자로 정리했습니다. 원본/가공본 비교에서 작은 이빨·힘줄의 단순화를 확인할 수 있습니다. 노멀맵은 밝기와 외곽 높이에서 만든 조명용 초안입니다.</p></main><script>
const DATA=${JSON.stringify(data)};const LABELS=${JSON.stringify(clipNames)};
const playerImage=new Image();playerImage.src=${JSON.stringify(player)};
const states=[];
const el=(s,p=document)=>p.querySelector(s);
for(const d of DATA){
 const article=document.createElement('article');article.dataset.id=d.id;
 article.innerHTML='<div class="head"><div class="badge">'+d.id+' · '+d.frames.length+' FRAMES</div><h2>'+d.title+'</h2><div class="small">'+d.cell.join(' × ')+' art px · 피벗 '+d.pivot.join(', ')+'</div></div><canvas class="stage" width="640" height="500"></canvas><div class="legend">동일한 아트 픽셀 크기로 표시 · 플레이어 키 약 67 art px</div><div class="controls"><select class="clip"><option value="cycle">전투 연결 재생</option>'+d.clips.map(c=>'<option value="'+c.name+'">'+LABELS[c.name]+' / '+c.name+' · '+(c.to-c.from+1)+'f</option>').join('')+'</select><button class="play">일시정지</button><button class="reset">처음부터</button><button class="step">한 프레임</button><input class="timeline" type="range" min="0" value="0"><div class="status"></div></div><div class="details"><div class="clips">'+d.clips.map(c=>'<button data-clip="'+c.name+'">'+LABELS[c.name]+' · '+(c.to-c.from+1)+'f</button>').join('')+'</div><details><summary>생성 원본과 네이티브 가공 비교</summary><img class="comparison" src="'+d.comparison+'" alt="생성 원본과 공통 16색 가공 비교"></details></div>';
 el('#grid').append(article);
 const s={d,article,canvas:el('canvas',article),images:{},mode:'cycle',sequence:[],index:0,elapsed:0,playing:true,finished:false};
 for(const c of d.clips){const im=new Image();im.src=d.sheets[c.name];s.images[c.name]=im;}
 function change(mode){s.mode=mode;s.sequence=mode==='cycle'?d.frames.filter(f=>f.clip!=='hurt'&&f.clip!=='death'):d.frames.filter(f=>f.clip===mode);s.index=0;s.elapsed=0;s.finished=false;s.playing=true;el('.clip',article).value=mode;el('.play',article).textContent='일시정지';el('.timeline',article).max=s.sequence.length-1;}
 el('.clip',article).onchange=e=>change(e.target.value);
 article.querySelectorAll('[data-clip]').forEach(b=>b.onclick=()=>change(b.dataset.clip));
 el('.play',article).onclick=()=>{if(s.finished){s.index=0;s.finished=false;}s.playing=!s.playing;el('.play',article).textContent=s.playing?'일시정지':'재생';};
 el('.reset',article).onclick=()=>change(s.mode);
 el('.step',article).onclick=()=>{s.playing=false;s.index=Math.min(s.index+1,s.sequence.length-1);s.elapsed=0;el('.play',article).textContent='재생';};
 el('.timeline',article).oninput=e=>{s.index=+e.target.value;s.elapsed=0;s.playing=false;el('.play',article).textContent='재생';};
 change('cycle');states.push(s);
}
function draw(s){
 const c=s.canvas,ctx=c.getContext('2d'),d=s.d,f=s.sequence[s.index],bg=el('#bg').value;ctx.imageSmoothingEnabled=false;
 ctx.fillStyle=bg==='light'?'#bcc0bd':'#202731';ctx.fillRect(0,0,c.width,c.height);
 if(bg==='checker')for(let y=0;y<c.height;y+=24)for(let x=0;x<c.width;x+=24){ctx.fillStyle=((x/24+y/24)%2)?'#323d4c':'#465368';ctx.fillRect(x,y,24,24);}
 const scale=3,px=d.id==='CeilingBell'?270:d.id==='RingSpine'?175:65,py=d.id==='CeilingBell'?35:d.id==='RingSpine'?398:160;
 const ox=px-d.pivot[0]*scale,oy=py-d.pivot[1]*scale;
 ctx.strokeStyle=bg==='light'?'#8f9691':'#586270';ctx.lineWidth=3;ctx.beginPath();
 if(d.id==='CeilingBell'){ctx.moveTo(90,py-4);ctx.lineTo(450,py-4);}else if(d.id==='SeamAmbusher'){ctx.moveTo(px-4,30);ctx.lineTo(px-4,460);}else{ctx.moveTo(20,py+3);ctx.lineTo(620,py+3);}ctx.stroke();
 const im=s.images[f.clip];if(im.complete&&im.naturalWidth)ctx.drawImage(im,f.localFrame*d.cell[0],0,d.cell[0],d.cell[1],ox,oy,d.cell[0]*scale,d.cell[1]*scale);
 if(el('#player').checked&&playerImage.complete){const ground=d.id==='RingSpine'?py+6:425;ctx.globalAlpha=.85;ctx.drawImage(playerImage,440,ground-240,240,240);ctx.globalAlpha=1;ctx.fillStyle=bg==='light'?'#303637':'#a7b3c2';ctx.font='15px sans-serif';ctx.fillText('PLAYER',486,ground+23);}
 if(el('#guides').checked){ctx.strokeStyle='#59cde4';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(px-9,py);ctx.lineTo(px+9,py);ctx.moveTo(px,py-9);ctx.lineTo(px,py+9);ctx.stroke();if(f.weakPointVisualCenter){ctx.strokeStyle='#f1e681';ctx.beginPath();ctx.arc(ox+f.weakPointVisualCenter[0]*scale,oy+f.weakPointVisualCenter[1]*scale,12,0,Math.PI*2);ctx.stroke();}}
 el('.timeline',s.article).value=s.index;const events=d.events.filter(e=>e.clip===f.clip&&e.frame===f.localFrame).map(e=>e.type).join(' · ');
 el('.status',s.article).textContent=LABELS[f.clip]+' / '+f.clip+'  '+(f.localFrame+1)+'f · '+f.durationMs+'ms'+(s.finished?' · 마지막 프레임 유지':'')+(events?' | '+events:'');
}
let last=performance.now();function tick(now){const delta=Math.min(100,now-last)*+el('#speed').value;last=now;for(const s of states){if(s.playing&&!s.finished){s.elapsed+=delta;while(s.elapsed>=s.sequence[s.index].durationMs){s.elapsed-=s.sequence[s.index].durationMs;if(s.index+1<s.sequence.length)s.index++;else{const clip=s.d.clips.find(c=>c.name===s.mode);if(s.mode==='cycle'||clip.loop)s.index=0;else{s.finished=true;s.playing=false;el('.play',s.article).textContent='다시 재생';break;}}}}draw(s);}requestAnimationFrame(tick);}requestAnimationFrame(tick);
window.creatureReview={states,draw};
</script></html>`;
fs.writeFileSync(path.join(base,'review.html'),html);
const files=[];function walk(dir){for(const item of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,item.name);if(item.isDirectory())walk(p);else files.push({file:path.relative(base,p).replaceAll('\\','/'),bytes:fs.statSync(p).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex')});}}walk(path.join(base,'processed'));
fs.writeFileSync(path.join(base,'package_manifest.json'),JSON.stringify({version:1,gameImported:false,creatures:data.map(d=>({id:d.id,clips:d.clips.length,frames:d.frames.length,cell:d.cell,pivot:d.pivot,paletteColors:16})),totalClips:24,totalFrames:data.reduce((n,d)=>n+d.frames.length,0),files},null,2));
console.log('Review and manifest built: '+files.length+' production files.');
