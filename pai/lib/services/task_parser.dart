enum ParsedTaskClassification {
  atomicTask,
  goal,
  subtaskCandidate,
  executionSignal,
  note,
  ambiguous,
}

extension ParsedTaskClassificationWireName on ParsedTaskClassification {
  String get wireName {
    switch (this) {
      case ParsedTaskClassification.atomicTask:
        return 'atomic_task';
      case ParsedTaskClassification.goal:
        return 'goal';
      case ParsedTaskClassification.subtaskCandidate:
        return 'subtask_candidate';
      case ParsedTaskClassification.executionSignal:
        return 'execution_signal';
      case ParsedTaskClassification.note:
        return 'note';
      case ParsedTaskClassification.ambiguous:
        return 'ambiguous';
    }
  }
}

class ParsedTaskSourceSpan {
  const ParsedTaskSourceSpan({required this.start, required this.end});

  final int start;
  final int end;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'start': start,
    'end': end,
  };
}

class ParsedTaskItem {
  const ParsedTaskItem({
    required this.id,
    required this.text,
    required this.normalizedText,
    required this.classification,
    required this.confidence,
    required this.reason,
    this.parentId,
    this.sourceSpan,
    this.suggestedSubtasks,
  });

  final String id;
  final String text;
  final String normalizedText;
  final ParsedTaskClassification classification;
  final double confidence;
  final String reason;
  final String? parentId;
  final ParsedTaskSourceSpan? sourceSpan;
  final List<String>? suggestedSubtasks;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'text': text,
    'normalizedText': normalizedText,
    'classification': classification.wireName,
    'confidence': confidence,
    'reason': reason,
    if (parentId != null) 'parentId': parentId,
    if (sourceSpan != null) 'sourceSpan': sourceSpan!.toJson(),
    if (suggestedSubtasks != null)
      'suggestedSubtasks': List<String>.from(suggestedSubtasks!),
  };
}

class FinalTaskSuggestion {
  const FinalTaskSuggestion({
    required this.title,
    this.parentTitle,
    required this.inferred,
    required this.confidence,
  });

  final String title;
  final String? parentTitle;
  final bool inferred;
  final double confidence;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'title': title,
    if (parentTitle != null) 'parentTitle': parentTitle,
    'inferred': inferred,
    'confidence': confidence,
  };
}

class ParseTaskSignals {
  const ParseTaskSignals({
    required this.executionRequested,
    required this.ambiguityDetected,
  });

  final bool executionRequested;
  final bool ambiguityDetected;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'executionRequested': executionRequested,
    'ambiguityDetected': ambiguityDetected,
  };
}

class ParseTasksResult {
  const ParseTasksResult({
    required this.rawInput,
    required this.normalizedInput,
    required this.items,
    required this.finalTasks,
    required this.signals,
  });

  final String rawInput;
  final String normalizedInput;
  final List<ParsedTaskItem> items;
  final List<FinalTaskSuggestion> finalTasks;
  final ParseTaskSignals signals;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'rawInput': rawInput,
    'normalizedInput': normalizedInput,
    'items': items.map((item) => item.toJson()).toList(growable: false),
    'finalTasks': finalTasks
        .map((task) => task.toJson())
        .toList(growable: false),
    'signals': signals.toJson(),
  };
}

class _ClauseSegment {
  const _ClauseSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.groupIndex,
  });

  final String text;
  final int start;
  final int end;
  final int groupIndex;
}

