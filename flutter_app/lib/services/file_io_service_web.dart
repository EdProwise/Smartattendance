import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class PickedImageResult {
  final String base64;
  final String dataUrl;
  const PickedImageResult({required this.base64, required this.dataUrl});
}

class PickedFileResult {
  final List<int> bytes;
  const PickedFileResult({required this.bytes});
}

/// Web file I/O — uses dart:html for file picking and blob-URL downloads.
class FileIoService {
  static final FileIoService instance = FileIoService._();
  FileIoService._();

  Future<PickedImageResult?> pickImageFromGallery() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..style.display = 'none';
    html.document.body!.append(input);

    try {
      final completer = Completer<html.File?>();
      input.onChange.listen((event) {
        final file =
            input.files?.isNotEmpty == true ? input.files!.first : null;
        if (!completer.isCompleted) completer.complete(file);
      });
      input.click();

      final file =
          await completer.future.timeout(const Duration(minutes: 5));
      if (file == null) return null;

      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      await reader.onLoad.first;

      final dataUrl = reader.result as String;
      final commaIndex = dataUrl.indexOf(',');
      if (commaIndex == -1) return null;
      return PickedImageResult(
        base64: dataUrl.substring(commaIndex + 1),
        dataUrl: dataUrl,
      );
    } on TimeoutException {
      return null;
    } finally {
      input.remove();
    }
  }

  Future<PickedFileResult?> pickExcelFile() async {
    final input = html.FileUploadInputElement()..accept = '.xlsx,.xls';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return null;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final bytes = Uint8List.view(reader.result as ByteBuffer);
    return PickedFileResult(bytes: bytes);
  }

  /// Downloads a file through the browser. Returns the filename on success.
  Future<String?> saveExcelFile(List<int> bytes, String filename) async {
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    return filename;
  }
}
