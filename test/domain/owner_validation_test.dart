import 'package:flutter_test/flutter_test.dart';
import 'package:pet_health_tracker/domain/models/owner.dart';
import 'package:pet_health_tracker/domain/rules/owner_validation.dart';

void main() {
  OwnerDraft draft({String name = 'Maria Santos', String email = '', String phone = ''}) =>
      OwnerDraft(name: name, email: email, phone: phone);

  test('a normal household passes', () {
    expect(validateOwnerDraft(draft()).isValid, isTrue);
    expect(
      validateOwnerDraft(
        draft(email: 'maria@example.com', phone: '+63 917 555 0142'),
      ).isValid,
      isTrue,
    );
  });

  test('digits alone are not a name', () {
    expect(validateOwnerDraft(draft(name: '12345'))[OwnerField.name], isNotNull);
    expect(validateOwnerDraft(draft(name: '...'))[OwnerField.name], isNotNull);
    expect(validateOwnerDraft(draft(name: ''))[OwnerField.name], isNotNull);
    expect(validateOwnerDraft(draft(name: 'Maria 2'))[OwnerField.name], isNull);
  });

  test('a name longer than 60 characters is rejected', () {
    expect(validateOwnerDraft(draft(name: 'M' * 61))[OwnerField.name], isNotNull);
  });

  test('email needs a shape when present', () {
    expect(validateOwnerDraft(draft(email: 'maria'))[OwnerField.email], isNotNull);
    expect(
      validateOwnerDraft(draft(email: 'maria@example'))[OwnerField.email],
      isNotNull,
    );
    expect(
      validateOwnerDraft(draft(email: 'maria@example.com'))[OwnerField.email],
      isNull,
    );
  });

  test('phone is digits and separators, 7 to 15 digits', () {
    expect(validateOwnerDraft(draft(phone: 'abc'))[OwnerField.phone], isNotNull);
    expect(validateOwnerDraft(draft(phone: '12345'))[OwnerField.phone], isNotNull);
    expect(
      validateOwnerDraft(draft(phone: '+63 917 555 0142'))[OwnerField.phone],
      isNull,
    );
  });
}
