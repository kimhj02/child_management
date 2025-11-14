import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:roulette/roulette.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StudentShopApp());
}

class StudentShopApp extends StatelessWidget {
  const StudentShopApp({
    super.key,
    this.dataStore,
  });

  final LocalDataStore? dataStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '학생 상점 관리자',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: StudentShopHomePage(
        dataStore: dataStore,
      ),
    );
  }
}

class Student {
  Student({
    required this.name,
    this.points = 0,
  });

  final String name;
  int points;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'points': points,
    };
  }
}

class StoreItem {
  StoreItem({
    required this.name,
  });

  final String name;
  bool isActive = true;

  StoreItem.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String? ?? '',
        isActive = json['isActive'] as bool? ?? true;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'isActive': isActive,
    };
  }
}

class RewardGoal {
  RewardGoal({
    required this.targetScore,
    required this.reward,
  });

  final int targetScore;
  String reward;

  factory RewardGoal.fromJson(Map<String, dynamic> json) {
    return RewardGoal(
      targetScore: (json['targetScore'] as num?)?.toInt() ?? 0,
      reward: json['reward'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetScore': targetScore,
      'reward': reward,
    };
  }
}

class LocalDataPayload {
  LocalDataPayload({
    required this.students,
    required this.storeItems,
    required this.rewardGoals,
    this.totalScore = 0,
  });

  LocalDataPayload.empty()
      : students = const [],
        storeItems = const [],
        rewardGoals = const [],
        totalScore = 0;

  final List<Student> students;
  final List<StoreItem> storeItems;
  final List<RewardGoal> rewardGoals;
  final int totalScore;
}

class LocalDataStore {
  LocalDataStore({SharedPreferences? preferences})
      : _preferences = preferences;

  final SharedPreferences? _preferences;

  static const String _storageKey = 'student_shop_data';

