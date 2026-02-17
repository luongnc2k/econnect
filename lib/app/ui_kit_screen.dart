import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_text_styles.dart';

class UiKitScreen extends StatelessWidget {
  const UiKitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EConnect UI Kit'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Typography
          Text('Typography', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          Text('H1 - Tiêu đề lớn', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.xs),
          Text('H2 - Tiêu đề vừa', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text('Body - Nội dung thường', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.xs),
          Text('Body Muted - Nội dung phụ', style: AppTextStyles.bodyMuted),
          const SizedBox(height: AppSpacing.xs),
          Text('Caption - Ghi chú', style: AppTextStyles.caption),

          const SizedBox(height: AppSpacing.xl),

          // Colors
          Text('Colors', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          _ColorRow(items: [
            _ColorItem('Primary', AppColors.primary),
            _ColorItem('Secondary', AppColors.secondary),
            _ColorItem('Background', AppColors.background),
            _ColorItem('Surface', AppColors.surface),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _ColorRow(items: [
            _ColorItem('Text', AppColors.text),
            _ColorItem('Muted', AppColors.mutedText),
            _ColorItem('Border', AppColors.border),
            _ColorItem('Error', AppColors.error),
          ]),

          const SizedBox(height: AppSpacing.xl),

          // Buttons
          Text('Buttons', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: () => _snack(context, 'ElevatedButton pressed'),
            child: const Text('Primary Button'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _snack(context, 'OutlinedButton pressed'),
            child: const Text('Outlined Button'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => _snack(context, 'TextButton pressed'),
            child: const Text('Text Button'),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Inputs
          Text('Inputs', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'example@email.com',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Mật khẩu',
              hintText: '••••••••',
            ),
            obscureText: true,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            decoration: InputDecoration(
              labelText: 'Tìm kiếm',
              hintText: 'Topic / nhóm / tutor...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () => _snack(context, 'Clear'),
                icon: const Icon(Icons.clear),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Cards
          Text('Cards', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nhóm học: IELTS Speaking', style: AppTextStyles.h2),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Tutor: Nguyễn A', style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Thời gian: 18:00, Thứ 6', style: AppTextStyles.bodyMuted),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Địa điểm: Quận 1', style: AppTextStyles.bodyMuted),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Chip(
                        label: const Text('Offline'),
                        backgroundColor: cs.primary.withValues(alpha: 0.1),
                        side: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Chip(
                        label: const Text('Còn chỗ'),
                        backgroundColor: AppColors.success.withValues(alpha: 0.1),
                        side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _snack(context, 'Xem chi tiết'),
                          child: const Text('Xem chi tiết'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _snack(context, 'Đăng ký'),
                          child: const Text('Đăng ký'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Status / Snackbars
          Text('Status', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatusPill(text: 'Success', color: AppColors.success),
              _StatusPill(text: 'Warning', color: AppColors.warning),
              _StatusPill(text: 'Error', color: AppColors.error),
              _StatusPill(text: 'Info', color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _ColorItem {
  final String name;
  final Color color;
  const _ColorItem(this.name, this.color);
}

class _ColorRow extends StatelessWidget {
  final List<_ColorItem> items;
  const _ColorRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items
          .map(
            (it) => Expanded(
              child: Container(
                height: 72,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: it.color,
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    it.name,
                    style: TextStyle(
                      color: _bestTextColor(it.color),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList()
        ..removeLast(), // bỏ margin thừa cuối
    );
  }

  Color _bestTextColor(Color bg) {
    // Tự chọn chữ trắng/đen theo độ sáng nền
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
