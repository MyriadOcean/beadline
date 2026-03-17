import 'dart:async';

import 'package:flutter/material.dart';

import '../core/di/service_locator.dart';
import '../i18n/translations.g.dart';
import '../models/song_unit.dart';
import '../repositories/library_repository.dart';

/// Debug view to check if temporary song units (discovered audio files) exist
class AudioEntriesDebugView extends StatefulWidget {
  const AudioEntriesDebugView({super.key});

  @override
  State<AudioEntriesDebugView> createState() => _AudioEntriesDebugViewState();
}

class _AudioEntriesDebugViewState extends State<AudioEntriesDebugView> {
  int _count = 0;
  bool _loading = true;
  List<SongUnit> _tempUnits = [];

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final repo = getIt<LibraryRepository>();
      final units = await repo.getTemporarySongUnits();
      setState(() {
        _tempUnits = units;
        _count = units.length;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading temporary song units: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.debug.audioEntriesTitle)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.t.debug.temporarySongUnitsFound.replaceAll('{count}', _count.toString()),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCount,
                    child: Text(context.t.debug.refresh),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (context.mounted) {
                        unawaited(
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(context.t.debug.temporarySongUnits),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _tempUnits.length,
                                  itemBuilder: (context, index) {
                                    final unit = _tempUnits[index];
                                    final duration = unit.metadata.duration;
                                    final durationText = duration != Duration.zero
                                        ? '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
                                        : 'No duration';
                                    return ListTile(
                                      title: Text(unit.displayName),
                                      subtitle: Text(
                                        '${unit.metadata.artistDisplay} - $durationText',
                                      ),
                                      trailing: Text(
                                        unit.originalFilePath?.split('\\').last ??
                                            unit.originalFilePath?.split('/').last ??
                                            '',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(context.t.debug.close),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(context.t.debug.showEntries),
                  ),
                ],
              ),
      ),
    );
  }
}
