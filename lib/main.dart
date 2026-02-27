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
    this.studentNumber = '',
    this.points = 0,
  });

  final String name;
  final String studentNumber;
  int points;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'] as String? ?? '',
      studentNumber: json['studentNumber'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'studentNumber': studentNumber,
      'points': points,
    };
  }
}

enum StudentSortOption {
  nameAsc,
  pointsDesc,
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

  int _selectedMenuIndex = 0;
  String _studentSearchQuery = '';
  StudentSortOption _studentSortOption = StudentSortOption.nameAsc;

  bool _isGiveCookieMode = false;
  int _giveCookieAmount = 1;
  static const int _rouletteCost = 10;
  final Set<Student> _selectedStudentsForGiveCookie = <Student>{};

  Widget _buildGiveCookiePanel() {
    return Builder(
      builder: (context) {
        final countController =
            TextEditingController(text: _giveCookieAmount.toString());

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text(
                      '포인트 지급',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: '개수',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isGiveCookieMode = false;
                          _selectedStudentsForGiveCookie.clear();
                        });
                      },
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () {
                        final parsed =
                            int.tryParse(countController.text.trim()) ?? 0;
                        if (parsed <= 0 ||
                            _selectedStudentsForGiveCookie.isEmpty) {
                          setState(() {
                            _isGiveCookieMode = false;
                            _selectedStudentsForGiveCookie.clear();
                          });
                          return;
                        }
                        setState(() {
                          _giveCookieAmount = parsed;
                          for (final student
                              in _selectedStudentsForGiveCookie.toList()) {
                            _adjustStudentPoints(student, parsed);
                          }
                          _isGiveCookieMode = false;
                          _selectedStudentsForGiveCookie.clear();
                        });
                      },
                      child: const Text('지급'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
              studentNumber: student.studentNumber,
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
              studentNumber: student.studentNumber,
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
      // 학생 삭제 시, 그 학생이 가지고 있던 포인트만큼 전체 점수에서 차감
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
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(),
                      const Divider(height: 1),
                      Expanded(
                        child: !_isDataLoaded
                            ? const Center(child: CircularProgressIndicator())
                            : Padding(
                                padding: const EdgeInsets.all(24),
                                child: _buildMainContent(),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isGiveCookieMode) ...[
              IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                top: 56,
                left: 220 + 24,
                right: 24,
                child: _buildGiveCookiePanel(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE0F2F1),
                  ),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '학생 상점',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '관리자 대시보드',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildSidebarItem(
            index: 0,
            icon: Icons.people_alt_outlined,
            label: '학생 목록',
          ),
          _buildSidebarItem(
            index: 1,
            icon: Icons.insights_outlined,
            label: '전체 점수 보기',
          ),
          _buildSidebarItem(
            index: 2,
            icon: Icons.casino_outlined,
            label: '상점 룰렛',
          ),
          _buildSidebarItem(
            index: 3,
            icon: Icons.storefront_outlined,
            label: '상점 상품 관리',
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              '오늘도 즐거운 수업 되세요!',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMenuIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMenuIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2E8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.teal.shade700 : Colors.grey.shade700,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.teal.shade800 : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final sectionLabel = switch (_selectedMenuIndex) {
      0 => '학생 목록 관리',
      1 => '전체 점수 & 보상 현황',
      2 => '상점 룰렛',
      3 => '상점 상품 관리',
      _ => '대시보드',
    };

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '학생 상점 관리자',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sectionLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          );

          final statusChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '실시간 관리',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.teal,
              ),
            ),
          );

