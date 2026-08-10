String formatMmSs(Duration d) {
  final totalSeconds = d.inSeconds;
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatMinutes(Duration d) {
  final mins = d.inMilliseconds / 60000;
  final rounded = (mins * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()} min'
      : '$rounded min';
}
