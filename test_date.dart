void main() {
  print('now: ${DateTime.now()}');
  print('parse: ${DateTime.parse("2026-08-03T12:10:00")}');
  print('parse UTC: ${DateTime.parse("2026-08-03T12:10:00").isUtc}');
}
