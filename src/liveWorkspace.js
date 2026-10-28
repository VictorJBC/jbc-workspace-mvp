import { supabase } from './supabaseClient.js';

// JBC Short URL hotfix v3.2.1: accepts load_number and legacy UUID links.
console.info('[JBC] Short URL hotfix v3.2.1 loaded');

// No service role key, localStorage fallback, or financial fields in this module.
const host = () => document.getElementById('app');
const e = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const date = value => value ? new Date(value).toLocaleString() : '—';
let epoch = 0;
let busy = false;
let snapshot = [];
const roles = () => String(window.jbcLiveRole || '').toLowerCase();
const canCreate = () => ['operations','admin'].includes(roles());
const canEdit = () => ['operations','support','accounting','admin'].includes(roles());
const opsStatuses = ['Dispatched','At Pickup','Picked Up','En Route','At Delivery','Delivered','Route Complete','On Hold'];
const trackingStatuses = ['Pending','Active','Needs Attention','Completed'];
const allowedStatuses = ['Open','In Progress','Blocked','Completed'];
function message(text) { host().innerHTML = `<div class="panel" style="padding:24px">${e(text)}</div>`; }
function link(loadNumber) { return '#live/' + encodeURIComponent(loadNumber); }
function isLive() { return location.hash === '#live' || location.hash.startsWith('#live/'); }
async function fetchLoads() {
  const { data, error } = await supabase.from('loads')
    .select('id,load_number,customer_name,carrier_name,ops_status,tracking_status,current_location,elite_team,is_archived,created_at')
    .order('created_at',{ascending:false}).limit(200);
  if (error) throw error;
  return data || [];
}
function renderList(loads) {
  host().innerHTML = `<div class="title"><div><h1>Shared Workspace</h1><p>Supabase · ${loads.length} shared shipments</p></div><div style="display:flex;gap:8px">${canCreate()?'<button class="btn sm" id="liveNew">+ New load</button>':''}<button class="btn sm" id="liveRefresh">↻ Refresh</button></div></div>
  <section class="panel" style="padding:18px"><p style="margin:0 0 14px;color:#64748b">These records are stored in PostgreSQL, not in the browser's local demo database.</p>
  <div style="overflow:auto"><table style="width:100%;border-collapse:collapse"><thead><tr><th>Load</th><th>Customer</th><th>Carrier</th><th>Status</th><th>Tracking</th><th>Location</th></tr></thead><tbody>
  ${loads.map(l=>`<tr><td style="padding:12px"><a href="${link(l.load_number)}">${e(l.load_number)}</a></td><td>${e(l.customer_name)}</td><td>${e(l.carrier_name)}</td><td>${e(l.ops_status)}</td><td>${e(l.tracking_status)}</td><td>${e(l.current_location)}</td></tr>`).join('') || '<tr><td colspan="6" style="padding:24px">No DEMO loads visible. Check RLS or seed data.</td></tr>'}
  </tbody></table></div></section>`;
  document.getElementById('liveRefresh').onclick=()=>window.jbcLive.render('live');
  const createButton=document.getElementById('liveNew'); if(createButton)createButton.onclick=()=>{location.hash='#live/new'};
}
async function renderDetail(id, currentEpoch) {
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) {
    const {data: oldLoad,error: oldError}=await supabase.from('loads').select('load_number').eq('id',id).single();
    if(oldError) throw oldError;
    location.replace(link(oldLoad.load_number));
    return;
  }
  const {data: load,error: loadError}=await supabase.from('loads')
    .select('id,load_number,customer_name,carrier_name,ops_status,tracking_status,current_location,eta,pickup_at,delivery_at,elite_team')
    .eq('load_number',id).single();
  if(loadError) throw loadError;
  const [stopsResult,tasksResult,notesResult]=await Promise.all([
    supabase.from('stops').select('id,stop_order,stop_type,name,address,appointment_at,status').eq('load_id',load.id).order('stop_order'),
    supabase.from('tasks').select('id,title,description,status,due_at,updated_at').eq('load_id',load.id).order('due_at'),
    supabase.from('load_notes').select('id,body,created_at').eq('load_id',load.id).order('created_at',{ascending:false})
  ]);
  for(const result of [stopsResult,tasksResult,notesResult]) if(result.error) throw result.error;
  if(currentEpoch!==epoch || !isLive()) return;
  const stops=stopsResult.data||[],tasks=tasksResult.data||[],notes=notesResult.data||[];
  host().innerHTML=`<div class="title"><div><p><a href="#live">← All shared loads</a></p><h1>${e(load.load_number)}</h1><p>${e(load.customer_name)} · ${e(load.carrier_name)}</p></div><button class="btn sm" id="liveRefresh">↻ Refresh</button></div>
  <section class="panel" style="padding:18px;margin-bottom:14px"><h3>Shipment status</h3><p><b>${e(load.ops_status)}</b> · Tracking: ${e(load.tracking_status)} · Location: ${e(load.current_location)}</p><p>Pickup: ${e(date(load.pickup_at))} · Delivery: ${e(date(load.delivery_at))}</p>${canEdit()?`<form id="liveEdit" style="display:flex;gap:10px;flex-wrap:wrap;align-items:end"><label>Status<br><select name="ops_status">${opsStatuses.map(x=>`<option ${x===load.ops_status?'selected':''}>${e(x)}</option>`).join('')}</select></label><label>Tracking<br><select name="tracking_status">${trackingStatuses.map(x=>`<option ${x===load.tracking_status?'selected':''}>${e(x)}</option>`).join('')}</select></label><label>Current location<br><input name="current_location" value="${e(load.current_location)}" maxlength="200"></label><button class="btn sm" type="submit">Save updates</button></form><p id="liveEditResult" role="status"></p>`:''}</section>
  <section class="panel" style="padding:18px;margin-bottom:14px"><h3>Stops (${stops.length})</h3>${stops.map(s=>`<p><b>${e(s.stop_order)}. ${e(s.stop_type)} — ${e(s.name)}</b><span style="margin-left:10px">${e(s.status)}</span><br><small>${e(s.address)} · ${e(date(s.appointment_at))}</small></p>`).join('')}</section>
  <section class="panel" style="padding:18px;margin-bottom:14px"><h3>Shared tasks (${tasks.length})</h3><p style="color:#64748b">Changing a task status writes to PostgreSQL and is visible to other accounts after Refresh.</p>
  ${tasks.map(t=>`<div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap;padding:12px 0;border-top:1px solid #e2e8f0"><div style="flex:1;min-width:220px"><b>${e(t.title)}</b><div><small>${e(t.description)} · Due ${e(date(t.due_at))}</small></div></div><select data-task="${e(t.id)}" aria-label="Status for ${e(t.title)}">${allowedStatuses.map(s=>`<option value="${e(s)}" ${t.status===s?'selected':''}>${e(s)}</option>`).join('')}</select></div>`).join('') || '<p>No tasks for this shipment.</p>'}
  <p id="liveActionError" role="alert" style="color:#b91c1c"></p></section>
  <section class="panel" style="padding:18px"><h3>Notes (${notes.length})</h3>${notes.map(n=>`<p>${e(n.body)} <small>(${e(date(n.created_at))})</small></p>`).join('') || '<p>No notes</p>'}</section>`;
  document.getElementById('liveRefresh').onclick=()=>window.jbcLive.render('live/'+id);
  const editForm=document.getElementById('liveEdit');
  if(editForm)editForm.onsubmit=async ev=>{
    ev.preventDefault();if(busy)return;
    busy=true;const button=editForm.querySelector('button');button.disabled=true;
    const result=document.getElementById('liveEditResult');
    try {
      const values=Object.fromEntries(new FormData(editForm));
      const {data,error}=await supabase.from('loads').update(values).eq('id',load.id).select('id,ops_status,tracking_status,current_location').single();
      if(error)throw error;if(!data)throw new Error('Update was not confirmed');
      if(result)result.textContent='Saved in Supabase. Refresh another session to verify.';
    }catch(ex){if(result)result.textContent='Update failed: '+(ex.message||String(ex));}
    finally{busy=false;button.disabled=false;}
  };
  host().querySelectorAll('[data-task]').forEach(select=>{
    select.onchange=async ()=>{
      if(busy)return;
      busy=true;select.disabled=true;
      const next=select.value, previous=tasks.find(t=>t.id===select.dataset.task)?.status;
      const err=document.getElementById('liveActionError');
      try {
        const {data,error}=await supabase.from('tasks').update({status:next}).eq('id',select.dataset.task).select('id,status').single();
        if(error)throw error;
        if(!data || data.status!==next)throw new Error('Task update was not confirmed.');
        if(isLive())await window.jbcLive.render('live/'+id);
      } catch(ex) {select.value=previous; if(err)err.textContent='Could not save task: '+(ex.message||String(ex));}
      finally {busy=false;select.disabled=false;}
    };
  });
}
async function renderCreate() {
  if(!canCreate()){message('Access denied: only Operations or Admin may create loads.');return;}
  host().innerHTML=`<div class="title"><div><p><a href="#live">← Shared Workspace</a></p><h1>Create shipment</h1><p>Writes to Supabase. Use fictional test data only.</p></div></div>
  <section class="panel" style="padding:20px;max-width:800px"><form id="liveCreate" style="display:grid;gap:14px">
  <label>Load number (required)<br><input name="load_number" required maxlength="80" placeholder="DEMO-OPS-003"></label>
  <label>Customer<br><input name="customer_name" maxlength="150" required></label>
  <label>Carrier<br><input name="carrier_name" maxlength="150"></label>
  <label>Operations status<br><select name="ops_status">${opsStatuses.map(x=>`<option>${e(x)}</option>`).join('')}</select></label>
  <label>Pickup name<br><input name="pickup_name" maxlength="150" placeholder="Pickup warehouse"></label>
  <label>Pickup address<br><input name="pickup_address" maxlength="250"></label>
  <label>Delivery name<br><input name="delivery_name" maxlength="150" placeholder="Receiver"></label>
  <label>Delivery address<br><input name="delivery_address" maxlength="250"></label>
  <button class="btn" type="submit">Create load and stops</button><p id="liveCreateResult" role="alert"></p></form></section>`;
  const form=document.getElementById('liveCreate');
  form.onsubmit=async ev=>{
    ev.preventDefault();if(busy)return;
    if(!canCreate()){message('Access denied');return;}
    busy=true;const button=form.querySelector('button');button.disabled=true;
    const output=document.getElementById('liveCreateResult');
    try{
      const v=Object.fromEntries(new FormData(form));
      const number=v.load_number.trim();if(!number)throw new Error('Load number is required.');
      const {data:sessionResult,error:sessionError}=await supabase.auth.getUser();
      if(sessionError)throw sessionError;
      const {data:load,error}=await supabase.from('loads').insert({load_number:number,customer_name:v.customer_name.trim(),carrier_name:v.carrier_name.trim(),ops_status:v.ops_status,tracking_status:'Pending',created_by:sessionResult.user?.id}).select('id,load_number').single();
      if(error)throw error;
      // Inserts are separate requests; on stop failure the load remains and can be repaired.
      const stops=[{load_id:load.id,stop_order:1,stop_type:'Pickup',name:v.pickup_name.trim(),address:v.pickup_address.trim(),status:'Pending'},
                   {load_id:load.id,stop_order:2,stop_type:'Delivery',name:v.delivery_name.trim(),address:v.delivery_address.trim(),status:'Pending'}];
      const {error:stopError}=await supabase.from('stops').insert(stops);
      if(stopError){output.textContent=`Load ${load.load_number} created, but stops failed: ${stopError.message}. Open the load and do not retry creation with the same number.`;return;}
      location.hash=link(load.load_number);
      window.jbcLive.render('live/'+encodeURIComponent(load.load_number));
    }catch(ex){output.textContent='Could not create shipment: '+(ex.message||String(ex));}
    finally{busy=false;button.disabled=false;}
  };
}
window.jbcLive={
  async render(route) {
    const myEpoch=++epoch;
    if(!window.jbcVerifiedAuth) return;
    message('Loading shared records from Supabase…');
    try {
      if(route==='live/new') { await renderCreate(); } else if(route.startsWith('live/')) {
        const id=decodeURIComponent(route.slice(5));
        if(!id || id.length>80) throw new Error('Invalid shipment identifier.');
        await renderDetail(id,myEpoch);
      } else {
        const loads=await fetchLoads();snapshot=loads;
        if(myEpoch===epoch&&isLive())renderList(loads);
      }
    } catch(error) { if(myEpoch===epoch&&isLive())message('Supabase query failed: '+(error.message||String(error))); }
  }
};
// Module execution happens after the classic scripts; restore deep links when the module is ready.
if(window.jbcVerifiedAuth && isLive()) window.jbcLive.render(location.hash.slice(1));
