#!/bin/sh
# Turns the original AI images in "이미지/이미지 raw" (이미지생성프롬프트_통합 부록 S1-S3,
# E1-E6) into game sprites with tools/pixelize.py.
#
# Every sprite is exported at 3x its logical size (skills 32 -> 96, icons
# 24 -> 72, ...): the game draws it into the same on-screen box, so the art
# keeps the raw image's finer dots. Run from the project root:
#   sh tools/process_extra_art.sh [out_dir]
set -e
RAW="${RAW_DIR:-이미지/이미지 raw}"
OUT="${1:-assets/images}"
P="python tools/pixelize.py"
X=3 # resolution multiple over the logical size

px() { echo "$(( ${1%x*} * X ))x$(( ${1#*x} * X ))"; }

$P "$RAW/skills" -o "$OUT/skills" --size "$(px 32x32)" --preview 0
$P "$RAW/icons" -o "$OUT/icons" --size "$(px 24x24)" --preview 0
for n in minifish:12x9 sparkle:7x7 fairy_up:24x24 fairy_down:24x24 butter_glow:96x72; do
  $P "$RAW/fx/${n%%:*}.png" -o "$OUT/fx" --size "$(px "${n##*:}")" --preview 0
done
# Scenes are sampled straight down: grid detection picks too coarse a pitch
# on some of them, and at 3x the raw detail survives anyway.
for s in spring summer autumn winter; do
  $P "$RAW/event/$s.png" -o "$OUT/event" --size "$(px 160x48)" --mode background --no-grid --preview 0
done
$P "$RAW/ui/wardrobe_bg.png" -o "$OUT/ui" --size "$(px 120x72)" --mode background --no-grid --preview 0
$P "$RAW/ui/offline.png" -o "$OUT/ui" --size "$(px 64x48)" --preview 0
$P "$RAW/ui/title_fish.png" -o "$OUT/ui" --size "$(px 16x12)" --preview 0
# Post lamps: logical 9x14, the size of stall/postlamp.png.
$P "$RAW/stall" -o "$OUT/stall" --size "$(px 9x14)" --preview 0

# Play store art: not bundled with the app.
if [ "$OUT" = assets/images ]; then
  mkdir -p store
  $P "$RAW/store/feature_graphic.png" -o store --size 512x250 --mode background --no-grid --preview 0
  $P "$RAW/store/splash.png" -o store --size 192x192 --preview 0
  python - <<'PY'
from PIL import Image
Image.open('store/feature_graphic.png').resize((1024, 500), Image.NEAREST).save('store/feature_graphic.png')
Image.open('store/splash.png').resize((384, 384), Image.NEAREST).save(
    'android/app/src/main/res/drawable-nodpi/splash.png')
PY
fi
