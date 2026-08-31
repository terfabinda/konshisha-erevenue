import 'package:flutter/material.dart';
import '../../core/constants/default_categories.dart';

class CategoryConfigWidget extends StatefulWidget {
  final Map<String, dynamic>? currentSettings;
  final Function(Map<String, dynamic>) onChange;

  const CategoryConfigWidget({
    super.key,
    this.currentSettings,
    required this.onChange,
  });

  @override
  State<CategoryConfigWidget> createState() => _CategoryConfigWidgetState();
}

class _CategoryConfigWidgetState extends State<CategoryConfigWidget> {
  final Map<String, bool> _enabled = {};
  final Map<String, double> _defaults = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showAll = true;

  @override
  void initState() {
    super.initState();
    for (final cat in defaultRevenueCategories) {
      final current =
          widget.currentSettings?['categories'] as Map<String, dynamic>? ?? {};
      _enabled[cat] = current[cat]?['enabled'] ?? true;
      _defaults[cat] = current[cat]?['defaultAmount'] ?? 0.0;
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      for (final cat in defaultRevenueCategories) {
        _enabled[cat] = value;
      }
    });
    _notifyChange();
  }

  void _toggleCategory(String category, bool enabled) {
    setState(() => _enabled[category] = enabled);
    _notifyChange();
  }

  void _updateDefault(String category, String value) {
    final amount = double.tryParse(value) ?? 0.0;
    _defaults[category] = amount;
    _notifyChange();
  }

  void _notifyChange() {
    final categories = <String, dynamic>{};
    for (final cat in defaultRevenueCategories) {
      categories[cat] = {
        'enabled': _enabled[cat] ?? false,
        'defaultAmount': _defaults[cat] ?? 0.0,
      };
    }
    widget.onChange({'categories': categories});
  }

  List<String> get _filteredCategories {
    if (_searchQuery.isEmpty) return defaultRevenueCategories;
    return defaultRevenueCategories
        .where((c) => c.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _enabled.values.where((e) => e).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search categories...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$enabledCount/${defaultRevenueCategories.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _toggleAll(true),
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text('Enable All'),
            ),
            TextButton.icon(
              onPressed: () => _toggleAll(false),
              icon: const Icon(Icons.deselect, size: 18),
              label: const Text('Disable All'),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredCategories.length,
            itemBuilder: (context, index) {
              final cat = _filteredCategories[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                leading: Checkbox(
                  value: _enabled[cat] ?? false,
                  onChanged: (v) => _toggleCategory(cat, v ?? false),
                ),
                title: Text(cat, style: const TextStyle(fontSize: 14)),
                trailing: SizedBox(
                  width: 100,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Amount',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _updateDefault(cat, v),
                    controller: TextEditingController(
                      text: (_defaults[cat] ?? 0.0) == 0.0
                          ? ''
                          : (_defaults[cat] ?? 0.0).toString(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
