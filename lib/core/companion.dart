import 'dart:async';
import 'dart:convert';

import 'package:elevenlabs_agents/elevenlabs_agents.dart' as eleven;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum CompanionPhase { idle, connecting, listening, thinking, speaking, error }

class CompanionMessage {
  const CompanionMessage({
    required this.role,
    required this.text,
    this.isFallback = false,
  });

  final String role;
  final String text;
  final bool isFallback;
}

class CompanionController extends ChangeNotifier {
  CompanionController({
    this.agentId = const String.fromEnvironment(
      'ELEVENLABS_AGENT_ID',
      defaultValue: 'agent_8301m6v7kzdgfza9119295h54skt',
    ),
  });

  final String agentId;
  final List<CompanionMessage> _messages = [];
  Map<String, Object?> _context = {};
  eleven.ConversationClient? _voice;
  WebSocketChannel? _text;
  StreamSubscription<Object?>? _textSubscription;
  Timer? _replyTimer;
  Completer<void>? _textReady;
  String? _conversationId;
  bool _disposed = false;
  bool _ending = false;
  bool _usingFallback = false;
  bool _textConnected = false;
  int _sessionGeneration = 0;

  CompanionPhase phase = CompanionPhase.idle;
  String? error;

  List<CompanionMessage> get messages => List.unmodifiable(_messages);
  bool get liveConfigured => agentId.isNotEmpty;
  bool get isVoiceActive =>
      _voice != null &&
      _voice!.status != eleven.ConversationStatus.disconnected;
  bool get isConnected =>
      _textConnected || _voice?.status == eleven.ConversationStatus.connected;
  bool get isMuted => _voice?.isMuted ?? true;
  String? get conversationId => _conversationId;
  String get modeLabel => _usingFallback
      ? 'Calculated demo guidance'
      : isVoiceActive
      ? 'ElevenLabs · live voice'
      : _textConnected
      ? 'ElevenLabs · live text'
      : 'Pip · ready to connect';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void updateContext(Map<String, Object?> context) {
    if (jsonEncode(context) == jsonEncode(_context)) return;
    final oldProfile = (_context['profile'] as Map?)?['id'];
    final newProfile = (context['profile'] as Map?)?['id'];
    _context = Map.of(context);
    if (oldProfile != null && oldProfile != newProfile) {
      _messages.clear();
      _usingFallback = false;
      unawaited(endSession());
      return;
    }
    if (_textConnected) {
      _sendSocket({'type': 'contextual_update', 'text': _contextText});
    }
    if (_voice?.status == eleven.ConversationStatus.connected) {
      _voice!.sendContextualUpdate(_contextText);
    }
  }

  String get _contextText =>
      'Current app-calculated synthetic financial snapshot. '
      'All monetary values are already formatted in GBP. Copy these values exactly; '
      'do not divide them or convert units. Do not invent missing figures. '
      '${jsonEncode(companionContextForModel(_context))}';

  String get _historyText => jsonEncode(
    _messages
        .where((message) => !message.isFallback)
        .takeLast(12)
        .map((message) => {'role': message.role, 'text': message.text})
        .toList(),
  );

  Future<void> sendText(String text) async {
    final message = text.trim();
    if (message.isEmpty || _disposed) return;
    if (message.length > 2000) {
      error = 'Please keep your message under 2,000 characters.';
      _notify();
      return;
    }
    if (phase == CompanionPhase.connecting ||
        phase == CompanionPhase.thinking) {
      return;
    }
    final generation = _sessionGeneration;
    error = null;
    _messages.add(CompanionMessage(role: 'user', text: message));
    phase = CompanionPhase.thinking;
    _notify();
    if (!liveConfigured) {
      _replyWithFallback(message);
      return;
    }
    try {
      if (_voice?.status == eleven.ConversationStatus.connected) {
        _voice!.sendUserMessage(message);
      } else {
        await _connectText();
        if (_disposed || generation != _sessionGeneration) return;
        _sendSocket({'type': 'user_message', 'text': message});
      }
      _replyTimer?.cancel();
      _replyTimer = Timer(const Duration(seconds: 35), () {
        if (phase != CompanionPhase.thinking ||
            generation != _sessionGeneration) {
          return;
        }
        error = 'Pip is taking too long. You can retry the connection.';
        unawaited(endSession());
        _replyWithFallback(message);
      });
    } catch (_) {
      if (_disposed || generation != _sessionGeneration) return;
      await endSession();
      if (_disposed) return;
      error = 'Live chat is unavailable. This reply uses your calculated demo figures. Try voice or send again to reconnect.';
      _replyWithFallback(message);
    }
  }

