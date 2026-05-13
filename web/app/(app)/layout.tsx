import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { DataProvider } from "@/lib/data-context";
import Sidebar from "./sidebar";

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  return (
    <DataProvider userId={user.id}>
      <div className="min-h-screen flex bg-zinc-50 dark:bg-zinc-950">
        <Sidebar email={user.email ?? ""} />
        <main className="flex-1 overflow-auto">{children}</main>
      </div>
    </DataProvider>
  );
}
