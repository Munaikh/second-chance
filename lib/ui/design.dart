import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

abstract final class AppColors {
  static const purple = Color(0xFF57258A);
  static const lavender = Color(0xFFD5B9F6);
  static const green = Color(0xFF22664B);
  static const amber = Color(0xFF954211);
  static Color canvas(BuildContext c) => Theme.of(c).scaffoldBackgroundColor;
  static Color surface(BuildContext c) => Theme.of(c).colorScheme.surface;
  static Color ink(BuildContext c) => Theme.of(c).colorScheme.onSurface;
  static Color muted(BuildContext c) =>
      Theme.of(c).colorScheme.onSurfaceVariant;
  static Color line(BuildContext c) => Theme.of(c).dividerColor;
  static Color accent(BuildContext c) => Theme.of(c).colorScheme.primary;
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFF0F0F4) : const Color(0xFF202029);
  final muted = dark ? const Color(0xFFBABAC7) : const Color(0xFF646471);
  final canvas = dark ? const Color(0xFF131318) : const Color(0xFFF7F7F9);
  final surface = dark ? const Color(0xFF1E1E25) : const Color(0xFFFDFDFE);
  final border = dark ? const Color(0xFF383840) : const Color(0xFFE5E5EB);
  final accent = dark ? const Color(0xFFD5B9F6) : AppColors.purple;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: dark ? const Color(0xFF25113C) : const Color(0xFFFCFAFF),
    secondary: dark ? const Color(0xFF8DD9B4) : AppColors.green,
    onSecondary: dark ? const Color(0xFF102D20) : const Color(0xFFFAFDFB),
    error: dark ? const Color(0xFFFFB4AA) : const Color(0xFFA32F32),
    onError: dark ? const Color(0xFF441014) : const Color(0xFFFFFAFA),
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border,
    surfaceContainerLowest: canvas,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: dark
        ? const Color(0xFF2C2C35)
        : const Color(0xFFF0F0F4),
    inverseSurface: dark ? const Color(0xFFF0F0F4) : const Color(0xFF262630),
    onInverseSurface: dark ? const Color(0xFF202029) : const Color(0xFFF5F5F8),
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    dividerColor: border,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    fontFamily: '.SF Pro Text',
    textTheme: TextTheme(
      displaySmall: TextStyle(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.8,
        height: 1.05,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.12,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
        height: 1.15,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: muted,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.all(17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      hintStyle: TextStyle(color: muted),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: border,
      overlayColor: accent.withValues(alpha: .1),
      trackHeight: 5,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: border,
      borderRadius: BorderRadius.circular(10),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: accent,
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color,
    this.border = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool border;
  @override
  Widget build(BuildContext context) => Material(
    color: color ?? AppColors.surface(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: border
          ? BorderSide(color: AppColors.line(context))
          : BorderSide.none,
    ),
    child: Padding(padding: padding, child: child),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: loading ? null : onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 20),
          if (loading || icon != null) const SizedBox(width: 9),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.muted(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: tint),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: tint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.color,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.canvas(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color ?? AppColors.accent(context), size: 21),
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: subtitle == null
        ? null
        : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
    trailing:
        trailing ??
        (onTap != null
            ? Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.muted(context),
              )
            : null),
    onTap: onTap,
  );
}

class Pip extends StatelessWidget {
  const Pip({
    super.key,
    this.size = 110,
    this.speaking = false,
    this.listening = false,
    this.celebrating = false,
  });
  final double size;
  final bool speaking;
  final bool listening;
  final bool celebrating;
  @override
  Widget build(BuildContext context) {
    Widget child = CustomPaint(
      size: Size.square(size),
      painter: _PipPainter(speaking, listening, celebrating),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      child = child
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
            begin: speaking ? -3 : -1,
            end: speaking ? 3 : 1,
            duration: Duration(milliseconds: speaking ? 400 : 1700),
            curve: Curves.easeInOut,
          )
          .rotate(
            begin: listening ? -.015 : 0,
            end: listening ? .015 : 0,
            duration: 900.ms,
          );
    }
    return Semantics(
      label:
          'Pip, your financial companion${speaking
              ? ', speaking'
              : listening
              ? ', listening'
              : ''}',
      image: true,
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

class _PipPainter extends CustomPainter {
  const _PipPainter(this.speaking, this.listening, this.celebrating);
  final bool speaking;
  final bool listening;
  final bool celebrating;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.scale(s);
    canvas.drawOval(
      const Rect.fromLTWH(25, 105, 72, 7),
      Paint()..color = const Color(0xFF57258A).withValues(alpha: .09),
    );
    final body = Path()
      ..moveTo(24, 80)
      ..cubicTo(9, 43, 36, 19, 65, 23)
      ..cubicTo(94, 20, 110, 42, 100, 75)
      ..cubicTo(98, 90, 90, 100, 76, 102)
      ..cubicTo(49, 110, 31, 98, 24, 80);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE4CCFF), Color(0xFFBD91ED)],
        ).createShader(const Rect.fromLTWH(16, 20, 90, 85)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(14, 67, 18, 11),
      Paint()..color = const Color(0xFFD7B6F7),
    );
    canvas.drawOval(
      Rect.fromLTWH(93, celebrating ? 47 : 64, 18, 11),
      Paint()..color = const Color(0xFFC89DF0),
    );
    final leaf = Path()
      ..moveTo(61, 24)
      ..quadraticBezierTo(63, 4, 85, 9)
      ..quadraticBezierTo(84, 26, 61, 24);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF589A73));
    final eye = Paint()..color = const Color(0xFF3D205B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(44, celebrating ? 56 : 51, 6, celebrating ? 4 : 11),
        const Radius.circular(4),
      ),
      eye,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(73, celebrating ? 56 : 51, 6, celebrating ? 4 : 11),
        const Radius.circular(4),
      ),
      eye,
    );
    canvas.drawCircle(
      const Offset(37, 69),
      5,
      Paint()..color = const Color(0xFFE992AE).withValues(alpha: .6),
    );
    canvas.drawCircle(
      const Offset(85, 69),
      5,
      Paint()..color = const Color(0xFFE992AE).withValues(alpha: .6),
    );
    if (speaking) {
      canvas.drawOval(const Rect.fromLTWH(56, 68, 12, 15), eye);
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(54, 71)
          ..quadraticBezierTo(61, 79, 68, 71),
        Paint()
          ..color = const Color(0xFF3D205B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );
    }
    if (listening) {
      for (var i = 0; i < 3; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(103, 47), radius: 7.0 + i * 5),
          -.8,
          1.6,
          false,
          Paint()
            ..color = const Color(0xFF8350B0).withValues(alpha: .8 - i * .2)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      speaking != old.speaking ||
      listening != old.listening ||
      celebrating != old.celebrating;
}

void showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
