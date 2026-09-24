export function normalizePhone(value: unknown): string {
  let phone = String(value ?? "").trim().replace(/[\\s()-]/g, "");

  if (phone.startsWith("00")) {
    phone = "+" + phone.slice(2);
  }

  if (!phone.startsWith("+")) {
    throw new Error("شماره موبایل باید با کد کشور وارد شود");
  }

  const digits = phone.slice(1);

  if (!/^\d{8,15}$/.test(digits)) {
    throw new Error("شماره موبایل بین المللی نامعتبر است");
  }

  return "+" + digits;
}
