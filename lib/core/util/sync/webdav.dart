import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:gpt_box/data/res/misc.dart';
import 'package:logging/logging.dart';
import 'package:webdav_client/webdav_client.dart';

import '../../../data/model/app/backup.dart';
import '../../../data/model/app/error.dart';
import '../../../data/store/all.dart';

abstract final class Webdav {
  /// Some WebDAV provider only support non-root path
  static const _prefix = 'gptbox/';

  static var _client = WebdavClient(
    url: Stores.setting.webdavUrl.fetch(),
    user: Stores.setting.webdavUser.fetch(),
    pwd: Stores.setting.webdavPwd.fetch(),
  );

  static final _logger = Logger('Webdav');

  static Future<String?> test(String url, String user, String pwd) async {
    final client = WebdavClient(url: url, user: user, pwd: pwd);
    try {
      await client.ping();
      return null;
    } catch (e, s) {
      _logger.warning('Test failed', e, s);
      return e.toString();
    }
  }

  static Future<WebdavErr?> upload({
    required String relativePath,
    String? localPath,
  }) async {
    try {
      await _client.writeFile(
        localPath ?? Paths.doc.joinPath(relativePath),
        _prefix + relativePath,
      );
    } catch (e, s) {
      _logger.warning('Upload $relativePath failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> delete(String relativePath) async {
    try {
      await _client.remove(_prefix + relativePath);
    } catch (e, s) {
      _logger.warning('Delete $relativePath failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<WebdavErr?> download({
    required String relativePath,
    String? localPath,
  }) async {
    try {
      await _client.readFile(
        _prefix + relativePath,
        localPath ?? Paths.doc.joinPath(relativePath),
      );
    } catch (e, s) {
      _logger.warning('Download $relativePath failed', e, s);
      return WebdavErr(type: WebdavErrType.generic, message: '$e');
    }
    return null;
  }

  static Future<List<String>> list() async {
    try {
      final list = await _client.readDir(_prefix);
      final names = <String>[];
      for (final item in list) {
        if ((item.isDir ?? true) || item.name == null) continue;
        names.add(item.name!);
      }
      return names;
    } catch (e, s) {
      _logger.warning('List failed', e, s);
    }
    return [];
  }

  static void changeClient(String url, String user, String pwd) {
    _client = WebdavClient(url: url, user: user, pwd: pwd);
    Stores.setting.webdavUrl.put(url);
    Stores.setting.webdavUser.put(user);
    Stores.setting.webdavPwd.put(pwd);
  }

  static Future<void> sync() async {
    final dlErr = await download(relativePath: Miscs.bakFileName);
    if (dlErr != null) return await backup();

    final dlFile = await File(Paths.bak).readAsString();
    final dlBak = await compute(Backup.fromJsonString, dlFile);
    if (dlBak == null) return await backup();

    await dlBak.merge();
    await Future.delayed(const Duration(milliseconds: 37));
    await backup();
  }

  /// Create a local backup and upload it to WebDAV
  static Future<void> backup() async {
    await Backup.backupToFile();
    final err = await upload(relativePath: Miscs.bakFileName);
    if (err != null) {
      _logger.warning('Upload failed: $err');
    }
  }
}