          final searchAndSort = _selectedMenuIndex == 0
              ? _buildStudentSearchAndSortRow(isCompact: isCompact)
              : const SizedBox.shrink();

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 8),
                    statusChip,
                  ],
                ),
                if (_selectedMenuIndex == 0) ...[
                  const SizedBox(height: 12),
                  searchAndSort,
                ],
              ],
            );
          }

          return Row(
            children: [
              titleBlock,
              const SizedBox(width: 16),
              statusChip,
              const Spacer(),
              if (_selectedMenuIndex == 0) searchAndSort,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentSearchAndSortRow({required bool isCompact}) {
    final searchField = TextField(
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
        ),
        hintText: '학생 이름 검색',
        filled: true,
        fillColor: const Color(0xFFF5F7FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onChanged: (value) {
        setState(() {
          _studentSearchQuery = value;
        });
      },
    );

    final sortDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: DropdownButton<StudentSortOption>(
        value: _studentSortOption,
        underline: const SizedBox.shrink(),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
        ),
        style: const TextStyle(fontSize: 12),
        onChanged: (value) {
          if (value == null) {
            return;
          }
          setState(() {
            _studentSortOption = value;
          });
        },
        items: const [
          DropdownMenuItem(
            value: StudentSortOption.nameAsc,
            child: Text('이름순'),
          ),
          DropdownMenuItem(
            value: StudentSortOption.pointsDesc,
            child: Text('점수 높은순'),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: searchField,
            ),
          ),
          const SizedBox(width: 12),
          sortDropdown,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 40,
          child: searchField,
        ),
        const SizedBox(width: 12),
        sortDropdown,
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_selectedMenuIndex) {
      case 0:
        return SingleChildScrollView(
          child: _buildStudentSection(),
        );
      case 1:
        // 전체 점수 보기: 화면을 가득 채우는 느낌으로 중앙 정렬
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildTotalScoreSection(),
                ),
              ),
            );
          },
        );
      case 2:
        // 상점 룰렛 화면: 룰렛 섹션만 가득 차게
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildRouletteSection(),
                ),
              ),
            );
          },
        );
      case 3:
        // 상점 상품 관리 화면: 상품 관리 섹션만 가득 차게
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildStoreSection(),
                ),
              ),
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStudentSection() {
    final visibleStudents = _filteredSortedStudents();

    return Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 포인트 지급 버튼
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: _students.isEmpty
                        ? null
                        : () {
                            setState(() {
                              if (_isGiveCookieMode) {
                                _isGiveCookieMode = false;
                                _selectedStudentsForGiveCookie.clear();
                              } else {
                                if (_giveCookieAmount <= 0) {
                                  _giveCookieAmount = 1;
                                }
                                _isGiveCookieMode = true;
                                _selectedStudentsForGiveCookie.clear();
                              }
                            });
                          },
                    child:
                        Text(_isGiveCookieMode ? '포인트 지급 종료' : '포인트 지급'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 학생 카드들 + 추가 카드 (가로 스크롤)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < visibleStudents.length; i++) ...[
                      _buildStudentTile(
                        index: i + 1,
                        student: visibleStudents[i],
                      ),
                      const SizedBox(width: 12),
                    ],
                    _buildStudentAddTile(width: 116),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Student> _filteredSortedStudents() {
    Iterable<Student> result = _students;
    final query = _studentSearchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where(
        (student) => student.name.toLowerCase().contains(query),
      );
    }

    int parseNumber(Student s) {
      final numOnly =
          s.studentNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
      return int.tryParse(numOnly.isEmpty ? s.studentNumber : numOnly) ??
          1000000;
    }

    final list = result.toList();
    list.sort((a, b) {
      final an = parseNumber(a);
      final bn = parseNumber(b);
      final cmp = an.compareTo(bn);
      if (cmp != 0) {
        return cmp;
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> _showAddStudentDialog() async {
    if (!_isDataLoaded) {
      return;
    }

    final numberController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<({String number, String name})>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('학생 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '학생 번호',
                  hintText: '예) 1, 2, 3',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '학생 이름',
                  hintText: '예) 김철수',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop((
                number: numberController.text.trim(),
                name: nameController.text.trim(),
              )),
              child: const Text('추가'),
            ),
          ],
        );
      },
    );

    numberController.dispose();
    nameController.dispose();

    if (result == null) {
      return;
    }

    final number = result.number.trim();
    final name = result.name.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _students.add(
        Student(
          name: name,
          studentNumber: number,
        ),
      );
    });
    unawaited(_persistData());
  }

  Widget _buildStudentAddTile({required double width}) {
    return SizedBox(
      width: width,
      height: 96,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: Colors.white,
        ),
        onPressed: _showAddStudentDialog,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '학생 추가',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile({
    required int index,
    required Student student,
  }) {
    final bool isSelectedForGiveCookie =
        _isGiveCookieMode && _selectedStudentsForGiveCookie.contains(student);

    return InkWell(
      onTap: _isGiveCookieMode
          ? () {
              setState(() {
                if (isSelectedForGiveCookie) {
                  _selectedStudentsForGiveCookie.remove(student);
                } else {
                  _selectedStudentsForGiveCookie.add(student);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelectedForGiveCookie
              ? Colors.teal.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelectedForGiveCookie
                ? Colors.teal.shade400
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade100,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.studentNumber.isNotEmpty
                            ? '${student.studentNumber} 번'
                            : '- 번',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.points} 포인트',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '학생 삭제',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeStudent(student),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPointActionButton(
                  label: '+1',
                  background: Colors.teal.shade50,
                  foreground: Colors.teal.shade700,
                  onPressed: () => _adjustStudentPoints(student, 1),
                ),
                const SizedBox(width: 4),
                _buildPointActionButton(
                  label: '-1',
                  background: Colors.orange.shade50,
                  foreground: Colors.orange.shade800,
                  onPressed: () => _adjustStudentPoints(student, -1),
                ),
                const SizedBox(width: 4),
                _buildPointActionButton(
                  label: '룰렛',
                  background: Colors.purple.shade50,
                  foreground: Colors.purple.shade700,
                  onPressed: student.points >= _rouletteCost
                      ? () => _adjustStudentPoints(
                            student,
                            -_rouletteCost,
                            isRoulette: true,
                          )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointActionButton({
    required String label,
    required Color background,
    required Color foreground,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 30,
      width: 40,
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
    return SizedBox(
      width: double.infinity,
      child: Card(
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                                onChanged: (value) =>
                                    _toggleItemActive(item, value),
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
      ),
    );
  }

  Widget _buildRouletteSection() {
    final activeItems = _activeStoreItems();
    final group = _createRouletteGroup(activeItems);
    final canSpin = !_isSpinning && group != null;

    return SizedBox(
      width: double.infinity,
      child: Card(
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
              children: [
                const Expanded(
                  child: Text(
                    '전체 점수 현황',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$totalScore / $maxScore 점',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: totalScore > 0 ? _confirmResetTotalScore : null,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('전체 점수 초기화'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isDataLoaded ? _confirmResetAllData : null,
                  child: Text(
                    '모든 데이터 초기화',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
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
                            margin: const EdgeInsets.only(right: 32),
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
                      labelText: '목표 점수 (50점 단위)',
                      hintText: '예) 50, 100, 150...',
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

    // 50점 단위 확인
    if (score % 50 != 0) {
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

  Future<void> _confirmResetTotalScore() async {
    if (!_isDataLoaded || _totalScore <= 0) {
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('전체 점수 초기화'),
          content: const Text('전체 점수를 0점으로 초기화할까요? 학생 개별 점수는 유지됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      _totalScore = 0;
    });
    await _persistData();
  }

  Future<void> _confirmResetAllData() async {
    if (!_isDataLoaded) {
      return;
    }

    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('모든 데이터 초기화'),
          content: const Text(
            '학생 목록, 상품, 보상 목표, 전체 점수를 모두 삭제하고 0에서 다시 시작할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('초기화'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) {
      return;
    }

    setState(() {
      _students.clear();
      _storeItems.clear();
      _rewardGoals.clear();
      _totalScore = 0;
      _rouletteResult = null;
      _selectedStudentsForGiveCookie.clear();
      _isGiveCookieMode = false;
    });
    await _persistData();
  }
}
