import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bible_loader.dart';
import 'notification_service.dart';

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gospel Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E2F11),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5E6BF),
        useMaterial3: true,
      ),
      home: const QuizHomePage(),
    );
  }
}

class QuizHomePage extends StatefulWidget {
  const QuizHomePage({super.key});

  @override
  State<QuizHomePage> createState() => _QuizHomePageState();
}

class _QuizHomePageState extends State<QuizHomePage> {
  static const String _highScoreKey = 'high_score';
  static const String _lifetimeRoundsKey = 'lifetime_rounds';
  static const String _lifetimeScoreKey = 'lifetime_score';
  static const String _lifetimePerfectRoundsKey = 'lifetime_perfect_rounds';
  static const String _lifetimeBestStreakKey = 'lifetime_best_streak';
  static const String _historyRoundPointsKey = 'history_round_points';
  static const String _historyBookPointsKey = 'history_book_points';
  static const String _historyChapterPointsKey = 'history_chapter_points';
  static const String _historyVersePointsKey = 'history_verse_points';
  static const String _dailyVerseNotificationsEnabledKey =
      'daily_verse_notifications_enabled';

  List<Map<String, dynamic>> _verses = [];
  List<String> _books = [];
  Map<String, List<int>> _bookChapters = {};
  Map<String, Map<int, List<int>>> _bookChapterVerses = {};

  final _random = Random();
  int _score = 0;
  int _highScore = 0;
  int _lifetimeRounds = 0;
  int _lifetimeScore = 0;
  int _lifetimePerfectRounds = 0;
  int _lifetimeBestStreak = 0;
  bool _showAllTimeGraphs = true;
  bool _dailyVerseNotificationsEnabled = false;
  int _round = 0;
  Map<String, dynamic>? _currentVerse;
  bool _showingResult = false;
  bool _gameOver = false;
  int _lastPoints = 0;
  int _booksCorrectInGame = 0;
  int _chaptersCorrectInGame = 0;
  int _versesCorrectInGame = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  final List<int> _historyRoundPoints = [];
  final List<int> _historyBookPoints = [];
  final List<int> _historyChapterPoints = [];
  final List<int> _historyVersePoints = [];
  String? _lastGuessRef;

  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;

  String _canonicalBookName(String name) {
    var normalized = name.trim().toLowerCase();
    normalized = normalized.replaceFirst(RegExp(r'^iii\s+'), '3 ');
    normalized = normalized.replaceFirst(RegExp(r'^ii\s+'), '2 ');
    normalized = normalized.replaceFirst(RegExp(r'^i\s+'), '1 ');
    if (normalized == 'revelation of john') {
      normalized = 'revelation';
    }
    return normalized;
  }

  @override
  void initState() {
    super.initState();
    _loadPersistentStats();
    _loadData();
  }

