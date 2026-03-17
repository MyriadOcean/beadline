import 'package:flutter/material.dart';

import '../../i18n/translations.g.dart';
import '../../models/source.dart';

/// Action chosen by the user when removing a video DisplaySource
/// that has a linked extracted AudioSource.
enum VideoRemovalAction {
  /// Remove both the video DisplaySource and the linked AudioSource.
  removeBoth,

  /// Remove only the video DisplaySource; keep the AudioSource as standalone
  /// (set its linkedVideoSourceId to null).
  keepAudio,

  /// Cancel the removal entirely.
  cancel,
}

/// Shows a dialog prompting the user about what to do with a linked
/// AudioSource when its originating video DisplaySource is being removed.
///
/// Returns the user's chosen [VideoRemovalAction].
/// If the dialog is dismissed (e.g. tapping outside), returns [VideoRemovalAction.cancel].
Future<VideoRemovalAction> showVideoRemovalPrompt(
  BuildContext context, {
  required DisplaySource videoSource,
  required AudioSource linkedAudio,
}) async {
  final videoName = videoSource.displayName ?? videoSource.id;
  final audioName = linkedAudio.displayName ?? linkedAudio.id;

  final result = await showDialog<VideoRemovalAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.t.videoRemoval.title),
      content: Text(
        context.t.videoRemoval.message.replaceAll('{videoName}', videoName).replaceAll('{audioName}', audioName),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(VideoRemovalAction.cancel),
          child: Text(context.t.videoRemoval.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(VideoRemovalAction.keepAudio),
          child: Text(context.t.videoRemoval.keepAudio),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(VideoRemovalAction.removeBoth),
          child: Text(context.t.videoRemoval.removeBoth),
        ),
      ],
    ),
  );

  return result ?? VideoRemovalAction.cancel;
}
