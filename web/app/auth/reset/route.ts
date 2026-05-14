import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import type { EmailOtpType } from "@supabase/supabase-js";

// Dedykowany handler dla linku z maila "reset password".
// Obsluguje dwa warianty:
//   1) token_hash + type  (zalecany template Supabase, dziala cross-device, bez PKCE)
//   2) code               (fallback PKCE, dziala gdy reset wyslano z tego samego browsera)
// W razie sukcesu kieruje na /reset-password (uzytkownik ma sesje recovery i moze zmienic haslo).
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const token_hash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const code = searchParams.get("code");

  const supabase = await createClient();

  if (token_hash && type) {
    const { error } = await supabase.auth.verifyOtp({ token_hash, type });
    if (!error) return NextResponse.redirect(`${origin}/reset-password`);
  } else if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(`${origin}/reset-password`);
  }

  return NextResponse.redirect(`${origin}/forgot-password?error=invalid_link`);
}
