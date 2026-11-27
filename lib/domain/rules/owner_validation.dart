/// Household owner validation, shared by the Welcome card and Profile → Edit.
///
/// Pure: the forms pass what they have, this returns the per-field errors so
/// each message can sit under the right input.
library;

import '../models/owner.dart';

/// A field the owner form can show an error under.
enum OwnerField {
  name('Name'),
  email('Email'),
  phone('Phone');

  const OwnerField(this.label);

  final String label;
}

class OwnerValidationResult {
  const OwnerValidationResult(this.errors);

  final Map<OwnerField, String> errors;

  bool get isValid => errors.isEmpty;

  String? operator [](OwnerField field) => errors[field];
}

/// One Unicode letter somewhere in the text. Rejects names made only of digits
/// or punctuation ("12345", "...").
final RegExp _hasLetter = RegExp(r'\p{L}', unicode: true);

/// Digits, optional `+`, then spaces, dashes, dots and brackets.
final RegExp _phoneShape = RegExp(r'^\+?[0-9 ().-]+$');

final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$');

/// Validates the household details. Email and phone are optional; a name is not.
OwnerValidationResult validateOwnerDraft(OwnerDraft draft) {
  final Map<OwnerField, String> errors = <OwnerField, String>{};

  final String name = draft.name.trim();
  if (name.isEmpty) {
    errors[OwnerField.name] = 'Add your name';
  } else if (!_hasLetter.hasMatch(name)) {
    errors[OwnerField.name] = 'A name needs at least one letter';
  } else if (name.length > 60) {
    errors[OwnerField.name] = 'Keep the name under 60 characters';
  }

  final String email = draft.email.trim();
  if (email.isNotEmpty && !_emailShape.hasMatch(email)) {
    errors[OwnerField.email] = 'Check the email — it needs an @ and a domain';
  }

  final String phone = draft.phone.trim();
  if (phone.isNotEmpty) {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!_phoneShape.hasMatch(phone)) {
      errors[OwnerField.phone] = 'Use digits, spaces, dashes or brackets';
    } else if (digits.length < 7 || digits.length > 15) {
      errors[OwnerField.phone] = 'A phone number has 7 to 15 digits';
    }
  }

  return OwnerValidationResult(errors);
}
