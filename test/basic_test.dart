import 'package:docfinder/core/file_types.dart';
import 'package:docfinder/core/formatters.dart';
import 'package:docfinder/domain/search_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file kinds are detected from extension', () {
    expect(kindOfExtension('PDF'), FileKind.pdf);
    expect(kindOfExtension('docx'), FileKind.word);
    expect(kindOfExtension('xyz'), FileKind.other);
  });

  test('bytes are formatted', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('search terms are split and lower-cased', () {
    const p = SearchParams(query: '  Ali  CV 2026 ');
    expect(p.terms, ['ali', 'cv', '2026']);
    expect(p.isActive, isTrue);
    expect(const SearchParams().isActive, isFalse);
  });
}
