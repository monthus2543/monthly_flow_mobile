import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'common_widgets.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.incomeMinor,
    required this.expenseMinor,
    this.hideBalances = false,
    this.investmentMode = false,
    this.fundCount = 0,
    this.monthlyInvestedMinor = 0,
    this.currentMinor = 0,
    this.cashInvestmentMinor = 0,
    this.onToggleMode,
  });
  final int incomeMinor;
  final int expenseMinor;
  final bool hideBalances;
  final bool investmentMode;
  final int fundCount, monthlyInvestedMinor, currentMinor;
  final int cashInvestmentMinor;
  final VoidCallback? onToggleMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final foreground = scheme.onSurface;
    final primary = scheme.primary;
    final stitch = primary;
    final base = HSLColor.fromColor(primary);
    Color tone(double hueOffset, double lightness) => base
        .withHue((base.hue + hueOffset) % 360)
        .withSaturation(dark ? .62 : .65)
        .withLightness(lightness)
        .toColor();
    final walletColors = [
      tone(0, dark ? .28 : .8),
      tone(12, dark ? .25 : .78),
      tone(24, dark ? .3 : .85),
    ];
    String amount(int minor) => hideBalances ? '******' : money(context, minor);
    Widget metric(
      String label,
      int value,
      Color color, {
      bool isMoney = true,
    }) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: foreground.withValues(alpha: .8)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isMoney ? amount(value) : value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: walletColors,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: dark ? .18 : .12),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        right: onToggleMode == null ? 0 : 40,
                      ),
                      child: Text(
                        context.l10n.t(
                          investmentMode
                              ? 'portfolio_value'
                              : 'monthly_balance',
                        ),
                        style: TextStyle(
                          color: foreground.withValues(alpha: .8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount(
                            investmentMode
                                ? currentMinor
                                : incomeMinor -
                                      expenseMinor -
                                      cashInvestmentMinor,
                          ),
                          style: TextStyle(
                            color: foreground,
                            fontSize: 31,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        (dark
                                ? Color.lerp(primary, Colors.black, .8)!
                                : Colors.white)
                            .withValues(alpha: dark ? .5 : .48),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: (dark ? primary : Colors.white).withValues(
                        alpha: dark ? .22 : .7,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CustomPaint(
                      foregroundPainter: _StitchedRim(
                        stitch.withValues(alpha: dark ? .38 : .3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 44),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            metric(
                              context.l10n.t(
                                investmentMode ? 'fund_count' : 'income',
                              ),
                              investmentMode ? fundCount : incomeMinor,
                              dark
                                  ? AppColors.tealDark
                                  : AppColors.categoryIncome,
                              isMoney: !investmentMode,
                            ),
                            const SizedBox(width: 16),
                            metric(
                              context.l10n.t(
                                investmentMode ? 'monthly_invested' : 'expense',
                              ),
                              investmentMode
                                  ? monthlyInvestedMinor
                                  : expenseMinor,
                              investmentMode
                                  ? AppColors.investment
                                  : dark
                                  ? AppColors.errorDark
                                  : AppColors.categoryExpense,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (onToggleMode != null)
            Positioned(
              right: 8,
              top: 4,
              child: IconButton(
                tooltip: context.l10n.t(
                  investmentMode ? 'spending_mode' : 'investments',
                ),
                onPressed: onToggleMode,
                icon: Icon(
                  investmentMode
                      ? Icons.account_balance_wallet_outlined
                      : Icons.trending_up_rounded,
                ),
                color: foreground,
              ),
            ),
          Positioned(
            right: -4,
            bottom: 18,
            child: ExcludeSemantics(
              child: Container(
                width: 84,
                height: 34,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(primary, Colors.white, .5)!,
                      Color.lerp(primary, Colors.white, .2)!,
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.walletSnap.first.withValues(alpha: .6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .22),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: AppColors.walletSnap,
                    ),
                    border: Border.all(
                      color: AppColors.walletSnapBorder.withValues(alpha: .65),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StitchedRim extends CustomPainter {
  const _StitchedRim(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(17),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(
          metric.extractPath(offset, math.min(offset + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StitchedRim oldDelegate) => color != oldDelegate.color;
}
