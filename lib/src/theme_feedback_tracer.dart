/// Internal end-to-end tracer for theme-owned feedback components.
///
/// The tracer joins one [ThemeSession] active period, renders the four real
/// feedback components through the merged state/status primitives, and keeps
/// each live participant until it is explicitly stopped, completed or failed.
/// It is deliberately absent from the public export barrel.
library;

import 'dart:async';

import 'package:characters/characters.dart';

import 'color_resolution.dart' show ComponentColors;
import 'color_theme.dart' show terminalStyledText;
import 'feedback.dart'
    show
        FeedbackClock,
        FeedbackLine,
        FeedbackOutcome,
        FeedbackRenderer,
        FeedbackState,
        MultiSpinner,
        Progress,
        Spinner,
        Text,
        TextKind,
        structureFeedbackLine;
import 'output_profile.dart' show GlyphSet, OutputProfile;
import 'presentation.dart' show DisplayText;
import 'prompt_structure.dart' show PromptStructure;
import 'state_help_presentation.dart' show StateGlyphs, Status, renderStatus;
import 'theme_session.dart'
    show
        ThemeFeedbackHandle,
        ThemeSession,
        ThemeSessionColorLayering,
        ThemeSessionHandle;

/// Renders one owned feedback line with textual status and safe glyphs.
final class ThemeFeedbackRenderer implements FeedbackRenderer {
  ThemeFeedbackRenderer(this.structure, this.colors);

  final PromptStructure structure;
  final ComponentColors colors;
  ThemeSessionHandle? _handle;

  /// Binds this renderer to the period that finished initialization.
  void attach(ThemeSessionHandle handle) => _handle = handle;

  @override
  String render(FeedbackLine line) {
    final handle = _handle;
    if (handle == null) {
      throw StateError('Feedback rendering requires an active theme period.');
    }
    final resolved = handle.componentColors(colors);
    final palette = resolved.palette;
    final profile = resolved.outputProfile;
    final glyphs = profile.glyphs == GlyphSet.unicode
        ? StateGlyphs.unicode
        : StateGlyphs.ascii;
    final body = _body(line, glyphs, handle.interaction.screenReader);
    final framed = _frameAndWrap(
      body,
      structure: structure,
      profile: profile,
      width: profile.geometry.columns,
    );
    final foreground = switch (line.state) {
      FeedbackState.hint => palette.muted,
      FeedbackState.success => palette.success,
      FeedbackState.warning => palette.warning,
      FeedbackState.failure => palette.error,
      _ => palette.foreground,
    };
    return terminalStyledText(
      framed,
      foreground: foreground,
      background: palette.background,
      depth: profile.colorDepth,
    );
  }

  String _body(FeedbackLine line, StateGlyphs glyphs, bool screenReader) {
    final message = DisplayText.from(line.message).value;
    return switch (line.state) {
      FeedbackState.information => message,
      FeedbackState.hint => 'Hint: $message',
      FeedbackState.running => 'Running: $message',
      FeedbackState.progress => 'Progress: $message',
      FeedbackState.success =>
        screenReader
            ? 'Success: $message'
            : renderStatus(Status.success, message, glyphs: glyphs),
      FeedbackState.warning =>
        screenReader
            ? 'Warning: $message'
            : renderStatus(Status.warning, message, glyphs: glyphs),
      FeedbackState.failure =>
        screenReader
            ? 'Error: $message'
            : renderStatus(Status.error, message, glyphs: glyphs),
    };
  }

  String _frameAndWrap(
    String body, {
    required PromptStructure structure,
    required OutputProfile profile,
    int? width,
  }) {
    String frame(String value) =>
        structureFeedbackLine(value, structure: structure, profile: profile);
    if (width == null || width <= 0) return frame(body);
    final prefixWidth = DisplayText.from(frame('')).value.characters.length;
    final available = (width - prefixWidth).clamp(1, width);
    return body
        .split('\n')
        .expand((line) => _wrapWords(line, available))
        .map(frame)
        .join('\n');
  }

