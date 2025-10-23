/// Custom exception for server-related errors
class ServerException implements Exception {
  final String code;
  final String message;
  final dynamic data;

  ServerException(this.code, this.message, {this.data});

  @override
  String toString() => 'ServerException: $code - $message';
}

/// Exception thrown when the connection to the server is lost
class ConnectionLostException extends ServerException {
  ConnectionLostException() 
      : super('CONNECTION_LOST', 'Connection to server was lost');
}

/// Exception thrown when authentication fails
class AuthenticationException extends ServerException {
  AuthenticationException(String message) 
      : super('AUTH_ERROR', message);
}

/// Exception thrown when a request times out
class RequestTimeoutException extends ServerException {
  RequestTimeoutException() 
      : super('REQUEST_TIMEOUT', 'The request timed out');
}

/// Exception thrown when a resource is not found
class NotFoundException extends ServerException {
  NotFoundException(String resource) 
      : super('NOT_FOUND', 'The requested $resource was not found');
}

/// Exception thrown when the user doesn't have permission to perform an action
class PermissionDeniedException extends ServerException {
  PermissionDeniedException(String action) 
      : super('PERMISSION_DENIED', 'You do not have permission to $action');
}

/// Exception thrown when a request is invalid
class InvalidRequestException extends ServerException {
  InvalidRequestException(String field, [String? details]) 
      : super('INVALID_REQUEST', 'Invalid request: $field', data: details);
}

/// Exception thrown when the server is unavailable
class ServerUnavailableException extends ServerException {
  ServerUnavailableException() 
      : super('SERVER_UNAVAILABLE', 'The server is currently unavailable');
}

/// Exception thrown when a file operation fails
class FileTransferException extends ServerException {
  FileTransferException(String message) 
      : super('FILE_TRANSFER_ERROR', message);
}

/// Exception thrown when a call-related operation fails
class CallException extends ServerException {
  CallException(String message) 
      : super('CALL_ERROR', message);
}

/// Helper method to create an appropriate exception from an error response
ServerException createServerException(dynamic error) {
  if (error is ServerException) return error;
  
  if (error is Map<String, dynamic>) {
    return ServerException(
      error['code']?.toString() ?? 'UNKNOWN_ERROR',
      error['message']?.toString() ?? 'An unknown error occurred',
      data: error['data'],
    );
  }
  
  return ServerException('UNKNOWN_ERROR', error?.toString() ?? 'An unknown error occurred');
}
