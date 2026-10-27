import { supabase } from "./supabaseClient.js";

export async function testSupabaseConnection() {
  console.log("Testing Supabase connection...");

  const { data, error } = await supabase.auth.getSession();

  if (error) {
    console.error("Supabase connection error:", error);
    return;
  }

  console.log("Supabase Auth responded successfully.");
  console.log("Current session:", data.session);
}