// Endgame: "새 노점 열기" prestige. Approved stage 11 (option A).
// Stars are earned from ALL-TIME production: total stars for a lifetime L is
// floor(cbrt(L / prestigeStarUnit)); a prestige grants total minus stars
// already earned. Tuned so a casual first run (about 2e18 at Lv.10) earns
// about 5-6 stars.
const prestigeUnlockLevel = 10;
const prestigeStarUnit = '10000000000000000'; // 1경
const prestigeBonusPermillePerStar = 50; // +5% production per star.
