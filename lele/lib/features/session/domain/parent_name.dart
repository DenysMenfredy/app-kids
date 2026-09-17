/// The part of a parent's name the app greets them by.
///
/// Registration deliberately takes and keeps the whole name: it is what the
/// backend stores as `users/{uid}.displayName` and what anything official —
/// a receipt, a support thread — has to carry. A greeting is a different
/// thing. "Olá, Denys Menfredy" wrapped onto two lines on a phone and grew
/// the dashboard header to match, so the greeting uses the first name and
/// the record keeps the rest.
///
/// Splits on whitespace only, so a hyphenated or accented first name
/// ("Ana-Paula", "Thaís") survives intact. Returns an empty string when the
/// name is not known yet, which the caller shows as a plain "Olá!".
String firstNameOf(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}
