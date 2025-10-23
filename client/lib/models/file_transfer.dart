import 'dart:typed_data';

class FileTransfer {
  final String fileId;
  final int? chunkIndex;
  final int? totalChunks;
  final Uint8List? data;
  final int? progress;
  final String? fileName;
  final int? fileSize;
  final bool isComplete;
  final bool isError;
  final String? error;

  FileTransfer._({
    required this.fileId,
    this.chunkIndex,
    this.totalChunks,
    this.data,
    this.progress,
    this.fileName,
    this.fileSize,
    this.isComplete = false,
    this.isError = false,
    this.error,
  });

  // Factory constructors for different states
  factory FileTransfer.chunk({
    required String fileId,
    required int chunkIndex,
    required int totalChunks,
    required Uint8List data,
  }) =>
      FileTransfer._(
        fileId: fileId,
        chunkIndex: chunkIndex,
        totalChunks: totalChunks,
        data: data,
      );

  factory FileTransfer.progress({
    required String fileId,
    required int progress,
  }) =>
      FileTransfer._(
        fileId: fileId,
        progress: progress,
      );

  factory FileTransfer.complete({
    required String fileId,
    required String fileName,
    required int fileSize,
  }) =>
      FileTransfer._(
        fileId: fileId,
        fileName: fileName,
        fileSize: fileSize,
        isComplete: true,
      );

  factory FileTransfer.error({
    required String fileId,
    required String error,
  }) =>
      FileTransfer._(
        fileId: fileId,
        isError: true,
        error: error,
      );

  // Getters
  bool get isInProgress => progress != null && progress! < 100 && !isComplete && !isError;
  
  // Helper methods
  FileTransfer copyWith({
    String? fileId,
    int? chunkIndex,
    int? totalChunks,
    Uint8List? data,
    int? progress,
    String? fileName,
    int? fileSize,
    bool? isComplete,
    bool? isError,
    String? error,
  }) {
    return FileTransfer._(
      fileId: fileId ?? this.fileId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      data: data ?? this.data,
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isComplete: isComplete ?? this.isComplete,
      isError: isError ?? this.isError,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'FileTransfer{\n'
           '  fileId: $fileId,\n'
           '  chunkIndex: $chunkIndex,\n'
           '  totalChunks: $totalChunks,\n'
           '  data: ${data?.length} bytes,\n'
           '  progress: $progress%\n'
           '  fileName: $fileName,\n'
           '  fileSize: $fileSize bytes\n'
           '  isComplete: $isComplete,\n'
           '  isError: $isError,\n'
           '  error: $error\n'
           '}';
  }
}
