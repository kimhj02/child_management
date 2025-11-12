import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:roulette/roulette.dart';

void main() {
  runApp(const StudentShopApp());
}

class StudentShopApp extends StatelessWidget {
  const StudentShopApp({super.key});

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
      home: const StudentShopHomePage(),
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

class LocalDataPayload {
  LocalDataPayload({
    required this.students,
    required this.storeItems,
  });

  LocalDataPayload.empty()
      : students = const [],
        storeItems = const [];

  final List<Student> students;
  final List<StoreItem> storeItems;
}

class LocalDataStore {
  LocalDataStore({this.fileName = 'student_shop_data.json'});

  final String fileName;
  File? _cachedFile;

  Future<File> _ensureFile() async {
    if (_cachedFile != null) {
      return _cachedFile!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString(jsonEncode(_emptyPayload), flush: true);
    }

    _cachedFile = file;
    return file;
  }

  Future<LocalDataPayload> load() async {
    try {
      final file = await _ensureFile();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return LocalDataPayload.empty();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return LocalDataPayload.empty();
      }

      final studentList = decoded['students'];
      final storeItemList = decoded['storeItems'];

      return LocalDataPayload(
        students: _decodeStudents(studentList),
        storeItems: _decodeStoreItems(storeItemList),
      );
    } catch (_) {
      return LocalDataPayload.empty();
    }
  }

  Future<void> save({
    required List<Student> students,
    required List<StoreItem> storeItems,
  }) async {
    try {
      final file = await _ensureFile();
      final payload = {
        'students': students.map((student) => student.toJson()).toList(),
        'storeItems': storeItems.map((item) => item.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // 저장 실패 시 조용히 무시 (단일 PC 사용 시 치명적이지 않음)
    }
  }

  static const Map<String, dynamic> _emptyPayload = {
    'students': <Map<String, dynamic>>[],
    'storeItems': <Map<String, dynamic>>[],
  };

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
}

class StudentShopHomePage extends StatefulWidget {
  const StudentShopHomePage({super.key});

  @override
  State<StudentShopHomePage> createState() => _StudentShopHomePageState();
}

class _StudentShopHomePageState extends State<StudentShopHomePage> {
  final List<Student> _students = [];
  final List<StoreItem> _storeItems = [];
  final LocalDataStore _dataStore = LocalDataStore();

  final TextEditingController _studentNameController = TextEditingController();

  final TextEditingController _itemNameController = TextEditingController();

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
    _loadInitialData();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _itemNameController.dispose();
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

  void _adjustStudentPoints(Student student, int delta) {
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
    const maxPoints = 20;

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
              '학생 포인트 현황 (최대 20점)',
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
                      _adjustStudentPoints(student, -10);
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
}