class _TrimmedSegment {
  const _TrimmedSegment({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final int start;
  final int end;
}

class _ClauseAnalysis {
  const _ClauseAnalysis({
    required this.normalizedText,
    required this.classification,
    required this.confidence,
    required this.reason,
  });

  final String normalizedText;
  final ParsedTaskClassification classification;
  final double confidence;
  final String reason;
}

class _ConditionalExtraction {
  const _ConditionalExtraction({
    required this.conditionText,
    required this.taskText,
    required this.confidenceBoostReason,
  });

  final String conditionText;
  final String taskText;
  final String confidenceBoostReason;
}

class _PronounModifierExtraction {
  const _PronounModifierExtraction({
    required this.modifierText,
    required this.kind,
  });

  final String modifierText;
  final String kind;
}

class _DraftParsedItem {
  _DraftParsedItem({
    required this.id,
    required this.text,
    required this.normalizedText,
    required this.classification,
    required this.confidence,
    required this.reason,
    required this.groupIndex,
    this.sourceSpan,
    this.suggestedSubtasks,
  });

  final String id;
  final String text;
  String normalizedText;
  ParsedTaskClassification classification;
  double confidence;
  String reason;
  final int groupIndex;
  String? parentId;
  final ParsedTaskSourceSpan? sourceSpan;
  List<String>? suggestedSubtasks;

  ParsedTaskItem toPublicItem() {
    return ParsedTaskItem(
      id: id,
      text: text,
      normalizedText: normalizedText,
      classification: classification,
      confidence: confidence,
      reason: reason,
      parentId: parentId,
      sourceSpan: sourceSpan,
      suggestedSubtasks: suggestedSubtasks == null
          ? null
          : List<String>.unmodifiable(suggestedSubtasks!),
    );
  }
}

class _SplitDecision {
  const _SplitDecision({required this.splitIndex, required this.nextStart});

  final int splitIndex;
  final int nextStart;
}

const List<String> _kActionVerbs = <String>[
  'clean up',
  'follow up',
  'hang up',
  'set up',
  'take care of',
  'add',
  'address',
  'arrange',
  'build',
  'buy',
  'call',
  'choose',
  'clarify',
  'create',
  'debug',
  'design',
  'document',
  'draft',
  'eat',
  'email',
  'exercise',
  'finish',
  'fix',
  'go',
  'handle',
  'implement',
  'improve',
  'investigate',
  'list',
  'make',
  'move',
  'organize',
  'plan',
  'polish',
  'prepare',
  'prioritize',
  'refactor',
  'redesign',
  'rename',
  'replace',
  'research',
  'review',
  'send',
  'ship',
  'take',
  'test',
  'update',
  'upgrade',
  'wire',
  'write',
];

const List<String> _kBroadGoalVerbs = <String>[
  'add',
  'clean up',
  'expand',
  'grow',
  'improve',
  'modernize',
  'organize',
  'overhaul',
  'redesign',
  'rework',
  'streamline',
  'upgrade',
  'work on',
];

const List<String> _kBroadGoalNouns = <String>[
  'app',
  'brand',
  'codebase',
  'documentation',
  'docs',
  'features',
  'feature set',
  'landing page',
  'marketing',
  'process',
  'product',
  'project',
  'site',
  'system',
  'ui',
  'website',
  'workflow',
];

const List<String> _kSpecificArtifactNouns = <String>[
  'brief',
  'button',
  'contract',
  'copy',
  'description',
  'doc',
  'docs page',
  'email',
  'hero',
  'headline',
  'image',
  'invoice',
  'issue',
  'layout',
  'list',
  'note',
  'paragraph',
  'screenshot',
  'section',
  'spec',
  'task',
  'test',
  'text',
  'ticket',
  'title',
];

const List<String> _kLeadingPhrases = <String>[
  'and then',
  'after that',
  'i need to',
  'i should',
  'i want to',
  'i might need to',
  'i might want to',
  'i may need to',
  'i may want to',
  'we need to',
  'we should',
  'we want to',
  'need to',
  'should',
  'want to',
  'might need to',
  'might want to',
  'may need to',
  'may want to',
  'remember to',
  'also',
  'then',
  'but',
  'please',
];

const List<String> _kHedgeWords = <String>[
  'kind of',
  'sort of',
  'probably',
  'maybe',
  'just',
  'kinda',
  'really',
  'actually',
];

const List<String> _kExecutionSignals = <String>[
  'do it',
  'do that',
  'handle it',
  'handle that',
  'take care of it',
  'take care of that',
  'finish it',
  'wrap it up',
];

const List<String> _kNotePrefixes = <String>[
  'background:',
  'context:',
  'fyi',
  'for reference',
  'note:',
  'notes:',
];

const List<String> _kStopWords = <String>[
  'a',
  'an',
  'and',
  'for',
  'from',
  'into',
  'it',
  'its',
  'more',
  'of',
  'on',
  'or',
  'our',
  'that',
  'the',
  'their',
  'them',
  'then',
  'this',
  'those',
  'to',
  'up',
  'with',
];

const List<String> _kConditionTargetVerbs = <String>[
  'adding',
  'building',
  'creating',
  'fixing',
  'implementing',
  'replacing',
  'updating',
];

const Map<String, List<String>> _kDomainAssociations = <String, List<String>>{
  'app': <String>['description', 'feature', 'features', 'screen', 'workflow'],
  'landing': <String>[
    'button',
    'copy',
    'headline',
    'hero',
    'image',
    'layout',
    'screenshot',
    'section',
    'text',
  ],
  'page': <String>[
    'button',
    'copy',
    'headline',
    'hero',
    'image',
    'layout',
    'screenshot',
    'section',
    'text',
  ],
  'project': <String>[
    'brief',
    'description',
    'docs',
    'feature',
    'features',
    'roadmap',
  ],
  'site': <String>[
    'button',
    'copy',
    'headline',
    'hero',
    'image',
    'layout',
    'screenshot',
    'section',
    'text',
  ],
  'website': <String>[
    'button',
    'copy',
    'headline',
    'hero',
    'image',
    'layout',
    'screenshot',
    'section',
    'text',
  ],
};

final RegExp _kIntentMarkerPattern = RegExp(
  r'\b(?:i need to|i should|i want to|i might need to|i might want to|i may need to|i may want to|we need to|we should|we want to)\b',
  caseSensitive: false,
);

final RegExp _kSequenceMarkerPattern = RegExp(
  r'\b(?:and then|after that|also|then)\b',
  caseSensitive: false,
);

final RegExp _kContrastMarkerPattern = RegExp(r'\bbut\b', caseSensitive: false);

final RegExp _kAndActionPattern = RegExp(
  '\\band\\b(?=\\s+(?:${_kActionVerbs.join('|')})\\b)',
  caseSensitive: false,
);

ParseTasksResult parseTasks(String rawInput) {
  final normalizedInput = normalizeTaskInput(rawInput);
  final clauseSegments = _segmentTaskClauseSegments(normalizedInput);
  final drafts = <_DraftParsedItem>[];

  for (var index = 0; index < clauseSegments.length; index++) {
    final segment = clauseSegments[index];
    final analysis = _classifyClause(segment.text);
    final suggestions = analysis.classification == ParsedTaskClassification.goal
        ? _suggestSubtasksForGoal(analysis.normalizedText)
        : null;
    drafts.add(
      _DraftParsedItem(
        id: 'task-item-${index + 1}',
        text: segment.text,
        normalizedText: analysis.normalizedText,
        classification: analysis.classification,
        confidence: analysis.confidence,
        reason: analysis.reason,
        groupIndex: segment.groupIndex,
        sourceSpan: ParsedTaskSourceSpan(
          start: segment.start,
          end: segment.end,
        ),
        suggestedSubtasks: suggestions,
      ),
    );
  }

  _applyContextualGoalRefinements(drafts);
  _applyParentChildInference(drafts);
  _applyPronounModifierMerges(drafts);

  final items = drafts
      .map((draft) => draft.toPublicItem())
      .toList(growable: false);
  final finalTasks = _buildFinalTasks(drafts);
  final signals = ParseTaskSignals(
    executionRequested: drafts.any(
      (draft) =>
          draft.classification == ParsedTaskClassification.executionSignal,
    ),
    ambiguityDetected: drafts.any(
      (draft) => draft.classification == ParsedTaskClassification.ambiguous,
    ),
  );

  return ParseTasksResult(
    rawInput: rawInput,
    normalizedInput: normalizedInput,
    items: items,
    finalTasks: finalTasks,
    signals: signals,
  );
}

// Normalization adds likely boundaries before repeated intent markers so the
// rest of the parser can treat run-on input more like lightly-punctuated prose.
String normalizeTaskInput(String rawInput) {
  var normalized = rawInput.replaceAll(RegExp(r'\r\n?'), '\n');
  normalized = normalized.replaceAll(RegExp(r'[ \t]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s*\n\s*'), '\n');
  normalized = normalized.replaceAll(RegExp(r'\s+([,.;!?])'), r'$1');
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'([^.!?;,\n])\s+(?=(?:and then|after that|also|then|i need to|i should|i want to|i might need to|i might want to|i may need to|i may want to|we need to|we should|we want to)\b)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}. ',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'((?:when|while|before|after)\s+[^.!?\n,]+?)\.\s+((?:i need to remember to|need to remember to|remember to|i need to|need to|i should|should|i want to|want to)\b)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(
      r'\bbut\.\s+((?:i need to|i should|i want to|i might need to|i might want to|i may need to|i may want to|need to|should|want to|might need to|might want to|may need to|may want to)\b)',
      caseSensitive: false,
    ),
    (match) => 'but ${match.group(1)}',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'([,.;!?])(?=\S)'),
    (match) => '${match.group(1)} ',
  );
  normalized = normalized.replaceAll(RegExp(r' {2,}'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\n{2,}'), '\n');
  return normalized.trim();
}

// Segmentation stays conservative: punctuation always splits, while conjunctions
// only split when they look like they introduce a fresh verb phrase.
List<String> segmentTaskClauses(String normalizedInput) {
  return _segmentTaskClauseSegments(
    normalizedInput,
  ).map((segment) => segment.text).toList(growable: false);
}

ParsedTaskItem classifyTaskClause(
  String clauseText, {
  String id = 'preview-item',
}) {
  final analysis = _classifyClause(clauseText.trim());
  final suggestions = analysis.classification == ParsedTaskClassification.goal
      ? _suggestSubtasksForGoal(analysis.normalizedText)
      : null;
  return ParsedTaskItem(
    id: id,
    text: clauseText.trim(),
    normalizedText: analysis.normalizedText,
    classification: analysis.classification,
    confidence: analysis.confidence,
    reason: analysis.reason,
    suggestedSubtasks: suggestions,
  );
}

// Enrichment is intentionally bounded to generic planning suggestions so broad
// goals become easier to review without silently inventing concrete commitments.
List<String> suggestSubtasksForGoal(String goalText) {
  final normalizedText = _normalizeTaskTitle(_stripLeadingPhrases(goalText));
  return _suggestSubtasksForGoal(normalizedText) ?? const <String>[];
}

bool hasActionableTaskClauses(ParseTasksResult result) {
  return result.items.any(
    (item) =>
        item.classification == ParsedTaskClassification.atomicTask ||
        item.classification == ParsedTaskClassification.goal ||
        item.classification == ParsedTaskClassification.subtaskCandidate,
  );
}

List<_ClauseSegment> _segmentTaskClauseSegments(String normalizedInput) {
  final clauses = <_ClauseSegment>[];
  if (normalizedInput.isEmpty) {
    return clauses;
  }

  final boundaryPattern = RegExp(r'[.!?;\n]+');
  var sentenceStart = 0;
  var groupIndex = 0;

  for (final match in boundaryPattern.allMatches(normalizedInput)) {
    _addSentenceClauses(
      clauses,
      normalizedInput,
      sentenceStart,
      match.start,
      groupIndex,
    );
    sentenceStart = match.end;
    groupIndex++;
  }

  _addSentenceClauses(
    clauses,
    normalizedInput,
    sentenceStart,
    normalizedInput.length,
    groupIndex,
  );
  return clauses;
}

void _addSentenceClauses(
  List<_ClauseSegment> clauses,
  String source,
  int start,
  int end,
  int groupIndex,
) {
  final trimmed = _trimSegment(source, start, end);
  if (trimmed == null) {
    return;
  }

  clauses.addAll(
    _splitClauseChunk(
      _ClauseSegment(
        text: trimmed.text,
        start: trimmed.start,
        end: trimmed.end,
        groupIndex: groupIndex,
      ),
    ),
  );
}

List<_ClauseSegment> _splitClauseChunk(_ClauseSegment sentence) {
  final clauses = <_ClauseSegment>[];
  var cursor = 0;

  while (cursor < sentence.text.length) {
    final decision = _findNextSplit(sentence.text, cursor);
    final end = decision?.splitIndex ?? sentence.text.length;
    final trimmed = _trimSegment(sentence.text, cursor, end);
    if (trimmed != null) {
      final chunk = _ClauseSegment(
        text: trimmed.text,
        start: sentence.start + trimmed.start,
        end: sentence.start + trimmed.end,
        groupIndex: sentence.groupIndex,
      );
      clauses.addAll(_splitCoordinatedActionList(chunk));
    }

    if (decision == null) {
      break;
    }
    cursor = decision.nextStart;
  }

  return clauses;
}

// Comma splitting is only used when every list part still looks like an action
// phrase, which keeps appositives and descriptive commas intact.
List<_ClauseSegment> _splitCoordinatedActionList(_ClauseSegment sentence) {
  if (!sentence.text.contains(',')) {
    return <_ClauseSegment>[sentence];
  }

  final parts = <_ClauseSegment>[];
  var partStart = 0;
  for (var index = 0; index < sentence.text.length; index++) {
    if (sentence.text.codeUnitAt(index) != 44) {
      continue;
    }

    final trimmed = _trimSegment(sentence.text, partStart, index);
    if (trimmed != null) {
      final segment = _trimLeadingCoordinator(
        _ClauseSegment(
          text: trimmed.text,
          start: sentence.start + trimmed.start,
          end: sentence.start + trimmed.end,
          groupIndex: sentence.groupIndex,
        ),
      );
      if (segment != null) {
        parts.add(segment);
      }
    }
    partStart = index + 1;
  }

  final trailing = _trimSegment(sentence.text, partStart, sentence.text.length);
  if (trailing != null) {
    final segment = _trimLeadingCoordinator(
      _ClauseSegment(
        text: trailing.text,
        start: sentence.start + trailing.start,
        end: sentence.start + trailing.end,
        groupIndex: sentence.groupIndex,
      ),
    );
    if (segment != null) {
      parts.add(segment);
    }
  }

  if (parts.length < 2) {
    return <_ClauseSegment>[sentence];
  }

  final actionishCount = parts
      .where((part) => _looksLikeActionPhrase(part.text))
      .length;
  if (actionishCount == parts.length && actionishCount >= 2) {
    return parts;
  }
  return <_ClauseSegment>[sentence];
}

_ClauseSegment? _trimLeadingCoordinator(_ClauseSegment segment) {
  final match = RegExp(
    r'^(?:and)\s+',
    caseSensitive: false,
  ).firstMatch(segment.text);
  if (match == null) {
    return segment;
  }
  final trimmed = _trimSegment(segment.text, match.end, segment.text.length);
  if (trimmed == null) {
    return null;
  }
  return _ClauseSegment(
    text: trimmed.text,
    start: segment.start + trimmed.start,
    end: segment.start + trimmed.end,
    groupIndex: segment.groupIndex,
  );
}

bool _isConditionalLead(String text) {
  return RegExp(
        r'^(?:when|while|before|after)\b',
        caseSensitive: false,
      ).hasMatch(text) &&
      !text.contains(',');
}

bool _looksLikeActionPhrase(String text) {
  final stripped = _stripHedgeWords(_stripLeadingPhrases(text));
  if (stripped.isEmpty) {
    return false;
  }
  final lower = stripped.toLowerCase();
  return _startsWithActionVerb(lower) || _looksLikeFlexibleVerbPhrase(lower);
}

bool _looksLikeSplitClauseStart(String text) {
  final stripped = _stripHedgeWords(_stripLeadingPhrases(text));
  if (stripped.isEmpty) {
    return false;
  }
  final lower = stripped.toLowerCase();
  return _startsWithActionVerb(lower) ||
      _looksLikeFlexibleVerbPhrase(lower) ||
      _isExecutionSignal(lower) ||
      _extractPronounModifier(text) != null;
}

_SplitDecision? _findNextSplit(String text, int fromIndex) {
  _SplitDecision? earliest;

  void consider(Match match, {required bool skipMatchedText}) {
    if (match.start <= fromIndex) {
      return;
    }
    final candidate = _SplitDecision(
      splitIndex: match.start,
      nextStart: skipMatchedText
          ? _skipWhitespace(text, match.end)
          : match.start,
    );
    if (earliest == null || candidate.splitIndex < earliest!.splitIndex) {
      earliest = candidate;
    }
  }

  for (final match in _kIntentMarkerPattern.allMatches(text)) {
    if (match.start > fromIndex) {
      final leadingText = text.substring(fromIndex, match.start).trimLeft();
      if (_isConditionalLead(leadingText)) {
        continue;
      }
      consider(match, skipMatchedText: false);
      break;
    }
  }
  for (final match in _kSequenceMarkerPattern.allMatches(text)) {
    if (match.start > fromIndex) {
      consider(match, skipMatchedText: false);
      break;
    }
  }
  for (final match in _kContrastMarkerPattern.allMatches(text)) {
    if (match.start > fromIndex) {
      final trailingText = text.substring(match.end).trimLeft();
      if (!_looksLikeSplitClauseStart(trailingText)) {
        continue;
      }
      consider(match, skipMatchedText: true);
      break;
    }
  }
  for (final match in _kAndActionPattern.allMatches(text)) {
    if (match.start > fromIndex) {
      consider(match, skipMatchedText: true);
      break;
    }
  }

  return earliest;
}

int _skipWhitespace(String text, int index) {
  var cursor = index;
  while (cursor < text.length && text.codeUnitAt(cursor) == 32) {
    cursor++;
  }
  return cursor;
}

_ClauseAnalysis _classifyClause(String clauseText) {
  final trimmedClause = clauseText.trim();
  if (trimmedClause.isEmpty) {
    return const _ClauseAnalysis(
      normalizedText: '',
      classification: ParsedTaskClassification.note,
      confidence: 0.0,
      reason: 'Empty clause after trimming.',
    );
  }

  final rawLower = trimmedClause.toLowerCase();
  if (_kNotePrefixes.any((prefix) => rawLower.startsWith(prefix))) {
    return _ClauseAnalysis(
      normalizedText: _sentenceCase(_stripLeadingPhrases(trimmedClause)),
      classification: ParsedTaskClassification.note,
      confidence: 0.92,
      reason: 'Looks like context or reference text instead of a task.',
    );
  }

  final conditional = _extractConditionalTask(trimmedClause);
  if (conditional != null) {
    return _classifyConditionalTask(conditional);
  }

  final stripped = _stripHedgeWords(_stripLeadingPhrases(trimmedClause));
  final normalizedText = _normalizeTaskTitle(stripped);
  final lower = stripped.toLowerCase();

  if (lower.isEmpty) {
    return const _ClauseAnalysis(
      normalizedText: '',
      classification: ParsedTaskClassification.ambiguous,
      confidence: 0.15,
      reason: 'Intent marker was present, but no actionable content remained.',
    );
  }

  if (_isExecutionSignal(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.executionSignal,
      confidence: 0.34,
      reason: 'Uses a vague execution phrase without naming the task itself.',
    );
  }

  if (_isPronounOnlyAction(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.ambiguous,
      confidence: 0.28,
      reason: 'Has an action verb, but the object is only a vague pronoun.',
    );
  }

  if (!_startsWithActionVerb(lower) && !_looksLikeFlexibleVerbPhrase(lower)) {
    final looksTaskish =
        trimmedClause.contains(' to ') || rawLower.startsWith('todo');
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: looksTaskish
          ? ParsedTaskClassification.ambiguous
          : ParsedTaskClassification.note,
      confidence: looksTaskish ? 0.32 : 0.88,
      reason: looksTaskish
          ? 'Mentions intent, but not with a clear task phrasing.'
          : 'Reads more like context than an actionable task.',
    );
  }

  if (_isBroadGoal(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.goal,
      confidence: 0.71,
      reason: 'Contains a broad outcome, but not a tightly scoped deliverable.',
    );
  }

  return _ClauseAnalysis(
    normalizedText: normalizedText,
    classification: ParsedTaskClassification.atomicTask,
    confidence: 0.9,
    reason: 'Explicit action verb with a concrete enough target.',
  );
}

