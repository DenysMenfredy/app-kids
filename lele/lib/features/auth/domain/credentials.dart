// Client-side checks on what the parent typed.
//
// These catch typos before a round trip and keep the error next to the field
// that caused it. They are a convenience, never a guarantee: the server
// decides what is actually acceptable (spec §22 constraint 1). Messages are
// pt-BR, aimed at a parent rather than a developer.

/// Firebase rejects anything shorter, so the rule is the backend's, not ours.
const minimumPasswordLength = 6;

String? validateEmail(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Informe seu e-mail.';
  // Deliberately loose: the goal is catching a slip, not policing RFC 5322.
  final looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!looksLikeEmail) return 'Esse e-mail não parece certo.';
  return null;
}

String? validatePassword(String value) {
  if (value.isEmpty) return 'Informe sua senha.';
  if (value.length < minimumPasswordLength) {
    return 'A senha precisa de pelo menos $minimumPasswordLength caracteres.';
  }
  return null;
}

String? validateName(String value) {
  final name = value.trim();
  if (name.isEmpty) return 'Informe seu nome.';
  if (name.length < 2) return 'Nome muito curto.';
  return null;
}
