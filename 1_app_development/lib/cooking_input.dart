/// Direction of the old filling sequence. New sessions still record it so the
/// token encoding of older saves stays the same, but the player never sees it
/// (the piping bag consumes the whole sequence at once).
enum CookingDirection { left, right }
