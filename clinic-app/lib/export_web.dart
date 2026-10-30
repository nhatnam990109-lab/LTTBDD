import 'dart:js_interop';

import 'package:web/web.dart' as web;

export 'export_documents.dart';

void exportHtml(String filename, String mime, String html) {
  final anchor = web.HTMLAnchorElement()
    ..href = 'data:$mime;charset=utf-8,${Uri.encodeComponent(html)}'
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}

void printHtml(String html) {
  final opened = web.window.open('', '_blank');
  if (opened == null) return;
  opened.document.open();
  opened.document.write(html.toJS);
  opened.document.close();
}
