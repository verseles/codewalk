import 'package:codewalk/features/sessions/session_model_options.dart';
import 'package:codewalk_core/codewalk_core.dart';
import 'package:flutter_test/flutter_test.dart';

ModelCost _price(double value) =>
    ModelCost(input: value, output: value, cacheRead: value, cacheWrite: value);

ModelEntry _model(
  String id, {
  String provider = 'prov',
  String? label,
  String? family,
  DateTime? released,
  bool deprecated = false,
  int? rank,
  bool free = false,
}) => ModelEntry(
  id: id,
  providerId: provider,
  label: label ?? id,
  family: family,
  released: released,
  deprecated: deprecated,
  providerRank: rank,
  cost: free ? [_price(0)] : null,
);

String _key(ModelEntry model) => '${model.providerId}/${model.id}';

ModelPickOptions _options(
  List<ModelEntry> models, {
  List<String> favorites = const [],
  List<String> recents = const [],
  Map<String, String> providers = const {},
  String query = '',
  ModelEntry? current,
}) => modelPickOptions(
  models: models,
  keyOf: _key,
  favoriteKeys: favorites,
  recentKeys: recents,
  providerNames: providers,
  query: query,
  current: current,
);

List<String> _ids(Iterable<ModelEntry> models) => [
  for (final model in models) model.id,
];

Map<String, List<String>> _groups(ModelPickOptions options) => {
  for (final (provider, models) in options.groups) provider: _ids(models),
};

