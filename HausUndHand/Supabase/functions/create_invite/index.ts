import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type InviteResponse = {
  token: string;
  expires_at: string;
  household_name: string;
  created_by_name?: string | null;
};

type ErrorResponse = {
  error: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

if (!supabaseUrl || !serviceRoleKey) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars");
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" } satisfies ErrorResponse), {
      status: 405,
      headers: { "Content-Type": "application/json" }
    });
  }

  try {
    const supabase = createClient(supabaseUrl!, serviceRoleKey!, {
      auth: { persistSession: false }
    });

    const authHeader = req.headers.get("Authorization");
    const accessToken = authHeader?.replace("Bearer ", "");
    if (!accessToken) {
      return new Response(JSON.stringify({ error: "Unauthorized" } satisfies ErrorResponse), {
        status: 401,
        headers: { "Content-Type": "application/json" }
      });
    }

    const { data: userResult, error: userError } = await supabase.auth.getUser(accessToken);
    if (userError || !userResult?.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" } satisfies ErrorResponse), {
        status: 401,
        headers: { "Content-Type": "application/json" }
      });
    }

    const payload = await req.json();
    const householdId = payload?.household_id as string | undefined;
    if (!householdId) {
      return new Response(JSON.stringify({ error: "household_id missing" } satisfies ErrorResponse), {
        status: 400,
        headers: { "Content-Type": "application/json" }
      });
    }

    const { data: membership, error: membershipError } = await supabase
      .from("household_members")
      .select("role, households(name)")
      .eq("household_id", householdId)
      .eq("user_id", userResult.user.id)
      .maybeSingle();

    if (membershipError || !membership) {
      return new Response(JSON.stringify({ error: "Haushalt nicht gefunden" } satisfies ErrorResponse), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }

    if (!["owner", "admin"].includes(membership.role)) {
      return new Response(JSON.stringify({ error: "Forbidden" } satisfies ErrorResponse), {
        status: 403,
        headers: { "Content-Type": "application/json" }
      });
    }

    const { data: invite, error: inviteError } = await supabase
      .from("invites")
      .insert({
        household_id: householdId,
        created_by: userResult.user.id
      })
      .select("token, expires_at")
      .single();

    if (inviteError || !invite) {
      console.error("Invite error", inviteError);
      return new Response(JSON.stringify({ error: "Invite konnte nicht erstellt werden" } satisfies ErrorResponse), {
        status: 500,
        headers: { "Content-Type": "application/json" }
      });
    }

    const { data: profile } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", userResult.user.id)
      .maybeSingle();

    const response: InviteResponse = {
      token: invite.token,
      expires_at: invite.expires_at,
      household_name: membership.households?.name ?? "",
      created_by_name: profile?.display_name ?? userResult.user.email ?? null
    };

    return new Response(JSON.stringify(response satisfies InviteResponse), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    console.error("Unexpected error", error);
    return new Response(JSON.stringify({ error: "Internal error" } satisfies ErrorResponse), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
});
