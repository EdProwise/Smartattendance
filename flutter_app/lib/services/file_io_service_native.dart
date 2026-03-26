import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PickedImageResult {
  final String base64;
  final String dataUrl;
  const PickedImageResult({required this.base64, required this.dataUrl});
}

class PickedFileResult {
  final List<int> bytes;
  const PickedFileResult({required this.bytes});
}

/// Native (Android / iOS / Desktop) file I/O.
class FileIoService {
  static final FileIoService instance = FileIoService._();
  FileIoService._();

  Future<PickedImageResult?> pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final b64 = base64Encode(bytes);
    return PickedImageResult(
      base64: b64,
      dataUrl: 'data:image/jpeg;base64,$b64',
    );
  }

  Future<PickedFileResult?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    final bytes = f.bytes ?? await File(f.path!).readAsBytes();
    return PickedFileResult(bytes: bytes);
  }

  /// Saves the Excel file to the app documents directory.
  /// Returns the full saved path on success.
  Future<String?> saveExcelFile(List<int> bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
