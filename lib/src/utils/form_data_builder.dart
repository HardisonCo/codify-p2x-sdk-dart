import 'package:dio/dio.dart';

/// Helper for constructing Dio [FormData] with **nested-array** field names
/// matching the Laravel convention — `field[i][nested]=value`.
///
/// The P2X API accepts multipart bodies in two flavours:
/// 1. Flat scalars: `title=…&amount=…`.
/// 2. Nested arrays: `members[0][name]=…&members[0][email]=…&members[1]…`.
///
/// Use [FormDataBuilder] to build the latter without manually flattening:
///
/// ```dart
/// final fd = FormDataBuilder()
///   ..add('title', 'My report')
///   ..addList(
///     'members',
///     <Map<String, dynamic>>[
///       <String, dynamic>{'name': 'Alice', 'email': 'a@x.com'},
///       <String, dynamic>{'name': 'Bob', 'email': 'b@x.com'},
///     ],
///   )
///   ..addFile('attachment', '/tmp/x.pdf');
///
/// await dio.post('/something', data: fd.build());
/// ```
class FormDataBuilder {
  final List<MapEntry<String, dynamic>> _entries = <MapEntry<String, dynamic>>[];

  /// Append a scalar [key]=[value] pair. `null` values are skipped.
  void add(String key, Object? value) {
    if (value == null) return;
    _entries.add(MapEntry<String, dynamic>(key, value));
  }

  /// Append a list of maps using Laravel `key[i][nested]` notation.
  void addList(String key, List<Map<String, dynamic>> items) {
    for (var i = 0; i < items.length; i++) {
      items[i].forEach((String k, Object? v) {
        if (v == null) return;
        _entries.add(MapEntry<String, dynamic>('$key[$i][$k]', v));
      });
    }
  }

  /// Append a file from a local path (uses [MultipartFile.fromFile]).
  Future<void> addFile(String key, String path, {String? filename}) async {
    final file = await MultipartFile.fromFile(path, filename: filename);
    _entries.add(MapEntry<String, dynamic>(key, file));
  }

  /// Append a file from in-memory bytes.
  void addFileBytes(
    String key,
    List<int> bytes, {
    required String filename,
  }) {
    _entries.add(
      MapEntry<String, dynamic>(
        key,
        MultipartFile.fromBytes(bytes, filename: filename),
      ),
    );
  }

  /// Build the [FormData] suitable for `dio.post(..., data: ...)`.
  FormData build() => FormData.fromMap(
        <String, dynamic>{
          for (final MapEntry<String, dynamic> e in _entries) e.key: e.value,
        },
      );
}
