/// Stub file I/O service — all operations are no-ops.
class PickedImageResult {
  final String base64;
  final String dataUrl;
  const PickedImageResult({required this.base64, required this.dataUrl});
}

class PickedFileResult {
  final List<int> bytes;
  const PickedFileResult({required this.bytes});
}

class FileIoService {
  static final FileIoService instance = FileIoService._();
  FileIoService._();

  Future<PickedImageResult?> pickImageFromGallery() async => null;
  Future<PickedFileResult?> pickExcelFile() async => null;
  Future<String?> saveExcelFile(List<int> bytes, String filename) async => null;
}
