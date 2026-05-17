import 'api_exception.dart';

/// HTTP 422 — Laravel validation failure.
///
/// Carries the field-keyed map of validation messages, the same shape
/// Laravel emits: `{ "email": ["...", "..."], "phone": ["..."] }`. Surface
/// these to the user via per-field error UI rather than a top-level toast.
class ValidationException extends ApiException {
  /// Construct.
  ValidationException({
    required super.message,
    required this.errors,
    super.data,
    super.originalError,
  }) : super(status: 422);

  /// Field-keyed validation messages, in the order Laravel returned them.
  final Map<String, List<String>> errors;

  @override
  String toString() {
    if (errors.isEmpty) {
      return 'ValidationException(422): $message';
    }
    final fieldList =
        errors.entries.map((e) => '${e.key}: ${e.value.join(", ")}').join('; ');
    return 'ValidationException(422): $message — $fieldList';
  }
}
