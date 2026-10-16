// Online ranking: the game's own boards on the Firebase server
// (firebase/functions/src/ranking.ts mirrors these values, and
// test/stage16_kakao_ranking_test.dart checks that the two agree).
const rankingBestAutoRate = 'bestAutoRate';
const rankingLifetime = 'lifetime';
const rankingBestCombo = 'bestCombo';
const rankingBoards = [rankingBestAutoRate, rankingLifetime, rankingBestCombo];

// Scores are kept as signed 64-bit integers. Larger values are submitted as
// this maximum and the ranking screen says so.
final rankingScoreMax = BigInt.parse('9223372036854775807');

// Scores are pushed at most this often from play (plus level-up, leaving the
// app and opening the ranking), never per tap.
const rankingSubmitIntervalMs = 5 * 60 * 1000;

// The server refuses a player's submissions closer together than this, so
// the app never sends them faster, not even the immediate ones above.
const rankingSubmitMinGapMs = rankingSubmitIntervalMs ~/ 5;

// How many players a board shows.
const rankingTopCount = 100;

// What the server treats as an implausible jump of a best score. Scores up
// to the board's floor always pass (early play moves fast). Above it, a
// score may reach at most max(previous best, floor) x slack x growth^hours,
// hours counted since the previous best was set. So it can grow 10x at
// once, about 12x five minutes later, 100x an hour later, and without limit
// after a day. A refused submission is simply retried later.
const rankingGrowthSlack = 10;
const rankingGrowthPerHour = 10;
final rankingGrowthFloor = {
  rankingBestAutoRate: BigInt.from(1000000),
  rankingLifetime: BigInt.from(1000000000),
  rankingBestCombo: BigInt.from(1000),
};
