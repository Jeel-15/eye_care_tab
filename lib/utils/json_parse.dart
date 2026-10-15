/// Safe JSON coercions — Laravel often serializes ints/decimals as strings.
library;

int jsonInt(dynamic v, {int fallback = 0}) => switch (v) {
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s) ?? fallback,
      _ => fallback,
    };

int? jsonIntOrNull(dynamic v) => switch (v) {
      null => null,
      int i => i,
      num n => n.toInt(),
      String s => int.tryParse(s),
      _ => null,
    };

double jsonDouble(dynamic v, {double fallback = 0}) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? fallback,
      _ => fallback,
    };

double? jsonDoubleOrNull(dynamic v) => switch (v) {
      null => null,
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

bool jsonBool(dynamic v, {bool fallback = false}) => switch (v) {
      bool b => b,
      num n => n != 0,
      String s => s == '1' || s.toLowerCase() == 'true',
      _ => fallback,
    };
