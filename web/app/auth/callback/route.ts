import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Obsługa potwierdzenia e-mail i magic-link.
// Supabase wysyła użytkownika do tego URL z ?code=<...>; my wymieniamy go na sesję.
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=auth_callback_failed`);
}
