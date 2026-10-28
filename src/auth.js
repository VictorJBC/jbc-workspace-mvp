import { supabase } from './supabaseClient.js';

const errorNode = () => document.getElementById('loginError');
const button = () => document.querySelector('#loginScreen button[type="submit"]');
const pending = (value) => { const el=document.getElementById('jbcAuthLoading'); if(el)el.hidden=!value; };
let revision = 0;

async function verifySession(session, currentRevision) {
  if (!session?.user) { if(currentRevision === revision) window.jbcApplyVerifiedSession(null); return; }
  try {
    const uid = session.user.id;
    const [profileResult, rolesResult] = await Promise.all([
      supabase.from('profiles').select('display_name,active').eq('id', uid).single(),
      supabase.from('user_roles').select('role').eq('user_id', uid)
    ]);
    if (currentRevision !== revision) return;
    if (profileResult.error || rolesResult.error) throw new Error('Unable to verify account permissions.');
    const profile = profileResult.data;
    const roles = (rolesResult.data || []).map(x => x.role);
    if (!profile?.active || !roles.some(x => ['support','operations','accounting','admin'].includes(x))) {
      await supabase.auth.signOut();
      if(currentRevision === revision) { window.jbcApplyVerifiedSession(null); errorNode().textContent = 'Your account is not authorized for this workspace.'; }
      return;
    }
    const role = ['admin','accounting','operations','support'].find(x => roles.includes(x));
    window.jbcApplyVerifiedSession({id:uid,email:session.user.email,name:profile.display_name || session.user.email,role});
  } catch (error) {
    if (currentRevision !== revision) return;
    window.jbcApplyVerifiedSession(null);
    errorNode().textContent = error.message || 'Could not verify your account.';
  }
}

window.jbcAuth = {
  async login() {
    const btn = button();
    btn.disabled = true;
    errorNode().textContent = '';
    try {
      const email = document.getElementById('loginEmail').value.trim();
      const password = document.getElementById('loginPassword').value;
      const {data,error} = await supabase.auth.signInWithPassword({email,password});
      if (error) throw error;
      // The auth listener handles the new session.
      if (!data.session) throw new Error('No active session returned.');
    } catch (error) {
      errorNode().textContent = error.message || 'Sign-in failed.';
    } finally { btn.disabled = false; }
  },
  async logout() {
    revision++;
    window.jbcApplyVerifiedSession(null);
    const {error} = await supabase.auth.signOut();
    if(error) errorNode().textContent = 'Sign-out failed. Please refresh and try again.';
  }
};

supabase.auth.onAuthStateChange((event,session) => {
  const currentRevision = ++revision;
  pending(true);
  // Avoid awaiting Supabase API calls directly inside the auth callback.
  Promise.resolve().then(() => verifySession(session,currentRevision));
});
