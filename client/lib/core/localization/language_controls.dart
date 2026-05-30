import 'package:client/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = AppLanguage.fromLocale(ref.watch(appLocaleProvider));

    return SegmentedButton<AppLanguage>(
      showSelectedIcon: false,
      segments: AppLanguage.values
          .map(
            (language) => ButtonSegment<AppLanguage>(
              value: language,
              label: Text(language.shortLabel),
            ),
          )
          .toList(),
      selected: {current},
      onSelectionChanged: (selection) {
        ref.read(appLocaleProvider.notifier).setLanguage(selection.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final current = AppLanguage.fromLocale(ref.watch(appLocaleProvider));

    return PopupMenuButton<AppLanguage>(
      tooltip: strings.language,
      icon: const Icon(Icons.language_rounded),
      initialValue: current,
      onSelected: (language) {
        ref.read(appLocaleProvider.notifier).setLanguage(language);
      },
      itemBuilder: (context) => AppLanguage.values
          .map(
            (language) => CheckedPopupMenuItem<AppLanguage>(
              value: language,
              checked: language == current,
              child: Text(language.nativeLabel),
            ),
          )
          .toList(),
    );
  }
}
