/// The household profile. One row, no accounts, no auth.
library;

/// An editable owner profile value object (what a profile form submits).
class OwnerDraft {
  const OwnerDraft({required this.name, this.email = '', this.phone = ''});

  final String name;
  final String email;
  final String phone;
}

/// The persisted household owner.
class Owner {
  const Owner({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// First letter of the name for the circular avatar ("?" when unnamed).
  String get initial {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  OwnerDraft toDraft() => OwnerDraft(name: name, email: email, phone: phone);

  Owner copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Owner(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
