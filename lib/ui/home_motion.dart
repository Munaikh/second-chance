import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Keeps the mounted home/chat elements on one interruptible spring.
class ConversationMotion extends StatelessWidget {
  const ConversationMotion({
    super.key,
    required this.open,
    required this.builder,
    required this.child,
  });

  final bool open;
  final ValueWidgetBuilder<double> builder;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: open ? 1 : 0,
    active: !MediaQuery.disableAnimationsOf(context),
    motion: const CupertinoMotion(
      duration: Duration(milliseconds: 300),
      bounce: .08,
    ),
    builder: builder,
    child: child,
  );
}
