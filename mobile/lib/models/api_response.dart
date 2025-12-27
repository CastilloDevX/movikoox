class ApiResponse<T> {
  final bool ok;
  final T? body;

  ApiResponse({
    required this.ok,
    this.body,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic data) fromJsonT,
  ) {
    return ApiResponse(
      ok: json['ok'] ?? false,
      body: json['body'] != null ? fromJsonT(json['body']) : null,
    );
  }
}
