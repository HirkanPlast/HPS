/// Shared numeric formatting for the Persian HPLeila interface.
class NumberFormatHelper {
  static String grouped(num value, {int decimals = 0}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final sign = parts.first.startsWith('-') ? '-' : '';
    final digits = sign.isEmpty ? parts.first : parts.first.substring(1);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\\d)(?=(\\d{3})+$)'),
      (match) => '${match[1]},',
    );
    return '$sign$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  static String integer(num value) => grouped(value.round());
}
