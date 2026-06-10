import '../client/p2x_client.dart';

/// Client for the **disbursement** protocol step — moving funds out of a
/// program (grants, reimbursements, payouts).
///
/// Most methods return passthrough `Map<String, dynamic>` since the
/// underlying `DisbursementResource` shape is template-driven.
class DisbursementClient {
  /// Construct.
  DisbursementClient(this._client);
  final P2xClient _client;

  /// GET `/disbursement/run/{disbursement}/{chain}` — start a personal-chain
  /// disbursement step.
  Future<Map<String, dynamic>> run({
    required int disbursement,
    required int chain,
  }) =>
      _getMap('/disbursement/run/$disbursement/$chain');

  /// GET `/disbursement/run-global/{disbursement}/{task}` — start a global
  /// disbursement step bound to a task.
  Future<Map<String, dynamic>> runGlobal({
    required int disbursement,
    required int task,
  }) =>
      _getMap('/disbursement/run-global/$disbursement/$task');

  /// POST `/disbursement/confirm` — confirm a queued disbursement.
  Future<Map<String, dynamic>> confirm({
    required int id,
    required int chainId,
  }) =>
      _postMap('/disbursement/confirm', <String, dynamic>{
        'id': id,
        'chain_id': chainId,
      });

  /// GET `/protocol/disbursement/all`.
  Future<List<dynamic>> listProtocolDisbursements() =>
      _getList('/protocol/disbursement/all');

  /// GET `/disbursement` — paginated index.
  Future<Map<String, dynamic>> list({int? page, int? perPage}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/disbursement',
        queryParameters: <String, dynamic>{
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/disbursement` — create.
  Future<Map<String, dynamic>> create({
    required String title,
    required String disbursementType,
    required num amount,
    required String currency,
    String? description,
  }) =>
      _postMap('/disbursement', <String, dynamic>{
        'title': title,
        'disbursement_type': disbursementType,
        'amount': amount,
        'currency': currency,
        if (description != null) 'description': description,
      });

  /// GET `/disbursement/{id}` — show.
  Future<Map<String, dynamic>> show({required int id}) =>
      _getMap('/disbursement/$id');

  /// PATCH `/disbursement/{id}` (rides POST + `_method=patch`).
  Future<Map<String, dynamic>> update({
    required int id,
    Map<String, dynamic>? patch,
  }) {
    return _client.request(() async {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/disbursement/$id',
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
    if (body == null) throw StateError('Empty disbursement response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError(
      'Malformed disbursement response — "data" is ${data.runtimeType}',
    );
  }
}
