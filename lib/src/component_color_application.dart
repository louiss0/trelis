/// Applies a component colour override inside an active theme period.
///
/// The owner has already selected the background and applied application
/// preferences, so those decisions are carried forward instead of resolved
/// twice. The pure colour resolver still applies the component replacement and
/// its shared and variant roles, including the final `NO_COLOR` restriction.
library;

import 'color_resolution.dart';
import 'theme_session.dart' show ThemeSessionHandle;

ResolvedColors applyComponentColors(
  ThemeSessionHandle handle,
  ComponentColors component,
) {
  final period = handle.colors;
  final background = switch (period.background) {
    BackgroundVariant.light => BackgroundPreference.light,
    BackgroundVariant.dark => BackgroundPreference.dark,
  };
  return resolveColors(
    facts: ColorDetectionFacts(
      outputProfile: period.outputProfile,
      noColor: handle.environment.environment['NO_COLOR'],
    ),
    lightDefault: period.palette,
    darkDefault: period.palette,
    preferences: ColorPreferences(background: background),
    component: component,
  );
}