  Future<void> _connectText() async {
    if (_textConnected) return;
    await _closeText();
    final generation = _sessionGeneration;
    final channel = WebSocketChannel.connect(
      Uri.https('api.elevenlabs.io', '/v1/convai/conversation', {
        'agent_id': agentId,
      }).replace(scheme: 'wss'),
    );
    _text = channel;
    await channel.ready.timeout(const Duration(seconds: 12));
    if (_disposed || generation != _sessionGeneration) {
      await channel.sink.close();
      throw StateError('Session cancelled');
    }
    _textReady = Completer<void>();
    _textSubscription = channel.stream.listen(
      (event) => _handleTextEvent(event, generation),
      onError: (Object _) => _handleTextClosed(generation),
      onDone: () => _handleTextClosed(generation),
    );
    _sendSocket({
      'type': 'conversation_initiation_client_data',
      'conversation_config_override': {
        'conversation': {'text_only': true},
      },
    });
    await _textReady!.future.timeout(const Duration(seconds: 15));
    _sendSocket({'type': 'contextual_update', 'text': _contextText});
    if (_messages.length > 1) {
      _sendSocket({
        'type': 'contextual_update',
        'text': 'Previous visible conversation: $_historyText',
      });
    }
  }

  void _sendSocket(Map<String, Object?> event) =>
      _text?.sink.add(jsonEncode(event));

