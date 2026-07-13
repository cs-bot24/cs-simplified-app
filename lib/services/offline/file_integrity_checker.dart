import 'dart:io';

import 'package:crypto/crypto.dart';

/// Computes and verifies checksums for downloaded material files.
///
/// The backend does not currently expose a server-side file hash (see
/// `Material` model — no checksum column), so this checker's job is
/// narrower than "verify against server hash": it protects against
/// *local* corruption — an interrupted write, a truncated download, or
/// disk-level bit rot between downloads. The hash computed right after a
/// successful download is stored and re-checked on demand (e.g. before
/// opening a file that looks suspicious, or via a manual "verify" action).
class FileIntegrityChecker {
  /// Streams the file to avoid loading large PDFs entirely into memory.
  Future<String> computeSha256(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }

  /// Returns true if [filePath] exists, is non-empty, and (when
  /// [expectedHash] is provided) matches the stored checksum.
  Future<bool> verify(String filePath, {String? expectedHash}) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    final size = await file.length();
    if (size == 0) return false;
    if (expectedHash == null) return true;
    final actual = await computeSha256(filePath);
    return actual == expectedHash;
  }
}