void main() {
  final day = DateTime.utc(2026, 11, 1);

  group('browsing', () {
    test('favorites and recents lead and leave their provider group', () {
      final a = _model('a');
      final b = _model('b');
      final c = _model('c', provider: 'other');
      final options = _options(
        [a, b, c],
        favorites: ['prov/b', 'gone/x'],
        recents: ['other/c', 'prov/b'],
      );
      expect(_ids(options.favorites), ['b']);
      // A favorite is not repeated among the recents.
      expect(_ids(options.recents), ['c']);
      expect(_groups(options), {
        'prov': ['a'],
      });
      expect(options.matches, isNull);
    });

    test('ranked providers first, then by name, then by id', () {
      final options = _options(
        [
          _model('z', provider: 'zeta'),
          _model('m', provider: 'mid', rank: 1),
          _model('a', provider: 'alpha'),
          _model('t', provider: 'top', rank: 0),
          _model('b', provider: 'beta'),
        ],
        providers: const {'beta': 'Aardvark'},
      );
      expect(
        [for (final (p, _) in options.groups) p],
        [
          'top',
          'mid',
          'beta', // named Aardvark
          'alpha',
          'zeta',
        ],
      );
    });

    test('free first, then newest; undated after, in arrival order', () {
      final options = _options([
        _model('undated-1'),
        _model('old', released: day.subtract(const Duration(days: 30))),
        _model('undated-2'),
        _model('new', released: day),
        _model('free-old', free: true, released: DateTime.utc(2020)),
      ]);
      expect(_groups(options)['prov'], [
        'free-old',
        'new',
        'old',
        'undated-1',
        'undated-2',
      ]);
    });

    test('only the newest release of a line shows; search still finds', () {
      final older = _model(
        'gpt-6.1',
        family: 'gpt',
        released: day.subtract(const Duration(days: 60)),
      );
      final newest = _model('gpt-6.2', family: 'gpt', released: day);
      // The same family at another provider, or free, is another line.
      final elsewhere = _model(
        'gpt-6.1',
        provider: 'other',
        family: 'gpt',
        released: day.subtract(const Duration(days: 60)),
      );
      final freeLine = _model(
        'gpt-6.1-free',
        family: 'gpt',
        free: true,
        released: day.subtract(const Duration(days: 60)),
      );
      final undated = _model('gpt-old', family: 'gpt');
      final noFamily = _model(
        'solo',
        released: day.subtract(const Duration(days: 900)),
      );
      final models = [older, newest, elsewhere, freeLine, undated, noFamily];
      final options = _options(models);
      expect(_groups(options), {
        'prov': ['gpt-6.1-free', 'gpt-6.2', 'solo', 'gpt-old'],
        'other': ['gpt-6.1'],
      });
      expect(_ids(_options(models, query: 'gpt 6.1').matches!), [
        'gpt-6.1',
        'gpt-6.1',
        'gpt-6.1-free',
      ]);
    });

    test('an old line keeps its newest release', () {
      final options = _options([
        _model('v1', family: 'old', released: DateTime.utc(2020)),
        _model('v2', family: 'old', released: DateTime.utc(2021)),
      ]);
      expect(_groups(options)['prov'], ['v2']);
    });

    test('a retired model is gone unless the session runs it', () {
      final retired = _model('retired', deprecated: true);
      final kept = _model('kept');
      expect(_groups(_options([retired, kept]))['prov'], ['kept']);
      expect(_options([retired], query: 'retired').matches, isEmpty);
      expect(_groups(_options([retired, kept], current: retired))['prov'], [
        'retired',
        'kept',
      ]);
      expect(
        _ids(_options([retired], query: 'retired', current: retired).matches!),
        ['retired'],
      );
    });

    test('a replaced release the session runs still shows', () {
      final older = _model('v1', family: 'f', released: DateTime.utc(2025));
      final newer = _model('v2', family: 'f', released: DateTime.utc(2026));
      expect(_groups(_options([older, newer], current: older))['prov'], [
        'v2',
        'v1',
      ]);
    });

    test('a retired release never hides the line it belonged to', () {
      final options = _options([
        _model('v2', family: 'f', released: day, deprecated: true),
        _model('v1', family: 'f', released: DateTime.utc(2025)),
      ]);
      expect(_groups(options)['prov'], ['v1']);
    });
  });

  group('searching', () {
    test('one list by relevance, each model once', () {
      final models = [
        _model('claude-sonnet-4', label: 'Claude Sonnet 4'),
        _model('sonnet', label: 'Sonnet'),
        _model('my-sonnet-x', label: 'My Sonnet X'),
        _model('personnet', label: 'Personnet'),
        _model('snt', label: 'S N T'),
        _model('gpt', label: 'GPT', provider: 'sonnetco'),
      ];
      final options = _options(
        models,
        query: 'sonnet',
        favorites: ['prov/sonnet'],
      );
      expect(options.groups, isEmpty);
      expect(_ids(options.matches!), [
        'sonnet', // the name itself
        'claude-sonnet-4', // a word starts with it, in arrival order
        'my-sonnet-x',
        'personnet', // inside the name
        'gpt', // the provider's id
      ]);
    });

    test('punctuation and spacing do not matter', () {
      final model = _model('gpt-6.2-sol', label: 'GPT-6.2 Sol');
      for (final query in ['gpt 6', 'GPT-6.2', 'gpt62', '6.2 sol', 'Sol']) {
        expect(_ids(_options([model], query: query).matches!), [
          'gpt-6.2-sol',
        ], reason: query);
      }
      // Only punctuation is no search at all.
      expect(_options([model], query: ' -_. ').matches, isNull);
    });

    test('the provider name and the letters in order also match', () {
      final alpha = _model('alpha', provider: 'p1');
      final options = _options(
        [alpha, _model('beta', provider: 'p2')],
        providers: const {'p1': 'Provider One'},
        query: 'provider one alpha',
      );
      expect(_ids(options.matches!), ['alpha']);
      expect(_ids(_options([alpha], query: 'aph').matches!), ['alpha']);
      // A single letter is not read as letters in order.
      expect(_options([alpha], query: 'q').matches, isEmpty);
    });

    test('a favorite leads an equal match; scripts other than Latin match', () {
      final first = _model('gemini-a', label: 'Gemini A');
      final second = _model('gemini-b', label: 'Gemini B');
      expect(
        _ids(
          _options(
            [first, second],
            query: 'gemini',
            favorites: ['prov/gemini-b'],
          ).matches!,
        ),
        ['gemini-b', 'gemini-a'],
      );
      final kana = _model('kana', label: 'モデル 大');
      expect(_ids(_options([kana], query: '大').matches!), ['kana']);
    });
  });
}
