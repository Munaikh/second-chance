import 'dart:convert';

/// Validates the small native component catalogue available to Cloudy.
Map<String, Object?> parseGeneratedUi(String source) {
  if (source.length > 16000) {
    throw const FormatException(
      'Keep the UI document under 16,000 characters.',
    );
  }
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('ui_json must contain a JSON object.');
  }
  _keys(decoded, {'title', 'description', 'components'});
  final raw = decoded['components'];
  if (raw is! List || raw.isEmpty || raw.length > 8) {
    throw const FormatException('Include between one and eight UI components.');
  }
  final components = <Map<String, Object?>>[];
  final singleControls = <String>{};
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Every UI component must be an object.');
    }
    final type = _text(item['type'], 'type', 32);
    final component = <String, Object?>{'type': type};
    switch (type) {
      case 'text':
        _keys(item, {'type', 'text'});
        component['text'] = _text(item['text'], 'text', 1000);
      case 'metrics':
      case 'chart':
        _keys(item, {'type', 'source'});
        final sources = type == 'chart'
            ? {'forecast', 'history'}
            : {'forecast', 'history', 'goal'};
        if (!sources.contains(item['source'])) {
          throw FormatException(
            '$type source must be ${sources.join(' or ')}.',
          );
        }
        component['source'] = item['source'];
      case 'scenario_controls':
        _keys(item, {'type'});
        if (!singleControls.add(type)) {
          throw const FormatException('Use scenario_controls only once.');
        }
      case 'goal_form':
        _keys(item, {'type', 'title', 'target_gbp'});
        if (!singleControls.add(type)) {
          throw const FormatException('Use goal_form only once.');
        }
        if (item.containsKey('title')) {
          component['title'] = _text(item['title'], 'goal title', 60);
        }
        if (item.containsKey('target_gbp')) {
          final target = item['target_gbp'];
          if (target is! num ||
              !target.isFinite ||
              target < 1 ||
              target > 100000) {
            throw const FormatException('The goal target must be £1–£100,000.');
          }
          component['target_gbp'] = target;
        }
      case 'checklist':
        _keys(item, {'type', 'items'});
        final items = item['items'];
        if (items is! List || items.isEmpty || items.length > 8) {
          throw const FormatException('Include one to eight checklist items.');
        }
        component['items'] = [
          for (final text in items) _text(text, 'checklist item', 200),
        ];
      case 'choices':
        _keys(item, {'type', 'options'});
        final options = item['options'];
        if (options is! List || options.isEmpty || options.length > 4) {
          throw const FormatException('Include one to four choices.');
        }
        component['options'] = [for (final option in options) _prompt(option)];
      case 'action':
        _keys(item, {'type', 'label', 'prompt'});
        component.addAll(
          _prompt({'label': item['label'], 'prompt': item['prompt']}),
        );
      default:
        throw FormatException('Unsupported UI component: $type.');
    }
    components.add(component);
  }
  return {
    'title': _text(decoded['title'], 'title', 100),
    if (decoded.containsKey('description'))
      'description': _text(decoded['description'], 'description', 400),
    'components': components,
  };
}

Map<String, Object?> _prompt(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('A choice must contain a label and prompt.');
  }
  _keys(value, {'label', 'prompt'});
  return {
    'label': _text(value['label'], 'button label', 60),
    'prompt': _text(value['prompt'], 'button prompt', 600),
  };
}

String _text(Object? value, String field, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.trim().length > maximum) {
    throw FormatException('$field must have 1–$maximum characters.');
  }
  return value.trim();
}

void _keys(Map<String, dynamic> value, Set<String> allowed) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw FormatException('Supported fields: ${allowed.join(', ')}.');
  }
}
