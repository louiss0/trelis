import 'package:test/test.dart';
import 'package:trelis/src/testing/compat_api.dart';
import 'package:trelis/src/presentation_preferences.dart';

void main() {
  final a = TerminalColor.indexed(1);
  final b = TerminalColor.indexed(2);
  final c = TerminalColor.indexed(3);
  final d = TerminalColor.indexed(4);
  final light = ColorThemes.terminalDefault.copyWith(foreground: a);
  final dark = ColorThemes.terminalDefault.copyWith(foreground: b);
  final rich = OutputProfile(
    cursor: CapabilitySupport.supported,
    geometry: OutputGeometry.fixed(columns: 80, rows: 24),
    colorDepth: ColorDepth.rgb,
  );
  ResolvedPresentation resolve({
    PresentationPreferences session = const PresentationPreferences(),
    PresentationPreferences invocation = const PresentationPreferences(),
    PromptMode sessionMode = PromptMode.automatic,
    PromptMode? invocationMode,
    bool? hint,
    BackgroundVariant? background,
    String? noColor,
    OutputProfile? profile,
  }) => resolvePresentation(
    outputProfile: profile ?? rich,
    lightDefault: light,
    darkDefault: dark,
    session: session,
    invocation: invocation,
    sessionMode: sessionMode,
    invocationMode: invocationMode,
    screenReaderHint: hint,
    backgroundHint: background,
    noColor: noColor,
  );

  test('automatic screen reader uses only an affirmative hint', () {
    for (final hint in [false, null]) {
      final result = resolve(hint: hint);
      expect(result.screenReader, isFalse);
      expect(result.mode, PromptMode.rich);
    }
    final result = resolve(hint: true);
    expect(result.screenReader, isTrue);
    expect(result.mode, PromptMode.linear);
    expect(resolve(profile: const OutputProfile()).mode, PromptMode.linear);
  });

  test('explicit mode and screen reader preferences resolve independently', () {
    expect(
      resolve(hint: true, invocationMode: PromptMode.rich).screenReader,
      isFalse,
    );
    final off = resolve(
      hint: true,
      invocationMode: PromptMode.linear,
      invocation: const PresentationPreferences(
        screenReader: ScreenReaderPreference.off,
      ),
    );
    expect(off.screenReader, isFalse);
    expect(off.mode, PromptMode.linear);
    final on = resolve(
      hint: false,
      invocation: const PresentationPreferences(
        screenReader: ScreenReaderPreference.on,
      ),
    );
    expect(on.mode, PromptMode.linear);
    expect(
      () => resolve(
        invocationMode: PromptMode.rich,
        invocation: const PresentationPreferences(
          screenReader: ScreenReaderPreference.on,
        ),
      ),
      throwsArgumentError,
    );
    expect(
      resolve(
        sessionMode: PromptMode.rich,
        invocationMode: PromptMode.automatic,
        hint: true,
      ).mode,
      PromptMode.linear,
    );
    expect(
      resolve(
        session: const PresentationPreferences(
          screenReader: ScreenReaderPreference.on,
        ),
        invocation: const PresentationPreferences(
          screenReader: ScreenReaderPreference.automatic,
        ),
        hint: false,
      ).screenReader,
      isFalse,
    );
  });

  test('explicit rich remains requested on unsupported output', () {
    const unsupported = OutputProfile();
    expect(unsupported.supportsRichInteraction, isFalse);
    final result = resolve(
      profile: unsupported,
      invocationMode: PromptMode.rich,
      hint: true,
    );
    expect(result.mode, PromptMode.rich);
    expect(result.screenReader, isFalse);
    expect(result.outputProfile.supportsRichInteraction, isFalse);
    expect(resolve(profile: unsupported).mode, PromptMode.linear);
  });

  test('background explicit, hint and unknown fallback', () {
    expect(resolve().background, BackgroundVariant.dark);
    expect(resolve().palette.foreground, b);
    expect(resolve(background: BackgroundVariant.light).palette.foreground, a);
    expect(
      resolve(
        background: BackgroundVariant.light,
        session: const PresentationPreferences(
          background: BackgroundPreference.dark,
        ),
      ).palette.foreground,
      b,
    );
    expect(
      resolve(
        session: const PresentationPreferences(
          background: BackgroundPreference.dark,
        ),
        invocation: const PresentationPreferences(
          background: BackgroundPreference.automatic,
        ),
        background: BackgroundVariant.light,
      ).palette.foreground,
      a,
    );
  });

  test('prototype legacy: replacement retains session variant roles', () {
    final replacement = ColorThemes.terminalDefault.copyWith(
      foreground: c,
      muted: c,
    );
    final result = resolve(
      background: BackgroundVariant.light,
      session: PresentationPreferences(
        lightPalette: light,
        roles: ColorRoleOverrides(accent: a, warning: a),
        lightRoles: ColorRoleOverrides(accent: c, success: c),
      ),
      invocation: PresentationPreferences(
        palette: replacement,
        roles: ColorRoleOverrides(accent: b, warning: b),
        lightRoles: ColorRoleOverrides(accent: d),
      ),
    );
    expect(result.palette.foreground, c);
    expect(result.palette.muted, c);
    expect(result.palette.warning, b);
    expect(result.palette.accent, d);
    expect(result.palette.success, c);
    final darkResult = resolve(
      session: PresentationPreferences(palette: light, darkPalette: dark),
    );
    expect(darkResult.palette.foreground, b);
    final native = resolve(
      invocation: const PresentationPreferences(
        palette: ColorThemes.terminalDefault,
      ),
    );
    expect(isTerminalDefault(native.palette.foreground), isTrue);
  });

  for (final variant in BackgroundVariant.values) {
    test('prototype legacy: role precedence across scopes for $variant', () {
      final sessionVariant = ColorRoleOverrides(
        accent: b,
        warning: b,
        success: b,
      );
      final invocationVariant = ColorRoleOverrides(success: d);
      final result = resolve(
        background: variant,
        session: PresentationPreferences(
          roles: ColorRoleOverrides(accent: a, warning: a, success: a),
          lightRoles: sessionVariant,
          darkRoles: sessionVariant,
        ),
        invocation: PresentationPreferences(
          roles: ColorRoleOverrides(warning: c, success: c),
          lightRoles: invocationVariant,
          darkRoles: invocationVariant,
        ),
      );
      expect(result.palette.accent, b); // session variant beats session shared
      expect(
        result.palette.warning,
        c,
      ); // invocation shared beats session variant
      expect(
        result.palette.success,
        d,
      ); // invocation variant beats invocation shared
    });
  }

  test('NO_COLOR is hard and does not alter palette or other facts', () {
    for (final depth in ColorDepth.values) {
      final profile = rich.copyWith(colorDepth: depth);
      expect(
        resolve(profile: profile, noColor: '').outputProfile.colorDepth,
        depth,
      );
      final disabled = resolve(profile: profile, noColor: '0');
      expect(disabled.outputProfile.colorDepth, ColorDepth.none);
      expect(disabled.outputProfile.cursor, profile.cursor);
      expect(disabled.palette.foreground, b);
      expect(
        terminalStyledText(
          'x',
          foreground: a,
          background: b,
          depth: disabled.outputProfile.colorDepth,
        ),
        'x',
      );
    }
  });
}
