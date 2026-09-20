// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Bogner Chess
// Additional permission under GPL-3.0 section 7: see LICENSE-APP-STORE-PERMISSION.md.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// How much work the app itself did for one step of a test, measured from the
/// frames the engine reported.
///
/// **What it is.** `FrameTiming.buildDuration` is the time the UI thread
/// spent building, laying out and painting a frame; `rasterDuration` is the
/// time the raster thread spent turning it into pixels. The two run in
/// parallel, so the work of a step is the longer of the two sums over the
/// frames that belong to it, not their total. That number is the app's own
/// cost. It does not contain the time the app spends waiting for a vsync,
/// nor the time an animation takes to finish, nor anything the test itself
/// does: a slower animation does not make it grow, a rebuild that got twice
/// as expensive does.
///
/// **What it is not.** It is a regression proxy, measured in a debug build on
/// a simulator, where every number is several times larger than on a device.
/// It says nothing about how fast a person can enter a game; human gate H9
/// (a stopwatch and a paper scoresheet on a real iPhone) is that check.
///
/// **Attribution.** Frames carry a `frameNumber`, and
/// `PlatformDispatcher.frameData.frameNumber` names the last frame that was
/// begun. A step is the half-open range of frame numbers between the reading
/// before it and the reading after it. Frames of an animation that is still
/// running belong to the step during which they were drawn, which is the
/// point: they are work the app does while the player is entering the next
/// move.
@immutable
class PlyWork {
  const PlyWork({
    required this.index,
    required this.label,
    required this.frames,
    required this.build,
    required this.raster,
    required this.wall,
  });

  /// One-based position in the run.
  final int index;

  /// What the step was, for example `12. e2e4`.
  final String label;

  /// How many frames the engine reported for this step.
  final int frames;

  /// UI-thread time over those frames.
  final Duration build;

  /// Raster-thread time over those frames.
  final Duration raster;

  /// Wall clock of the step, for context only. It also contains the vsync
  /// waits of every pumped frame (up to about 17 ms each at 60 Hz) and
  /// whatever else the simulator was busy with, so it is reported and never
  /// budgeted.
  final Duration wall;

  /// The budgeted number: the busier of the two threads.
  Duration get appWork => build > raster ? build : raster;
}

/// Collects [PlyWork] while a test drives the app.
///
/// ```dart
/// final recorder = PlyWorkRecorder(binding)..start();
/// for (...) {
///   recorder.beginPly('12. e2e4');
///   await tester.tapPoints(taps);
///   recorder.endPly();
/// }
/// final report = await recorder.stop(tester, budget: kPlyBudget);
/// ```
class PlyWorkRecorder {
  PlyWorkRecorder(this._binding);

  final IntegrationTestWidgetsFlutterBinding _binding;
  final List<FrameTiming> _timings = <FrameTiming>[];
  final List<_Mark> _marks = <_Mark>[];
  final Stopwatch _clock = Stopwatch();
  _Mark? _open;

  int get _frameNumber => _binding.platformDispatcher.frameData.frameNumber;

  void _collect(List<FrameTiming> timings) => _timings.addAll(timings);

  void start() => _binding.addTimingsCallback(_collect);

  void beginPly(String label) {
    assert(_open == null, 'endPly was not called for ${_open?.label}');
    _open = _Mark(label, _frameNumber);
    _clock
      ..reset()
      ..start();
  }

  void endPly() {
    _clock.stop();
    final open = _open!;
    _marks.add(open..close(_frameNumber, _clock.elapsed));
    _open = null;
  }

  /// Stops collecting and builds the report.
  ///
  /// The engine batches frame timings and can hold them back for about a
  /// second, so this pumps until the last step's frames have arrived. If they
  /// never do, the report says so and the budget check fails rather than
  /// passing on no data.
  Future<PlyWorkReport> stop(
    WidgetTester tester, {
    required Duration budget,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    assert(_open == null, 'endPly was not called for ${_open?.label}');
    final wanted = _marks.isEmpty ? -1 : _marks.last.lastFrame;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) &&
        !_timings.any((timing) => timing.frameNumber >= wanted)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    _binding.removeTimingsCallback(_collect);

    final plies = <PlyWork>[];
    for (final (index, mark) in _marks.indexed) {
      final frames = _timings.where(
        (timing) =>
            timing.frameNumber > mark.firstFrame &&
            timing.frameNumber <= mark.lastFrame,
      );
      plies.add(
        PlyWork(
          index: index + 1,
          label: mark.label,
          frames: frames.length,
          build: _sum(frames.map((timing) => timing.buildDuration)),
          raster: _sum(frames.map((timing) => timing.rasterDuration)),
          wall: mark.wall,
        ),
      );
    }
    return PlyWorkReport(plies: plies, budget: budget);
  }

