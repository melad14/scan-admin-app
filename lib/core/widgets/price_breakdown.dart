import 'package:flutter/material.dart';
import 'package:dr_ray_technician/core/models/service.dart';
import 'package:dr_ray_technician/core/theme/app_colors.dart';

/// "900.0" → "900", "12.5" → "12.50"
String fmtMoney(num? v) {
  final d = (v ?? 0).toDouble();
  return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
}

double _num(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;

/// Itemised price of an order, built from the server's `pricing` object:
/// each service, services subtotal, home-visit transfer fee, emergency fee,
/// discount, any manual adjustment, and the total — so the total is never a
/// number the patient can't reconcile with the lines above it.
class PriceBreakdown extends StatelessWidget {
  final Map<String, dynamic>? pricing;
  final List<MedicalService> services;

  /// Prescription order the admin hasn't priced yet — the services cost is unknown.
  final bool awaitingPricing;

  /// Cancelled order: whatever is left is the cancellation (transfer) fee.
  final bool cancelled;

  final bool showServices;

  const PriceBreakdown({
    super.key,
    required this.pricing,
    required this.services,
    this.awaitingPricing = false,
    this.cancelled = false,
    this.showServices = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = pricing ?? const {};

    final servicesSum = services.fold<double>(0, (sum, s) => sum + s.price);
    final servicesTotal = p.containsKey('servicesTotal') ? _num(p['servicesTotal']) : servicesSum;
    final transferFee = _num(p['transferFee']);
    final emergencyFee = _num(p['emergencyFee']);
    final discount = _num(p['discount']);
    final total = p.containsKey('total')
        ? _num(p['total'])
        : servicesTotal + transferFee + emergencyFee - discount;

    // An admin-entered custom price can differ from the sum of the parts —
    // show the difference as its own line instead of an unexplained total.
    final adjustment = total - (servicesTotal + transferFee + emergencyFee - discount);
    final showAdjustment = !awaitingPricing && adjustment.abs() >= 0.5;

    Widget row(String label, String value,
        {Color? valueColor, bool bold = false, double size = 13}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: size,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? c.textPrimary : c.textSecondary,
                  )),
            ),
            const SizedBox(width: 12),
            Text(value,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: size,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ?? (bold ? c.textPrimary : c.textPrimary),
                  fontFamily: 'Inter',
                )),
          ],
        ),
      );
    }

    Widget divider() =>
        Container(height: 1, color: c.borderLight, margin: const EdgeInsets.symmetric(vertical: 8));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showServices && services.isNotEmpty) ...[
          ...services.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.nameAr, style: TextStyle(fontSize: 14, color: c.textPrimary)),
                    ),
                    const SizedBox(width: 12),
                    Text('${fmtMoney(s.price)} ج.م',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 13, color: c.textSecondary, fontFamily: 'Inter')),
                  ],
                ),
              )),
          divider(),
        ],
        if (awaitingPricing)
          row('تكلفة الفحوصات', 'قيد التسعير', valueColor: c.warning)
        else if (!cancelled || servicesTotal > 0)
          row('إجمالي الفحوصات', '${fmtMoney(servicesTotal)} ج.م'),
        if (transferFee > 0)
          row(cancelled ? 'رسوم الإلغاء (انتقال الفريق)' : 'رسوم انتقال الفريق الطبي',
              '${fmtMoney(transferFee)} ج.م'),
        if (emergencyFee > 0) row('رسوم خدمة الطوارئ', '${fmtMoney(emergencyFee)} ج.م'),
        if (discount > 0) row('خصم', '- ${fmtMoney(discount)} ج.م', valueColor: c.success),
        if (showAdjustment)
          row(adjustment < 0 ? 'خصم إضافي' : 'تعديل على السعر',
              '${adjustment < 0 ? '- ' : '+ '}${fmtMoney(adjustment.abs())} ج.م',
              valueColor: adjustment < 0 ? c.success : null),
        divider(),
        row(
          awaitingPricing ? 'الإجمالي (حتى الآن)' : 'الإجمالي',
          '${fmtMoney(total)} ج.م',
          bold: true,
          size: 16,
          valueColor: c.accent,
        ),
        if (awaitingPricing)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('سيتم تحديث الإجمالي بعد مراجعة الروشتة وتسعير الفحوصات.',
                style: TextStyle(fontSize: 11, color: c.textMuted)),
          ),
      ],
    );
  }
}
