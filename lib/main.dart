import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const ContactIndexDemoApp());
}

class ContactIndexDemoApp extends StatelessWidget {
  const ContactIndexDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '微信式索引通讯录',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1AAD19),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8F5),
      ),
      home: const ContactIndexDemoPage(),
    );
  }
}

class ContactIndexDemoPage extends StatefulWidget {
  const ContactIndexDemoPage({super.key});

  @override
  State<ContactIndexDemoPage> createState() => _ContactIndexDemoPageState();
}

class _ContactIndexDemoPageState extends State<ContactIndexDemoPage> {
  static const double _sectionHeaderExtent = 38;
  static const double _contactTileExtent = 72;
  static const double _preferredIndexLetterExtent = 14;
  static final List<String> _indexLetters = <String>[
    ...List<String>.generate(
      26,
      (int index) => String.fromCharCode(65 + index),
    ),
    '#',
  ];

  late final ScrollController _scrollController;
  late final List<ContactSection> _sections;
  late final Map<String, ContactSection> _sectionMap;
  late final Map<String, double> _sectionOffsets;

  String _currentLetter = 'A';
  String? _dragLetter;

  @override
  void initState() {
    super.initState();
    _sections = groupContacts(buildSampleContacts());
    _sectionMap = <String, ContactSection>{
      for (final ContactSection section in _sections) section.letter: section,
    };
    _sectionOffsets = calculateSectionOffsets(
      _sections,
      headerExtent: _sectionHeaderExtent,
      itemExtent: _contactTileExtent,
    );
    _currentLetter = _sections.first.letter;
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _dragLetter != null) {
      return;
    }