_ClauseAnalysis _classifyConditionalTask(_ConditionalExtraction extraction) {
  final taskText = _resolveConditionalTaskText(
    conditionText: extraction.conditionText,
    taskText: extraction.taskText,
  );
  final normalizedText = _normalizeTaskTitle(taskText);
  final lower = taskText.toLowerCase();

  if (lower.isEmpty) {
    return _ClauseAnalysis(
      normalizedText: '',
      classification: ParsedTaskClassification.ambiguous,
      confidence: 0.24,
      reason: extraction.confidenceBoostReason,
    );
  }

  if (_isExecutionSignal(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.executionSignal,
      confidence: 0.34,
      reason: extraction.confidenceBoostReason,
    );
  }

  if (_isPronounOnlyAction(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.ambiguous,
      confidence: 0.36,
      reason:
          '${extraction.confidenceBoostReason} The extracted task still uses a vague pronoun.',
    );
  }

  if (_isBroadGoal(lower)) {
    return _ClauseAnalysis(
      normalizedText: normalizedText,
      classification: ParsedTaskClassification.goal,
      confidence: 0.76,
      reason: extraction.confidenceBoostReason,
    );
  }

  final confidence = _startsWithActionVerb(lower) ? 0.9 : 0.84;
  return _ClauseAnalysis(
    normalizedText: normalizedText,
    classification: ParsedTaskClassification.atomicTask,
    confidence: confidence,
    reason: extraction.confidenceBoostReason,
  );
}