  void _handleTextEvent(Object? raw, int generation) {
    if (_disposed || generation != _sessionGeneration || raw is! String) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, Object?>) return;
      switch (data['type']) {
        case 'conversation_initiation_metadata':
          final metadata =
              data['conversation_initiation_metadata_event'] as Map?;
          _conversationId = metadata?['conversation_id'] as String?;
          _textConnected = true;
          _usingFallback = false;
          if (!(_textReady?.isCompleted ?? true)) _textReady!.complete();
          _notify();
        case 'ping':
          _sendSocket({
            'type': 'pong',
            'event_id': (data['ping_event'] as Map?)?['event_id'],
          });
        case 'agent_response':
          final text =
              (data['agent_response_event'] as Map?)?['agent_response'];
          if (text is String && text.isNotEmpty) {
            _receiveMessage('assistant', text);
          }
        case 'agent_response_correction':
          final text =
              (data['agent_response_correction_event']
                  as Map?)?['corrected_agent_response'];
          if (text is String &&
              _messages.isNotEmpty &&
              _messages.last.role == 'assistant') {
            _messages[_messages.length - 1] = CompanionMessage(
              role: 'assistant',
              text: text,
            );
            _notify();
          }
        case 'error':
          _handleTextClosed(generation);
      }
    } catch (_) {
      error = 'Pip received an unreadable reply. Please reconnect.';
      _notify();
    }
  }

  void _handleTextClosed(int generation) {
    if (_disposed || generation != _sessionGeneration || _ending) return;
    _textConnected = false;
    if (!(_textReady?.isCompleted ?? true)) {
      _textReady!.completeError(StateError('Connection closed'));
    }
    if (phase != CompanionPhase.thinking) {
      phase = CompanionPhase.idle;
      error = 'The connection ended. Your conversation is kept here; send a message to reconnect.';
    }
    _notify();
  }

  void _receiveMessage(String role, String text) {
    if (_disposed) return;
    if (_messages.isNotEmpty &&
        _messages.last.role == role &&
        _messages.last.text == text) {
      return;
    }
    _messages.add(CompanionMessage(role: role, text: text));
    if (role == 'user') phase = CompanionPhase.thinking;
    if (role == 'assistant') {
      _replyTimer?.cancel();
      _usingFallback = false;
      phase = isVoiceActive ? CompanionPhase.speaking : CompanionPhase.idle;
    }
    _notify();
  }

  Future<void> startVoice() async {
    if (_disposed || isVoiceActive || phase == CompanionPhase.connecting) {
      return;
    }
    await endSession();
    if (!liveConfigured) {
      phase = CompanionPhase.error;
      error = 'Voice needs an ElevenLabs agent. You can still use calculated text guidance.';
      _notify();
      return;
    }
    final generation = _sessionGeneration;
    phase = CompanionPhase.connecting;
    error = null;
    _notify();
    try {
      final permission = await Permission.microphone.request();
      if (_disposed || generation != _sessionGeneration) return;
      if (!permission.isGranted) {
        phase = CompanionPhase.error;
        error = 'Microphone access is off. Enable Second Chance in Settings, or continue by text.';
        _notify();
        return;
      }
    } catch (_) {
      phase = CompanionPhase.error;
      error = 'We couldn’t access the microphone. You can continue by text and try voice again.';
      _notify();
      return;
    }
    final client = eleven.ConversationClient(
      callbacks: eleven.ConversationCallbacks(
        onConnect: ({required conversationId}) {
          if (_disposed || generation != _sessionGeneration) return;
          _conversationId = conversationId;
          _usingFallback = false;
          _notify();
        },
        onMessage: ({required message, required source}) {
          if (generation == _sessionGeneration) {
            _receiveMessage(
              source == eleven.Role.user ? 'user' : 'assistant',
              message,
            );
          }
        },
        onUserTranscript: ({required transcript, required eventId}) {
          if (generation == _sessionGeneration) {
            _receiveMessage('user', transcript);
          }
        },
        onModeChange: ({required mode}) {
          if (_disposed || generation != _sessionGeneration) return;
          phase = mode == eleven.ConversationMode.speaking
              ? CompanionPhase.speaking
              : CompanionPhase.listening;
          _notify();
        },
        onDisconnect: (_) {
          if (_disposed || generation != _sessionGeneration || _ending) return;
          phase = CompanionPhase.idle;
          _notify();
        },
        onError: (message, [details]) {
          if (_disposed || generation != _sessionGeneration || _ending) return;
          error = companionVoiceErrorMessage(details ?? message);
          phase = CompanionPhase.error;
          _notify();
        },
      ),
    );
    _voice = client;
    try {
      await client
          .startSession(agentId: agentId)
          .timeout(const Duration(seconds: 25));
      if (_disposed || generation != _sessionGeneration) {
        if (_voice == client) {
          await client.endSession();
          client.dispose();
          _voice = null;
        }
        return;
      }
      client.sendContextualUpdate(_contextText);
      if (_messages.isNotEmpty) {
        client.sendContextualUpdate(
          'Previous visible conversation: $_historyText',
        );
      }
      phase = CompanionPhase.listening;
      _usingFallback = false;
      _notify();
    } catch (failure) {
      if (_voice == client) {
        await client.endSession();
        client.dispose();
        _voice = null;
      }
      if (_disposed || generation != _sessionGeneration) return;
      phase = CompanionPhase.error;
      error = companionVoiceErrorMessage(failure);
      _notify();
    }
  }

  Future<void> toggleMute() async {
    await _voice?.toggleMute();
    _notify();
  }

  // shortcut: the SDK has no output-pause API; end the session to stop audio immediately.
  Future<void> stopSpeaking() => endSession();

  Future<void> _closeText() async {
    _textConnected = false;
    await _textSubscription?.cancel();
    _textSubscription = null;
    await _text?.sink.close();
    _text = null;
    _textReady = null;
  }

  Future<void> endSession() async {
    _ending = true;
    _sessionGeneration++;
    _replyTimer?.cancel();
    await _closeText();
    final voice = _voice;
    _voice = null;
    await voice?.endSession();
    voice?.dispose();
    _ending = false;
    phase = CompanionPhase.idle;
    _notify();
  }

  void _replyWithFallback(String input) {
    _usingFallback = true;
    _messages.add(
      CompanionMessage(
        role: 'assistant',
        text: calculatedCompanionReply(input, _context),
        isFallback: true,
      ),
    );
    phase = CompanionPhase.idle;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _replyTimer?.cancel();
    unawaited(endSession());
    super.dispose();
  }
}