  Future<SharedPreferences> _ensurePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }
    return SharedPreferences.getInstance();
  }

  Future<LocalDataPayload> load() async {
    try {
      final prefs = await _ensurePreferences();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return LocalDataPayload.empty();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return LocalDataPayload.empty();
      }

      final studentList = decoded['students'];
      final storeItemList = decoded['storeItems'];
      final rewardGoalList = decoded['rewardGoals'];
      final totalScore = (decoded['totalScore'] as num?)?.toInt() ?? 0;

      return LocalDataPayload(
        students: _decodeStudents(studentList),
        storeItems: _decodeStoreItems(storeItemList),
        rewardGoals: _decodeRewardGoals(rewardGoalList),
        totalScore: totalScore,
      );
    } catch (_) {
      return LocalDataPayload.empty();
    }
  }

  Future<void> save({
    required List<Student> students,
    required List<StoreItem> storeItems,
    required List<RewardGoal> rewardGoals,
    required int totalScore,
  }) async {
    try {
      final prefs = await _ensurePreferences();
      final payload = {
        'students': students.map((student) => student.toJson()).toList(),
        'storeItems': storeItems.map((item) => item.toJson()).toList(),
        'rewardGoals': rewardGoals.map((goal) => goal.toJson()).toList(),
        'totalScore': totalScore,
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {
      // 저장 실패 시 조용히 무시 (단일 PC 사용 시 치명적이지 않음)
    }
  }

  List<Student> _decodeStudents(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map((element) {
          if (element is Map<String, dynamic>) {
            return Student.fromJson(element);
          }
          if (element is Map) {
            return Student.fromJson(
              element.map(
                (key, val) => MapEntry(key.toString(), val),
              ),
            );
          }
          return null;
        })
        .whereType<Student>()
        .toList();
  }

  List<StoreItem> _decodeStoreItems(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map((element) {
          if (element is Map<String, dynamic>) {
            return StoreItem.fromJson(element);
          }
          if (element is Map) {
            return StoreItem.fromJson(
              element.map(
                (key, val) => MapEntry(key.toString(), val),
              ),
            );
          }
          return null;
        })
        .whereType<StoreItem>()
        .toList();
  }

  List<RewardGoal> _decodeRewardGoals(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value
        .map((element) {
          if (element is Map<String, dynamic>) {
            return RewardGoal.fromJson(element);
          }
          if (element is Map) {
            return RewardGoal.fromJson(
              element.map(
                (key, val) => MapEntry(key.toString(), val),
              ),
            );
          }
          return null;
        })
        .whereType<RewardGoal>()
        .toList();
  }
}

class StudentShopHomePage extends StatefulWidget {
  const StudentShopHomePage({
    super.key,
    this.dataStore,
  });

  final LocalDataStore? dataStore;

  @override
  State<StudentShopHomePage> createState() => _StudentShopHomePageState();
}

class _StudentShopHomePageState extends State<StudentShopHomePage> {
  final List<Student> _students = [];
  final List<StoreItem> _storeItems = [];
  final List<RewardGoal> _rewardGoals = [];
  int _totalScore = 0;
  late final LocalDataStore _dataStore;

  final TextEditingController _studentNameController = TextEditingController();

  final TextEditingController _itemNameController = TextEditingController();
  
  final TextEditingController _rewardGoalScoreController = TextEditingController();
  final TextEditingController _rewardGoalRewardController = TextEditingController();

  final RouletteController _rouletteController = RouletteController();
  final Random _random = Random();

  String? _rouletteResult;
  bool _isSpinning = false;
  bool _isDataLoaded = false;

  static const double _rouletteWheelSize = 200;
  static const List<Color> _rouletteSliceColors = [
    Color(0xFF00897B),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF3949AB),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFF5E35B1),
    Color(0xFF00796B),
  ];

  @override
  void initState() {
    super.initState();
    _dataStore = widget.dataStore ?? LocalDataStore();
    _loadInitialData();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _itemNameController.dispose();
    _rewardGoalScoreController.dispose();
    _rewardGoalRewardController.dispose();
    _rouletteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final payload = await _dataStore.load();
    if (!mounted) {
      return;
    }

    setState(() {
      _students
        ..clear()
        ..addAll(
          payload.students.map(
            (student) => Student(
              name: student.name,
              points: student.points,
            ),
          ),
        );
      _storeItems
        ..clear()
        ..addAll(
          payload.storeItems.map((item) {
            final restored = StoreItem(name: item.name);
            restored.isActive = item.isActive;
            return restored;
          }),
        );
      _rewardGoals
        ..clear()
        ..addAll(
          payload.rewardGoals.map((goal) {
            final restored = RewardGoal(
              targetScore: goal.targetScore,
              reward: goal.reward,
            );
            return restored;
          }),
        );
      // 기존 데이터 마이그레이션: totalScore가 없으면 학생 포인트 합으로 초기화
      if (payload.totalScore == 0 && payload.students.isNotEmpty) {
        _totalScore = payload.students.fold(0, (sum, student) => sum + student.points);
      } else {
        _totalScore = payload.totalScore;
      }
      _isDataLoaded = true;
    });
  }

  Future<void> _persistData() async {
    await _dataStore.save(
      students: _students
          .map(
            (student) => Student(
              name: student.name,
              points: student.points,
            ),
          )
          .toList(growable: false),
      storeItems: _storeItems
          .map((item) {
            final copy = StoreItem(name: item.name);
            copy.isActive = item.isActive;
            return copy;
          })
          .toList(growable: false),
      rewardGoals: _rewardGoals
          .map((goal) => RewardGoal(
                targetScore: goal.targetScore,
                reward: goal.reward,
              ))
          .toList(growable: false),
      totalScore: _totalScore,
    );
  }

  void _addStudent() {
    if (!_isDataLoaded) {
      return;
    }

    final name = _studentNameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    setState(() {
      _students.add(
        Student(
          name: name,
        ),
      );
      _studentNameController.clear();
    });
    unawaited(_persistData());
  }

  void _removeStudent(Student student) {
    if (!_isDataLoaded) {
      return;
    }

    setState(() {
      // 학생 삭제 시 그 학생의 포인트만큼 total_score에서 차감
      _totalScore = max(0, _totalScore - student.points);
      _students.remove(student);
    });
    unawaited(_persistData());
  }

  void _addStoreItem() {
    if (!_isDataLoaded) {
      return;
    }

    final name = _itemNameController.text.trim();

    if (name.isEmpty) {
      return;
    }

    setState(() {
      _storeItems.add(
        StoreItem(
          name: name,
        ),
      );
      _itemNameController.clear();
    });
    unawaited(_persistData());
  }

  void _removeStoreItem(StoreItem item) {
    if (!_isDataLoaded) {
      return;
    }

    setState(() {
      _storeItems.remove(item);
      if (_rouletteResult == item.name) {
        _rouletteResult = null;
      }
    });
    unawaited(_persistData());
  }

  void _toggleItemActive(StoreItem item, bool value) {
    if (!_isDataLoaded) {
      return;
    }

    setState(() {
      item.isActive = value;
      if (!item.isActive && _rouletteResult == item.name) {
        _rouletteResult = null;
      }
    });
    unawaited(_persistData());
  }

  List<StoreItem> _activeStoreItems() {
    return _storeItems.where((item) => item.isActive).toList(growable: false);
  }

  RouletteGroup? _createRouletteGroup(List<StoreItem> items) {
    if (items.isEmpty) {
      return null;
    }

    const textStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );

    return RouletteGroup.uniform(
      items.length,
      textBuilder: (index) => items[index].name,
      textStyleBuilder: (_) => textStyle,
      colorBuilder: (index) =>
          _rouletteSliceColors[index % _rouletteSliceColors.length],
    );
  }

  Future<void> _spinRoulette() async {
    if (_isSpinning || !_isDataLoaded) {
      return;
    }

    final activeItems = _activeStoreItems();
    if (activeItems.isEmpty) {
      return;
    }

    final targetIndex = _random.nextInt(activeItems.length);
    final offset = _random.nextDouble();

    setState(() {
      _isSpinning = true;
      _rouletteResult = null;
    });

    bool rollCompleted = false;
    try {
      rollCompleted = await _rouletteController.rollTo(
        targetIndex,
        duration: const Duration(milliseconds: 4200),
        minRotateCircles: 6,
        curve: Curves.easeOutQuart,
        offset: offset,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSpinning = false;
          if (rollCompleted) {
            final latestItems = _activeStoreItems();
            if (targetIndex < latestItems.length) {
              _rouletteResult = latestItems[targetIndex].name;
            }
          }
        });
      }
    }
  }

  void _adjustStudentPoints(Student student, int delta, {bool isRoulette = false}) {
    if (!_isDataLoaded) {
      return;
    }

    if (!_students.contains(student)) {
      return;
    }

    final original = student.points;
    final updated = max(0, original + delta);
    final actualDelta = updated - original;

    if (actualDelta == 0 && delta < 0) {
      return;
    }

    setState(() {
      student.points = updated;
      // 룰렛 사용 시에는 total_score를 유지, 일반 포인트 변경 시에는 total_score도 변경
      if (!isRoulette) {
        _totalScore = max(0, _totalScore + actualDelta);
      }
    });

    if (actualDelta == 0) {
      return;
    }

    unawaited(_persistData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학생 상점 관리자'),
      ),
      body: !_isDataLoaded
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTotalScoreSection(),
                      const SizedBox(height: 16),
                      _buildStudentSection(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildRouletteSection(),
                      const SizedBox(height: 16),
                      _buildStoreSection(),
                    ],
                  ),
                ),
              ],
            ),
          );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTotalScoreSection(),
                const SizedBox(height: 16),
                _buildStudentSection(),
                const SizedBox(height: 16),
                _buildRouletteSection(),
                const SizedBox(height: 16),
                _buildStoreSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentSection() {
    const maxPoints = 100;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학생 관리',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentNameController,
                    decoration: const InputDecoration(
                      labelText: '학생 이름',
                      hintText: '예) 김철수',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addStudent(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _addStudent,
                    child: const Text('추가'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 24),
            const Text(
              '학생 포인트 현황 (최대 100점)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_students.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('등록된 학생이 없습니다.'),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _students.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == _students.length - 1 ? 0 : 16),
                      child: _buildStudentBarRow(_students[i], maxPoints),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentBarRow(Student student, int maxPoints) {
    final ratio = maxPoints == 0 ? 0.0 : student.points / max(1, maxPoints);
    final clamped = ratio.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                student.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 20,
                  child: Stack(
                    children: [
                      Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: clamped,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.shade400,
                                Colors.tealAccent.shade400,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 68,
              child: Text(
                '${student.points}점',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPointActionButton(
              label: '+1',
              background: Colors.teal.shade50,
              foreground: Colors.teal.shade700,
              onPressed: () => _adjustStudentPoints(student, 1),
            ),
            const SizedBox(width: 6),
            _buildPointActionButton(
              label: '-1',
              background: Colors.orange.shade50,
              foreground: Colors.orange.shade800,
              onPressed: () => _adjustStudentPoints(student, -1),
            ),
            const SizedBox(width: 6),
            _buildPointActionButton(
              label: '룰렛',
              background: Colors.purple.shade50,
              foreground: Colors.purple.shade700,
              onPressed: student.points >= 10
                  ? () {
                      _adjustStudentPoints(student, -10, isRoulette: true);
                      setState(() {
                        _rouletteResult = null;
                      });
                    }
                  : null,
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: '학생 삭제',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _removeStudent(student),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPointActionButton({
    required String label,
    required Color background,
    required Color foreground,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 32,
      width: 48,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildStoreSection() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '룰렛 상품 관리',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '룰렛에 사용할 상품을 등록하세요. 활성화된 상품만 룰렛에 포함됩니다.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _itemNameController,
              decoration: const InputDecoration(
                labelText: '아이템 이름',
                hintText: '예) 간식 쿠폰',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addStoreItem(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _addStoreItem,
                child: const Text('아이템 추가'),
              ),
            ),
            const Divider(height: 32),
            if (_storeItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('등록된 상품이 없습니다.'),
                ),
              )
            else
              Column(
                children: _storeItems.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      dense: true,
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        item.isActive ? '룰렛에 포함됨' : '룰렛에서 제외됨',
                        style: TextStyle(
                          color: item.isActive
                              ? Colors.teal.shade600
                              : Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: item.isActive,
                              onChanged: (value) => _toggleItemActive(item, value),
                            ),
                          ),
                          IconButton(
                            tooltip: '아이템 삭제',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeStoreItem(item),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouletteSection() {
    final activeItems = _activeStoreItems();
    final group = _createRouletteGroup(activeItems);
    final canSpin = !_isSpinning && group != null;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '상점 룰렛',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('활성화된 아이템 중에서 무작위로 당첨을 선택합니다.'),
            const SizedBox(height: 12),
            SizedBox(
              height: _rouletteWheelSize + 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (group != null)
                    Positioned(
                      top: 0,
                      child: _buildRoulettePointer(),
                    ),
                  Positioned(
                    top: group != null ? 36 : 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Center(
                      child: SizedBox(
                        width: _rouletteWheelSize,
                        height: _rouletteWheelSize,
                        child: group != null
                            ? Roulette(
                                controller: _rouletteController,
                                group: group,
                                style: const RouletteStyle(
                                  dividerThickness: 2.5,
                                  centerStickerColor: Colors.white,
                                  textLayoutBias: 0.82,
                                ),
                              )
                            : _buildEmptyRoulettePlaceholder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSpin ? _spinRoulette : null,
                icon: const Icon(Icons.casino),
                label: Text(_isSpinning ? '스핀 중...' : '룰렛 돌리기'),
              ),
            ),
            if (!canSpin && group == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '활성화된 아이템을 1개 이상 등록하세요.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 16),
            if (_rouletteResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '이번 당첨 아이템',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _rouletteResult!,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRoulettePlaceholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            '룰렛에 사용할 활성화된 아이템이 없습니다.\n상품을 추가하고 스위치를 켜주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoulettePointer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: const Icon(
        Icons.arrow_drop_down,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildTotalScoreSection() {
    const maxScore = 2000;
    final totalScore = _totalScore;
    final ratio = totalScore / maxScore;
    final clampedRatio = ratio.clamp(0.0, 1.0);

    // 보상 목표점수 정렬 (낮은 점수부터)
    final sortedGoals = List<RewardGoal>.from(_rewardGoals)
      ..sort((a, b) => a.targetScore.compareTo(b.targetScore));

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '전체 점수 현황',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$totalScore / $maxScore 점',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 세로 막대 그래프
            SizedBox(
              height: 300,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        // 배경 그리드
                        Column(
                          children: [
                            for (var i = 10; i >= 0; i--)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        '${i * 200}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // 막대 그래프
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: 300 * clampedRatio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.teal.shade400,
                                  Colors.tealAccent.shade400,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Stack(
                              children: [
                                // 보상 목표선
                                for (final goal in sortedGoals)
                                  if (goal.targetScore <= maxScore)
                                    Positioned(
                                      bottom: (goal.targetScore / maxScore) * 300 - 1,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        color: totalScore >= goal.targetScore
                                            ? Colors.green.shade600
                                            : Colors.orange.shade600,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                color: totalScore >= goal.targetScore
                                                    ? Colors.green.shade600
                                                    : Colors.orange.shade600,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: totalScore >= goal.targetScore
                                                    ? Colors.green.shade600
                                                    : Colors.orange.shade600,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${goal.targetScore}점',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 보상 목록
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '보상 목표',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (sortedGoals.isEmpty)
                          Text(
                            '보상 목표가 없습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: sortedGoals.length,
                              itemBuilder: (context, index) {
                                final goal = sortedGoals[index];
                                final isAchieved = totalScore >= goal.targetScore;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isAchieved
                                        ? Colors.green.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isAchieved
                                          ? Colors.green.shade300
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isAchieved
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            size: 16,
                                            color: isAchieved
                                                ? Colors.green.shade700
                                                : Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${goal.targetScore}점',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isAchieved
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        goal.reward,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isAchieved
                                              ? Colors.green.shade800
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // 보상 목표 관리
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rewardGoalScoreController,
                    decoration: const InputDecoration(
                      labelText: '목표 점수 (100점 단위)',
                      hintText: '예) 100, 200, 300...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rewardGoalRewardController,
                    decoration: const InputDecoration(
                      labelText: '보상 내용',
                      hintText: '예) 간식 파티',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addRewardGoal,
                  child: const Text('추가'),
                ),
              ],
            ),
            if (sortedGoals.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sortedGoals.map((goal) {
                  return Chip(
                    label: Text('${goal.targetScore}점: ${goal.reward}'),
                    onDeleted: () => _removeRewardGoal(goal),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addRewardGoal() {
    if (!_isDataLoaded) {
      return;
    }

    final scoreText = _rewardGoalScoreController.text.trim();
    final reward = _rewardGoalRewardController.text.trim();

    if (scoreText.isEmpty || reward.isEmpty) {
      return;
    }

    final score = int.tryParse(scoreText);
    if (score == null || score <= 0 || score > 2000) {
      return;
    }

    // 100점 단위 확인
    if (score % 100 != 0) {
      return;
    }

    // 이미 존재하는 점수인지 확인
    if (_rewardGoals.any((goal) => goal.targetScore == score)) {
      return;
    }

    setState(() {
      _rewardGoals.add(RewardGoal(targetScore: score, reward: reward));
      _rewardGoalScoreController.clear();
      _rewardGoalRewardController.clear();
    });
    unawaited(_persistData());
  }

  void _removeRewardGoal(RewardGoal goal) {
    if (!_isDataLoaded) {
      return;
    }

    setState(() {
      _rewardGoals.remove(goal);
    });
    unawaited(_persistData());
  }
}