String _stripLeadingPhrases(String text) {
  var stripped = text.trim();
  var changed = true;
  while (changed && stripped.isNotEmpty) {
    changed = false;
    final lower = stripped.toLowerCase();
    for (final phrase in _kLeadingPhrases) {
      if (lower == phrase) {
        stripped = '';
        changed = true;
        break;
      }
      if (lower.startsWith('$phrase ')) {
        stripped = stripped.substring(phrase.length).trimLeft();
        changed = true;
        break;
      }
    }
    if (changed) {
      stripped = stripped.replaceFirst(RegExp(r'^[-,:]+\s*'), '').trimLeft();
    }
  }
  return stripped.trim();
}

String _stripHedgeWords(String text) {
  var stripped = text.trim();
  var changed = true;
  while (changed && stripped.isNotEmpty) {
    changed = false;
    final lower = stripped.toLowerCase();
    for (final hedge in _kHedgeWords) {
      if (lower == hedge) {
        stripped = '';
        changed = true;
        break;
      }
      if (lower.startsWith('$hedge ')) {
        stripped = stripped.substring(hedge.length).trimLeft();
        changed = true;
        break;
      }
    }
  }
  return stripped.trim();
}

_ConditionalExtraction? _extractConditionalTask(String clauseText) {
  final reminderPattern = RegExp(
    r'^(when|while|before|after)\s+(.+?)\s+(?:i need to remember to|need to remember to|remember to|i need to|need to|i should|should|i want to|want to)\s+(.+)$',
    caseSensitive: false,
  );
  final reminderMatch = reminderPattern.firstMatch(clauseText.trim());
  if (reminderMatch != null) {
    final conditionText =
        '${reminderMatch.group(1)!.toLowerCase()} ${reminderMatch.group(2)!.trim()}';
    return _ConditionalExtraction(
      conditionText: conditionText,
      taskText: reminderMatch.group(3)!.trim(),
      confidenceBoostReason:
          'Concrete task extracted from a conditional reminder: $conditionText.',
    );
  }

  final commaPattern = RegExp(
    r'^(when|while|before|after)\s+(.+?),\s*(.+)$',
    caseSensitive: false,
  );
  final commaMatch = commaPattern.firstMatch(clauseText.trim());
  if (commaMatch != null) {
    final conditionText =
        '${commaMatch.group(1)!.toLowerCase()} ${commaMatch.group(2)!.trim()}';
    return _ConditionalExtraction(
      conditionText: conditionText,
      taskText: commaMatch.group(3)!.trim(),
      confidenceBoostReason:
          'Concrete task extracted from a conditional reminder: $conditionText.',
    );
  }

  return null;
}

