import {supabase} from './supabaseClient.js';
export const CODES=['No status','LOADED?','LOCATION?','Not tracking','ARRIVED@DEL','DEL?','DELAYED','POD PENDING'];
export const QUEUES=['Active Tasks','Seniors Only','Support POD Pending','Back to Ops'];
export const STATUSES=['Open','In Progress','Blocked','Completed'];
export const OPS=['Dispatched','At Pickup','Picked Up','En Route','At Delivery','Delivered','Route Complete','On Hold'];
export const COLORS={'No status':['#fff','#cbd5e1'],'LOADED?':['#edf3ff','#2f80ed'],'LOCATION?':['#eaf8ef','#1da66a'],'Not tracking':['#fff9e6','#f4c430'],'ARRIVED@DEL':['#fff0e3','#f28c28'],'DEL?':['#fff0e3','#f28c28'],'DELAYED':['#fff0ef','#dc3545'],'POD PENDING':['#f4edff','#9b55dc']};
export const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const local=v=>v?new Date(v).toLocaleString():'No due time';
export const inputDate=v=>v?new Date(new Date(v).getTime()-new Date(v).getTimezoneOffset()*60000).toISOString().slice(0,16):'';
export const select=(values,selected)=>values.map(v=>`<option value="${esc(v)}" ${v===selected?'selected':''}>${esc(v)}</option>`).join('');
export async function requireData(query){const {data,error}=await query;if(error)throw error;return data;}
export const role=()=>String(window.jbcLiveRole||'').toLowerCase();
export const canCreate=()=>['operations','admin'].includes(role());
export async function teams(){return await requireData(supabase.from('elite_teams').select('id,name,department,team_number').order('department').order('team_number'))||[];}
export async function updateTask(id,fields){const rows=await requireData(supabase.from('tasks').update(fields).eq('id',id).select('id'));if(!rows?.length)throw Error('Task not updated. Check RLS.');}
export async function updateLoad(id,fields){const rows=await requireData(supabase.from('loads').update(fields).eq('id',id).select('id'));if(!rows?.length)throw Error('Load not updated. Check RLS.');}
export async function createTask(fields){const rows=await requireData(supabase.from('tasks').insert(fields).select('id'));if(!rows?.length)throw Error('Task not created.');}
export async function addNote(loadId,body){await requireData(supabase.from('load_notes').insert({load_id:loadId,body}));}
export async function setElites(loadId,support,operations){await requireData(supabase.rpc('set_load_elites',{p_load_id:loadId,p_support_elite_id:support||null,p_operations_elite_id:operations||null}));}
export function showError(e){window.alert('Supabase: '+(e?.message||String(e)));}
export function attachPanel(html){document.getElementById('jbcOperationalPanel')?.remove();const panel=document.createElement('aside');panel.id='jbcOperationalPanel';panel.innerHTML=`<div class="jbc-sidehead"><b>Task Details / Quick Actions</b><button id="jbcClosePanel" class="btn sm">✕</button></div><div class="jbc-sidecontent">${html}</div>`;document.body.append(panel);panel.querySelector('#jbcClosePanel').onclick=()=>panel.remove();return panel;}
export function installStyles(){if(document.getElementById('jbcOperationalCss'))return;const style=document.createElement('style');style.id='jbcOperationalCss';style.textContent=`
#jbcOperationalPanel{position:fixed;right:0;top:0;bottom:0;width:min(440px,96vw);background:#fff;box-shadow:-12px 0 35px #172b3a33;z-index:99999;display:flex;flex-direction:column;font:12px system-ui;color:#213745}
.jbc-sidehead{display:flex;align-items:center;justify-content:space-between;padding:20px;border-bottom:1px solid #dce5ea;font-size:15px}
.jbc-sidecontent{padding:20px;overflow:auto;flex:1}.jbc-sidecontent label{display:block;font-size:11px;font-weight:700;margin:13px 0 5px;color:#526a7a}
.jbc-sidecontent input,.jbc-sidecontent select,.jbc-sidecontent textarea{width:100%;padding:9px;border:1px solid #d4e0e7;border-radius:7px;background:#fff;color:#213745}
.jbc-sidecontent textarea{min-height:85px}.jbc-sidecontent button{margin-top:14px}.jbc-sidecontent .jbc-message{color:#a32922;margin:12px 0}
.jbc-workbench .jbc-row{display:flex;align-items:center;gap:9px;padding:8px 12px;border-bottom:1px solid #e8edf1;cursor:pointer;min-height:39px;font-size:12px}
.jbc-workbench .jbc-row:hover{filter:brightness(.975)}.jbc-workbench .jbc-group{border:1px solid #dce5ea;border-radius:10px;overflow:hidden;background:white;margin:17px 0}
.jbc-workbench .jbc-groupheader{padding:13px 15px;display:flex;justify-content:space-between;background:white}
.jbc-workbench .jbc-dot{width:13px;height:13px;border-radius:50%;display:inline-block;flex:none}.jbc-workbench .jbc-rowtitle{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.jbc-workbench .jbc-loadlink{padding:5px 9px;border-radius:12px;background:#f3f6f8;color:#254f6a;font-weight:700;text-decoration:none}
.jbc-workbench .jbc-overdue{color:#c22b26;font-weight:700}.jbc-workbench .jbc-filterbar{display:flex;gap:7px;flex-wrap:wrap;padding:14px;border:1px solid #dce5ea;background:#fff;border-radius:10px}
.jbc-workbench .jbc-filterbar input{padding:8px;min-width:220px;flex:1;border:1px solid #dce5ea;border-radius:7px}.jbc-workbench .jbc-filterbar select{padding:8px;border:1px solid #dce5ea;border-radius:7px}
.jbc-workbench .jbc-chips{display:flex;gap:8px;flex-wrap:wrap;margin:13px 0}.jbc-workbench .jbc-chips button{border:1px solid #dce5ea;border-radius:20px;background:white;padding:8px 13px}
.jbc-workbench .jbc-chips button.active{background:#0a1721;color:white}.jbc-fab{position:fixed;bottom:24px;right:28px;width:58px;height:58px;border:0;border-radius:50%;background:#07858a;color:#fff;font-size:30px;box-shadow:0 6px 20px #0002;z-index:1000;cursor:pointer}
`;document.head.append(style);}
