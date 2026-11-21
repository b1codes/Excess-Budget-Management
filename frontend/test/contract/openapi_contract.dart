// Consumer-side contract checks against the backend's committed OpenAPI
// schema (backend/openapi.json).
//
// The backend fails its own tests when that file drifts from what the API
// serves (apps/common/tests/test_openapi_snapshot.py), so checking the client
// against it here checks the client against the real API without running it.
//
// This is a small JSON Schema validator for the subset pydantic and
// django-ninja emit ($ref, anyOf, type, enum, format, pattern, length and range
// limits, required, properties, items), plus two rules JSON Schema can't say:
//
// * Objects are closed. A key the schema doesn't list is an error, because in a
//   response fixture it's a field the client reads that the API never sends
//   (goal_accounts and user_id slipped through this way), and in a request
//   it's a field pydantic silently drops.
// * In requests, Decimal fields (money, rates, hours) are sent as strings
//   ("12.50"), never JSON numbers. The API rejects values with more decimal
//   places than the field allows, and a double such as 0.1 + 0.2 serialises
//   as 0.30000000000000004.

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../helpers/fake_api.dart';

const kApiPrefix = '/api/v1';

/// Whether a value is a response from the API or a request the client sends.
enum Direction { response, request }

class OpenApiContract {
  OpenApiContract._(this.document);