String _resolveConditionalTaskText({
  required String conditionText,
  required String taskText,
}) {
  final strippedTask = _stripHedgeWords(_stripLeadingPhrases(taskText));
  final match = RegExp(
    r'^([a-z][a-z\-]*)\s+(it|this|that)$',
    caseSensitive: false,
  ).firstMatch(strippedTask);
  if (match == null) {
    return strippedTask;
  }

  final target = _extractConditionTarget(conditionText);
  if (target == null) {
    return strippedTask;
  }

  return '${match.group(1)} $target';
}

_PronounModifierExtraction? _extractPronounModifier(String clauseText) {
  final stripped = _stripHedgeWords(_stripLeadingPhrases(clauseText));
  final match = RegExp(
    r'^(?:do)\s+(?:it|this|that)\s+(outside|indoors|at\s+[a-z][a-z\-]*(?:\s+[a-z][a-z\-]*){0,3}|tomorrow|tonight|later(?:\s+today)?|first|after\s+[a-z][a-z\-]*(?:\s+[a-z][a-z\-]*){0,3}|before\s+[a-z][a-z\-]*(?:\s+[a-z][a-z\-]*){0,3})$',
    caseSensitive: false,
  ).firstMatch(stripped);
  if (match == null) {
    return null;
  }

  final modifierText = match.group(1)!.trim();
  final lower = modifierText.toLowerCase();
  final kind = lower == 'first'
      ? 'priority'
      : lower == 'outside' || lower == 'indoors' || lower.startsWith('at ')
      ? 'location'
      : 'time';

  return _PronounModifierExtraction(modifierText: modifierText, kind: kind);
}

