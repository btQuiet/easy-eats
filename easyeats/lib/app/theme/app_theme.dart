import 'package:flutter/material.dart';

/// Paleta de Easy Eats. En los widgets, usar ColorScheme para que los colores
/// se adapten al modo claro u oscuro.
abstract final class AppColors {
  static const cream = Color(0xFFF8F6F1);
  static const paper = Color(0xFFFFFEFA);
  static const forest = Color(0xFF183D33);
  static const sage = Color(0xFFD9E9DA);
  static const sageSurface = Color(0xFFE3ECDF);
  static const coral = Color(0xFFE7654E);
  // El coral más oscuro ofrece contraste para texto claro en botones.
  static const coralAction = Color(0xFFB94731);
  static const coralSurface = Color(0xFFFBE4DC);
  static const onCoralSurface = Color(0xFF542211);
  static const sand = Color(0xFFF4EADB);
  static const onSand = Color(0xFF514025);
  static const muted = Color(0xFF62736B);
  static const border = Color(0xFFE0E5DC);
  static const error = Color(0xFFBA1A1A);
  static const errorSurface = Color(0xFFFFDAD6);
  static const onErrorSurface = Color(0xFF410002);
  static const sidebarText = Color(0xFFF2F4E9);
  static const sidebarMuted = Color(0xFFB6C7BA);
  static const sidebarSelected = Color(0xFF254C3E);

  static const darkBackground = Color(0xFF17221D);
  static const darkPaper = Color(0xFF202E26);
  static const darkText = Color(0xFFE7EEE7);
  static const darkPrimary = Color(0xFFBDDCC6);
  static const onDarkPrimary = Color(0xFF14281D);
  static const darkSage = Color(0xFF2B4334);
  static const darkCoral = Color(0xFFF3A088);
  static const onDarkCoral = Color(0xFF2E2119);
  static const darkCoralSurface = Color(0xFF573529);
  static const onDarkCoralSurface = Color(0xFFFFDED2);
  static const darkSand = Color(0xFF3F3729);
  static const onDarkSand = Color(0xFFF4DFC0);
  static const darkMuted = Color(0xFFB4C3B7);
  static const darkBorder = Color(0xFF3A4B40);
  static const darkError = Color(0xFFFFB4AB);
  static const darkErrorSurface = Color(0xFF93000A);
  static const darkSidebar = Color(0xFF112B22);
}

