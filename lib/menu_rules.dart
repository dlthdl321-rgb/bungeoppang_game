import 'cosmetic_config.dart';
import 'models.dart';

bool cosmeticUnlocked(GameState s, CosmeticDefinition d) =>
    s.level >= d.unlockLevel && s.lifetime >= d.unlockProductionAmount;
