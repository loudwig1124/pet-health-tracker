/// SQLite vaccine catalog repository.
library;

import 'package:sqflite/sqflite.dart';

import '../../domain/models/vaccine_type.dart';
import '../repositories/vaccine_type_repository.dart';
import 'mappers.dart';

class SqliteVaccineTypeRepository implements VaccineTypeRepository {
  const SqliteVaccineTypeRepository(this._db);

  final Database _db;

  static const String _table = 'vaccine_type';

  @override
  Future<List<VaccineType>> list() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'is_core DESC, sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(vaccineTypeFromRow).toList(growable: false);
  }
}
