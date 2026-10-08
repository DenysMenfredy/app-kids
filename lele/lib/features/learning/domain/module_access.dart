/// Presentation-only mirror of D02; the backend and Firestore Rules remain
/// authoritative and enforce the same first-module-free policy.
bool canOpenModule({
  required int moduleNumber,
  required bool premium,
  required bool firebaseEnabled,
}) => !firebaseEnabled || moduleNumber == 1 || premium;