/// Material 3 con títulos editoriales, superficies cálidas y acciones coral.
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ThemeMode.system,
/// )
abstract final class AppTheme {
  static const controlRadius = 12.0;
  static const cardRadius = 20.0;
  static const panelRadius = 24.0;

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkBackground : AppColors.cream;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.darkPrimary : AppColors.forest,
          onPrimary: isDark ? AppColors.onDarkPrimary : AppColors.paper,
          primaryContainer: isDark ? AppColors.darkSage : AppColors.sage,
          onPrimaryContainer: isDark ? AppColors.darkText : AppColors.forest,
          secondary: isDark ? AppColors.darkCoral : AppColors.coralAction,
          onSecondary: isDark ? AppColors.onDarkCoral : AppColors.paper,
          secondaryContainer: isDark
              ? AppColors.darkCoralSurface
              : AppColors.coralSurface,
          onSecondaryContainer: isDark
              ? AppColors.onDarkCoralSurface
              : AppColors.onCoralSurface,
          tertiary: isDark ? AppColors.onDarkSand : AppColors.onSand,
          onTertiary: isDark ? AppColors.darkSand : AppColors.paper,
          tertiaryContainer: isDark ? AppColors.darkSand : AppColors.sand,
          onTertiaryContainer: isDark ? AppColors.onDarkSand : AppColors.onSand,
          surface: isDark ? AppColors.darkPaper : AppColors.paper,
          onSurface: isDark ? AppColors.darkText : AppColors.forest,
          onSurfaceVariant: isDark ? AppColors.darkMuted : AppColors.muted,
          surfaceDim: background,
          surfaceBright: isDark ? AppColors.darkSage : AppColors.paper,
          surfaceContainerLowest: background,
          surfaceContainerLow: background,
          surfaceContainer: isDark ? AppColors.darkPaper : AppColors.paper,
          surfaceContainerHigh: isDark
              ? AppColors.darkSage
              : AppColors.sageSurface,
          surfaceContainerHighest: isDark
              ? AppColors.darkBorder
              : AppColors.sage,
          outline: isDark ? AppColors.darkMuted : AppColors.muted,
          outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
          inverseSurface: isDark ? AppColors.paper : AppColors.darkPaper,
          onInverseSurface: isDark ? AppColors.forest : AppColors.darkText,
          inversePrimary: isDark ? AppColors.forest : AppColors.darkPrimary,
          error: isDark ? AppColors.darkError : AppColors.error,
          onError: isDark ? AppColors.onErrorSurface : AppColors.paper,
          errorContainer: isDark
              ? AppColors.darkErrorSurface
              : AppColors.errorSurface,
          onErrorContainer: isDark
              ? AppColors.errorSurface
              : AppColors.onErrorSurface,
          surfaceTint: Colors.transparent,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = _textTheme(base.textTheme, scheme);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(panelRadius),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(controlRadius),
      borderSide: BorderSide(color: scheme.outline),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonSize = Size(48, 48);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text,
      extensions: [isDark ? AppThemeColors.dark : AppThemeColors.light],
      appBarTheme: AppBarThemeData(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          minimumSize: buttonSize,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          minimumSize: buttonSize,
          padding: buttonPadding,
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: scheme.primary,
              minimumSize: buttonSize,
              padding: buttonPadding,
              textStyle: text.labelLarge,
              shape: controlShape,
            ).copyWith(
              side: WidgetStateProperty.resolveWith((states) {
                return BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? scheme.onSurface.withValues(alpha: 0.12)
                      : scheme.outline,
                );
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        elevation: 0,
        shape: controlShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        disabledColor: scheme.onSurface.withValues(alpha: 0.08),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelLarge,
        unselectedLabelTextStyle: text.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: panelShape,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(panelRadius),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: controlShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        circularTrackColor: scheme.primaryContainer,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final text = base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    // Fuentes del sistema: sin descargas ni dependencias adicionales.
    // Para asegurar la misma tipografía en todas las plataformas, registrar
    // una fuente serif propia en pubspec.yaml y sustituir esta familia.
    TextStyle? editorial(TextStyle? style) => style?.copyWith(
      fontFamily: 'Georgia',
      fontFamilyFallback: const ['Times New Roman', 'serif'],
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      height: 1.15,
    );

    return text.copyWith(
      displayLarge: editorial(text.displayLarge),
      displayMedium: editorial(text.displayMedium),
      displaySmall: editorial(text.displaySmall),
      headlineLarge: editorial(text.headlineLarge),
      headlineMedium: editorial(text.headlineMedium),
      headlineSmall: editorial(text.headlineSmall),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      bodySmall: text.bodySmall?.copyWith(height: 1.4),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// Colores de marca sin un rol equivalente en Material.
///
///     final colors = Theme.of(context).extension<AppThemeColors>()!;
///
/// Usar [coral] como acento decorativo; para botones, ColorScheme.secondary.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.coral,
    required this.sidebar,
    required this.onSidebar,
    required this.sidebarMuted,
    required this.sidebarSelected,
  });

  static const light = AppThemeColors(
    coral: AppColors.coral,
    sidebar: AppColors.forest,
    onSidebar: AppColors.sidebarText,
    sidebarMuted: AppColors.sidebarMuted,
    sidebarSelected: AppColors.sidebarSelected,
  );

  static const dark = AppThemeColors(
    coral: AppColors.darkCoral,
    sidebar: AppColors.darkSidebar,
    onSidebar: AppColors.sidebarText,
    sidebarMuted: AppColors.sidebarMuted,
    sidebarSelected: AppColors.sidebarSelected,
  );

  final Color coral;
  final Color sidebar;
  final Color onSidebar;
  final Color sidebarMuted;
  final Color sidebarSelected;

  @override
  AppThemeColors copyWith({
    Color? coral,
    Color? sidebar,
    Color? onSidebar,
    Color? sidebarMuted,
    Color? sidebarSelected,
  }) {
    return AppThemeColors(
      coral: coral ?? this.coral,
      sidebar: sidebar ?? this.sidebar,
      onSidebar: onSidebar ?? this.onSidebar,
      sidebarMuted: sidebarMuted ?? this.sidebarMuted,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
    );
  }

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      coral: Color.lerp(coral, other.coral, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      onSidebar: Color.lerp(onSidebar, other.onSidebar, t)!,
      sidebarMuted: Color.lerp(sidebarMuted, other.sidebarMuted, t)!,
      sidebarSelected: Color.lerp(sidebarSelected, other.sidebarSelected, t)!,
    );
  }
}
