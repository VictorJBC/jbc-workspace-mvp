import {supabase} from './supabaseClient.js';
import {CODES,QUEUES,STATUSES,OPS,COLORS,esc,local,inputDate,select,requireData,role,canCreate,teams,updateTask,updateLoad,createTask,addNote,setElites,showError,attachPanel,installStyles} from './operationalMvp.js';
const $=id=>document.getElementById(id);
let wbFilter={search:'',queue:'All tasks',elite:'All Teams',show:'Incomplete tasks'};
let cached={loads:[],tasks:[],teams:[]};
const fmtStatus=t=>t.status==='Completed';
const codeOptions=selected=>CODES.map(v=>`<option value="${esc(v)}" ${v===selected?'selected':''}>${esc(v.toUpperCase())}</option>`).join('');
const opts=(teams,dept,chosen)=>`<option value="">Unassigned</option>`+teams.filter(t=>t.department===dept).map(t=>`<option value="${esc(t.id)}" ${t.id===chosen?'selected':''}>${esc(t.name)}</option>`).join('');
const input=(label,name,value='',type='text')=>`<label>${esc(label)}</label><input type="${type}" name="${name}" value="${esc(value)}">`;
export async function workbench(render){installStyles();const loads=await requireData(supabase.from('loads').select('id,load_number,customer_name,current_location,ops_status,tracking_status').limit(200));const ids=loads.map(x=>x.id);const tasks=ids.length?await requireData(supabase.from('tasks').select('id,load_id,title,description,status,due_at,task_code,task_queue,task_elite_id').in('load_id',ids).order('due_at',{ascending:true,nullsFirst:false})):[];let et=[];try{et=await teams()}catch(e){console.warn('Elite catalog not available',e)}cached={loads,tasks,teams:et};
 const app=$('app');app.innerHTML=`<div class="jbc-workbench"><div class="title"><div><h1>Workbench</h1><p>Tasks · Supabase · shared across sessions</p></div></div><div class="jbc-chips" id="jbcWbChips"></div><div class="jbc-filterbar"><input id="jbcWbSearch" placeholder="Search task, customer, load..." value="${esc(wbFilter.search)}"><select id="jbcWbShow">${select(['Incomplete tasks','All tasks','Completed tasks'],wbFilter.show)}</select><button class="btn sm" id="jbcWbNew">＋ Add task</button><button class="btn sm" id="jbcWbRefresh">↻ Refresh Workbench</button><div style="width:100%;display:flex;align-items:center;gap:7px;flex-wrap:wrap"><b style="font-size:11px">ELITE TEAM</b><select id="jbcWbElite"><option value="All Teams">All Teams</option>${et.filter(x=>x.department==='support').map(x=>`<option value="${esc(x.id)}" ${wbFilter.elite===x.id?'selected':''}>${esc(x.name)}</option>`).join('')}</select><small>Task assignment is independent of the task text and status.</small></div></div><div id="jbcWbGroups"></div></div>`;
 $('jbcWbSearch').oninput=e=>{wbFilter.search=e.target.value;draw()};$('jbcWbShow').onchange=e=>{wbFilter.show=e.target.value;draw()};$('jbcWbElite').onchange=e=>{wbFilter.elite=e.target.value;draw()};$('jbcWbRefresh').onclick=()=>render('loads');$('jbcWbNew').onclick=()=>taskPanel(null,render);
 function draw(){const term=wbFilter.search.toLowerCase();let list=tasks.filter(t=>{const l=loads.find(x=>x.id===t.load_id);return l&&[t.title,t.description,l.load_number,l.customer_name].some(x=>String(x||'').toLowerCase().includes(term))&&(wbFilter.elite==='All Teams'||t.task_elite_id===wbFilter.elite)&&(wbFilter.show==='All tasks'||(wbFilter.show==='Completed tasks'?fmtStatus(t):!fmtStatus(t)))});
 const chips=['All tasks','Overdue','Blocked','Delayed loads','Unassigned'];$('jbcWbChips').innerHTML=chips.map(c=>{const n=c==='All tasks'?list.length:c==='Overdue'?list.filter(t=>t.due_at&&new Date(t.due_at)<new Date()&&!fmtStatus(t)).length:c==='Blocked'?list.filter(t=>t.status==='Blocked').length:c==='Delayed loads'?list.filter(t=>t.task_code==='DELAYED').length:list.filter(t=>!t.task_elite_id).length;return `<button class="${wbFilter.queue===c?'active':''}" data-filter="${esc(c)}">${esc(c)} <b>${n}</b></button>`}).join('');$('jbcWbChips').onclick=e=>{const b=e.target.closest('[data-filter]');if(b){wbFilter.queue=b.dataset.filter;draw()}};
 if(wbFilter.queue==='Overdue')list=list.filter(t=>t.due_at&&new Date(t.due_at)<new Date()&&!fmtStatus(t));if(wbFilter.queue==='Blocked')list=list.filter(t=>t.status==='Blocked');if(wbFilter.queue==='Delayed loads')list=list.filter(t=>t.task_code==='DELAYED');if(wbFilter.queue==='Unassigned')list=list.filter(t=>!t.task_elite_id);
 $('jbcWbGroups').innerHTML=QUEUES.map(q=>{const group=list.filter(t=>(t.task_queue||'Active Tasks')===q);return `<section class="jbc-group"><div class="jbc-groupheader"><b>${esc(q)} (${group.length})</b><small>${q==='Active Tasks'?'Soonest due first · overdue in red':q==='Seniors Only'?'Private senior queue (UI grouping only)':q==='Support POD Pending'?'POD follow-up':'Returned to Operations'}</small></div>${group.map(t=>{const l=loads.find(x=>x.id===t.load_id);const [bg,dot]=COLORS[t.task_code]||COLORS['No status'];const overdue=t.due_at&&new Date(t.due_at)<new Date()&&!fmtStatus(t);return `<div class="jbc-row" style="background:${bg}" data-task="${esc(t.id)}"><button class="btn sm" data-complete="${esc(t.id)}" title="Complete task">${fmtStatus(t)?'✓':'○'}</button><select data-code="${esc(t.id)}" title="Task code / row color" style="width:145px;min-width:145px;max-width:145px;background:${bg};color:#243745;border:1px solid #dce5ea;border-radius:6px;padding:5px 6px;font-size:11px;font-weight:700">${codeOptions(t.task_code||'No status')}</select><span class="jbc-rowtitle">${esc(t.title)}</span><a class="jbc-loadlink" href="#shipment/${encodeURIComponent(l.load_number)}">#${esc(l.load_number)}</a><span class="${overdue?'jbc-overdue':''}">${esc(local(t.due_at))}</span></div>`}).join('')||'<p style="padding:12px;color:#789">No tasks in this section.</p>'}</section>`}).join('');
 $('jbcWbGroups').onchange=async e=>{
   const sel=e.target.closest('[data-code]');
   if(!sel)return;
   const task=tasks.find(t=>t.id===sel.dataset.code);
   if(!task)return;
   const previous=task.task_code||'No status';
   const next=sel.value;
   if(previous===next)return;
   const row=sel.closest('.jbc-row');
   const applyColor=code=>{
     const [background]=COLORS[code]||COLORS['No status'];
     if(row)row.style.background=background;
     sel.style.background=background;
   };
   task.task_code=next;
   applyColor(next);
   sel.disabled=true;
   try{
     await updateTask(task.id,{task_code:next});
   }catch(ex){
     task.task_code=previous;
     sel.value=previous;
     applyColor(previous);
     showError(ex);
   }finally{
     sel.disabled=false;
   }
 };$('jbcWbGroups').onclick=async e=>{if(e.target.closest('[data-code]'))return;const done=e.target.closest('[data-complete]');if(done){e.stopPropagation();try{await updateTask(done.dataset.complete,{status:'Completed',completed_at:new Date().toISOString()});await render('loads')}catch(ex){showError(ex)}return}if(e.target.closest('a'))return;const row=e.target.closest('[data-task]');if(row)taskPanel(tasks.find(t=>t.id===row.dataset.task),render)};
 }draw();
}
export async function taskPanel(task,render,loadId){installStyles();const isNew=!task;const loads=await requireData(supabase.from('loads').select('id,load_number,customer_name').limit(200));const et=cached.teams.length?cached.teams:await teams();const l=loads.find(x=>x.id===(task?.load_id||loadId));const panel=attachPanel(`<p>${isNew?'Create task':'Edit task'} ${l?'· #'+esc(l.load_number):''}</p><form id="jbcTaskForm"><label>Related shipment</label><select name="load_id" required>${loads.map(x=>`<option value="${esc(x.id)}" ${x.id===(task?.load_id||loadId)?'selected':''}>#${esc(x.load_number)} · ${esc(x.customer_name)}</option>`).join('')}</select><label>TASK TEXT</label><textarea name="title" required>${esc(task?.title||'')}</textarea><label>DESCRIPTION / COMMENTS</label><textarea name="description">${esc(task?.description||'')}</textarea>${input('DUE DATE AND TIME','due_at',inputDate(task?.due_at),'datetime-local')}<label>CLASSIFICATION (controls row color)</label><select name="task_code">${codeOptions(task?.task_code||'No status')}</select><label>TASK QUEUE</label><select name="task_queue">${select(QUEUES,task?.task_queue||'Active Tasks')}</select><label>ASSIGN TO SUPPORT ELITE</label><select name="task_elite_id">${opts(et,'support',task?.task_elite_id)}</select><label>TASK STATUS</label><select name="status">${select(STATUSES,task?.status||'Open')}</select><button class="btn primary" type="submit">Save task</button><button class="btn sm" type="button" id="jbcTaskQuick">Quick Actions for shipment</button><p class="jbc-message" id="jbcTaskError"></p></form>`);
 panel.querySelector('#jbcTaskQuick').onclick=()=>{const id=panel.querySelector('[name=load_id]').value;shipmentPanel(id,render)};
 panel.querySelector('form').onsubmit=async e=>{e.preventDefault();const f=e.currentTarget;const values=Object.fromEntries(new FormData(f));values.title=values.title.trim();if(!values.title)return;values.due_at=values.due_at?new Date(values.due_at).toISOString():null;values.task_elite_id=values.task_elite_id||null;try{if(isNew)await createTask(values);else await updateTask(task.id,values);panel.remove();await render(location.hash.slice(1)||'loads')}catch(ex){$('jbcTaskError').textContent=ex.message||String(ex)}};
}
// Quick Actions intentionally changes only the shipment's location/status, not its other attributes.
export async function shipmentPanel(loadId,render){
 installStyles();
 const load=await requireData(supabase.from('loads').select('id,load_number,current_location,ops_status').eq('id',loadId).single());
 const panel=attachPanel(`<p><b>Quick Actions · #${esc(load.load_number)}</b></p><button class="btn sm" id="jbcQuickTask">＋ Add task</button><button class="btn sm" id="jbcQuickViewTasks">☑ View tasks</button><button class="btn sm" id="jbcQuickNote">✎ Add note</button><form id="jbcQuickForm"><label>UPDATE LOCATION</label><input name="current_location" value="${esc(load.current_location||'')}"><label>CHANGE SHIPMENT STATUS</label><select name="ops_status">${select(OPS,load.ops_status)}</select><button class="btn primary" type="submit">Save quick changes</button><p class="jbc-message" id="jbcQuickError"></p></form>`);
 panel.querySelector('#jbcQuickTask').onclick=()=>taskPanel(null,render,loadId);
 panel.querySelector('#jbcQuickViewTasks').onclick=()=>{panel.remove();location.hash='#shipment/'+encodeURIComponent(load.load_number)+'/tasks'};
 panel.querySelector('#jbcQuickNote').onclick=async()=>{const body=window.prompt('Note for #'+load.load_number);if(body?.trim())try{await addNote(loadId,body.trim());panel.remove();await render(location.hash.slice(1))}catch(ex){showError(ex)}};
 panel.querySelector('#jbcQuickForm').onsubmit=async e=>{e.preventDefault();const data=Object.fromEntries(new FormData(e.currentTarget));try{await updateLoad(loadId,data);panel.remove();await render(location.hash.slice(1))}catch(ex){panel.querySelector('#jbcQuickError').textContent=ex.message||String(ex)}};
}
// Details cards have their own scoped editors; ownership changes are Operations/Admin only.
const DETAIL_FIELDS={
 customer:[['Customer','customer_name'],['PO / Reference','po_number'],['Equipment','equipment'],['Broker','broker_name']],
 carrier:[['Carrier','carrier_name'],['Dispatcher','dispatcher'],['Driver','driver_name'],['Driver phone','driver_phone']],
 operations:[['Current location','current_location'],['Appointment notes','appointment_note']],
 ownership:[]
};
export async function editDetailSection(loadId,section,render){
 installStyles();const fields=DETAIL_FIELDS[section];if(!fields)throw Error('Unknown detail section');
 const load=await requireData(supabase.from('loads').select('*').eq('id',loadId).single());
 let et=[],assignments=[];
 if(section==='ownership'){
  if(!canCreate())throw Error('Only Operations/Admin can change Elite assignments.');
  et=await teams();assignments=await requireData(supabase.rpc('get_visible_load_elites',{p_load_id:loadId}));
 }
 const sup=et.find(t=>t.name===assignments.find(a=>a.department==='support')?.elite_name)?.id||'';
 const ops=et.find(t=>t.name===assignments.find(a=>a.department==='operations')?.elite_name)?.id||'';
 const title={customer:'Shipment / Customer',carrier:'Carrier / Driver',operations:'Operations / Tracking',ownership:'Groups / Ownership'}[section];
 const panel=attachPanel(`<h3>Edit ${esc(title)} · #${esc(load.load_number)}</h3><form id="jbcSectionForm">${fields.map(([label,key])=>input(label,key,load[key]||'')).join('')}${section==='operations'?`<label>Operations status</label><select name="ops_status">${select(OPS,load.ops_status)}</select><label>Tracking status</label><input name="tracking_status" value="${esc(load.tracking_status||'')}">${input('ETA','eta',inputDate(load.eta),'datetime-local')}`:''}${section==='ownership'?`<label>Elite Support</label><select name="support_elite">${opts(et,'support',sup)}</select><label>Elite Operations</label><select name="operations_elite">${opts(et,'operations',ops)}</select>`:''}<button class="btn primary" type="submit">Save ${esc(title)}</button><p class="jbc-message" id="jbcSectionError"></p></form>`);
 panel.querySelector('form').onsubmit=async e=>{e.preventDefault();const data=Object.fromEntries(new FormData(e.currentTarget));try{
  if(section==='ownership')await setElites(loadId,data.support_elite,data.operations_elite);
  else{if(section==='operations')data.eta=data.eta?new Date(data.eta).toISOString():null;await updateLoad(loadId,data)}
  panel.remove();await render(location.hash.slice(1));
 }catch(ex){panel.querySelector('#jbcSectionError').textContent=ex.message||String(ex)}};
}
export async function attachDetailActions(load,render){installStyles();document.getElementById('jbcDetailFab')?.remove();const fab=document.createElement('button');fab.id='jbcDetailFab';fab.className='jbc-fab';fab.textContent='+';fab.title='Quick Actions · #'+load.load_number;document.body.append(fab);fab.onclick=()=>shipmentPanel(load.id,render).catch(showError);
 const body=document.getElementById('originalBody');if(body){body.onclick=e=>{const btn=e.target.closest('[data-section-edit]');if(btn)editDetailSection(load.id,btn.dataset.sectionEdit,render).catch(showError)}};
}
export function cleanupDetail(){document.getElementById('jbcDetailFab')?.remove();document.getElementById('jbcOperationalPanel')?.remove()}
