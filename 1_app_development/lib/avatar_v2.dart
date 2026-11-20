import 'package:flutter/foundation.dart';

import 'avatar_rig_config.dart';
import 'avatar_v2_atlas.dart';
import 'cosmetic_config.dart';

// 26번 4-7단계: the front vendor redrawn from a bare base (no hair, plain
// underwear, bare feet), one picture per skin tone, with every item - the
// defaults too - its own worn layer in assets/images/avatar_v2/<character>/
// (25번 문서 23~31번, tools/avatar_v2.py). No `_cut` masks, no recoloured
// copies: a hat erases only the hair under it (its hairmask).
//
// The game switches to v2 only when every required picture is there
// ([avatarV2Ready], generated) and [avatarV2Enabled]; until then the v1
// vendor is drawn as before, so old and new art never mix. The cooking
// frames stay v1.

/// Hair styles with a part hanging behind the body (`hair_<id>_back.png`).
const avatarV2HairBacks = {'long', 'ponytail', 'curly'};

/// Draw order of the v2 layers, back to front: the face sits right on the
/// base so the fringe of the hair layer can fall over it.
const rigV2Order = [
  RigLayer.behind,
  RigLayer.base,
  RigLayer.eyes,
  RigLayer.mouth,
  RigLayer.bottom,
  RigLayer.shoes,
  RigLayer.top,
  RigLayer.outfit,
  RigLayer.hair,
  RigLayer.hat,
  RigLayer.accessory,
  RigLayer.tool,
  RigLayer.front,
];

String avatarV2Base(String character, String skin) =>
    'avatar_v2/$character/base@$skin.png';

String avatarV2Item(String character, CosmeticSlot slot, String id) =>
    'avatar_v2/$character/${slot.name}_$id.png';

/// What the worn item leaves bare of the base, erased from it (optional,
/// without it the base is drawn whole): for hair the head beside it (26번
/// 3차 H10), for a hat the head above its edge, for trousers and shoes a
/// sliver of leg beside them (26번 3차 AV).
String avatarV2ItemBaseMask(String character, CosmeticSlot slot, String id) =>
    avatarV2Item(character, slot, id).replaceFirst('.png', '_basemask.png');

/// What hair style [hair] leaves bare of the head (26번 3차 H10).
String avatarV2BaseMask(String character, String hair) =>
    avatarV2ItemBaseMask(character, CosmeticSlot.hair, hair);

/// Where [hat] presses the hair down: erased from the hair layer only.
String avatarV2HairMask(String character, String hat) =>
    'avatar_v2/$character/hat_${hat}_hairmask.png';

/// The share card's proud pose (25번 39번, 26번 3차 AV): both arms raised
/// with a bungeoppang, one per skin tone, and where the hanging arms were
/// (opaque = erased from the body and what is worn over it).
String avatarV2ProudArms(String character, String skin) =>
    'avatar_v2/$character/pose_proud_arms@$skin.png';

String avatarV2ProudHide(String character) =>
    'avatar_v2/$character/pose_proud_hide.png';

/// Whether the v2 vendor is drawn and has its proud pose pictures.
bool avatarV2ProudReady(String character, String skin) =>
    avatarV2On &&
    avatarV2Shipped.contains(avatarV2ProudArms(character, skin)) &&
    avatarV2Shipped.contains(avatarV2ProudHide(character));

/// An eye or mouth frame made for one base (its own skin colour).
String avatarV2Feature(
        String character, String skin, String channel, String frame) =>
    'avatar_v2/$character/face_${channel}_$frame@$skin.png';

/// Every picture v2 needs: the three bases and every item layer the
/// wardrobe can show (defaults included; blanks have none), girl and boy.
/// tools/avatar_v2.py `required()` makes the same list.
Iterable<String> avatarV2Required() sync* {
  final characters = [
    for (final d in cosmeticDefinitions)
      if (d.slot == CosmeticSlot.character) d.id
  ];
  final skins = [
    for (final d in cosmeticDefinitions)
      if (d.slot == CosmeticSlot.skin) d.id
  ];
  for (final c in characters) {
    for (final s in skins) {
      yield avatarV2Base(c, s);
    }
    for (final d in cosmeticDefinitions) {
      if (!rigSlotLayers.containsKey(d.slot) || blankCosmetics.contains(d.id)) {
        continue;
      }
      final item = avatarV2Item(c, d.slot, d.id);
      yield item;
      if (d.slot == CosmeticSlot.hair && avatarV2HairBacks.contains(d.id)) {
        yield item.replaceFirst('.png', '_back.png');
      }
    }
  }
}

/// Whether [files] hold every required v2 picture.
bool avatarV2ReadyFor(Set<String> files) =>
    avatarV2Required().every(files.contains);

/// Tests only: draw v2 (true) or v1 (false) whatever the art says.
@visibleForTesting
bool? debugAvatarV2Override;

/// Tests only: the v2 pictures as if shipped.
@visibleForTesting
Set<String>? debugAvatarV2Files;

/// The v2 pictures the app ships.
Set<String> get avatarV2Shipped => debugAvatarV2Files ?? avatarV2Files;

/// The v2 vendor's switch. 26번 3차 G (2026-11-20) turned it off ("아바타
/// 전(v1)이 더 낫다 — 얼굴·몸은 그대로 두고 머리·옷만 바꿔야"); 26번 3차 AV
/// (2026-11-20, DEC-145·147) turns it on again: the base is now the 42번
/// bare base (the v1 face and body) and every item the 43~49번 picture drawn
/// worn on it (and 41번 황금 뒤집개), checked tile by tile.
const avatarV2Enabled = true;

/// Whether the front vendor is drawn from the v2 art.
bool get avatarV2On => debugAvatarV2Override ?? (avatarV2Enabled && avatarV2Ready);
