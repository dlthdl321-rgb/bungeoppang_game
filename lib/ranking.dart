// Fictional names/scores, not real users or a network leaderboard.
const rankingFixtures = [
  ('mock-01', '달빛제빵사', '950000000000000000', true),
  ('mock-02', '골목의온도', '32000000000000000', false),
  ('mock-03', '노을한입', '6400000000000000', false),
  ('mock-04', '별빛화로', '150000000000000', true),
  ('mock-05', '바삭한하루', '30000000000000', false),
  ('mock-06', '겨울산책', '7000000000000', false),
  ('mock-07', '팥알수집가', '950000000000', true),
  ('mock-08', '빵굽는구름', '140000000000', false),
  ('mock-09', '밤참연구소', '36000000000', false),
  ('mock-10', '동네한바퀴', '5800000000', true),
  ('mock-11', '따뜻한손', '820000000', false),
  ('mock-12', '작은노점', '170000000', false),
  ('mock-13', '한판더요', '23000000', true),
  ('mock-14', '단팥일기', '4700000', false),
  ('mock-15', '슈크림별', '640000', false),
  ('mock-16', '오늘도한입', '95000', true),
  ('mock-17', '붕어한마리', '12000', false),
  ('mock-18', '첫손님', '1600', false),
  ('mock-19', '갓구운꿈', '150', true),
  ('mock-20', '골목새싹', '12', false),
];

class RankingEntry {
  final String id, name;
  final BigInt score;
  final bool isMe;
  final int rank;
  const RankingEntry(this.id, this.name, this.score, this.isMe, this.rank);
}

typedef _Row = ({String id, String name, BigInt score, bool friend});

int _compareRows(_Row a, _Row b) {
  final score = b.score.compareTo(a.score);
  return score != 0 ? score : a.id.compareTo(b.id);
}

// Fixture scores are parsed and sorted once, not on every 100ms rebuild.
final List<_Row> _fixtureRows = [
  for (final r in rankingFixtures)
    (id: r.$1, name: r.$2, score: BigInt.parse(r.$3), friend: r.$4)
]..sort(_compareRows);
final _lastRanking = <bool, (BigInt, List<RankingEntry>)>{};

/// Unmodifiable; the same instance is returned while [lifetime] is unchanged.
List<RankingEntry> rankingFor(BigInt lifetime, {bool friendsOnly = false}) {
  final cached = _lastRanking[friendsOnly];
  if (cached != null && cached.$1 == lifetime) return cached.$2;
  final me = (id: 'self', name: '나', score: lifetime, friend: true);
  final rows = [
    for (final r in _fixtureRows)
      if (!friendsOnly || r.friend) r
  ];
  final at = rows.indexWhere((r) => _compareRows(me, r) < 0);
  rows.insert(at < 0 ? rows.length : at, me);
  var rank = 0;
  BigInt? previous;
  final result = List<RankingEntry>.unmodifiable([
    for (var i = 0; i < rows.length; i++)
      (() {
        final r = rows[i];
        if (previous != r.score) rank = i + 1;
        previous = r.score;
        return RankingEntry(r.id, r.name, r.score, r.id == me.id, rank);
      })()
  ]);
  _lastRanking[friendsOnly] = (lifetime, result);
  return result;
}
