import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../tests/test_detail_repository.dart';

/// Porteado de kX (main.js:61156+) — el curriculum completo (G1-G5, P1-P5,
/// K1-K5) está embebido como datos estáticos en el bundle JS original, NO
/// viene de una API (confirmado leyendo el componente: `this.videos = $1`
/// con arrays literales de cientos de técnicas, sin ningún llamado HTTP).
/// Acá se extrajeron esos 3 arrays reales (144 + 159 + 114 técnicas, con
/// sus mistakes) a JSON y se empaquetan como assets — mismo contenido real,
/// cargado localmente igual que en el original.
enum CurriculumCategory { graduate, practitioner, kids }

class CurriculumRepository {
  Future<List<TestTechnique>> fetchCategory(CurriculumCategory category) async {
    final path = switch (category) {
      CurriculumCategory.graduate => 'assets/curriculum/graduate.json',
      CurriculumCategory.practitioner => 'assets/curriculum/practitioner.json',
      CurriculumCategory.kids => 'assets/curriculum/kids.json',
    };
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>().map(TestTechnique.fromJson).toList();
  }
}
