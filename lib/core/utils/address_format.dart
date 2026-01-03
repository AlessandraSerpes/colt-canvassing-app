String formatZip(String? zip) {
  final z = (zip ?? '').trim();
  if (z.isEmpty) return '';
  // If ZIP+4, keep it
  if (z.contains('-')) return z;
  return z.padLeft(5, '0');
}

/// Replaces the trailing ZIP in an address string (if present) with `houses.zip`.
/// Example:
/// "..., BOSTON, MA 2134" + "02134"  -> "..., BOSTON, MA 02134"
String addressWithZip(String address, String? zip) {
  final z = formatZip(zip);
  if (z.isEmpty) return address;

  // Match: ", MA 2134" or ", MA 02134" at end (or before trailing text)
  final re = RegExp(r'(,\s*[A-Z]{2}\s+)(\d{4,5})(\b.*)$');

  final m = re.firstMatch(address);
  if (m == null) return address;

  final prefix = m.group(1) ?? '';
  final suffix = m.group(3) ?? '';
  return address.replaceFirst(re, '$prefix$z$suffix');
}
