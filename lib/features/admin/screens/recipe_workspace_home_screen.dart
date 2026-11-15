import 'package:flutter/material.dart';
import 'admin_recipe_tech_screen.dart';
import 'ingredient_catalog_screen.dart';
import 'recipe_tech_cards_screen.dart';
import 'recipe_tech_editor_screen.dart';

class RecipeWorkspaceHomeScreen extends StatelessWidget {
  const RecipeWorkspaceHomeScreen({super.key});
  static const bg = Color(0xFFF8F4EE);
  static const brown = Color(0xFF8B5E3C);
  static const dark = Color(0xFF3B281F);
  static const muted = Color(0xFF806F65);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: bg, elevation: 0, title: const Text('Технологический модуль', style: TextStyle(color: dark, fontWeight: FontWeight.w700)), iconTheme: const IconThemeData(color: brown)),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFEADFD5))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ВСЛАСТЬ', style: TextStyle(letterSpacing: 3, color: brown, fontWeight: FontWeight.w700)),
        SizedBox(height: 12),
        Text('Технологии, рецептуры и точная калькуляция', style: TextStyle(fontSize: 23, height: 1.2, color: dark, fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        Text('Рабочее пространство технолога-калькулятора. Сначала проверяем распознанный рецепт, затем подтверждаем ингредиенты и цены.', style: TextStyle(color: muted, height: 1.45)),
      ])),
      const SizedBox(height: 18),
      _Tile(icon: Icons.document_scanner_outlined, title: 'Распознать рецепт', subtitle: 'Фотографии, локальный OCR и проверка распознанного текста', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRecipeTechScreen()))),
      _Tile(icon: Icons.inventory_2_outlined, title: 'Справочник сырья и цен', subtitle: 'Ингредиенты, закупочная цена, пищевая ценность и единицы измерения', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IngredientCatalogScreen()))),
      _Tile(icon: Icons.edit_note_outlined, title: 'Создать технологическую карту', subtitle: 'Ручное заполнение состава, технологии, выхода, КБЖУ и себестоимости', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeTechEditorScreen()))),
      _Tile(icon: Icons.menu_book_outlined, title: 'Технологические карты', subtitle: 'Сохранённые рецептуры, выход, себестоимость и КБЖУ', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeTechCardsScreen()))),
      const SizedBox(height: 12),
      const Text('Расчёты выполняются по подтверждённым данным справочника. Если цены или пищевая ценность отсутствуют, система не подставляет вымышленные значения.', style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
    ]),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEADFD5))),
    child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFF5EDE5), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: const Color(0xFF8B5E3C))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Color(0xFF3B281F), fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF806F65), fontSize: 12, height: 1.35)),
      ])),
      const Icon(Icons.chevron_right, color: Color(0xFF8B5E3C)),
    ]))),
  );
}
