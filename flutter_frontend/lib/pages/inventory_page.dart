import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_client.dart';
import '../themes/colors.dart';

class InventoryPage extends StatefulWidget {
  @override
  _InventoryPageState createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<dynamic> _items = [];
  List<dynamic> _shoppingLists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await apiClient.getInventory();
      final lists = await apiClient.getShoppingLists();
      setState(() {
        _items = items;
        _shoppingLists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  Future<void> _loadInventory() async {
    await _loadData();
  }

  Future<void> _showEditDialog({Map<String, dynamic>? item}) async {
    final nameController =
        TextEditingController(text: item?['product_name'] ?? '');
    final stockController =
        TextEditingController(text: item?['stock']?.toString() ?? '0');
    final safetyController = TextEditingController(
        text: item?['safety_stock_level']?.toString() ?? '0');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item == null ? 'Add Item' : 'Edit Item',
          style: TextStyle(
            fontFamily: 'Boska',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : kTextDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStyledTextField(
              controller: nameController,
              label: 'Product Name',
              isDark: isDark,
              enabled: item == null,
            ),
            SizedBox(height: 16),
            _buildStyledTextField(
              controller: stockController,
              label: 'Stock',
              isDark: isDark,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            _buildStyledTextField(
              controller: safetyController,
              label: 'Safety Stock Level',
              isDark: isDark,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Satoshi',
                color: kTextGray,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () async {
              try {
                await apiClient.upsertInventoryItem(
                  nameController.text,
                  int.parse(stockController.text),
                  int.parse(safetyController.text),
                );
                Navigator.pop(context);
                _loadInventory();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required bool isDark,
    bool enabled = true,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        fontFamily: 'Satoshi',
        color: isDark ? Colors.white : kTextDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Satoshi',
          color: kTextGray,
        ),
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : kBgLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kPrimary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    try {
      await apiClient.deleteInventoryItem(id);
      _loadInventory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  Future<void> _archiveList(int id) async {
    try {
      await apiClient.archiveShoppingList(id);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to archive list: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: ClipRect(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(
                'Inventory',
                style: TextStyle(
                  fontFamily: 'Boska',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).appBarTheme.titleTextStyle?.color,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _showEditDialog(),
                ),
                SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding:
                    EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 16),
                children: [
                  // Shopping Lists Section
                  if (_shoppingLists.isNotEmpty) ...[
                    Text(
                      'Shopping Lists',
                      style: TextStyle(
                        fontFamily: 'Boska',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : kTextDark,
                      ),
                    ),
                    SizedBox(height: 12),
                    ..._shoppingLists.map((list) =>
                        _buildShoppingListCard(context, list, isDark)),
                    SizedBox(height: 24),
                  ],

                  // Inventory Section
                  Text(
                    'My Inventory',
                    style: TextStyle(
                      fontFamily: 'Boska',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : kTextDark,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (_items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No items in inventory',
                          style: TextStyle(
                            color: kTextGray,
                            fontFamily: 'Satoshi',
                          ),
                        ),
                      ),
                    )
                  else
                    ..._items.map((item) =>
                        _buildInventoryItemCard(context, item, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildShoppingListCard(
      BuildContext context, dynamic list, bool isDark) {
    // Parse items JSON
    List<dynamic> items = [];
    try {
      items = jsonDecode(list['items_json']);
    } catch (_) {}

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.indigo.withOpacity(0.2)
            : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.indigo.withOpacity(0.3)
              : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.indigo.withOpacity(0.3)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_cart_outlined,
              color: isDark ? Colors.indigo[200] : Colors.blue[700],
            ),
          ),
          title: Text(
            list['title'],
            style: TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            '${items.length} items • ${list['created_at'].substring(0, 10)}',
            style: TextStyle(
              fontFamily: 'Satoshi',
              color: kTextGray,
              fontSize: 12,
            ),
          ),
          children: [
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isChecked = item['checked'] == true;

              return ListTile(
                dense: true,
                title: Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    decoration: isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? kTextGray : null,
                  ),
                ),
                subtitle: Text('${item['quantity']} - ${item['notes'] ?? ''}'),
                leading: IconButton(
                  icon: Icon(
                    isChecked ? Icons.check_circle : Icons.circle_outlined,
                    color: isChecked ? Colors.green : kTextGray,
                    size: 20,
                  ),
                  onPressed: () async {
                    try {
                      await apiClient.checkShoppingListItem(
                          list['id'], index, item);
                      _loadData(); // Reload to reflect changes
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isChecked
                              ? 'Item unchecked'
                              : 'Item added to inventory!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton.icon(
                onPressed: () => _archiveList(list['id']),
                icon: Icon(Icons.archive_outlined, size: 18),
                label: Text('Archive List'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItemCard(
      BuildContext context, dynamic item, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey[800]!.withOpacity(0.5)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.cyan.withOpacity(0.2)
                : kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.inventory_2_outlined,
            color: isDark ? Colors.cyan : kPrimary,
          ),
        ),
        title: Text(
          item['product_name'],
          style: TextStyle(
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              _buildBadge(
                context,
                'Stock: ${item['stock']}',
                item['stock'] < item['safety_stock_level']
                    ? Colors.red
                    : Colors.green,
              ),
              SizedBox(width: 8),
              Text(
                'Safety: ${item['safety_stock_level']}',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  color: kTextGray,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
          onPressed: () => _deleteItem(item['product_id']),
        ),
        onTap: () => _showEditDialog(item: item),
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String text, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Satoshi',
        ),
      ),
    );
  }
}
