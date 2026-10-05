// Online ranking (Google Play Games Services v2 leaderboards).
// Logical names; the Play Console IDs live in android/.../games-ids.xml.
const rankingBestAutoRate = 'bestAutoRate';
const rankingLifetime = 'lifetime';
const rankingBestCombo = 'bestCombo';

// Play Games scores are signed 64-bit integers. Larger values are submitted
// as this maximum and the records screen says so.
final rankingScoreMax = BigInt.parse('9223372036854775807');

// Scores are pushed at most this often from play (plus level-up, leaving the
// app and opening the ranking), never per tap.
const rankingSubmitIntervalMs = 5 * 60 * 1000;
