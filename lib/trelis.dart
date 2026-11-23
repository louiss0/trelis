/// Accessible, nonvisually reviewable terminal prompts for Dart.
///
/// This public API is **unstable**: the coordinated theme-instance cutover is
/// complete, but the independent interaction and colour release gates are not.
/// Themes own one I/O environment and recover terminal resources after their
/// last active component; components are created through theme instances and
/// their `.prompt()`, `.present()` or `.start()` methods take no runtime
/// configuration. See `docs/adaptive-theme-public-api-migration.md` for the
/// migration from static factories and direct component construction.
library;

export 'src/public_theme_api.dart';
export 'src/themes/plain_theme.dart';
export 'src/themes/rail_theme.dart';
export 'src/themes/branch_theme.dart';
export 'src/themes/box_theme.dart';
export 'src/themes/round_theme.dart';
export 'src/themes/double_theme.dart';
export 'src/themes/minimal_theme.dart';
export 'src/themes/ascii_theme.dart';
export 'src/themes/chevron_theme.dart';
export 'src/themes/bracket_theme.dart';
export 'src/themes/form_theme.dart';
export 'src/themes/ledger_theme.dart';
export 'src/themes/colon_theme.dart';
export 'src/themes/line_theme.dart';
export 'src/themes/block_theme.dart';

export 'src/color_theme.dart';
export 'src/output_profile.dart';
export 'src/prompt_structure.dart';
export 'src/terminal_io.dart';

// Immutable colour and interaction inputs, observations and results.
// Resolver functions, resolver fact inputs and the theme session state
// machine stay internal; hint observations arrive through theme
// constructor parameters instead.
export 'src/color_resolution.dart'
    show
        BackgroundObservation,
        BackgroundPreference,
        BackgroundVariant,
        ColorPreferences,
        ColorRoleOverrides,
        ComponentColors,
        ResolvedColors;
export 'src/interaction_resolution.dart'
    show
        InteractionPreferences,
        ResolvedInteraction,
        ScreenReaderObservation,
        ScreenReaderPreference,
        TerminalLocality;
export 'src/state_help_presentation.dart' show SingleSelectionStyle;
export 'src/theme_session.dart'
    show ThemeInteractionState, ThemeResolvedCallback;
// Immutable observations accepted by theme constructors.
export 'src/hint_observations.dart'
    show
        ContainerObservation,
        HintPlatform,
        NativeHintObservations,
        RemoteSessionObservation;

// Public result, choice and component-value types stay available. Concrete
// component classes, their direct constructors and PromptSource variants are
// intentionally absent from the public barrel.
export 'src/text_input.dart'
    show
        Accepted,
        Cancelled,
        Choice,
        CivilDate,
        ColorValue,
        CronCellFrame,
        CronExpression,
        CronPreview,
        CronPreviewConfig,
        CronPreviewStatus,
        CronProfile,
        DateCalendar,
        DateDigits,
        DateFieldOrder,
        DurationInputMode,
        DurationValue,
        IPAddressValue,
        InputEnded,
        InstructionDisplay,
        Interrupted,
        KeyGesture,
        KeyGestureProvenance,
        KeyModifier,
        MaskElement,
        MaskInterpretation,
        MaskLiteral,
        MaskSlot,
        MaskTemplate,
        MaskedValue,
        NumericAnswer,
        NumericConvention,
        NumericNegativePattern,
        PathTarget,
        PromptMode,
        PromptResult,
        TagStyle,
        TextInputCurrentView,
        TextInputPresentationEvent,
        TextInputPresentationEventKind,
        TextInputTranscript,
        TreeNode,
        Unavailable;
export 'src/feedback.dart'
    show
        FeedbackClock,
        FeedbackLine,
        FeedbackOutcome,
        FeedbackRenderer,
        FeedbackState,
        FeedbackTimer,
        TaskActivity,
        TextKind;
