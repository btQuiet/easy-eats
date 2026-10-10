import 'dart:collection';

typedef Json = Map<String, dynamic>;

dynamic _immutable(dynamic value) {
  if (value is Map) {
    return UnmodifiableMapView<String, dynamic>(
      value.map((k, v) => MapEntry(k as String, _immutable(v))),
    );
  }
  if (value is List) {
    return List.unmodifiable(value.map(_immutable));
  }
  return value;
}

class Recipe {
  Recipe.fromJson(Json json)
    : data = _immutable(json) as Json,
      code = json['code'] as String,
      name = json['name'] as String;
  final Json data;
  final String code;
  final String name;
  String get category => data['category'] as String;
  List<dynamic> get ingredients => List.unmodifiable(data['ingredients']);
  List<dynamic> get allergens => List.unmodifiable(data['allergens']);
  bool? get compatible => data['compatible'] as bool?;
}

class Meal {
  Meal.fromJson(Json json)
    : data = _immutable(json) as Json,
      recipe = Recipe.fromJson(json['recipe_snapshot'] as Json);
  final Json data;
  final Recipe recipe;
  String get id => data['id'] as String;
  int get version => data['version'] as int;
  String get date => data['date'] as String;
  String get slot => data['meal_slot'] as String;
  bool get canSwap => data['can_swap'] == true;
  bool get canFeedback => data['can_feedback'] == true;
  bool get needsAttention => data['compatibility'] == 'needs_attention';
}

class Profile {
  Profile.fromJson(Json json) : data = _immutable(json) as Json;
  final Json data;
  int get version => data['version'] as int;
  bool get completed => data['completed'] == true;
  String? get startDate => data['service_start_date'] as String?;
}

class ApiException implements Exception {
  const ApiException(
    this.code,
    this.message, {
    this.details = const {},
    this.uncertain = false,
  });
  final String code;
  final String message;
  final Json details;
  final bool uncertain;
  @override
  String toString() => message;
}

class ApiResult {
  const ApiResult(this.data, this.meta, this.status);
  final dynamic data;
  final Json meta;
  final int status;
}

const mealLabels = {
  'desayuno': 'Desayuno',
  'comida': 'Comida',
  'merienda': 'Merienda',
  'cena': 'Cena',
};
const weekdays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const dietLabels = {
  'omnivore': 'Omnívora',
  'vegetarian': 'Vegetariana',
  'vegan': 'Vegana',
};
const repetitionLabels = {
  'low': 'Poca repetición · objetivo 1 vez por semana',
  'normal': 'Repetición normal · objetivo 2 veces por semana',
  'high': 'Más repetición · objetivo 3 veces por semana',
};
String selectionText(
  List codes,
  List options, {
  required String empty,
  int? limit,
}) {
  if (codes.isEmpty) return empty;
  final names = {
    for (final raw in options)
      (raw as Json)['code']: raw['known'] == false
          ? '${raw['name']} (revisar)'
          : raw['name'],
  };
  final shown = limit == null ? codes : codes.take(limit).toList();
  final text = shown.map((code) => names[code] ?? '$code (revisar)').join(', ');
  return limit != null && codes.length > limit
      ? '$text y ${codes.length - limit} más'
      : text;
}

int weeklyMealCount(Json profile) =>
    (profile['weekly_slots'] as List).fold<int>(
      0,
      (count, raw) => count + ((raw as Json)['meal_slots'] as List).length,
    );
const steps = ['plan', 'calendar', 'restrictions', 'preferences', 'summary'];
String dateKey(DateTime date) => date.toIso8601String().substring(0, 10);
String foldSearch(String value) {
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  return value
      .toLowerCase()
      .replaceAllMapped(RegExp('[áéíóúüñ]'), (m) => accents[m[0]]!)
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
}

String shortDate(String value) {
  final d = DateTime.parse(value);
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

String monthLabel(String value) {
  const names = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final d = DateTime.parse('$value-01');
  return '${names[d.month - 1]} de ${d.year}';
}