String calculatedCompanionReply(String input, Map<String, Object?> context) {
  final profile = context['profile'] as Map? ?? {};
  final forecast = context['forecast'] as Map? ?? {};
  final goal = context['goal'] as Map? ?? {};
  final question = input.toLowerCase();
  final name = profile['name'] as String? ?? 'you';
  final firstGap =
      ((context['shortfallPence'] ?? forecast['shortfallPence']) as num?)
          ?.toInt() ??
      0;
  final lowestBalance = (context['lowestBalancePence'] as num?)?.toInt();
  final shortfall =
      (context['maximumShortfallPence'] as num?)?.toInt() ??
      (lowestBalance != null && lowestBalance < 0 ? -lowestBalance : firstGap);
  final rawDate =
      (context['shortfallDate'] ??
              forecast['shortfallDate'] ??
              (forecast['firstShortfall'] as Map?)?['date'])
          as String?;
  final date = rawDate == null ? 'the forecast date' : rawDate.split('T').first;
  final rawLowestDate =
      (context['lowestDate'] ?? (forecast['lowestDay'] as Map?)?['date'])
          as String?;
  final lowestDate = rawLowestDate?.split('T').first;
  final gapTiming = lowestDate == null ? '' : ' on $lowestDate';
  final causes =
      ((context['causes'] ?? forecast['causes'] ?? forecast['pressureCauses'])
              as List?)
          ?.whereType<String>()
          .join('; ');
  final summary = context['summary'] as String?;
  if (question.contains('credit')) {
    return '${profile['creditExplanation'] ?? 'Checking a free credit report can help you spot incorrect information. Correcting errors may help lenders assess you accurately; a score increase is not guaranteed.'} You do not need to borrow money to make progress.';
  }
  if (RegExp(r'sav|goal|buffer|grow|progress').hasMatch(question)) {
    final saved = (goal['savedPence'] as num?)?.toInt();
    final target = (goal['targetPence'] as num?)?.toInt();
    return '${saved != null && target != null ? 'Your recorded goal is ${_pounds(saved)} towards ${_pounds(target)}. ' : ''}Choose an amount that leaves enough for essentials. If money is tight, reviewing a bill is a useful positive action too.';
  }
  if (RegExp(r'plan|support|help|next|draft|worr|stress|anxious')
      .hasMatch(question)) {
    return '${shortfall > 0 ? 'A forecast ${_pounds(shortfall)} gap can feel worrying, $name. ' : 'We can take this one step at a time, $name. '}Open Build a recovery plan to prepare a request to your provider, with your figures and evidence checklist. Review the draft before using it; nothing is sent and support is not guaranteed.';
  }
  if (RegExp(r'change|what if|scenario|less|income|spend|save')
      .hasMatch(question)) {
    return 'Time travel lets you change income, weekly spending or a one-off cost. ${shortfall > 0 ? 'Your current calculated scenario reaches a largest gap of ${_pounds(shortfall)}$gapTiming. ' : 'Your current calculated scenario has no forecast negative daily closing balance. '}These are estimates, so check timing with your provider before relying on them.';
  }
  if (shortfall > 0) {
    return 'Your calculated forecast first falls below zero on $date. Its largest projected gap is ${_pounds(shortfall)}$gapTiming. ${causes?.isNotEmpty ?? false ? '$causes. ' : ''}Try a different assumption in Time travel, or prepare a support request before the payment is due.';
  }
  return summary ??
      'Your selected forecast has no negative daily closing balance. Keep a small buffer for uncertain dates and review your commitments before setting a savings amount.';
}

String _pounds(int pence) =>
    '£${(pence / 100).toStringAsFixed(pence % 100 == 0 ? 0 : 2)}';

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final items = toList();
    return items.skip(items.length > count ? items.length - count : 0);
  }
}

// Give the language model display amounts so it never needs to convert pence.
Object? companionContextForModel(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        if (entry.key is String)
          if ((entry.key as String).endsWith('Pence') && entry.value is num)
            (entry.key as String).replaceFirst(RegExp(r'Pence$'), 'GBP'):
                _pounds((entry.value as num).toInt())
          else
            entry.key as String: companionContextForModel(entry.value),
    };
  }
  if (value is List) return value.map(companionContextForModel).toList();
  return value;
}

String companionVoiceErrorMessage(Object? failure) {
  final detail = failure.toString().toLowerCase();
  if (RegExp(r'permission|notallowed|not allowed|denied|not authorized')
      .hasMatch(detail)) {
    return 'Microphone access is off. Enable microphone access for Second Chance in Settings, then retry voice. You can continue by text.';
  }
  if (detail.contains('timeout') || detail.contains('timed out')) {
    return 'Voice took too long to connect. Check your internet connection and try again, or continue by text.';
  }
  return 'Voice is unavailable. Check microphone access and your internet connection, then retry. You can continue by text.';
}
