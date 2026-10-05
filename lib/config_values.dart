// Config tables store numbers as decimal strings (BigInt-safe) and dates as
// ISO strings in const objects, which cannot hold parsed fields. These parse
// each distinct value once; BigInt and DateTime are immutable, so sharing is
// safe and per-frame rebuilds stop re-parsing.
final _bigInts = <String, BigInt>{};
final _dates = <String, DateTime>{};

BigInt configBigInt(String decimal) =>
    _bigInts[decimal] ??= BigInt.parse(decimal);

DateTime configUtc(String iso) => _dates[iso] ??= DateTime.parse(iso).toUtc();
