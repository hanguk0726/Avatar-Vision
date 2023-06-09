abstract class Result<T> {
  const Result._();

  factory Result.success(T value) = Success<T>;
  factory Result.error(String message) = Error<T>;
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value) : super._();
}

class Error<T> extends Result<T> {
  final String message;
  const Error(this.message) : super._();
}