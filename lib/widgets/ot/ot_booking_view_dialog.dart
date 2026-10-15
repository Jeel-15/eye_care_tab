import 'package:flutter/material.dart';
import '../app_dialog.dart';
import '../detail_card_kit.dart';
import '../form_kit.dart';

/// The one host for a read-only record view: identity and key facts in the
/// header, the rest as a [FactSheet]. Every tab View dialog uses this.
Future<void> showRecordView(
  BuildContext context, {
  required String name,
  List<Widget> pills = const [],
  String? meta,
  List<Color>? avatarColors,
  List<HeaderFact> facts = const [],
  required List<FactSection> sections,
}) {
  return showDialog<void>(
    context: context,
    builder: (dCtx) => AppDialog(
      size: AppDialogSize.large,
      header: EntityDialogHeader(
        name: name,
        avatarColors: avatarColors,
        pills: pills,
        meta: meta,
        facts: facts.isEmpty ? null : HeaderFacts(facts),
        onClose: () => Navigator.pop(dCtx),
      ),
      body: FactSheet(sections: sections),
      actions: [AppSecondaryButton(label: 'Close', onPressed: () => Navigator.pop(dCtx))],
    ),
  );
}
