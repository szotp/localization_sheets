import 'package:arb/models/arb_document.dart';
import 'package:arb/models/arb_project.dart';
import 'package:collection/collection.dart' show IterableExtension;

void insertDescriptions(ArbProject project) {
  final List<ArbDocument?> docs = project.documents.toList();
  docs.removeWhere((x) => x!.locale == project.defaultTemplate);
  docs.insert(0, project.mapDocuments[project.defaultTemplate]);

  final def = docs.first!;

  for (final entry in def.resources.values) {
    final comments = <String>[];

    comments.add('### ${entry.value.text}');

    for (final doc in docs) {
      final resource =
          doc!.resources.values.firstWhereOrNull((x) => x.id == entry.id);
      var value = resource?.value.text;
      value ??= '!!! MISSING !!!';
      comments.add('- ${doc.locale}: $value');
    }

    var commentsString = comments.join('\n');
    commentsString = '/** $commentsString */';

    entry.description = '\n$commentsString';
  }
}
