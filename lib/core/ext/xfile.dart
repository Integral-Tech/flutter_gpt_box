import 'dart:convert';

import 'package:cross_file/cross_file.dart';

extension XFileX on XFile? {
  Future<String?> get base64 async {
    final format = this?.path.split('.').lastOrNull;
    if (format == null) return null;
    final bytes = await this?.readAsBytes();
    if (bytes == null) return null;
    return 'data:image/$format;base64,${base64Encode(bytes)}';
  }
}
