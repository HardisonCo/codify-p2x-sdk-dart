import '../client/p2x_client.dart';

/// Client for the **referral** protocol step — sending cases to external
/// agencies / providers.
class ReferralClient {
  /// Construct.
  ReferralClient(this._client);
  final P2xClient _client;

  /// GET `/referral/run/{referral}/{chain}`.
  Future<Map<String, dynamic>> run({
    required int referral,
    required int chain,
  }) =>
      _getMap('/referral/run/$referral/$chain');

  /// GET `/referral/run-global/{referral}/{task}`.
  Future<Map<String, dynamic>> runGlobal({
    required int referral,
    required int task,
  }) =>
      _getMap('/referral/run-global/$referral/$task');

  /// POST `/referral/confirm` — confirm a referral with the chosen
  /// [destination].
  Future<Map<String, dynamic>> confirm({
    required int id,
    required int chainId,
    required String destination,
  }) =>
      _postMap('/referral/confirm', <String, dynamic>{
        'id': id,
        'chain_id': chainId,
        'destination': destination,
      });

  /// GET `/protocol/referral/all`.
  Future<List<dynamic>> listProtocolReferrals() =>
      _getList('/protocol/referral/all');

  /// GET `/referral` — paginated index.
  Future<Map<String, dynamic>> list({int? page, int? perPage}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/referral',
        queryParameters: <String, dynamic>{
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/referral` — create.
  Future<Map<String, dynamic>> create({
    required String title,
    required List<dynamic> referralDestinations,
    required String urgencyLevel,
    bool? trackingEnabled,
    String? description,
  }) =>
      _postMap('/referral', <String, dynamic>{
        'title': title,
        'referral_destinations': referralDestinations,
        'urgency_level': urgencyLevel,
        if (trackingEnabled != null) 'tracking_enabled': trackingEnabled,
        if (description != null) 'description': description,
      });

  /// GET `/referral/{id}`.
  Future<Map<String, dynamic>> show({required int id}) =>
      _getMap('/referral/$id');

  /// PATCH `/referral/{id}`.
  Future<Map<String, dynamic>> update({
    required int id,
    Map<String, dynamic>? patch,
  }) {
    return _client.request(() async {
      final response = await _client.dio.patch<Map<String, dynamic>>(
        '/referral/$id',
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
    if (body == null) throw StateError('Empty referral response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError(
      'Malformed referral response — "data" is ${data.runtimeType}',
    );
  }
}