  List<String> _wrapWords(String text, int width) {
    final lines = <String>[];
    var current = '';
    void flush() {
      if (current.isNotEmpty) lines.add(current);
      current = '';
    }

    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (word.characters.length > width) {
        flush();
        var cluster = '';
        for (final character in word.characters) {
          if (cluster.characters.length == width) {
            lines.add(cluster);
            cluster = '';
          }
          cluster += character;
        }
        current = cluster;
        continue;
      }
      if (current.isEmpty) {
        current = word;
      } else if (current.characters.length + 1 + word.characters.length <=
          width) {
        current = '$current $word';
      } else {
        flush();
        current = word;
      }
    }
    flush();
    return lines.isEmpty ? <String>[''] : lines;
  }
}

/// One live feedback participant bound to its component and period.
final class ThemeFeedbackControl<T> {
  const ThemeFeedbackControl._(this._handle, this.component, this._end);

  final ThemeFeedbackHandle _handle;

  /// The real component, available for application updates while live.
  final T component;
  final void Function(FeedbackOutcome? outcome, String? detail) _end;

  /// Ends the component with an explicit outcome and releases participation.
  Future<void> finish(FeedbackOutcome outcome, {String? detail}) =>
      _handle.finish(() => _end(outcome, detail));

  /// Stops presentation without inventing an outcome.
  Future<void> stop() => _handle.finish();
}

/// Creates real feedback components inside one theme-owned active period.
final class ThemeFeedbackTracer {
  ThemeFeedbackTracer(
    this._owner, {
    this.structure = PromptStructure.plain,
    this.colors = const ComponentColors(),
  });

  final ThemeSession _owner;
  final PromptStructure structure;
  final ComponentColors colors;

  ThemeFeedbackRenderer _renderer() => ThemeFeedbackRenderer(structure, colors);

  /// Presents one literal line after the period resolves and before output.
  Future<void> text(String content, {TextKind kind = TextKind.ordinary}) =>
      _owner.feedback((handle) {
        final renderer = _renderer()..attach(handle);
        Text.themed(
          content,
          kind: kind,
          themeRenderer: renderer,
        ).present(session: handle.session);
      });

  /// Starts caller-owned progress with explicit running and final states.
  Future<ThemeFeedbackControl<Progress>> progress(
    String label, {
    int? total,
    Duration interval = const Duration(seconds: 5),
    int milestone = 10,
    FeedbackClock? clock,
  }) async {
    final renderer = _renderer();
    late final Progress component;
    final handle = await _owner.startFeedback((period) {
      renderer.attach(period);
      component = Progress.themed(
        label,
        total: total,
        interval: interval,
        milestone: milestone,
        clock: clock,
        themeRenderer: renderer,
      );
      component.start(session: period.session);
    }, stop: () => component.dispose());
    return ThemeFeedbackControl._(handle, component, (outcome, detail) {
      if (outcome == null) {
        component.dispose();
      } else {
        component.finish(outcome, detail: detail);
      }
    });
  }

  /// Starts activity whose total work is unknown.
  Future<ThemeFeedbackControl<Spinner>> spinner(String label) async {
    final renderer = _renderer();
    late final Spinner component;
    final handle = await _owner.startFeedback((period) {
      renderer.attach(period);
      component = Spinner.themed(label, themeRenderer: renderer);
      component.start(session: period.session);
    }, stop: () => component.dispose());
    return ThemeFeedbackControl._(handle, component, (outcome, detail) {
      if (outcome == null) {
        component.dispose();
      } else {
        component.finish(outcome, detail: detail);
      }
    });
  }

  /// Starts a stable group of uniquely named tasks.
  Future<ThemeFeedbackControl<MultiSpinner>> multiSpinner(
    Iterable<String> tasks, {
    Duration interval = const Duration(seconds: 5),
    FeedbackClock? clock,
  }) async {
    final renderer = _renderer();
    final names = tasks.toList();
    late final MultiSpinner component;
    final handle = await _owner.startFeedback((period) {
      renderer.attach(period);
      component = MultiSpinner.themed(
        tasks,
        interval: interval,
        clock: clock,
        themeRenderer: renderer,
      );
      component.start(session: period.session);
    }, stop: () => component.dispose());
    return ThemeFeedbackControl._(handle, component, (outcome, detail) {
      if (outcome == null) {
        component.dispose();
      } else {
        for (final task in names) {
          component.finishTask(task, outcome, detail: detail);
        }
      }
    });
  }
}