    final String? letter = letterFromOffset(
      _scrollController.offset,
      _sections,
      _sectionOffsets,
    );
    if (letter != null && letter != _currentLetter) {
      setState(() {
        _currentLetter = letter;
      });
    }
  }

  void _handleIndexTapDown(TapDownDetails details, double letterExtent) {
    _selectIndexLetter(
      _letterFromLocalDy(details.localPosition.dy, letterExtent),
      animate: true,
      fromDrag: false,
    );
  }

  void _handleIndexDragDown(DragDownDetails details, double letterExtent) {
    _selectIndexLetter(
      _letterFromLocalDy(details.localPosition.dy, letterExtent),
      animate: false,
      fromDrag: true,
    );
  }

  void _handleIndexDragUpdate(DragUpdateDetails details, double letterExtent) {
    _selectIndexLetter(
      _letterFromLocalDy(details.localPosition.dy, letterExtent),
      animate: false,
      fromDrag: true,
    );
  }

  void _handleIndexDragEnd([DragEndDetails? _]) {
    if (_dragLetter == null) {
      return;
    }

    setState(() {
      _dragLetter = null;
    });
  }

  String _letterFromLocalDy(double dy, double letterExtent) {
    final double totalHeight = _indexLetters.length * letterExtent;
    final double normalizedDy = dy.clamp(0.0, totalHeight - 0.001).toDouble();
    final int index = (normalizedDy / letterExtent).floor().clamp(
      0,
      _indexLetters.length - 1,
    );
    return _indexLetters[index];
  }

  void _selectIndexLetter(
    String letter, {
    required bool animate,
    required bool fromDrag,
  }) {
    final bool hasSection = _sectionMap.containsKey(letter);
    final String? nextDragLetter = fromDrag ? letter : null;
    if (_dragLetter != nextDragLetter || (hasSection && _currentLetter != letter)) {
      setState(() {
        _dragLetter = nextDragLetter;
        if (hasSection) {
          _currentLetter = letter;
        }
      });
    }

    if (!hasSection || !_scrollController.hasClients) {
      return;
    }

    final double maxScrollExtent = _scrollController.position.maxScrollExtent;
    final double targetOffset = (_sectionOffsets[letter] ?? 0)
        .clamp(0.0, maxScrollExtent)
        .toDouble();

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if ((_scrollController.offset - targetOffset).abs() > 1) {
      _scrollController.jumpTo(targetOffset);
    }
  }

  List<Widget> _buildSlivers() {
    final List<Widget> slivers = <Widget>[];

    for (final ContactSection section in _sections) {
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: SectionHeaderDelegate(
            letter: section.letter,
            count: section.contacts.length,
            height: _sectionHeaderExtent,
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return ContactTile(
                contact: section.contacts[index],
                extent: _contactTileExtent,
              );
            },
            childCount: section.contacts.length,
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 20)));
    return slivers;
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label$value',
              style: TextStyle(
                color: const Color(0xFF1F2937),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexBar(double availableHeight) {
    final String selectedLetter = _dragLetter ?? _currentLetter;
    final double desiredHeight =
        _indexLetters.length * _preferredIndexLetterExtent;
    final double barHeight = math.min(
      desiredHeight,
      math.max(availableHeight - 12, 0),
    );
    final double letterExtent = barHeight / _indexLetters.length;
    final double letterFontSize = math.max(
      8,
      math.min(10, letterExtent - 2),
    );
    final double activeBubbleHeight = math.max(12, letterExtent - 2);

    return SizedBox(
      key: const ValueKey<String>('index-bar'),
      width: 42,
      height: barHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails details) {
          _handleIndexTapDown(details, letterExtent);
        },
        onVerticalDragDown: (DragDownDetails details) {
          _handleIndexDragDown(details, letterExtent);
        },
        onVerticalDragUpdate: (DragUpdateDetails details) {
          _handleIndexDragUpdate(details, letterExtent);
        },
        onVerticalDragEnd: _handleIndexDragEnd,
        onVerticalDragCancel: _handleIndexDragEnd,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7F3),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCEBDD)),
          ),
          child: Column(
            children: _indexLetters.map((String letter) {
              final bool enabled = _sectionMap.containsKey(letter);
              final bool selected = selectedLetter == letter && enabled;

              return SizedBox(
                key: ValueKey<String>('index-letter-$letter'),
                height: letterExtent,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 20,
                    height: activeBubbleHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1AAD19)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: letterFontSize,
                        height: 1,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : enabled
                            ? const Color(0xFF475569)
                            : const Color(0xFFB8C1CC),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDragOverlay(String letter) {
    final bool hasSection = _sectionMap.containsKey(letter);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD9212A24),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SizedBox(
          width: 112,
          height: 112,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasSection ? '跳转中' : '无联系人',
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalContacts = _sections.fold<int>(
      0,
      (int count, ContactSection section) => count + section.contacts.length,
    );
    final String selectedLetter = _dragLetter ?? _currentLetter;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 78,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('微信式索引通讯录'),
            SizedBox(height: 4),
            Text(
              'A-Z 点击跳转、滚动高亮、拖动联动',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6E9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      '当前',
                      style: TextStyle(
                        color: Color(0xFF56705A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedLetter,
                      key: const ValueKey<String>('current-letter-badge'),
                      style: const TextStyle(
                        color: Color(0xFF1AAD19),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFEAF8EE), Color(0xFFF7FAF7)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x120F172A),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          '像微信一样，在成百上千联系人里毫秒级定位到目标分组。',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '这个 demo 使用 CustomScrollView + SliverPersistentHeader 构建分组列表，右侧索引条同时支持点击和拖动，滚动时还会自动同步高亮。',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _buildSummaryChip(
                              label: '当前分组 ',
                              value: selectedLetter,
                              color: const Color(0xFF1AAD19),
                            ),
                            _buildSummaryChip(
                              label: '联系人 ',
                              value: '$totalContacts 位',
                              color: const Color(0xFF0EA5E9),
                            ),
                            _buildSummaryChip(
                              label: '模式 ',
                              value: '缺失字母自动置灰',
                              color: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x100F172A),
                          blurRadius: 26,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: <Widget>[
                          CustomScrollView(
                            key: const ValueKey<String>('contact-scroll-view'),
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            slivers: _buildSlivers(),
                          ),
                          Positioned(
                            right: 6,
                            top: 0,
                            bottom: 0,
                            child: LayoutBuilder(
                              builder: (BuildContext context, BoxConstraints constraints) {
                                return Center(
                                  child: _buildIndexBar(constraints.maxHeight),
                                );
                              },
                            ),
                          ),
                          if (_dragLetter != null) Center(
                            child: _buildDragOverlay(_dragLetter!),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const SectionHeaderDelegate({
    required this.letter,
    required this.count,
    required this.height,
  });

  final String letter;
  final int count;
  final double height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: overlapsContent ? const Color(0xFFF5FAF6) : const Color(0xFFF8FBF8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      child: Row(
        children: <Widget>[
          Text(
            letter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$count 位联系人',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant SectionHeaderDelegate oldDelegate) {
    return letter != oldDelegate.letter ||
        count != oldDelegate.count ||
        height != oldDelegate.height;
  }
}

class ContactTile extends StatelessWidget {
  const ContactTile({super.key, required this.contact, required this.extent});

  final Contact contact;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = colorForLetter(contact.letter);

    return SizedBox(
      height: extent,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF0F4F2)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Text(
                      contact.name.substring(0, 1),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${contact.pinyin}  ·  ${contact.phone}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    contact.tag,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Contact {
  const Contact({
    required this.name,
    required this.pinyin,
    required this.phone,
    required this.tag,
  });

  final String name;
  final String pinyin;
  final String phone;
  final String tag;

  String get letter {
    final String normalized = pinyin.trim().isEmpty
        ? '#'
        : pinyin.trim()[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(normalized) ? normalized : '#';
  }
}

class ContactSection {
  const ContactSection({required this.letter, required this.contacts});

  final String letter;
  final List<Contact> contacts;
}

List<Contact> buildSampleContacts() {
  return const <Contact>[
    Contact(name: '安然', pinyin: 'anran', phone: '138 1001 1201', tag: '设计'),
    Contact(name: '安柠', pinyin: 'anning', phone: '138 1001 1202', tag: '运营'),
    Contact(name: '白露', pinyin: 'bailu', phone: '138 1001 1203', tag: '增长'),
    Contact(name: '毕成', pinyin: 'bicheng', phone: '138 1001 1204', tag: '后端'),
    Contact(name: '陈默', pinyin: 'chenmo', phone: '138 1001 1205', tag: '产品'),
    Contact(name: '程希', pinyin: 'chengxi', phone: '138 1001 1206', tag: '测试'),
    Contact(name: '邓远', pinyin: 'dengyuan', phone: '138 1001 1207', tag: '商务'),
    Contact(name: '丁舟', pinyin: 'dingzhou', phone: '138 1001 1208', tag: '前端'),
    Contact(name: '方可', pinyin: 'fangke', phone: '138 1001 1209', tag: '客服'),
    Contact(name: '冯野', pinyin: 'fengye', phone: '138 1001 1210', tag: '数据'),
    Contact(name: '顾言', pinyin: 'guyan', phone: '138 1001 1211', tag: '品牌'),
    Contact(name: '高宁', pinyin: 'gaoning', phone: '138 1001 1212', tag: '法务'),
    Contact(name: '韩松', pinyin: 'hansong', phone: '138 1001 1213', tag: '行政'),
    Contact(name: '何遇', pinyin: 'heyu', phone: '138 1001 1214', tag: '财务'),
    Contact(name: '江禾', pinyin: 'jianghe', phone: '138 1001 1215', tag: '产品'),
    Contact(name: '贾川', pinyin: 'jiachuan', phone: '138 1001 1216', tag: '销售'),
    Contact(name: '柯林', pinyin: 'kelin', phone: '138 1001 1217', tag: '设计'),
    Contact(name: '孔岳', pinyin: 'kongyue', phone: '138 1001 1218', tag: '研发'),
    Contact(name: '林夏', pinyin: 'linxia', phone: '138 1001 1219', tag: '增长'),
    Contact(name: '陆遥', pinyin: 'luyao', phone: '138 1001 1220', tag: '运营'),
    Contact(name: '孟初', pinyin: 'mengchu', phone: '138 1001 1221', tag: '客服'),
    Contact(name: '莫白', pinyin: 'mobai', phone: '138 1001 1222', tag: '内容'),
    Contact(name: '倪航', pinyin: 'nihang', phone: '138 1001 1223', tag: '商务'),
    Contact(name: '宁澄', pinyin: 'ningcheng', phone: '138 1001 1224', tag: '采购'),
    Contact(name: '裴景', pinyin: 'peijing', phone: '138 1001 1225', tag: '法务'),
    Contact(name: '潘越', pinyin: 'panyue', phone: '138 1001 1226', tag: '测试'),
    Contact(name: '秦川', pinyin: 'qinchuan', phone: '138 1001 1227', tag: '前端'),
    Contact(name: '邱禾', pinyin: 'qiuhe', phone: '138 1001 1228', tag: '后端'),
    Contact(name: '苏砚', pinyin: 'suyan', phone: '138 1001 1229', tag: '品牌'),
    Contact(name: '沈确', pinyin: 'shenque', phone: '138 1001 1230', tag: '财务'),
    Contact(name: '唐宁', pinyin: 'tangning', phone: '138 1001 1231', tag: '运营'),
    Contact(name: '田湛', pinyin: 'tianzhan', phone: '138 1001 1232', tag: '产品'),
    Contact(name: '王强', pinyin: 'wangqiang', phone: '138 1001 1233', tag: '销售'),
    Contact(name: '温宁', pinyin: 'wenning', phone: '138 1001 1234', tag: '客服'),
    Contact(name: '吴悠', pinyin: 'wuyou', phone: '138 1001 1235', tag: '设计'),
    Contact(name: '谢安', pinyin: 'xiean', phone: '138 1001 1236', tag: '法务'),
    Contact(name: '徐舟', pinyin: 'xuzhou', phone: '138 1001 1237', tag: '测试'),
    Contact(name: '叶青', pinyin: 'yeqing', phone: '138 1001 1238', tag: '品牌'),
    Contact(name: '杨朔', pinyin: 'yangshuo', phone: '138 1001 1239', tag: '内容'),
    Contact(name: '张弛', pinyin: 'zhangchi', phone: '138 1001 1240', tag: '后端'),
    Contact(name: '周牧', pinyin: 'zhoumu', phone: '138 1001 1241', tag: '商务'),
    Contact(name: '赵溪', pinyin: 'zhaoxi', phone: '138 1001 1242', tag: '行政'),
    Contact(name: '2号客服', pinyin: '2haokefu', phone: '138 1001 1243', tag: '特殊'),
    Contact(name: '·小满', pinyin: '·xiaoman', phone: '138 1001 1244', tag: '特殊'),
  ];
}

List<ContactSection> groupContacts(List<Contact> contacts) {
  final Map<String, List<Contact>> grouped = <String, List<Contact>>{};

  for (final Contact contact in contacts) {
    grouped.putIfAbsent(contact.letter, () => <Contact>[]).add(contact);
  }

  for (final List<Contact> group in grouped.values) {
    group.sort((Contact a, Contact b) => a.pinyin.compareTo(b.pinyin));
  }

  final List<String> sortedKeys = grouped.keys.toList()
    ..sort((String a, String b) {
      if (a == '#') {
        return 1;
      }
      if (b == '#') {
        return -1;
      }
      return a.compareTo(b);
    });

  return sortedKeys
      .map(
        (String letter) => ContactSection(
          letter: letter,
          contacts: List<Contact>.unmodifiable(grouped[letter]!),
        ),
      )
      .toList(growable: false);
}

Map<String, double> calculateSectionOffsets(
  List<ContactSection> sections, {
  required double headerExtent,
  required double itemExtent,
}) {
  final Map<String, double> offsets = <String, double>{};
  double currentOffset = 0;

  for (final ContactSection section in sections) {
    offsets[section.letter] = currentOffset;
    currentOffset += headerExtent + section.contacts.length * itemExtent;
  }

  return offsets;
}

String? letterFromOffset(
  double offset,
  List<ContactSection> sections,
  Map<String, double> offsets,
) {
  String? currentLetter;

  for (final ContactSection section in sections) {
    final double sectionOffset = offsets[section.letter] ?? 0;
    if (offset >= sectionOffset) {
      currentLetter = section.letter;
      continue;
    }
    break;
  }

  if (currentLetter != null) {
    return currentLetter;
  }
  return sections.isEmpty ? null : sections.first.letter;
}

Color colorForLetter(String letter) {
  const List<Color> palette = <Color>[
    Color(0xFF1AAD19),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF6366F1),
    Color(0xFFF59E0B),
  ];

  if (letter == '#') {
    return const Color(0xFF64748B);
  }

  return palette[math.max(0, letter.codeUnitAt(0) - 65) % palette.length];
}