String _mergeModifierIntoTaskTitle(String title, String modifierText) {
  final lowerTitle = title.toLowerCase();
  final lowerModifier = modifierText.toLowerCase();
  if (lowerTitle.endsWith(' $lowerModifier')) {
    return title;
  }
  return '$title $modifierText';
}

String? _extractConditionTarget(String conditionText) {
  final targetPattern = RegExp(
    '^(?:when|while|before|after)\\s+'
    '(?:${_kConditionTargetVerbs.join('|')})\\s+'
    r'(.+)$',
    caseSensitive: false,
  );
  final match = targetPattern.firstMatch(conditionText.trim());
  if (match == null) {
    return null;
  }

  final target = match.group(1)!.trim();
  if (target.isEmpty || target.split(' ').length > 6) {
    return null;
  }
  return target;
}

String _normalizeTaskTitle(String text) {
  var normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  normalized = normalized.replaceFirst(
    RegExp(r'^(?:to)\s+', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceFirst(RegExp(r'[.!?]+$'), '');

  final betterDescriptionMatch = RegExp(
    r'^(?:add|write|update|improve)\s+(?:a\s+)?(?:better|clearer|improved)\s+description\s+of\s+(?:the\s+)?(.+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (betterDescriptionMatch != null) {
    final subject = betterDescriptionMatch.group(1)!.trim();
    return _sentenceCase(
      'Improve ${_ensureLeadingArticle(subject)} description',
    );
  }

  final addMoreMatch = RegExp(
    r'^add\s+(?:more|additional)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (addMoreMatch != null) {
    return _sentenceCase('Plan additional ${addMoreMatch.group(1)!.trim()}');
  }

  final takeTestMatch = RegExp(
    r'^take\s+(?:a|an|that|this|the)\s+test$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (takeTestMatch != null) {
    return 'Take the test';
  }

  return _sentenceCase(normalized);
}

String _ensureLeadingArticle(String text) {
  final lower = text.toLowerCase();
  if (lower.startsWith('a ') ||
      lower.startsWith('an ') ||
      lower.startsWith('the ')) {
    return text;
  }
  return 'the $text';
}

String _sentenceCase(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}

bool _isExecutionSignal(String text) {
  return _kExecutionSignals.any(
    (signal) => text == signal || text.startsWith('$signal '),
  );
}

bool _isPronounOnlyAction(String text) {
  return RegExp(
    r'^(?:add|address|change|do|finish|fix|handle|improve|move|plan|replace|review|send|test|update|write)\s+(?:it|that|this|them)$',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _startsWithActionVerb(String text) {
  for (final verb in _kActionVerbs) {
    if (text == verb || text.startsWith('$verb ')) {
      return true;
    }
  }
  return false;
}

bool _looksLikeFlexibleVerbPhrase(String text) {
  return RegExp(
    r'^[a-z]{4,}(?:ify|ise|ize|en)\b',
    caseSensitive: false,
  ).hasMatch(text);
}

bool _isBroadGoal(String text) {
  final hasSpecificArtifact = _containsAnyTerm(text, _kSpecificArtifactNouns);
  final hasBroadNoun = _containsAnyTerm(text, _kBroadGoalNouns);
  final startsWithBroadVerb = _kBroadGoalVerbs.any(
    (verb) => text == verb || text.startsWith('$verb '),
  );

  if (text.startsWith('add more ') || text.startsWith('add additional ')) {
    return true;
  }
  if (text.startsWith('work on ')) {
    return true;
  }
  if (text.contains(' more ') && hasBroadNoun) {
    return true;
  }
  if (startsWithBroadVerb && hasBroadNoun && !hasSpecificArtifact) {
    return true;
  }
  return false;
}

bool _containsAnyTerm(String text, List<String> terms) {
  for (final term in terms) {
    if (RegExp(
      '\\b${RegExp.escape(term)}\\b',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
  }
  return false;
}

List<String>? _suggestSubtasksForGoal(String normalizedGoal) {
  final lower = normalizedGoal.toLowerCase();
  if (lower.contains('feature')) {
    return const <String>[
      'List desired features',
      'Prioritize feature ideas',
      'Implement selected features',
    ];
  }
  if (lower.contains('landing page') ||
      lower.contains('website') ||
      lower.contains('site') ||
      lower.contains('ui')) {
    return const <String>[
      'List the main areas to update',
      'Prioritize the highest-impact visual changes',
      'Implement the selected updates',
    ];
  }
  if (lower.contains('project') ||
      lower.contains('app') ||
      lower.contains('workflow')) {
    return const <String>[
      'Break the goal into concrete deliverables',
      'Choose the highest-priority next step',
      'Complete the selected next step',
    ];
  }
  return const <String>[
    'Break the goal into concrete deliverables',
    'Choose the highest-priority next step',
    'Complete the selected next step',
  ];
}

void _applyContextualGoalRefinements(List<_DraftParsedItem> drafts) {
  final contextKeywords = drafts
      .expand((draft) => _extractKeywords(draft.normalizedText))
      .toSet();

  for (final draft in drafts) {
    if (draft.classification != ParsedTaskClassification.goal) {
      continue;
    }
    if (draft.normalizedText == 'Plan additional features' &&
        contextKeywords.contains('project')) {
      draft.normalizedText = 'Plan additional project features';
    }
  }
}

void _applyParentChildInference(List<_DraftParsedItem> drafts) {
  final grouped = <int, List<_DraftParsedItem>>{};
  for (final draft in drafts) {
    grouped
        .putIfAbsent(draft.groupIndex, () => <_DraftParsedItem>[])
        .add(draft);
  }

  for (final group in grouped.values) {
    for (var index = 0; index < group.length; index++) {
      final parent = group[index];
      if (parent.classification != ParsedTaskClassification.goal) {
        continue;
      }

      final children = <_DraftParsedItem>[];
      for (
        var childIndex = index + 1;
        childIndex < group.length;
        childIndex++
      ) {
        final child = group[childIndex];
        if (child.classification == ParsedTaskClassification.goal) {
          break;
        }
        if (child.classification == ParsedTaskClassification.atomicTask &&
            child.parentId == null) {
          children.add(child);
        }
      }

      if (children.isEmpty) {
        continue;
      }

      final attachAll = children.length >= 2;
      for (final child in children) {
        if (!attachAll &&
            !_likelyRelated(parent.normalizedText, child.normalizedText)) {
          continue;
        }
        child.parentId = parent.id;
        child.classification = ParsedTaskClassification.subtaskCandidate;
        child.confidence = _clampConfidence((child.confidence * 0.92) + 0.02);
        child.reason =
            'Specific action grouped under the preceding broader goal.';
      }
    }
  }
}

void _applyPronounModifierMerges(List<_DraftParsedItem> drafts) {
  for (var index = 1; index < drafts.length; index++) {
    final current = drafts[index];
    final previous = drafts[index - 1];
    if (current.groupIndex != previous.groupIndex) {
      continue;
    }
    if (previous.classification != ParsedTaskClassification.atomicTask &&
        previous.classification != ParsedTaskClassification.subtaskCandidate) {
      continue;
    }

    final extraction = _extractPronounModifier(current.text);
    if (extraction == null) {
      continue;
    }

    previous.normalizedText = _mergeModifierIntoTaskTitle(
      previous.normalizedText,
      extraction.modifierText,
    );
    previous.confidence = _clampConfidence(previous.confidence + 0.04);
    previous.reason =
        '${previous.reason} Merged ${extraction.kind} modifier from pronoun follow-up: ${extraction.modifierText}.';

    current.classification = ParsedTaskClassification.note;
    current.confidence = 0.18;
    current.reason =
        'Pronoun follow-up merged into the previous task as a ${extraction.kind} modifier.';
  }
}

bool _likelyRelated(String parentText, String childText) {
  final parentKeywords = _extractKeywords(parentText);
  final childKeywords = _extractKeywords(childText);
  final parentIsFeatureGoal =
      parentKeywords.contains('feature') || parentKeywords.contains('features');
  if (parentIsFeatureGoal &&
      !childKeywords.contains('feature') &&
      !childKeywords.contains('features')) {
    return false;
  }
  if (parentKeywords.any(childKeywords.contains)) {
    return true;
  }

  for (final keyword in parentKeywords) {
    final related = _kDomainAssociations[keyword];
    if (related == null) {
      continue;
    }
    if (related.any(childKeywords.contains)) {
      return true;
    }
  }
  return false;
}

Set<String> _extractKeywords(String text) {
  return RegExp(r'[a-zA-Z]+')
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .where((word) => word.length > 2)
      .where((word) => !_kStopWords.contains(word))
      .where((word) => !_kActionVerbs.contains(word))
      .toSet();
}

List<FinalTaskSuggestion> _buildFinalTasks(List<_DraftParsedItem> drafts) {
  final parentsById = <String, _DraftParsedItem>{
    for (final draft in drafts) draft.id: draft,
  };
  final tasks = <FinalTaskSuggestion>[];
  final seen = <String>{};

  for (final draft in drafts) {
    if (draft.normalizedText.isEmpty) {
      continue;
    }

    FinalTaskSuggestion? candidate;
    switch (draft.classification) {
      case ParsedTaskClassification.atomicTask:
        candidate = FinalTaskSuggestion(
          title: draft.normalizedText,
          inferred: false,
          confidence: draft.confidence,
        );
      case ParsedTaskClassification.goal:
        candidate = FinalTaskSuggestion(
          title: draft.normalizedText,
          inferred: false,
          confidence: draft.confidence,
        );
      case ParsedTaskClassification.subtaskCandidate:
        final parent = parentsById[draft.parentId];
        candidate = FinalTaskSuggestion(
          title: draft.normalizedText,
          parentTitle: parent?.normalizedText,
          inferred: false,
          confidence: draft.confidence,
        );
      case ParsedTaskClassification.executionSignal:
      case ParsedTaskClassification.note:
      case ParsedTaskClassification.ambiguous:
        candidate = null;
    }

    if (candidate == null) {
      continue;
    }

    final key = '${candidate.parentTitle ?? ''}::${candidate.title}'
        .toLowerCase();
    if (seen.add(key)) {
      tasks.add(candidate);
    }
  }

  return tasks;
}

double _clampConfidence(double value) {
  return (value.clamp(0.0, 1.0) as num).toDouble();
}

_TrimmedSegment? _trimSegment(String text, int start, int end) {
  var trimmedStart = start;
  var trimmedEnd = end;

  while (trimmedStart < trimmedEnd &&
      _isTrimmableCodeUnit(text.codeUnitAt(trimmedStart))) {
    trimmedStart++;
  }
  while (trimmedEnd > trimmedStart &&
      _isTrimmableCodeUnit(text.codeUnitAt(trimmedEnd - 1))) {
    trimmedEnd--;
  }

  if (trimmedStart >= trimmedEnd) {
    return null;
  }

  return _TrimmedSegment(
    text: text.substring(trimmedStart, trimmedEnd),
    start: trimmedStart,
    end: trimmedEnd,
  );
}

bool _isTrimmableCodeUnit(int codeUnit) {
  return codeUnit == 9 ||
      codeUnit == 10 ||
      codeUnit == 13 ||
      codeUnit == 32 ||
      codeUnit == 44;
}
