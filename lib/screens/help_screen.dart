import 'package:flutter/material.dart';
import '../utils/constants.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('راهنمای HPLeila')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.menu_book, size: 38),
            const SizedBox(height: 8),
            Text('راهنمای HPLeila', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('راهنمای آفلاین برنامه؛ با هر نسخهٔ جدید، توضیحات امکانات تازه نیز همراه برنامه به‌روز می‌شود.'),
            const SizedBox(height: 8),
            Text('نسخهٔ راهنما: ${AppConstants.version}', style: Theme.of(context).textTheme.labelMedium),
          ]),
        )),
        const _HelpSection(title: 'شروع کار', icon: Icons.play_circle_outline, body: 'از بخش «مدیریت کالاها» نام، کد، واحد، موجودی اولیه و قیمت خرید و فروش را ثبت کنید.'),
        const _HelpSection(title: 'ثبت فاکتور فروش', icon: Icons.receipt_long, body: 'از منوی اصلی «فاکتورهای فروش» و سپس «فاکتور جدید» را انتخاب کنید. کالا را انتخاب کنید؛ قیمت واحد به‌طور خودکار از قیمت فروش ثبت‌شده خوانده می‌شود. چند کالا اضافه کنید، تخفیف را در بخش پایانی وارد و فاکتور را ثبت کنید.'),
        const _HelpSection(title: 'مقدار کالا و عدد اعشاری', icon: Icons.scale_outlined, body: 'برای کالاهای فله‌ای یا واحدهایی مثل کیلو و متر، مقدار اعشاری مانند 1.5 یا 2.25 وارد کنید. برای کالای دانه‌ای نیز تعداد صحیح مانند 3 وارد می‌شود. واحد کالا را هنگام تعریف آن درست انتخاب کنید.'),
        const _HelpSection(title: 'جست‌وجو و PDF فاکتور', icon: Icons.search, body: 'در فهرست فاکتورها با شماره فاکتور، نام یا شماره تماس مشتری و تاریخ جست‌وجو کنید. با بازکردن هر فاکتور، جزئیات را ببینید و PDF را به اشتراک بگذارید یا چاپ کنید.'),
        const _HelpSection(title: 'موجودی و تراکنش‌ها', icon: Icons.inventory_2_outlined, body: 'خرید یا ورود کالا موجودی را افزایش می‌دهد و فروش آن را کاهش می‌دهد. در صفحهٔ موجودی و گزارش‌ها تغییرات را پیگیری کنید.'),
        const _HelpSection(title: 'پشتیبان‌گیری و بازیابی', icon: Icons.backup_outlined, body: 'از منوی اصلی «پشتیبان‌گیری و بازیابی» را باز کنید و فایل JSON بسازید. فایل را در جای امن نگه دارید. بازیابی، اطلاعات فعلی را با محتوای فایل جایگزین می‌کند؛ قبل از بازیابی از اطلاعات فعلی نیز پشتیبان بگیرید.'),
        const _HelpSection(title: 'حالت روز و شب', icon: Icons.dark_mode_outlined, body: 'در تنظیمات، حالت روز/شب را روشن یا خاموش کنید. انتخاب شما ذخیره می‌شود و پس از بازکردن دوبارهٔ برنامه باقی می‌ماند.'),
        const _HelpSection(title: 'اگر مشکلی پیش آمد', icon: Icons.support_agent, body: 'پیش از حذف یا نصب مجدد برنامه، حتماً از اطلاعات پشتیبان بگیرید. این راهنما همراه به‌روزرسانی‌های HPLeila تکمیل می‌شود.'),
      ],
    ),
  );
}

class _HelpSection extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  const _HelpSection({required this.title, required this.body, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ExpansionTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [Align(alignment: Alignment.centerRight, child: Text(body))],
    ),
  );
}