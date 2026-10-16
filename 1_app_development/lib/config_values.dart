// Config tables store numbers as decimal strings (BigInt-safe) in const
// objects, which cannot hold parsed fields. This parses each distinct value
// once; BigInt is immutable, so sharing is safe and per-frame rebuilds stop
// re-parsing.
final _bigInts = <String, BigInt>{};

BigInt configBigInt(String decimal) =>
    _bigInts[decimal] ??= BigInt.parse(decimal);