  Future<void> _loadPersistentStats() async {
    final prefs = await SharedPreferences.getInstance();
    final historyTotal = (prefs.getStringList(_historyRoundPointsKey) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final historyBook = (prefs.getStringList(_historyBookPointsKey) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final historyChapter = (prefs.getStringList(_historyChapterPointsKey) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
    final historyVerse = (prefs.getStringList(_historyVersePointsKey) ?? [])
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _highScore = prefs.getInt(_highScoreKey) ?? 0;
      _lifetimeRounds = prefs.getInt(_lifetimeRoundsKey) ?? 0;
      _lifetimeScore = prefs.getInt(_lifetimeScoreKey) ?? 0;
      _lifetimePerfectRounds = prefs.getInt(_lifetimePerfectRoundsKey) ?? 0;
      _lifetimeBestStreak = prefs.getInt(_lifetimeBestStreakKey) ?? 0;
      _dailyVerseNotificationsEnabled =
          prefs.getBool(_dailyVerseNotificationsEnabledKey) ?? false;
      _historyRoundPoints
        ..clear()
        ..addAll(historyTotal);
      _historyBookPoints
        ..clear()
        ..addAll(historyBook);
      _historyChapterPoints
        ..clear()
        ..addAll(historyChapter);
      _historyVersePoints
        ..clear()
        ..addAll(historyVerse);
    });
  }

  Future<void> _savePersistentStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_highScoreKey, _highScore);
    await prefs.setInt(_lifetimeRoundsKey, _lifetimeRounds);
    await prefs.setInt(_lifetimeScoreKey, _lifetimeScore);
    await prefs.setInt(_lifetimePerfectRoundsKey, _lifetimePerfectRounds);
    await prefs.setInt(_lifetimeBestStreakKey, _lifetimeBestStreak);
    await prefs.setBool(
      _dailyVerseNotificationsEnabledKey,
      _dailyVerseNotificationsEnabled,
    );
    await prefs.setStringList(
      _historyRoundPointsKey,
      _historyRoundPoints.map((value) => value.toString()).toList(),
    );
    await prefs.setStringList(
      _historyBookPointsKey,
      _historyBookPoints.map((value) => value.toString()).toList(),
    );
    await prefs.setStringList(
      _historyChapterPointsKey,
      _historyChapterPoints.map((value) => value.toString()).toList(),
    );
    await prefs.setStringList(
      _historyVersePointsKey,
      _historyVersePoints.map((value) => value.toString()).toList(),
    );
  }

  Future<void> _loadData() async {
    final json = await BibleLoader.loadJson('assets/top_777_nt.json');
    final verses = (json['verses'] as List).cast<Map<String, dynamic>>();
    final structureJson = await BibleLoader.loadJson(
      'assets/bible_structure_nt.json',
    );
    final structureBooks = (structureJson['books'] as List)
        .cast<Map<String, dynamic>>();

    final books = <String>{};
    final bookOrder = <String, int>{};

    for (final v in verses) {
      final book = v['book_name'] as String;
      final bookNum = v['book'] as int;
      books.add(book);
      bookOrder.putIfAbsent(book, () => bookNum);
    }

    final orderedBooks = books.toList()
      ..sort((a, b) {
        final aOrder = bookOrder[a] ?? 999;
        final bOrder = bookOrder[b] ?? 999;
        final byOrder = aOrder.compareTo(bOrder);
        return byOrder != 0 ? byOrder : a.compareTo(b);
      });

    final structureByCanonical = <String, Map<String, dynamic>>{};
    for (final structureBook in structureBooks) {
      final structureName = structureBook['book_name'] as String;
      structureByCanonical[_canonicalBookName(structureName)] = structureBook;
    }

    final fullBookChapters = <String, List<int>>{};
    final fullBookChapterVerses = <String, Map<int, List<int>>>{};
    for (final topBook in orderedBooks) {
      final structureBook = structureByCanonical[_canonicalBookName(topBook)];
      if (structureBook == null) {
        continue;
      }

      final chapterVerseCounts = (structureBook['chapter_verse_counts'] as List)
          .cast<int>();
      fullBookChapters[topBook] = List<int>.generate(
        chapterVerseCounts.length,
        (index) => index + 1,
      );
      fullBookChapterVerses[topBook] = {
        for (var index = 0; index < chapterVerseCounts.length; index++)
          index + 1: List<int>.generate(
            chapterVerseCounts[index],
            (i) => i + 1,
          ),
      };
    }

    setState(() {
      _verses = verses;
      _books = orderedBooks;
      _bookChapters = fullBookChapters;
      _bookChapterVerses = fullBookChapterVerses;
    });

    await _syncVerseNotifications();
    _nextVerse();
  }

  Future<void> _toggleDailyVerseNotifications(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required for daily verses.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _dailyVerseNotificationsEnabled = enabled;
    });
    await _savePersistentStats();
    await _syncVerseNotifications();
  }

  Future<void> _syncVerseNotifications() async {
    if (_dailyVerseNotificationsEnabled && _verses.isNotEmpty) {
      await NotificationService.instance.scheduleDailyRandomMiddayVerses(
        verses: _verses,
      );
      return;
    }
    await NotificationService.instance.cancelDailyVerseNotifications();
  }

  void _nextVerse() {
    setState(() {
      _currentVerse = _verses[_random.nextInt(_verses.length)];
      _selectedBook = null;
      _selectedChapter = null;
      _selectedVerse = null;
      _showingResult = false;
      _lastGuessRef = null;
      _round++;
    });
  }

  void _submitGuess() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerse == null) {
      return;
    }

    final correct = _currentVerse!;

    final bookOk = _selectedBook == correct['book_name'];
    final chapterOk = bookOk && _selectedChapter == correct['chapter'];
    final verseOk = chapterOk && _selectedVerse == correct['verse'];

    int points = 0;
    if (bookOk) points += 1;
    if (chapterOk) points += 2;
    if (verseOk) points += 3;

    var bookProgress = bookOk ? 1 : 0;
    var chapterProgress = chapterOk ? 1 : 0;
    var verseProgress = verseOk ? 1 : 0;

    setState(() {
      _lastPoints = points;
      _score += points;
      if (_score > _highScore) {
        _highScore = _score;
      }
      _lifetimeRounds++;
      _lifetimeScore += points;
      if (points > 0) {
        _currentStreak++;
        if (_currentStreak > _bestStreak) {
          _bestStreak = _currentStreak;
        }
        if (_currentStreak > _lifetimeBestStreak) {
          _lifetimeBestStreak = _currentStreak;
        }
      } else {
        _currentStreak = 0;
      }
      if (points == 6) {
        _lifetimePerfectRounds++;
      }
      _historyRoundPoints.add(points);
      _historyBookPoints.add(bookProgress);
      _historyChapterPoints.add(chapterProgress);
      _historyVersePoints.add(verseProgress);
      _booksCorrectInGame += bookProgress;
      _chaptersCorrectInGame += chapterProgress;
      _versesCorrectInGame += verseProgress;
      _lastGuessRef = '$_selectedBook $_selectedChapter:$_selectedVerse';
      _showingResult = true;
      _gameOver = points == 0;
    });

    _savePersistentStats();
  }

  void _restartGame() {
    setState(() {
      _score = 0;
      _round = 0;
      _gameOver = false;
      _showingResult = false;
      _lastPoints = 0;
      _booksCorrectInGame = 0;
      _chaptersCorrectInGame = 0;
      _versesCorrectInGame = 0;
      _currentStreak = 0;
      _bestStreak = 0;
      _lastGuessRef = null;
    });
    _nextVerse();
  }

  @override
  Widget build(BuildContext context) {
    if (_verses.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: _round == 0
            ? const Center(child: CircularProgressIndicator())
            : _buildGameScreen(),
      ),
    );
  }

  Widget _buildGameScreen() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.menu_book_rounded, color: cs.primary, size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gospel Quiz',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    'Top 777 NT verses',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(170),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 18,
                      color: cs.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Highscore: $_highScore',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Round $_round',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 20),

          // Verse card
          Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: cs.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(Icons.format_quote_rounded, color: cs.primary, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    _currentVerse?['text'] ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                      fontSize: 17,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_showingResult)
            _buildResultSection()
          else ...[
            _buildDropdownSection(),
            const SizedBox(height: 20),
            _buildSubmitButton(),
            const SizedBox(height: 18),
            _buildInGameStatsPanel(),
            const SizedBox(height: 18),
            _buildLearningProgressPanel(),
          ],

          const SizedBox(height: 16),
          Card(
            elevation: 1,
            color: cs.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: const Text('Daily Midday Verse Notification'),
              subtitle: const Text('Random verse at 12:00 each day'),
              value: _dailyVerseNotificationsEnabled,
              onChanged: _toggleDailyVerseNotifications,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDropdownSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final chapters = _selectedBook != null
        ? (_bookChapters[_selectedBook] ?? [])
        : <int>[];
    final verses = (_selectedBook != null && _selectedChapter != null)
        ? (_bookChapterVerses[_selectedBook]?[_selectedChapter] ?? [])
        : <int>[];

    InputDecoration dropdownDecor(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your Guess',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _selectedBook,
          decoration: dropdownDecor('Book'),
          isExpanded: true,
          menuMaxHeight: 350,
          items: _books
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: (v) => setState(() {
            _selectedBook = v;
            _selectedChapter = null;
            _selectedVerse = null;
          }),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedChapter,
                decoration: dropdownDecor('Chapter'),
                menuMaxHeight: 300,
                items: chapters
                    .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
                    .toList(),
                onChanged: _selectedBook == null
                    ? null
                    : (v) => setState(() {
                        _selectedChapter = v;
                        _selectedVerse = null;
                      }),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedVerse,
                decoration: dropdownDecor('Verse'),
                menuMaxHeight: 300,
                items: verses
                    .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                    .toList(),
                onChanged: _selectedChapter == null
                    ? null
                    : (v) => setState(() {
                        _selectedVerse = v;
                      }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit =
        _selectedBook != null &&
        _selectedChapter != null &&
        _selectedVerse != null;

    return FilledButton.icon(
      onPressed: canSubmit ? _submitGuess : null,
      icon: const Icon(Icons.check_circle_rounded),
      label: const Text('Submit Guess'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInGameStatsPanel() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 2,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'In-Game Stats',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Score system: Book: 1  Chapter: 2  Verse: 3',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withAlpha(170),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            // Large current score box
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Score',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_score',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Three boxes in a row
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    label: 'Books',
                    count: '$_booksCorrectInGame',
                    color: cs.primary,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    label: 'Chapters',
                    count: '$_chaptersCorrectInGame',
                    color: cs.secondary,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    label: 'Verses',
                    count: '$_versesCorrectInGame',
                    color: cs.tertiary,
                    theme: theme,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String count,
    required Color color,
    required ThemeData theme,
  }) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgressPanel() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allTimeAccuracy = _lifetimeRounds == 0
        ? 0
        : ((_lifetimeScore / (_lifetimeRounds * 6)) * 100).round();

    return Card(
      elevation: 2,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Progress Over Time',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$allTimeAccuracy%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              _showAllTimeGraphs
                  ? 'All sessions since first launch (${_historyRoundPoints.length} rounds)'
                  : 'Recent form: last 30 rounds',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('All-time'),
                  selected: _showAllTimeGraphs,
                  onSelected: (_) {
                    setState(() {
                      _showAllTimeGraphs = true;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Last 30'),
                  selected: !_showAllTimeGraphs,
                  onSelected: (_) {
                    setState(() {
                      _showAllTimeGraphs = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildProgressGraphRow(
              label: 'Book',
              values: _selectGraphSource(_historyBookPoints),
              maxValue: 1,
              color: cs.primary,
            ),
            const SizedBox(height: 12),
            _buildProgressGraphRow(
              label: 'Chapter',
              values: _selectGraphSource(_historyChapterPoints),
              maxValue: 1,
              color: cs.secondary,
            ),
            const SizedBox(height: 12),
            _buildProgressGraphRow(
              label: 'Verse',
              values: _selectGraphSource(_historyVersePoints),
              maxValue: 1,
              color: cs.tertiary,
            ),
            const SizedBox(height: 12),
            _buildProgressGraphRow(
              label: 'Total',
              values: _selectGraphSource(_historyRoundPoints),
              maxValue: 6,
              color: cs.primaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  List<int> _selectGraphSource(List<int> values) {
    if (_showAllTimeGraphs || values.length <= 30) {
      return values;
    }
    return values.sublist(values.length - 30);
  }

  Widget _buildProgressGraphRow({
    required String label,
    required List<int> values,
    required int maxValue,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final graphValues = _toGraphValues(values, bins: 24);
    final average = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / (values.length * maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${(average * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final value in graphValues)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.2),
                    child: Container(
                      height: value < 0
                          ? 4
                          : (6 + (value / maxValue).clamp(0.0, 1.0) * 30),
                      decoration: BoxDecoration(
                        color: value < 0
                            ? cs.surfaceContainerHighest
                            : Color.alphaBlend(
                                Colors.white.withAlpha(40),
                                color,
                              ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<double> _toGraphValues(List<int> values, {required int bins}) {
    if (values.isEmpty) {
      return List<double>.filled(bins, -1);
    }

    if (values.length <= bins) {
      final padded = List<double>.filled(bins, -1);
      final start = bins - values.length;
      for (var i = 0; i < values.length; i++) {
        padded[start + i] = values[i].toDouble();
      }
      return padded;
    }

    final compressed = <double>[];
    for (var i = 0; i < bins; i++) {
      final start = (i * values.length / bins).floor();
      final end = ((i + 1) * values.length / bins).floor();
      final safeEnd = end <= start ? start + 1 : end;
      var sum = 0;
      for (var j = start; j < safeEnd; j++) {
        sum += values[j];
      }
      compressed.add(sum / (safeEnd - start));
    }

    return compressed;
  }

  Widget _buildResultSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final correct = _currentVerse!;

    final bookOk = _selectedBook == correct['book_name'];
    final chapterOk = bookOk && _selectedChapter == correct['chapter'];
    final verseOk = chapterOk && _selectedVerse == correct['verse'];

    Color cardColor;
    Color contentColor;
    IconData headerIcon;
    String headerText;

    if (_gameOver) {
      cardColor = cs.errorContainer;
      contentColor = cs.onErrorContainer;
      headerIcon = Icons.heart_broken_rounded;
      headerText = 'Game Over!';
    } else if (_lastPoints == 6) {
      cardColor = const Color(0xFF1B5E20);
      contentColor = Colors.white;
      headerIcon = Icons.emoji_events_rounded;
      headerText = 'Perfect! +6';
    } else {
      cardColor = cs.tertiaryContainer;
      contentColor = cs.onTertiaryContainer;
      headerIcon = Icons.lightbulb_rounded;
      headerText = '+$_lastPoints point${_lastPoints == 1 ? '' : 's'}';
    }

    return Card(
      elevation: 6,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(headerIcon, size: 36, color: contentColor),
            const SizedBox(height: 8),
            Text(
              headerText,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Correct Answer',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: contentColor.withAlpha(220),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${correct['book_name']} ${correct['chapter']}:${correct['verse']}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
            if (_lastGuessRef != null) ...[
              const SizedBox(height: 10),
              Text(
                'Your guess: $_lastGuessRef',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: contentColor,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resultChip('Book', bookOk),
                const SizedBox(width: 8),
                _resultChip('Ch.', chapterOk),
                const SizedBox(width: 8),
                _resultChip('Vs.', verseOk),
              ],
            ),
            if (_gameOver) ...[
              const SizedBox(height: 12),
              Text(
                'Final Score: $_score',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: contentColor,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _gameOver ? _restartGame : _nextVerse,
              icon: Icon(
                _gameOver ? Icons.replay_rounded : Icons.arrow_forward_rounded,
              ),
              label: Text(_gameOver ? 'Play Again' : 'Next Verse'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultChip(String label, bool correct) {
    final cs = Theme.of(context).colorScheme;

    return Chip(
      avatar: Icon(
        correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
        color: correct ? const Color(0xFF2E7D32) : cs.error,
        size: 18,
      ),
      label: Text(label),
    );
  }
}
