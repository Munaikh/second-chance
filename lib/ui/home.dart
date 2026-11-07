import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_sheets/smooth_sheets.dart';
import 'package:second_chance/core/companion.dart';
import 'package:second_chance/core/finance.dart';
import 'package:second_chance/main.dart';
import 'package:second_chance/ui/assistant_widgets.dart';
import 'package:second_chance/ui/design.dart';
import 'package:second_chance/ui/cloudy.dart';
import 'package:second_chance/ui/forecast.dart';
import 'package:second_chance/ui/profile.dart';
import 'package:second_chance/ui/home_motion.dart';
import 'package:second_chance/ui/voice_companion_view.dart';

class PreparePage extends StatefulWidget {
  const PreparePage({
    super.key,
    required this.onSupport,
    required this.onGrow,
    this.startInConversation = false,
    this.initialQuestion,
  });
  final VoidCallback onSupport, onGrow;
  final bool startInConversation;
  final String? initialQuestion;
  @override
  State<PreparePage> createState() => _PreparePageState();
}

class _PreparePageState extends State<PreparePage>
    with WidgetsBindingObserver, RouteAware {
  final _sheet = SheetController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _chatScroll = ScrollController();
  CompanionController? _companion;
  PageRoute<dynamic>? _route;
  late bool _chatOpen = widget.startInConversation;
  bool _voiceOpen = false;
  int _messageCount = 0;
  String? _profileId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focus.addListener(_onFocus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (_companion == null) {
      _companion = state.companion;
      _companion!.addListener(_onCompanion);
      if (widget.initialQuestion != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _sendPrompt(widget.initialQuestion!);
        });
      }
    }
    if (_profileId != null && _profileId != state.profile.id) {
      _chatOpen = false;
      _voiceOpen = false;
      _input.clear();
      _focus.unfocus();
    }
    _profileId = state.profile.id;
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  void _onFocus() {
    if (_focus.hasFocus && !_chatOpen) setState(() => _chatOpen = true);
  }

  void _onCompanion() {
    if (!mounted) return;
    final count = _companion!.messages.length;
    if (count != _messageCount) {
      _messageCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _chatScroll.hasClients) {
          if (MediaQuery.disableAnimationsOf(context)) {
            _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
          } else {
            _chatScroll.animateTo(
              _chatScroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(.23, 1, .32, 1),
            );
          }
        }
      });
    }
    setState(() {});
  }

  @override
  void didPushNext() {
    _focus.unfocus();
    unawaited(_companion?.endSession());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_companion?.endSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _companion?.removeListener(_onCompanion);
    unawaited(_companion?.endSession());
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _input.dispose();
    _sheet.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String prompt) async {
    setState(() {
      _chatOpen = true;
      _voiceOpen = false;
    });
    _focus.unfocus();
    AppScope.of(context).updateCompanionContext();
    await _companion!.sendText(prompt);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty ||
        _companion!.phase == CompanionPhase.connecting ||
        _companion!.phase == CompanionPhase.thinking) {
      return;
    }
    _input.clear();
    await _sendPrompt(text);
  }

  Future<void> _voice() async {
    setState(() {
      _chatOpen = true;
      _voiceOpen = true;
    });
    _focus.unfocus();
    AppScope.of(context).updateCompanionContext();
    if (!_companion!.isVoiceActive &&
        _companion!.phase != CompanionPhase.connecting) {
      await _companion!.startVoice();
    }
  }

  void _showTextChat() {
    setState(() => _voiceOpen = false);
  }

  Future<void> _endVoice() async {
    await _companion!.endSession();
    if (mounted) _showTextChat();
  }

  Future<void> _closeChat() async {
    _focus.unfocus();
    unawaited(_companion!.endSession());
    if (widget.startInConversation) {
      Navigator.of(context).maybePop();
    } else {
      setState(() {
        _chatOpen = false;
        _voiceOpen = false;
      });
    }
  }

  Future<void> _reconnectVoice() async {
    await _companion!.endSession();
    if (mounted) await _voice();
  }

  void _toggleSheet(double rest, double expanded) {
    if (!_sheet.hasClient) return;
    final target = (_sheet.value ?? rest) > rest + 40 ? rest : expanded;
    _sheet.animateTo(
      SheetOffset.absolute(target),
      duration: MediaQuery.disableAnimationsOf(context)
          // Smooth Sheets requires a positive duration and has no jump API.
          ? const Duration(microseconds: 1)
          : const Duration(milliseconds: 280),
      curve: const Cubic(.23, 1, .32, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final companion = _companion!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.viewPaddingOf(context).top;
    final foreground = dark ? const Color(0xFFF0F6FC) : AssistantColors.ink;
    final talking = companion.phase == CompanionPhase.speaking;
    return PopScope(
      canPop: !_chatOpen || widget.startInConversation,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeChat();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AssistantColors.sky(dark),
              stops: const [0, .50, 1],
            ),
          ),
          child: Column(
            children: [
              if (state.persistenceError != null)
                SafeArea(
                  bottom: false,
                  child: MaterialBanner(
                    content: Text(state.persistenceError!),
                    actions: [
                      TextButton(
                        onPressed: state.persist,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final compact = box.maxHeight < 570;
                    final maxExtent = math.max(160.0, box.maxHeight - top - 74);
                    final rest = math.min(
                      maxExtent,
                      math.max(210.0, box.maxHeight * .40),
                    );
                    final peek = math.min(rest, 150.0);
                    final largeSize = compact ? 230.0 : 300.0;
                    final mascotTop = compact
                        ? top + 76
                        : math.max(top + 158, box.maxHeight * .35);
                    final voicePanelHeight = math.min(
                      box.maxHeight - top - 80,
                      math.max(box.maxHeight / 3, 240.0),
                    );
                    final voiceSize = math.min(box.maxWidth, 390.0);
                    final voiceTop = math.max(
                      top + 60,
                      (box.maxHeight - voicePanelHeight - voiceSize) / 2,
                    );
                    return ClipRect(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (!compact)
                            Positioned(
                              top: top + 96,
                              left: 26,
                              right: 24,
                              child: ConversationMotion(
                                open: _chatOpen,
                                builder: (context, progress, child) =>
                                    ExcludeSemantics(
                                      excluding: _chatOpen,
                                      child: Opacity(
                                        opacity: (1 - progress).clamp(0.0, 1.0),
                                        child: Transform.translate(
                                          offset: Offset(0, -24 * progress),
                                          child: Transform.scale(
                                            alignment: Alignment.topLeft,
                                            scale: 1 - .12 * progress,
                                            child: child,
                                          ),
                                        ),
                                      ),
                                    ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: 'Your money,\n'),
                                      TextSpan(
                                        text: 'a little clearer.',
                                        style: TextStyle(
                                          fontFamily: 'Georgia',
                                          fontStyle: FontStyle.italic,
                                          color: foreground,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize:
                                        MediaQuery.textScalerOf(context)
                                                .scale(1) >
                                            1.5
                                        ? 28
                                        : 36,
                                    height: 1.15,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -1.1,
                                  ),
                                ),
                              ),
                            ),
                          ConversationMotion(
                            open: _chatOpen,
                            builder: (context, progress, child) =>
                                ConversationMotion(
                                  open: _voiceOpen,
                                  builder: (context, voiceProgress, child) {
                                    final targetSize =
                                        78 + (voiceSize - 78) * voiceProgress;
                                    final targetTop =
                                        top +
                                        2 +
                                        (voiceTop - top - 2) * voiceProgress;
                                    final size =
                                        largeSize +
                                        (targetSize - largeSize) * progress;
                                    return Positioned(
                                      top:
                                          mascotTop +
                                          (targetTop - mascotTop) * progress,
                                      left: (box.maxWidth - size) / 2,
                                      width: largeSize,
                                      height: largeSize,
                                      child: Transform.scale(
                                        alignment: Alignment.topLeft,
                                        scale: size / largeSize,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: child!,
                                ),
                            child: Cloudy(
                              key: const ValueKey('home_mascot'),
                              size: largeSize,
                              phase: companion.phase,
                              onTap: _voice,
                            ),
                          ),
                          Positioned.fill(
                            top: _voiceOpen
                                ? box.maxHeight - voicePanelHeight
                                : top + 92,
                            child: ConversationMotion(
                              open: _chatOpen,
                              builder: (context, progress, child) {
                                if (!_chatOpen && progress.abs() < .001) {
                                  return const SizedBox.shrink();
                                }
                                return IgnorePointer(
                                  ignoring: !_chatOpen,
                                  child: ExcludeSemantics(
                                    excluding: !_chatOpen,
                                    child: Opacity(
                                      opacity: progress.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(0, 18 * (1 - progress)),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: _voiceOpen
                                  ? VoiceCompanionPanel(
                                      key: const ValueKey(
                                        'voice_companion_panel',
                                      ),
                                      companion: companion,
                                      onMute: companion.toggleMute,
                                      onEnd: _endVoice,
                                      onChat: _showTextChat,
                                      transcript: _ConversationBody(
                                        companion: companion,
                                        scroll: _chatScroll,
                                        onRetry: _reconnectVoice,
                                        onSupport: widget.onSupport,
                                        voice: true,
                                      ),
                                    )
                                  : _ConversationBody(
                                      companion: companion,
                                      scroll: _chatScroll,
                                      onRetry: _reconnectVoice,
                                      onSupport: widget.onSupport,
                                    ),
                            ),
                          ),
                          IgnorePointer(
                            ignoring: _chatOpen,
                            child: ExcludeSemantics(
                              excluding: _chatOpen,
                              child: ConversationMotion(
                                open: _chatOpen,
                                builder: (context, progress, child) =>
                                    Transform.translate(
                                      key: const ValueKey('overview_motion'),
                                      offset: Offset(
                                        0,
                                        box.maxHeight * progress,
                                      ),
                                      child: Opacity(
                                        opacity: (1 - progress).clamp(0.0, 1.0),
                                        child: child,
                                      ),
                                    ),
                                child: SheetViewport(
                                  padding: EdgeInsets.only(
                                    top: top + 74,
                                    bottom: 4,
                                  ),
                                  child: Sheet(
                                    key: ValueKey(
                                      'financial_sheet_${state.profile.id}',
                                    ),
                                    controller: _sheet,
                                    initialOffset: SheetOffset.absolute(rest),
                                    snapGrid: SheetSnapGrid(
                                      snaps: [
                                        SheetOffset.absolute(peek),
                                        SheetOffset.absolute(rest),
                                        SheetOffset.absolute(maxExtent),
                                      ],
                                    ),
                                    scrollConfiguration:
                                        const SheetScrollConfiguration(),
                                    decoration: MaterialSheetDecoration(
                                      size: SheetSize.stretch,
                                      color: AppColors.surface(context),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(30),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      elevation: 0,
                                    ),
                                    child: _FinancialSheet(
                                      onSupport: widget.onSupport,
                                      onGrow: widget.onGrow,
                                      onToggle: () =>
                                          _toggleSheet(rest, maxExtent),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: top + 10,
                            left: 18,
                            right: 18,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_chatOpen)
                                  AssistantIconButton(
                                    key: const ValueKey('home_menu'),
                                    icon: CupertinoIcons.chevron_left,
                                    label: 'Back to your overview',
                                    onPressed: _closeChat,
                                  )
                                else
                                  const SizedBox.square(dimension: 48),
                                if (!_chatOpen)
                                  Text(
                                    'raise',
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.8,
                                    ),
                                  ),
                                AssistantIconButton(
                                  key: const ValueKey('open_profiles'),
                                  icon: CupertinoIcons.person_crop_circle,
                                  label: 'Demo profiles',
                                  onPressed: () =>
                                      openPage(context, const ProfilePage()),
                                  child: Text(
                                    state.profile.initials,
                                    style: TextStyle(
                                      color: foreground,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_chatOpen && !_voiceOpen)
                            Positioned(
                              top: top + 77,
                              left: 85,
                              right: 85,
                              child: Text(
                                talking
                                    ? 'Cloudy is speaking'
                                    : companion.phase ==
                                          CompanionPhase.listening
                                    ? 'Cloudy is listening'
                                    : 'Cloudy',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Offstage(
                offstage: _voiceOpen,
                child: CompanionComposer(
                  controller: _input,
                  focusNode: _focus,
                  companion: companion,
                  onSend: _send,
                  onVoice: _voice,
                  onStop: companion.stopSpeaking,
                  onPrompt: _sendPrompt,
                  showSuggestions: !_chatOpen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinancialSheet extends StatelessWidget {
  const _FinancialSheet({
    required this.onSupport,
    required this.onGrow,
    required this.onToggle,
  });
  final VoidCallback onSupport, onGrow, onToggle;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final forecast = state.forecast;
    final pressure = forecast.firstShortfall;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 9, 12, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted(context).withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'FOR YOU, ${state.profile.name.toUpperCase()}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '7 Nov · demo',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('expand_overview'),
                    tooltip: 'Expand or collapse your overview',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () {
                      final scroll = PrimaryScrollController.maybeOf(context);
                      if (scroll != null &&
                          scroll.hasClients &&
                          scroll.offset > 0) {
                        scroll.jumpTo(0);
                      }
                      onToggle();
                    },
                    icon: const Icon(
                      CupertinoIcons.chevron_up_chevron_down,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: PageStorageKey('prepare_${state.profile.id}'),
            padding: const EdgeInsets.fromLTRB(24, 3, 24, 30),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available today',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPence(state.profile.openingBalancePence),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          pressure == null
                              ? 'Your next 30 days'
                              : 'Expected ${formatDate(pressure.date)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pressure == null
                              ? 'Looking steady'
                              : '${formatPence(state.shortfallPence)} gap',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final singleColumn =
                      MediaQuery.textScalerOf(context).scale(16) > 22 ||
                      constraints.maxWidth < 300;
                  final tasks = [
                    _OverviewTaskCard(
                      key: const ValueKey('open_forecast'),
                      icon: CupertinoIcons.chart_bar_alt_fill,
                      title: 'Forecast',
                      subtitle: 'See money coming in and going out',
                      onPressed: () => openPage(context, const ForecastPage()),
                    ),
                    _OverviewTaskCard(
                      key: const ValueKey('open_comparison'),
                      icon: CupertinoIcons.arrow_left_right,
                      title: 'Expected vs actual',
                      subtitle: 'Look back at what changed',
                      onPressed: () => openPage(
                        context,
                        const ForecastPage(initialLookBack: true),
                      ),
                    ),
                    _OverviewTaskCard(
                      key: const ValueKey('open_support'),
                      icon: CupertinoIcons.heart,
                      title: 'Get support',
                      subtitle: state.recovery == null
                          ? 'Make a plan'
                          : 'Your saved support plan',
                      onPressed: onSupport,
                    ),
                    _OverviewTaskCard(
                      key: const ValueKey('open_savings'),
                      icon: CupertinoIcons.leaf_arrow_circlepath,
                      title: 'Savings goal',
                      subtitle: state.goal == null
                          ? 'Start your emergency buffer'
                          : '${state.goal!.title} · ${formatPence(state.goal!.savedPence)} of ${formatPence(state.goal!.targetPence)} recorded',
                      onPressed: onGrow,
                    ),
                  ];
                  if (singleColumn) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 10,
                      children: tasks,
                    );
                  }
                  return Column(
                    spacing: 10,
                    children: [
                      for (var row = 0; row < 2; row++)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: 10,
                            children: [
                              Expanded(child: tasks[row * 2]),
                              Expanded(child: tasks[row * 2 + 1]),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              const SectionHeading('Your next 30 days'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoneyMetric(
                      'Expected income',
                      forecast.totalIncomePence,
                    ),
                  ),
                  Expanded(
                    child: _MoneyMetric(
                      'Planned spending',
                      forecast.totalOutgoingsPence,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              ForecastChart(forecast: forecast, compact: true),
              const SizedBox(height: 20),
              SectionHeading(
                'Coming up',
                action: 'See all',
                onAction: () => openPage(context, const LedgerPage()),
              ),
              ...forecast.entries.take(4).map((e) => LedgerRow(e)),
              const SizedBox(height: 20),
              Text(
                'Synthetic UK demo · 7 Nov 2026\nFuture amounts and dates are estimates.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewTaskCard extends StatelessWidget {
  const _OverviewTaskCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 100),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(15),
      foregroundColor: AppColors.ink(context),
      backgroundColor: AppColors.canvas(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.line(context)),
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.accent(context)),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric(this.label, this.amount);
  final String label;
  final int amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 5),
      Text(formatPence(amount), style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({
    required this.companion,
    required this.scroll,
    required this.onRetry,
    required this.onSupport,
    this.voice = false,
  });
  final bool voice;
  final CompanionController companion;
  final ScrollController scroll;
  final VoidCallback onRetry, onSupport;
  @override
  Widget build(BuildContext context) {
    final busy =
        companion.phase == CompanionPhase.connecting ||
        companion.phase == CompanionPhase.thinking;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      key: const ValueKey('conversation_messages'),
      controller: scroll,
      padding: EdgeInsets.fromLTRB(22, voice ? 8 : 22, 22, 16),
      children: [
        if (companion.messages.isEmpty && !busy && companion.error == null)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              voice
                  ? 'Your conversation will appear here.'
                  : 'I’m here. What’s on your mind?',
              style: TextStyle(
                fontSize: voice ? 14 : 22,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: dark ? const Color(0xFFF0F6FC) : AssistantColors.ink,
              ),
            ),
          ),
        ...companion.messages.map((m) => CompanionBubble(m)),
        if (busy)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                companion.phase == CompanionPhase.connecting
                    ? 'Connecting…'
                    : 'Cloudy is thinking…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (companion.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Surface(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companion.error!),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Reconnect'),
                  ),
                  if (companion.lastVoiceDiagnostic != null ||
                      companion.lastTextDiagnostic != null)
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                companion.lastVoiceDiagnostic ??
                                companion.lastTextDiagnostic!,
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Connection details copied'),
                          ),
                        );
                      },
                      child: const Text('Copy connection details'),
                    ),
                ],
              ),
            ),
          ),
        if (companion.messages.isNotEmpty && !voice)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onSupport,
              child: const Text('Make a support plan'),
            ),
          ),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Row(
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: AppColors.accent(context),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            CupertinoIcons.arrow_turn_up_right,
            color: Theme.of(context).colorScheme.onPrimary,
            size: 22,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'second chance',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(letterSpacing: -.6),
          ),
        ),
        TextButton(
          key: const ValueKey('open_profiles'),
          onPressed: () => openPage(context, const ProfilePage()),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: AppColors.ink(context),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.line(context),
                child: Text(
                  state.profile.initials,
                  style: TextStyle(
                    color: AppColors.ink(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(CupertinoIcons.chevron_down, size: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class LedgerRow extends StatelessWidget {
  const LedgerRow(this.entry, {super.key});
  final LedgerEntry entry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: AppColors.canvas(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            entry.isIncome
                ? CupertinoIcons.arrow_down_left
                : CupertinoIcons.arrow_up_right,
            size: 17,
            color: AppColors.muted(context),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${formatDate(entry.date)}${entry.isEstimate ? ' · expected' : ' · synthetic record'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${entry.isIncome ? '+' : '−'}${formatPence(entry.amountPence.abs(), decimals: entry.amountPence % 100 != 0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: entry.isIncome
                ? Theme.of(context).colorScheme.secondary
                : AppColors.ink(context),
          ),
        ),
      ],
    ),
  );
}