  /// Loads backend/openapi.json. Flutter runs tests from frontend/.
  factory OpenApiContract.load() {
    final file = File('../backend/openapi.json');
    if (!file.existsSync()) {
      throw StateError(
        'backend/openapi.json not found from ${Directory.current.path}. '
        'Run the tests from frontend/, or regenerate it with `make openapi`.',
      );
    }
    return OpenApiContract._(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  }

  final Map<String, dynamic> document;

  Map<String, dynamic> get schemas =>
      (document['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;

  Map<String, dynamic> get paths => document['paths'] as Map<String, dynamic>;

  Map<String, dynamic> schemaNamed(String name) {
    final schema = schemas[name];
    if (schema == null) throw ArgumentError('No schema named $name');
    return schema as Map<String, dynamic>;
  }

  Map<String, dynamic> _resolve(Map<String, dynamic> schema) {
    final ref = schema[r'$ref'] as String?;
    if (ref == null) return schema;
    const prefix = '#/components/schemas/';
    if (!ref.startsWith(prefix)) {
      throw UnsupportedError('Unsupported \$ref $ref');
    }
    return _resolve(schemaNamed(ref.substring(prefix.length)));
  }

  // ── Validation ─────────────────────────────────────────────────────────────

  /// Problems with [value] against [schema], as `path: message` strings.
  ///
  /// With [opaqueIds], `format: uuid` only requires a string. Test fixtures use
  /// readable ids such as "goal-1", and the client treats ids as opaque.
  List<String> validate(
    Object? value,
    Map<String, dynamic> schema, {
    Direction direction = Direction.response,
    bool opaqueIds = false,
  }) {
    final errors = <String>[];
    _validate(value, schema, r'$', errors, direction, opaqueIds);
    return errors;
  }

  List<String> validateAgainst(
    Object? value,
    String schemaName, {
    Direction direction = Direction.response,
    bool opaqueIds = false,
  }) => validate(
    value,
    schemaNamed(schemaName),
    direction: direction,
    opaqueIds: opaqueIds,
  );

  void _validate(
    Object? value,
    Map<String, dynamic> rawSchema,
    String at,
    List<String> errors,
    Direction direction,
    bool opaqueIds,
  ) {
    final schema = _resolve(rawSchema);

    final anyOf = schema['anyOf'] as List<dynamic>?;
    if (anyOf != null) {
      final branches = anyOf.cast<Map<String, dynamic>>();
      if (direction == Direction.request &&
          value is num &&
          _isDecimal(branches)) {
        errors.add(
          '$at: send Decimal fields as a string (e.g. '
          '"${value.toStringAsFixed(2)}"), not the number $value',
        );
        return;
      }
      List<String>? closest;
      for (final branch in branches) {
        final branchErrors = <String>[];
        _validate(value, branch, at, branchErrors, direction, opaqueIds);
        if (branchErrors.isEmpty) return;
        if (closest == null || branchErrors.length < closest.length) {
          closest = branchErrors;
        }
      }
      errors.addAll(closest ?? ['$at: no anyOf branch matched']);
      return;
    }

    if (schema.containsKey('const') && value != schema['const']) {
      errors.add('$at: expected ${jsonEncode(schema['const'])}');
      return;
    }
    final enumValues = schema['enum'] as List<dynamic>?;
    if (enumValues != null && !enumValues.contains(value)) {
      errors.add('$at: ${jsonEncode(value)} is not one of $enumValues');
      return;
    }

    final type = schema['type'] as String?;
    switch (type) {
      case null:
        return; // Unconstrained.
      case 'null':
        if (value != null) errors.add('$at: expected null');
      case 'boolean':
        if (value is! bool) errors.add('$at: expected a boolean');
      case 'integer':
        if (value is! int) {
          errors.add('$at: expected an integer, got ${jsonEncode(value)}');
        } else {
          _checkRange(value, schema, at, errors);
        }
      case 'number':
        if (value is! num) {
          errors.add('$at: expected a number, got ${jsonEncode(value)}');
        } else {
          _checkRange(value, schema, at, errors);
        }
      case 'string':
        if (value is! String) {
          errors.add('$at: expected a string, got ${jsonEncode(value)}');
        } else {
          _checkString(value, schema, at, errors, opaqueIds);
        }
      case 'array':
        if (value is! List) {
          errors.add('$at: expected an array, got ${jsonEncode(value)}');
          return;
        }
        final items = schema['items'] as Map<String, dynamic>?;
        if (items == null) return;
        for (var i = 0; i < value.length; i++) {
          _validate(value[i], items, '$at[$i]', errors, direction, opaqueIds);
        }
      case 'object':
        if (value is! Map) {
          errors.add('$at: expected an object, got ${jsonEncode(value)}');
          return;
        }
        final properties =
            (schema['properties'] as Map<String, dynamic>?) ?? const {};
        final required =
            (schema['required'] as List<dynamic>?)?.cast<String>() ?? const [];
        for (final key in required) {
          if (!value.containsKey(key)) errors.add('$at: missing "$key"');
        }
        for (final entry in value.entries) {
          final key = entry.key as String;
          final propertySchema = properties[key] as Map<String, dynamic>?;
          if (propertySchema == null) {
            errors.add(
              '$at: "$key" is not in ${schema['title'] ?? 'the schema'}',
            );
            continue;
          }
          _validate(
            entry.value,
            propertySchema,
            '$at.$key',
            errors,
            direction,
            opaqueIds,
          );
        }
      default:
        throw UnsupportedError('Unsupported schema type $type at $at');
    }
  }

  /// A pydantic Decimal: a number branch alongside a pattern-checked string.
  static bool _isDecimal(List<Map<String, dynamic>> branches) =>
      branches.any((b) => b['type'] == 'number') &&
      branches.any((b) => b['type'] == 'string' && b['pattern'] != null);

  static void _checkRange(
    num value,
    Map<String, dynamic> schema,
    String at,
    List<String> errors,
  ) {
    final min = schema['minimum'] as num?;
    final max = schema['maximum'] as num?;
    if (min != null && value < min) errors.add('$at: $value < minimum $min');
    if (max != null && value > max) errors.add('$at: $value > maximum $max');
  }

  // pydantic's Decimal pattern can match an empty prefix, so it accepts any
  // string ("twelve" included). Decimal strings are checked here instead: a
  // plain number with no more decimal places than the field allows.
  static const _decimalPatternPrefix = r'^(?!^[-+.]*$)';
  static final _decimal = RegExp(r'^[+-]?\d+(\.(\d+))?$');
  static final _decimalPlaces = RegExp(r'\\.\\d\{0,(\d+)\}');

  static void _checkDecimal(
    String value,
    String pattern,
    String at,
    List<String> errors,
  ) {
    final match = _decimal.firstMatch(value);
    if (match == null) {
      errors.add('$at: "$value" is not a decimal number');
      return;
    }
    final places = _decimalPlaces.firstMatch(pattern)?.group(1);
    final sent = match.group(2)?.length ?? 0;
    if (places != null && sent > int.parse(places)) {
      errors.add('$at: "$value" has more than $places decimal places');
    }
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static void _checkString(
    String value,
    Map<String, dynamic> schema,
    String at,
    List<String> errors,
    bool opaqueIds,
  ) {
    final minLength = schema['minLength'] as int?;
    final maxLength = schema['maxLength'] as int?;
    if (minLength != null && value.length < minLength) {
      errors.add('$at: shorter than $minLength characters');
    }
    if (maxLength != null && value.length > maxLength) {
      errors.add('$at: longer than $maxLength characters');
    }
    final pattern = schema['pattern'] as String?;
    if (pattern != null && pattern.startsWith(_decimalPatternPrefix)) {
      _checkDecimal(value, pattern, at, errors);
    } else if (pattern != null && !RegExp(pattern).hasMatch(value)) {
      errors.add('$at: "$value" does not match $pattern');
    }
    switch (schema['format']) {
      case 'uuid' when !opaqueIds && !_uuid.hasMatch(value):
        errors.add('$at: "$value" is not a uuid');
      case 'date'
          when !_date.hasMatch(value) || DateTime.tryParse(value) == null:
        errors.add('$at: "$value" is not a YYYY-MM-DD date');
      case 'date-time'
          when !value.contains('T') || DateTime.tryParse(value) == null:
        errors.add('$at: "$value" is not an ISO 8601 date-time');
      case 'email' when !value.contains('@'):
        errors.add('$at: "$value" is not an email address');
    }
  }

  // ── Examples ───────────────────────────────────────────────────────────────

  /// A value the API could send for [schema].
  ///
  /// [full] fills in every optional field and picks a non-null branch of every
  /// nullable one, with one item in each array. Otherwise only required fields
  /// are sent, nullable ones are null and arrays are empty. A client parser
  /// has to cope with both.
  Object? example(Map<String, dynamic> rawSchema, {required bool full}) {
    final schema = _resolve(rawSchema);
    final anyOf = schema['anyOf'] as List<dynamic>?;
    if (anyOf != null) {
      final branches = anyOf.cast<Map<String, dynamic>>();
      final nonNull = branches.where((b) => b['type'] != 'null').toList();
      if (!full && nonNull.length < branches.length) return null;
      return example(nonNull.first, full: full);
    }
    if (schema.containsKey('const')) return schema['const'];
    final enumValues = schema['enum'] as List<dynamic>?;
    if (enumValues != null) return enumValues.first;

    switch (schema['type']) {
      case 'null':
        return null;
      case 'boolean':
        return true;
      case 'integer':
        return (schema['minimum'] as num?)?.ceil() ?? 1;
      case 'number':
        final min = schema['minimum'] as num?;
        final max = schema['maximum'] as num?;
        if (min != null && max != null) return (min + max) / 2;
        return (min ?? 0) + 1.5;
      case 'string':
        return _exampleString(schema);
      case 'array':
        if (!full) return <Object?>[];
        return [example(schema['items'] as Map<String, dynamic>, full: full)];
      case 'object':
        final properties =
            (schema['properties'] as Map<String, dynamic>?) ?? const {};
        final required =
            (schema['required'] as List<dynamic>?)?.cast<String>() ?? const [];
        return {
          for (final entry in properties.entries)
            if (full || required.contains(entry.key))
              entry.key: example(
                entry.value as Map<String, dynamic>,
                full: full,
              ),
        };
      default:
        throw UnsupportedError('No example for ${jsonEncode(schema)}');
    }
  }

  Object? exampleOf(String schemaName, {required bool full}) =>
      example(schemaNamed(schemaName), full: full);

  var _ids = 0;

  String _exampleString(Map<String, dynamic> schema) {
    switch (schema['format']) {
      case 'uuid':
        _ids++;
        return '00000000-0000-4000-8000-${_ids.toString().padLeft(12, '0')}';
      case 'date':
        return '2026-01-15';
      case 'date-time':
        return '2026-01-15T10:30:00Z';
      case 'email':
        return 'user@example.com';
    }
    if (schema['pattern'] != null) return '12.34'; // Decimal fields.
    final minLength = (schema['minLength'] as int?) ?? 0;
    final maxLength = schema['maxLength'] as int?;
    var text = 'text';
    if (text.length < minLength) text = text.padRight(minLength, 'x');
    if (maxLength != null && text.length > maxLength) {
      text = text.substring(0, maxLength);
    }
    return text;
  }

  // ── Operations ─────────────────────────────────────────────────────────────

  /// The operation the API would route [method] [path] to, or null.
  ///
  /// [path] is relative to /api/v1, as the client's ApiClient sends it. A
  /// literal segment beats a parameter, so /allocations/summary isn't taken
  /// for /allocations/{allocation_id}.
  Operation? match(String method, String path) {
    final full = '$kApiPrefix$path';
    Operation? best;
    var bestParams = 1 << 30;
    for (final entry in paths.entries) {
      final template = entry.key;
      final params = '{'.allMatches(template).length;
      final regex = RegExp(
        '^${template.split('/').map((s) => s.startsWith('{') ? '[^/]+' : RegExp.escape(s)).join('/')}\$',
      );
      if (!regex.hasMatch(full)) continue;
      final op =
          (entry.value as Map<String, dynamic>)[method.toLowerCase()]
              as Map<String, dynamic>?;
      if (op != null && params < bestParams) {
        best = Operation(method.toUpperCase(), template, op);
        bestParams = params;
      }
    }
    return best;
  }

  /// Every operation, as `METHOD /api/v1/path/{param}`.
  Iterable<String> get operationIds sync* {
    for (final entry in paths.entries) {
      for (final method in (entry.value as Map<String, dynamic>).keys) {
        yield '${method.toUpperCase()} ${entry.key}';
      }
    }
  }
}

class Operation {
  Operation(this.method, this.template, this.spec);
  final String method;
  final String template;
  final Map<String, dynamic> spec;

  String get id => '$method $template';

  /// The documented success status and its body schema (null for 204).
  (int, Map<String, dynamic>?) get success {
    final responses = spec['responses'] as Map<String, dynamic>;
    final status = responses.keys.firstWhere((s) => s.startsWith('2'));
    final content =
        (responses[status] as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    final schema =
        (content?['application/json'] as Map<String, dynamic>?)?['schema']
            as Map<String, dynamic>?;
    return (int.parse(status), schema);
  }

  Map<String, dynamic>? get requestSchema {
    final body = spec['requestBody'] as Map<String, dynamic>?;
    final content = body?['content'] as Map<String, dynamic>?;
    return (content?['application/json'] as Map<String, dynamic>?)?['schema']
        as Map<String, dynamic>?;
  }

  /// Whether the operation takes a bearer token (it lists a security scheme).
  bool get requiresAuth =>
      (spec['security'] as List<dynamic>?)?.isNotEmpty ?? false;

  Set<String> get queryParams => {
    for (final p in (spec['parameters'] as List<dynamic>? ?? const []))
      if ((p as Map<String, dynamic>)['in'] == 'query') p['name'] as String,
  };
}

/// A stand-in for the API that answers [FakeApi] requests the way the real one
/// would, and records every way a request breaks the contract.
///
/// Each request must route to a documented operation, carry a bearer token if
/// the operation is secured, use only documented query parameters, and send a
/// body that matches the operation's request schema (or no body if it takes
/// none). The answer is the operation's success
/// status with a body generated from its response schema, unless [respond]
/// registered one, in which case that body is checked against the schema too.
class ContractServer {
  ContractServer(this.contract, this.api) {
    api.adapter.fallback = _answer;
  }

  final OpenApiContract contract;
  final FakeApi api;

  /// Contract violations, as `METHOD /path: problem`.
  final violations = <String>[];

  /// Operations that were called, as `METHOD /api/v1/template`.
  final hits = <String>[];

  final _canned = <String, List<Object?>>{};

  /// Answers `"METHOD /path"` with [body] (the API's success status). Repeated
  /// calls queue answers for repeated requests; the last one then sticks.
  void respond(String methodAndPath, Object? body) =>
      (_canned[methodAndPath] ??= []).add(body);

  (int, Object?) _answer(RequestOptions options) {
    final method = options.method;
    final path = options.path;
    final label = '$method $path';
    final op = contract.match(method, path);
    if (op == null) {
      violations.add('$label: no such operation in openapi.json');
      return (404, {'detail': 'Not Found'});
    }
    hits.add(op.id);

    // Regression: the client skipped the token for every /auth/ path, so
    // GET and PATCH /auth/me always got a 401 (found by the E2E suite).
    if (op.requiresAuth && options.headers['Authorization'] == null) {
      violations.add('$label: needs a bearer token but was sent without one');
    }

    final allowed = op.queryParams;
    for (final key in options.queryParameters.keys) {
      if (!allowed.contains(key)) {
        violations.add('$label: undocumented query parameter "$key"');
      }
    }

    final requestSchema = op.requestSchema;
    final body = options.data;
    if (requestSchema == null) {
      if (body != null) violations.add('$label: sends a body it takes none');
    } else {
      final errors = contract.validate(
        body,
        requestSchema,
        direction: Direction.request,
        opaqueIds: true,
      );
      violations.addAll(errors.map((e) => '$label request $e'));
    }

    final (status, responseSchema) = op.success;
    if (responseSchema == null) return (status, null);
    final canned = _canned[label];
    if (canned != null && canned.isNotEmpty) {
      final reply = canned.length > 1 ? canned.removeAt(0) : canned.first;
      final errors = contract.validate(reply, responseSchema, opaqueIds: true);
      violations.addAll(errors.map((e) => '$label canned response $e'));
      return (status, reply);
    }
    return (status, contract.example(responseSchema, full: true));
  }
}
