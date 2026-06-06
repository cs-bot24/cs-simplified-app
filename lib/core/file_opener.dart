import 'dart:io';
import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Opens a material file based on its type.
///
/// PDF → existing PdfViewerScreen (caller handles this)
/// PPT/PPTX/DOC/DOCX → download to temp dir, then open with device app
class FileOpener {
  static Future<void> openExternal({
    required BuildContext context,
    required String url,
    required String title,
    required String fileType,
  }) async {
    // Show loading dialog
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(),
    );

    try {
      // Download to temp directory
      final tempDir  = await getTemporaryDirectory();
      final fileName = '${title.replaceAll(RegExp(r'[^\w\s]'), '_')}.$fileType';
      final filePath = '${tempDir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          dev.log('[FileOpener] $received / $total bytes');
        },
      );

      // Dismiss loading dialog
      if (context.mounted) Navigator.of(context).pop();

      // Open with device app
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && context.mounted) {
        _showError(context, fileType);
      }
    } catch (e) {
      dev.log('[FileOpener] Error: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        _showError(context, fileType, error: e.toString());
      }
    }
  }

  static void _showError(BuildContext context, String fileType, {String? error}) {
    final isPpt = fileType == 'ppt' || fileType == 'pptx';
    final msg   = isPpt
        ? 'No PowerPoint-compatible application found on this device.\n'
          'Please install Microsoft PowerPoint, WPS Office, or Google Slides.'
        : 'No document viewer found on this device.\n'
          'Please install Microsoft Word, WPS Office, or Google Docs.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cannot Open File'),
        content: Text(error != null ? '$msg\n\n($error)' : msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();
  @override
  Widget build(BuildContext context) => const AlertDialog(
    content: Row(children: [
      CircularProgressIndicator(),
      SizedBox(width: 20),
      Expanded(child: Text('Preparing file...')),
    ]),
  );
}
