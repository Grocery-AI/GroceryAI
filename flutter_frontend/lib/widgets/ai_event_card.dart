import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_client.dart';
import '../models/ai_event.dart';
import '../pages/inventory_page.dart';

class AIEventCard extends StatelessWidget {
  final AIEvent event;

  const AIEventCard({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(_getIconForEvent(), color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  _getTitleForEvent(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Narrative
            Text(
              event.narrative,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            // Specific Content
            _buildSpecificContent(context),
          ],
        ),
      ),
    );
  }

  IconData _getIconForEvent() {
    if (event.isInventoryEvent) return Icons.inventory;
    if (event.isMenuEvent) return Icons.restaurant_menu;
    if (event.isRestockEvent) return Icons.shopping_cart;
    if (event.isProcurementEvent) return Icons.list_alt;
    return Icons.smart_toy;
  }

  String _getTitleForEvent() {
    if (event.isInventoryEvent) return 'Inventory Analysis';
    if (event.isMenuEvent) return 'Menu Suggestions';
    if (event.isRestockEvent) return 'Restock Plan';
    if (event.isProcurementEvent) return 'Procurement Plan';
    return 'AI Assistant';
  }

  Widget _buildSpecificContent(BuildContext context) {
    if (event.isInventoryEvent) return _InventoryAnalysisWidget(event: event);
    if (event.isMenuEvent) return _MenuSuggestionsWidget(event: event);
    if (event.isRestockEvent) return _RestockPlanWidget(event: event);
    if (event.isProcurementEvent) return _ProcurementPlanWidget(event: event);
    return const SizedBox.shrink();
  }
}

class _InventoryAnalysisWidget extends StatelessWidget {
  final AIEvent event;
  const _InventoryAnalysisWidget({required this.event});

  @override
  Widget build(BuildContext context) {
    final lowStock = event.lowStockItems;
    final healthy = event.healthyItems;

    if (lowStock.isEmpty && healthy.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory is empty.', style: TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InventoryPage()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Go to Inventory'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lowStock.isNotEmpty) ...[
          const Text('⚠️ Low Stock:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ...lowStock.map((item) {
            final stock = item['stock'] ?? 0;
            final safety = item['safety_stock_level'] ?? 0;
            final name = item['product_name'] ?? 'Unknown';
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('• $name (Stock: $stock / Safety: $safety)'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart, size: 20, color: Colors.blue),
                    tooltip: 'Add to Shopping List',
                    onPressed: () async {
                      final quantity = (safety - stock) > 0 ? (safety - stock) : 1;
                      final itemsJson = jsonEncode([
                        {"item": name, "quantity": quantity, "unit": "unit"}
                      ]);
                      try {
                        await apiClient.createShoppingList("Restock: $name", itemsJson);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added "$name" to new shopping list')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (healthy.isNotEmpty) ...[
          const Text('✅ Healthy:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ...healthy.map((item) {
            final stock = item['stock'] ?? 0;
            final safety = item['safety_stock_level'] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('• ${item['product_name']} (Stock: $stock / Safety: $safety)'),
            );
          }),
        ],
      ],
    );
  }
}

class _MenuSuggestionsWidget extends StatelessWidget {
  final AIEvent event;
  const _MenuSuggestionsWidget({required this.event});

  @override
  Widget build(BuildContext context) {
    final dishes = event.dishes;

    return Column(
      children: dishes.map<Widget>((dish) {
        final missing = dish['missing_ingredients'] as List? ?? [];
        return Card(
          color: Colors.orange.shade50,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.restaurant),
            title: Text(dish['name'] ?? 'Unknown Dish'),
            subtitle: missing.isNotEmpty
                ? Text('Missing: ${missing.join(", ")}', style: const TextStyle(color: Colors.red))
                : const Text('Ready to cook!', style: TextStyle(color: Colors.green)),
          ),
        );
      }).toList(),
    );
  }
}

class _RestockPlanWidget extends StatelessWidget {
  final AIEvent event;
  const _RestockPlanWidget({required this.event});

  @override
  Widget build(BuildContext context) {
    final items = event.restockItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(event.summary, style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        ...items.map((item) => ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(item['name'] ?? ''),
          subtitle: Text(item['notes'] ?? ''),
          trailing: Text('\$${item['price_estimate'] ?? '?'}'),
        )),
      ],
    );
  }
}

class _ProcurementPlanWidget extends StatelessWidget {
  final AIEvent event;
  const _ProcurementPlanWidget({required this.event});

  @override
  Widget build(BuildContext context) {
    final items = event.procurementItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.goal.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Goal: ${event.goal}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ...items.map((item) => CheckboxListTile(
          value: false,
          onChanged: null,
          title: Text(item['name'] ?? ''),
          subtitle: Text('${item['quantity']} - ${item['notes'] ?? ''}'),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
        )),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _saveToShoppingList(context),
            icon: const Icon(Icons.save_alt),
            label: const Text('Save to Shopping List'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveToShoppingList(BuildContext context) async {
    try {
      final items = event.procurementItems;
      final title = event.goal.isNotEmpty ? event.goal : 'Shopping List';
      
      await apiClient.createShoppingList(title, jsonEncode(items));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to Shopping List! Check Inventory page.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}
