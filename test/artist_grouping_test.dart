
import 'package:flutter_test/flutter_test.dart';
import 'package:nautune/utils/artist_grouping.dart';

void main() {
  group('ArtistGrouping', () {
    test('extractBaseName splits on semicolon', () {
      expect(ArtistGrouping.extractBaseName('Zach Bryan; John Mayer'), 'Zach Bryan');
      expect(ArtistGrouping.extractBaseName('Artist A; Artist B'), 'Artist A');
      expect(ArtistGrouping.extractBaseName('One;Two;Three'), 'One');
    });

    test('extractBaseName splits on comma', () {
      expect(ArtistGrouping.extractBaseName('Zach Bryan, John Mayer'), 'Zach Bryan');
      expect(ArtistGrouping.extractBaseName('Artist A, Artist B'), 'Artist A');
    });

    test('extractBaseName splits on other separators', () {
      expect(ArtistGrouping.extractBaseName('Artist A feat. Artist B'), 'Artist A');
      expect(ArtistGrouping.extractBaseName('Artist A & Artist B'), 'Artist A');
      expect(ArtistGrouping.extractBaseName('Artist A vs Artist B'), 'Artist A');
    });

    test('extractBaseName respects exceptions', () {
      expect(ArtistGrouping.extractBaseName('AC/DC'), 'AC/DC');
      expect(ArtistGrouping.extractBaseName('AC,DC'), 'AC,DC');
      expect(ArtistGrouping.extractBaseName('Tyler, The Creator'), 'Tyler, The Creator');
      expect(ArtistGrouping.extractBaseName('Earth, Wind & Fire'), 'Earth, Wind & Fire');
      expect(ArtistGrouping.extractBaseName('Simon & Garfunkel'), 'Simon & Garfunkel');
    });

    test('extractBaseName respects protected names passed in', () {
      // Mimic what happens if "Some Band, The" is protected via ID
      final protected = {'Some Band, The'};
      expect(ArtistGrouping.extractBaseName('Some Band, The', protectedNames: protected), 'Some Band, The');
      // But if it has a feature
      expect(ArtistGrouping.extractBaseName('Some Band, The feat. Guest', protectedNames: protected), 'Some Band, The');
    });
  });
}
