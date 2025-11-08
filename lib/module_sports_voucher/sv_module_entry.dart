import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:town_pass/module_sports_voucher/page/sv_home_page.dart';
import 'package:town_pass/module_sports_voucher/page/sv_map_page.dart';
import 'package:town_pass/module_sports_voucher/page/sv_match_page.dart';
import 'package:town_pass/module_sports_voucher/page/sv_text_search_page.dart';
import 'package:town_pass/module_sports_voucher/util/sv_navigator_util.dart';
import 'package:town_pass/util/tp_colors.dart';

/// 動茲券模組入口
/// 提供給台北通主程式載入使用
class SportsVoucherModule extends StatelessWidget {
  final double? initialBalance;

  const SportsVoucherModule({super.key, this.initialBalance});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '台北通動茲券模組',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: TPColors.grayscale50,
        colorScheme: ColorScheme.fromSeed(seedColor: TPColors.primary500),
      ),
      initialRoute: SvNavigatorUtil.home,
      getPages: [
        GetPage(
          name: SvNavigatorUtil.home,
          page: () => SvHomePage(initialBalance: initialBalance),
        ),
        GetPage(
          name: SvNavigatorUtil.map,
          page: () => const SvMapPage(),
        ),
        GetPage(
          name: SvNavigatorUtil.textSearch,
          page: () => const SvTextSearchPage(),
        ),
        GetPage(
          name: SvNavigatorUtil.match,
          page: () => const SvMatchPage(),
        ),
      ],
    );
  }
}

