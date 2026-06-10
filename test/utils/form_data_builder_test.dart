import 'package:flutter_test/flutter_test.dart';
import 'package:ycaas_flutter_sdk/src/utils/form_data_builder.dart';

void main() {
  test('addList flattens to Laravel-style key[i][nested]', () {
    final fd = FormDataBuilder()
      ..add('title', 'My report')
      ..addList('members', <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Alice', 'email': 'a@x.com'},
        <String, dynamic>{'name': 'Bob', 'email': 'b@x.com'},
      ]);
    final keys = fd.build().fields.map((e) => e.key).toList();
    expect(keys, containsAll(<String>[
      'title',
      'members[0][name]',
      'members[0][email]',
      'members[1][name]',
      'members[1][email]',
    ]));
  });

  test('null values are skipped', () {
    final fd = FormDataBuilder()
      ..add('a', 'present')
      ..add('b', null);
    final keys = fd.build().fields.map((e) => e.key).toSet();
    expect(keys, <String>{'a'});
  });
}
