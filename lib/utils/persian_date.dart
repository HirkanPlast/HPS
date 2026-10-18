import 'package:shamsi_date/shamsi_date.dart';

class PersianDateHelper {
  /// Returns today as YYYY/MM/DD Shamsi
  static String today() {
    final j = Jalali.now();
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  /// First day of current month YYYY/MM/01
  static String monthStart() {
    final j = Jalali.now();
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/01';
  }

  /// Format Jalali to YYYY/MM/DD
  static String format(Jalali j) {
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  /// Parse YYYY/MM/DD to Jalali
  static Jalali? parse(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return Jalali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  /// Pretty display e.g. ۱۴۰۵/۰۷/۱۵
  static String pretty(String dateStr) {
    return dateStr; // already in good format; can add Persian digits later
  }

  /// Month name
  static String monthName(int month) {
    const names = [
      '', 'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return names[month.clamp(1, 12)];
  }
}
