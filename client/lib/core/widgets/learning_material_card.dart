import 'package:client/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningMaterialCard extends StatelessWidget {
  final String materialUrl;
  final String? fileName;

  const LearningMaterialCard({
    super.key,
    required this.materialUrl,
    this.fileName,
  });

  Future<void> _openMaterial(BuildContext context) async {
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final uri = Uri.tryParse(materialUrl);
    if (uri == null) {
      _showMessage(
        context,
        strings.text(
          en: 'Could not open the learning material.',
          vi: 'Không mở được tài liệu học.',
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showMessage(
        context,
        strings.text(
          en: 'Could not open the learning material.',
          vi: 'Không mở được tài liệu học.',
        ),
      );
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strings = AppStrings(Localizations.localeOf(context).languageCode);
    final materialLabel = strings.text(
      en: 'Class material',
      vi: 'Tài liệu buổi học',
    );
    final displayName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : materialLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_outlined,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materialLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _openMaterial(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(strings.text(en: 'Open', vi: 'Mở')),
          ),
        ],
      ),
    );
  }
}
