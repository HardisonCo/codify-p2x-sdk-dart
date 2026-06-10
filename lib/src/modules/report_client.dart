import '../client/p2x_client.dart';

/// Client for the **report** protocol step — data submission for automated
/// report generation.
class ReportClient {
  /// Construct.
  ReportClient(this._client);
  final P2xClient _client;

  /// GET `/report/run/{report}/{chain}`.
  Future<Map<String, dynamic>> run({
    required int report,
    required int chain,
  }) =>
      _getMap('/report/run/$report/$chain');

  /// GET `/report/run-global/{report}/{task}`.
  Future<Map<String, dynamic>> runGlobal({
    required int report,
    required int task,
  }) =>
      _getMap('/report/run-global/$report/$task');

  /// POST `/report/submit` — submit the populated [fields] for a report.
  Future<Map<String, dynamic>> submit({
    required int id,
    required int chainId,
    required Map<String, dynamic> fields,
  }) =>
      _postMap('/report/submit', <String, dynamic>{
        'id': id,
        'chain_id': chainId,
        'fields': fields,
      });

  /// GET `/protocol/report/all`.
  Future<List<dynamic>> listProtocolReports() =>
      _getList('/protocol/report/all');

  /// GET `/report` — paginated index.
  Future<Map<String, dynamic>> list({int? page, int? perPage}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/report',
        queryParameters: <String, dynamic>{
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/report` — create.
  Future<Map<String, dynamic>> create({
    required String title,
    required String reportType,
    required List<dynamic> templateFields,
    required String reportingFrequency,
    String? description,
  }) =>
      _postMap('/report', <String, dynamic>{
        'title': title,
        'report_type': reportType,
        'template_fields': templateFields,
        'reporting_frequency': reportingFrequency,
        if (description != null) 'description': description,
      });

  /// GET `/report/{id}`.
  Future<Map<String, dynamic>> show({required int id}) =>
      _getMap('/report/$id');

  /// PATCH `/report/{id}`.
  Future<Map<String, dynamic>> update({
    required int id,
    Map<String, dynamic>? patch,
  }) {
    return _client.request(() async {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/report/$id',
        data: patch ?? const <String, dynamic>{},
      );
      return _data(response.data);
    });
  }

  Future<Map<String, dynamic>> _getMap(String path) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      return _data(response.data);
    });
  }

  Future<List<dynamic>> _getList(String path) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      return data is List ? List<dynamic>.from(data) : const <dynamic>[];
    });
  }

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic>? body,
  ) {
    return _client.request(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        path,
        data: body,
      );
      return _data(response.data);
    });
  }

  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    if (body == null) throw StateError('Empty report response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError(
      'Malformed report response — "data" is ${data.runtimeType}',
    );
  }
}
