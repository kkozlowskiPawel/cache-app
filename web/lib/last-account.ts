// Prosta pamiec ostatnio uzywanego konta w przegladarce.
const KEY = "cache.lastAccountId";

export function getLastAccountId(): string | null {
  if (typeof window === "undefined") return null;
  return window.localStorage.getItem(KEY);
}

export function setLastAccountId(id: string | null) {
  if (typeof window === "undefined") return;
  if (id) window.localStorage.setItem(KEY, id);
  else window.localStorage.removeItem(KEY);
}
