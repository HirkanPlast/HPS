/// Shared numeric formatting for the Persian HPLeila interface.
class NumberFormatHelper {
  static String grouped(num value, {int decimals = 0}) {
    final fixed = value.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final sign = parts.first.startsWith('-') ? '-' : '';
    final digits = sign.isEmpty ? parts.first : parts.first.substring(1);
    final grouped = digits.replaceAllMapped(
      RegExp(r'([0-9])(?=([0-9]{3})+$)'),
      (match) => '${match[1]},',
    );
    return '$sign$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
  }

  static String integer(num value) => grouped(value.round());

  static String quantity(num value) {
    var raw = value.toStringAsFixed(3);
    while (raw.contains('.') && raw.endsWith('0')) {
      raw = raw.substring(0, raw.length - 1);
    }
    if (raw.endsWith('.')) raw = raw.substring(0, raw.length - 1);
    final parts = raw.split('.');
    final whole = grouped(num.tryParse(parts.first) ?? 0);
    return parts.length == 1 ? whole : '$whole.${parts[1]}';
  }
}
