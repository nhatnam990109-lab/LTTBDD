import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

export 'export_documents.dart';

void exportHtml(String filename, String mime, String html) {
  FilePicker.saveFile(
    dialogTitle: 'Lưu tệp',
    fileName: filename,
    mimeType: mime,
    bytes: Uint8List.fromList(utf8.encode(html)),
  );
}

void printHtml(String html) {
  FilePicker.saveFile(
    dialogTitle: 'Lưu bản in HTML',
    fileName: 'ho-so.html',
    mimeType: 'text/html',
    bytes: Uint8List.fromList(utf8.encode(html)),
  );
}
