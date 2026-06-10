import '../client/p2x_client.dart';

/// Client for the **challenge** protocol step — adaptive task challenges
/// (video / text prompts, dynamic task generation).
class ChallengeClient {
  /// Construct.
  ChallengeClient(this._client);
  final P2xClient _client;

  /// POST `/challenge/set-result/{result}` — submit a task result, possibly
  /// with an attached image.
  Future<Map<String, dynamic>> setResult({
    required int result,
    required bool taskFinished,
    Map<String, dynamic>? taskResult,
  }) =>
      _postMap('/challenge/set-result/$result', <String, dynamic>{
        'task_finished': taskFinished,
        if (taskResult != null) 'task_result': taskResult,
      });

  /// POST `/challenge/start-task` — begin a task within an attached
  /// challenge.
  Future<Map<String, dynamic>> startTask({
    required int attachedChallengeId,
    required int challengeTaskId,
  }) =>
      _postMap('/challenge/start-task', <String, dynamic>{
        'attached_challenge_id': attachedChallengeId,
        'challenge_task_id': challengeTaskId,
      });

  /// GET `/challenge/get-challenge/{challenge}/{chain}`.
  Future<Map<String, dynamic>> getChallenge({
    required int challenge,
    required int chain,
  }) =>
      _getMap('/challenge/get-challenge/$challenge/$chain');

  /// GET `/challenge/get-global-challenge/{challenge}/{task}`.
  Future<Map<String, dynamic>> getGlobalChallenge({
    required int challenge,
    required int task,
  }) =>
      _getMap('/challenge/get-global-challenge/$challenge/$task');

  /// GET `/challenge/get-challenge-tasks/{challenge}/{chain}`.
  Future<List<dynamic>> getChallengeTasks({
    required int challenge,
    required int chain,
  }) =>
      _getList('/challenge/get-challenge-tasks/$challenge/$chain');

  /// GET `/challenge/get-challenge-global-tasks/{challenge}/{task}`.
  Future<List<dynamic>> getChallengeGlobalTasks({
    required int challenge,
    required int task,
  }) =>
      _getList('/challenge/get-challenge-global-tasks/$challenge/$task');

  /// POST `/challenge/run` — bind a challenge to a personal chain.
  Future<Map<String, dynamic>> run({
    required int personalChainId,
    required int challengeId,
  }) =>
      _postMap('/challenge/run', <String, dynamic>{
        'personal_chain_id': personalChainId,
        'challenge_id': challengeId,
      });

  /// POST `/challenge/run-global` — bind a challenge to a global module
  /// task.
  Future<Map<String, dynamic>> runGlobal({
    required Map<String, dynamic> body,
  }) =>
      _postMap('/challenge/run-global', body);

  /// GET `/challenge/finish/{attached}` — mark an attached challenge done.
  Future<Map<String, dynamic>> finish({required int attached}) =>
      _getMap('/challenge/finish/$attached');

  /// GET `/challenge/get-types` — `[{id, name}, …]`.
  Future<List<dynamic>> getTypes() => _getList('/challenge/get-types');

  /// DELETE `/challenge/task/destroy/{task}`.
  Future<Map<String, dynamic>> destroyTask({required int task}) {
    return _client.request(() async {
      final response = await _client.dio.delete<Map<String, dynamic>>(
        '/challenge/task/destroy/$task',
      );
      return _data(response.data);
    });
  }

  /// GET `/challenge` — paginated index.
  Future<Map<String, dynamic>> list({int? page, int? perPage}) {
    return _client.request(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/challenge',
        queryParameters: <String, dynamic>{
          if (page != null) 'page': page,
          if (perPage != null) 'per_page': perPage,
        },
      );
      return Map<String, dynamic>.from(response.data ?? <String, dynamic>{});
    });
  }

  /// POST `/challenge` — create.
  Future<Map<String, dynamic>> create({
    required String title,
    required String challengeType,
    required bool taskMandatory,
    required bool timeLimited,
    required List<Map<String, dynamic>> tasks,
  }) =>
      _postMap('/challenge', <String, dynamic>{
        'title': title,
        'challenge_type': challengeType,
        'task_mandatory': taskMandatory,
        'time_limited': timeLimited,
        'tasks': tasks,
      });

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
    if (body == null) throw StateError('Empty challenge response');
    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data == null) return const <String, dynamic>{};
    throw StateError(
      'Malformed challenge response — "data" is ${data.runtimeType}',
    );
  }
}