  static Duration _sum(Iterable<Duration> durations) =>
      durations.fold(Duration.zero, (total, one) => total + one);
}

class _Mark {
  _Mark(this.label, this.firstFrame);

  final String label;
  final int firstFrame;
  late final int lastFrame;
  late final Duration wall;

  void close(int frame, Duration elapsed) {
    lastFrame = frame;
    wall = elapsed;
  }
}

/// What a run of [PlyWorkRecorder] measured.
@immutable
class PlyWorkReport {
  const PlyWorkReport({required this.plies, required this.budget});

  final List<PlyWork> plies;
  final Duration budget;

  /// Steps for which no frame was reported. Not zero work: no measurement.
  /// The budget cannot be checked while this is not empty.
  List<PlyWork> get unmeasured =>
      plies.where((ply) => ply.frames == 0).toList(growable: false);

  List<PlyWork> get overBudget =>
      plies.where((ply) => ply.appWork > budget).toList(growable: false);

  /// The compact summary that goes into `reportData` and onto stdout.
  Map<String, Object?> toJson() => <String, Object?>{
    'metric': 'app_work_ms_per_ply',
    'definition':
        'max(sum of FrameTiming.buildDuration, sum of '
        'FrameTiming.rasterDuration) over the frames of one ply. Debug '
        'build on a simulator; a regression proxy, not human speed (H9).',
    'budget_ms': _ms(budget),
    'plies': plies.length,
    'frames': plies.fold<int>(0, (total, ply) => total + ply.frames),
    'app_work_ms': _stats(plies.map((ply) => ply.appWork)),
    'build_ms': _stats(plies.map((ply) => ply.build)),
    'raster_ms': _stats(plies.map((ply) => ply.raster)),
    'wall_ms': _stats(plies.map((ply) => ply.wall)),
    'unmeasured_plies': unmeasured.map((ply) => ply.label).toList(),
    'over_budget': overBudget
        .map(
          (ply) => <String, Object?>{
            'ply': ply.index,
            'label': ply.label,
            'app_work_ms': _ms(ply.appWork),
          },
        )
        .toList(),
    'per_ply_app_work_ms': [for (final ply in plies) _ms(ply.appWork)],
    'per_ply_wall_ms': [for (final ply in plies) _ms(ply.wall)],
  };

  /// A table for a human to paste into the task file.
  String toTable() {
    final lines = <String>[
      'ply | frames | build ms | raster ms | app work ms | wall ms',
    ];
    for (final ply in plies) {
      lines.add(
        '${ply.index.toString().padLeft(3)} '
        '${ply.label.padRight(10)} '
        '${ply.frames.toString().padLeft(3)} '
        '${_ms(ply.build).toStringAsFixed(1).padLeft(8)} '
        '${_ms(ply.raster).toStringAsFixed(1).padLeft(8)} '
        '${_ms(ply.appWork).toStringAsFixed(1).padLeft(8)} '
        '${_ms(ply.wall).toStringAsFixed(1).padLeft(8)}',
      );
    }
    return lines.join('\n');
  }

  static double _ms(Duration duration) =>
      (duration.inMicroseconds / 100).round() / 10;

  static Map<String, Object?> _stats(Iterable<Duration> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return <String, Object?>{};
    double at(double quantile) =>
        _ms(sorted[((sorted.length - 1) * quantile).round()]);
    final total = sorted.fold(Duration.zero, (sum, one) => sum + one);
    return <String, Object?>{
      'min': _ms(sorted.first),
      'p50': at(0.5),
      'p90': at(0.9),
      'max': _ms(sorted.last),
      'mean': _ms(total ~/ sorted.length),
      'total': _ms(total),
    };
  }
}
