import 'package:beadline/models/source.dart';
import 'package:beadline/models/source_origin.dart';
import 'package:beadline/views/widgets/video_removal_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const videoSource = DisplaySource(
    id: 'video-1',
    origin: LocalFileOrigin('/path/to/video.mp4'),
    priority: 0,
    displayName: 'My Video',
    displayType: DisplayType.video,
  );

  const linkedAudio = AudioSource(
    id: 'audio-1',
    origin: LocalFileOrigin('/path/to/video.mp4'),
    priority: 0,
    displayName: 'Audio from My Video',
    format: AudioFormat.other,
    linkedVideoSourceId: 'video-1',
  );

  Widget buildTestApp({required Future<void> Function(BuildContext) onTap}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => onTap(context),
            child: const Text('Show Dialog'),
          ),
        ),
      ),
    );
  }

  group('showVideoRemovalPrompt', () {
    testWidgets('displays video and audio names in dialog', (tester) async {
      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) => showVideoRemovalPrompt(
          ctx,
          videoSource: videoSource,
          linkedAudio: linkedAudio,
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Video Source'), findsOneWidget);
      expect(find.textContaining('My Video'), findsOneWidget);
      expect(find.textContaining('Audio from My Video'), findsOneWidget);
    });

    testWidgets('returns removeBoth when "Remove Both" is tapped',
        (tester) async {
      VideoRemovalAction? result;

      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) async {
          result = await showVideoRemovalPrompt(
            ctx,
            videoSource: videoSource,
            linkedAudio: linkedAudio,
          );
        },
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove Both'));
      await tester.pumpAndSettle();

      expect(result, VideoRemovalAction.removeBoth);
    });

    testWidgets('returns keepAudio when "Keep Audio" is tapped',
        (tester) async {
      VideoRemovalAction? result;

      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) async {
          result = await showVideoRemovalPrompt(
            ctx,
            videoSource: videoSource,
            linkedAudio: linkedAudio,
          );
        },
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Audio'));
      await tester.pumpAndSettle();

      expect(result, VideoRemovalAction.keepAudio);
    });

    testWidgets('returns cancel when "Cancel" is tapped', (tester) async {
      VideoRemovalAction? result;

      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) async {
          result = await showVideoRemovalPrompt(
            ctx,
            videoSource: videoSource,
            linkedAudio: linkedAudio,
          );
        },
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, VideoRemovalAction.cancel);
    });

    testWidgets('returns cancel when dialog is dismissed by tapping outside',
        (tester) async {
      VideoRemovalAction? result;

      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) async {
          result = await showVideoRemovalPrompt(
            ctx,
            videoSource: videoSource,
            linkedAudio: linkedAudio,
          );
        },
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap outside the dialog to dismiss it
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(result, VideoRemovalAction.cancel);
    });

    testWidgets('falls back to source ID when displayName is null',
        (tester) async {
      const videoNoName = DisplaySource(
        id: 'video-no-name',
        origin: LocalFileOrigin('/path/to/video.mp4'),
        priority: 0,
        displayType: DisplayType.video,
      );

      const audioNoName = AudioSource(
        id: 'audio-no-name',
        origin: LocalFileOrigin('/path/to/video.mp4'),
        priority: 0,
        format: AudioFormat.other,
        linkedVideoSourceId: 'video-no-name',
      );

      await tester.pumpWidget(buildTestApp(
        onTap: (ctx) => showVideoRemovalPrompt(
          ctx,
          videoSource: videoNoName,
          linkedAudio: audioNoName,
        ),
      ));

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.textContaining('video-no-name'), findsOneWidget);
      expect(find.textContaining('audio-no-name'), findsOneWidget);
    });
  });
}
