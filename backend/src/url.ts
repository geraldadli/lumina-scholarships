/**
 * Validasi tautan sumber beasiswa. Awalan "https://" saja tidak cukup: harus ada hostname sungguhan.
 *
 * Ditolak: "https://", "https:///path", "https://?q=1", "https://:8080", host kosong,
 * dan label kosong (".com", "a..b", "example."). Diterima: hostname biasa, IPv4/IPv6, port, path, query.
 */
export function isHttpsUrlWithHost(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  // Karakter pertama setelah "://" harus bagian dari host (bukan "/", "?", "#", atau spasi).
  if (!/^https:\/\/[^/?#\s]/.test(value)) return false;

  let host: string;
  try {
    host = new URL(value).hostname;
  } catch {
    return false;
  }
  if (host.startsWith('[') && host.endsWith(']')) return true; // literal IPv6
  return host.length > 0 && host.split('.').every((label) => label.length > 0);
}
