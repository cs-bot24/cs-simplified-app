// lib/models/ai_block.dart — Phase 2: Structured AI Response Models

import 'dart:convert';
import 'package:flutter/foundation.dart';

// ── Block type enum ───────────────────────────────────────────────────────────

enum AiBlockType {
  heading, text, math, matrix, code,
  definition, theorem, proof, example,
  exercise, solution, warning, tip, quote,
  bulletList, numberedList, table, diagram,
  divider, unknown,
}

AiBlockType _typeFromString(String s) {
  const map = {
    'heading': AiBlockType.heading,
    'text': AiBlockType.text,
    'math': AiBlockType.math,
    'matrix': AiBlockType.matrix,
    'code': AiBlockType.code,
    'definition': AiBlockType.definition,
    'theorem': AiBlockType.theorem,
    'proof': AiBlockType.proof,
    'example': AiBlockType.example,
    'exercise': AiBlockType.exercise,
    'solution': AiBlockType.solution,
    'warning': AiBlockType.warning,
    'tip': AiBlockType.tip,
    'quote': AiBlockType.quote,
    'bullet_list': AiBlockType.bulletList,
    'numbered_list': AiBlockType.numberedList,
    'table': AiBlockType.table,
    'diagram': AiBlockType.diagram,
    'divider': AiBlockType.divider,
  };
  return map[s] ?? AiBlockType.unknown;
}

/// Coerces any decoded-JSON value to plain readable text.
///
/// AI providers occasionally emit a nested object (e.g.
/// {"type":"text","content":"..."}) inside a bullet_list/numbered_list
/// "items" array, or inside a table cell, instead of a plain string. Naively
/// calling toString() on that produced a raw Dart map dump in the UI
/// (e.g. "{type: text, content: ...}"). This pulls the actual text out
/// instead.
String _coerceBlockText(dynamic e) {
  if (e == null) return '';
  if (e is String) return e.trim();
  if (e is Map) {
    for (final key in const ['content', 'text', 'item', 'value', 'label', 'name']) {
      final v = e[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    // Nothing text-like found — last resort, join any string values.
    return e.values.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' — ');
  }
  if (e is List) {
    return e.map(_coerceBlockText).where((s) => s.isNotEmpty).join(', ');
  }
  return e.toString().trim();
}

// ── Single block ──────────────────────────────────────────────────────────────

@immutable
class AiBlock {
  final AiBlockType          type;
  final Map<String, dynamic> raw;
  const AiBlock({required this.type, required this.raw});

  factory AiBlock.fromJson(Map<String, dynamic> j) =>
      AiBlock(type: _typeFromString(j['type'] as String? ?? ''), raw: j);

  // heading
  String get text       => _s('text') ?? _s('content') ?? '';
  int    get level      => (raw['level'] as int?) ?? 2;

  // generic content
  String get content    => _s('content') ?? _s('text') ?? '';

  // definition
  String get term       => _s('term') ?? '';

  // theorem / example / exercise
  String get title      => _s('title') ?? '';
  String get difficulty => _s('difficulty') ?? 'medium';

  // math / matrix
  String get latex      => _s('latex') ?? _s('content') ?? '';
  bool   get display    => (raw['display'] as bool?) ?? true;
  String get label      => _s('label') ?? '';

  // code
  String get language   => _s('language') ?? '';

  // lists
  List<String> get items =>
      (raw['items'] as List<dynamic>? ?? [])
          .map(_coerceBlockText)
          .where((e) => e.isNotEmpty)
          .toList();

  // table
  List<String> get headers =>
      (raw['headers'] as List<dynamic>? ?? []).map(_coerceBlockText).toList();

  List<List<String>> get rows =>
      (raw['rows'] as List<dynamic>? ?? []).map((row) {
        if (row is List) return row.map(_coerceBlockText).toList();
        return <String>[_coerceBlockText(row)];
      }).toList();

  // diagram
  String get source => _s('source') ?? _s('content') ?? _s('code') ?? '';
  String get format => _s('format') ?? 'mermaid';

  String? _s(String key) {
    final v = raw[key];
    if (v == null) return null;
    final s = _coerceBlockText(v);
    return s.isEmpty ? null : s;
  }
}

// ── Full parsed response ──────────────────────────────────────────────────────

@immutable
class AiJsonResponse {
  final List<AiBlock> blocks;
  final String?       subject;
  const AiJsonResponse({required this.blocks, this.subject});

  factory AiJsonResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['blocks'];
    final blocks = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(AiBlock.fromJson).toList()
        : <AiBlock>[];
    return AiJsonResponse(blocks: blocks, subject: j['subject'] as String?);
  }

  /// Parse a raw backend string. Returns null if not valid JSON blocks.
  /// Handles common model mistakes: ```json fences, prose before {, trailing commas.
  static AiJsonResponse? tryParse(String raw) {
    String t = raw.trim();

    // Strip ```json ... ``` fences
    final fenceRe = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final fenceMatch = fenceRe.firstMatch(t);
    if (fenceMatch != null) {
      t = fenceMatch.group(1)?.trim() ?? t;
    }

    // Find the start of the JSON object (skip any prose prefix)
    final braceStart = t.indexOf('{');
    if (braceStart < 0) return null;
    if (braceStart > 0) t = t.substring(braceStart);

    // Remove trailing commas before ] or }
    t = t.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    try {
      final j = jsonDecode(t) as Map<String, dynamic>?;
      if (j == null || !j.containsKey('blocks')) return null;
      return AiJsonResponse.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  bool get isEmpty => blocks.isEmpty;
}
