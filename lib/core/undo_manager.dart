import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manages undo/redo operations for critical actions
/// Requirements: 1.5, 5.3
class UndoManager extends ChangeNotifier {
  UndoManager({int maxStackSize = 50}) : _maxStackSize = maxStackSize;
  final List<UndoableAction> _undoStack = [];
  final List<UndoableAction> _redoStack = [];
  final int _maxStackSize;

  /// Whether there are actions that can be undone
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are actions that can be redone
  bool get canRedo => _redoStack.isNotEmpty;

  /// Description of the next action to undo
  String? get undoDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.description : null;

  /// Description of the next action to redo
  String? get redoDescription =>
      _redoStack.isNotEmpty ? _redoStack.last.description : null;

  /// Number of actions in undo stack
  int get undoCount => _undoStack.length;

  /// Number of actions in redo stack
  int get redoCount => _redoStack.length;

  /// Execute an action and add it to the undo stack
  Future<void> execute(UndoableAction action) async {
    await action.execute();
    _undoStack.add(action);
    _redoStack.clear(); // Clear redo stack on new action

    // Limit stack size
    while (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }

    notifyListeners();
  }

  /// Undo the last action
  Future<void> undo() async {
    if (!canUndo) return;

    final action = _undoStack.removeLast();
    await action.undo();
    _redoStack.add(action);

    notifyListeners();
  }

  /// Redo the last undone action
  Future<void> redo() async {
    if (!canRedo) return;

    final action = _redoStack.removeLast();
    await action.execute();
    _undoStack.add(action);

    notifyListeners();
  }

  /// Clear all undo/redo history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

/// Base class for undoable actions
abstract class UndoableAction {
  /// Human-readable description of the action
  String get description;

  /// Execute the action
  Future<void> execute();

  /// Undo the action
  Future<void> undo();
}

/// Undoable action for deleting a Song Unit
class DeleteSongUnitAction extends UndoableAction {
  DeleteSongUnitAction({
    required this.songUnitId,
    required this.songUnitData,
    required this.deleteFunction,
    required this.restoreFunction,
  });
  final String songUnitId;
  final Map<String, dynamic> songUnitData;
  final Future<void> Function(String id) deleteFunction;
  final Future<void> Function(Map<String, dynamic> data) restoreFunction;

  @override
  String get description => 'Delete song unit';

  @override
  Future<void> execute() async {
    await deleteFunction(songUnitId);
  }

  @override
  Future<void> undo() async {
    await restoreFunction(songUnitData);
  }
}

/// Undoable action for deleting a Tag
class DeleteTagAction extends UndoableAction {
  DeleteTagAction({
    required this.tagId,
    required this.tagData,
    required this.affectedSongUnitIds,
    required this.deleteFunction,
    required this.restoreFunction,
  });
  final String tagId;
  final Map<String, dynamic> tagData;
  final List<String> affectedSongUnitIds;
  final Future<void> Function(String id) deleteFunction;
  final Future<void> Function(
    Map<String, dynamic> data,
    List<String> songUnitIds,
  )
  restoreFunction;

  @override
  String get description => 'Delete tag';

  @override
  Future<void> execute() async {
    await deleteFunction(tagId);
  }

  @override
  Future<void> undo() async {
    await restoreFunction(tagData, affectedSongUnitIds);
  }
}

/// Undoable action for batch tag operations
class BatchTagAction extends UndoableAction {
  BatchTagAction({
    required this.songUnitIds,
    required this.tagIds,
    required this.isAddOperation,
    required this.previousTagStates,
    required this.addFunction,
    required this.removeFunction,
    required this.restoreFunction,
  });
  final List<String> songUnitIds;
  final List<String> tagIds;
  final bool isAddOperation;
  final Map<String, List<String>> previousTagStates;
  final Future<void> Function(List<String> songUnitIds, List<String> tagIds)
  addFunction;
  final Future<void> Function(List<String> songUnitIds, List<String> tagIds)
  removeFunction;
  final Future<void> Function(Map<String, List<String>> states) restoreFunction;

  @override
  String get description =>
      isAddOperation ? 'Add tags to songs' : 'Remove tags from songs';

  @override
  Future<void> execute() async {
    if (isAddOperation) {
      await addFunction(songUnitIds, tagIds);
    } else {
      await removeFunction(songUnitIds, tagIds);
    }
  }

  @override
  Future<void> undo() async {
    await restoreFunction(previousTagStates);
  }
}

/// Undoable action for updating a Song Unit
class UpdateSongUnitAction extends UndoableAction {
  UpdateSongUnitAction({
    required this.songUnitId,
    required this.previousData,
    required this.newData,
    required this.updateFunction,
  });
  final String songUnitId;
  final Map<String, dynamic> previousData;
  final Map<String, dynamic> newData;
  final Future<void> Function(Map<String, dynamic> data) updateFunction;

  @override
  String get description => 'Update song unit';

  @override
  Future<void> execute() async {
    await updateFunction(newData);
  }

  @override
  Future<void> undo() async {
    await updateFunction(previousData);
  }
}
