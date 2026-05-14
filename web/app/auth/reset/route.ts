import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Dedykowana sciezka dla linku z maila "reset password".
// Wymienia code na sesje (recovery) i kieruje na /reset-password.
// Uzywana przez signup-flow w iOS i web (auth.resetPasswordForEmail z redirectTo wskazujacym tutaj).
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}/reset-password`);
    }
  }

  return NextResponse.redirect(`${origin}/forgot-password?error=invalid_link`);
}
