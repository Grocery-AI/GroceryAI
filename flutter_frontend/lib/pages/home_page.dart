import 'package:flutter/material.dart';
import 'dart:ui';
import 'chat_detail_page.dart';
import 'profile_page.dart';
import '../services/api_client.dart';
import '../themes/colors.dart';
import '../widgets/frosted_glass_button.dart';
import '../widgets/frosted_glass_textfield.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _rooms = [];
  Set<int> _pinnedRoomIds = {};
  bool _isLoading = true;
  final _createRoomController = TextEditingController();
  final _searchController = TextEditingController();
  bool _showCreateForm = false;
  bool _showSearchForm = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      print('[HomePage] Loading rooms...');
      final rooms = await apiClient.getRooms();
      print('[HomePage] Retrieved ${rooms.length} rooms from API');
      for (var i = 0; i < rooms.length; i++) {
        print('[HomePage]   Room $i: ${rooms[i]}');
      }
      setState(() {
        _rooms = rooms
            .map((r) => {
                  'id': r['id'] as int,
                  'name': r['name'] as String,
                })
            .toList();
        _isLoading = false;
      });
      print('[HomePage] Updated state with ${_rooms.length} rooms');
    } catch (e) {
      print('Error loading rooms: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load rooms: $e')),
        );
      }
    }
  }

  void _togglePin(int roomId) {
    setState(() {
      if (_pinnedRoomIds.contains(roomId)) {
        _pinnedRoomIds.remove(roomId);
      } else {
        _pinnedRoomIds.add(roomId);
      }
    });
  }

  Future<void> _createRoom() async {
    final name = _createRoomController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Room name cannot be empty')),
      );
      return;
    }

    try {
      print('[HomePage] Creating room: $name');
      await apiClient.createRoom(name);
      print('[HomePage] Room created successfully');
      _createRoomController.clear();

      print('[HomePage] Loading rooms after creation...');
      final rooms = await apiClient.getRooms();
      print('[HomePage] Retrieved ${rooms.length} rooms from API');
      for (var i = 0; i < rooms.length; i++) {
        print('[HomePage]   Room $i: ${rooms[i]}');
      }

      // 更新 state 一次，包含所有變化
      setState(() {
        _showCreateForm = false;
        _rooms = rooms
            .map((r) => {
                  'id': r['id'] as int,
                  'name': r['name'] as String,
                })
            .toList();
      });
      print('[HomePage] Updated state with ${_rooms.length} rooms');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room created successfully')),
        );
      }
    } catch (e) {
      print('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create room: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredRooms() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _rooms;
    return _rooms
        .where((room) => room['name'].toLowerCase().contains(query))
        .toList();
  }

  List<Map<String, dynamic>> _getPinnedRooms() {
    return _getFilteredRooms()
        .where((room) => _pinnedRoomIds.contains(room['id']))
        .toList();
  }

  List<Map<String, dynamic>> _getUnpinnedRooms() {
    return _getFilteredRooms()
        .where((room) => !_pinnedRoomIds.contains(room['id']))
        .toList();
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final isPinned = _pinnedRoomIds.contains(room['id']);
    return ListTile(
      leading: Text('💬', style: TextStyle(fontSize: 24)),
      title: Text(
        room['name'],
        style: TextStyle(fontFamily: 'Boska', fontWeight: FontWeight.w400),
      ),
      subtitle: Text('Tap to enter chat'),
      trailing: IconButton(
        icon: Icon(
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          color: isPinned ? Color(0xFF10B981) : Colors.grey,
        ),
        onPressed: () => _togglePin(room['id']),
      ),
      onTap: () {
        // 關閉搜尋框
        if (_showSearchForm) {
          setState(() {
            _showSearchForm = false;
            _searchController.clear();
          });
        }
        // 導航到聊天室
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              roomId: room['id'].toString(),
              roomName: room['name'],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _createRoomController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinnedRooms = _getPinnedRooms();
    final unpinnedRooms = _getUnpinnedRooms();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Grocery AI',
          style: TextStyle(
            fontFamily: 'Boska',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF064E3B),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              setState(() {
                _showCreateForm = !_showCreateForm;
                // 如果打開創建表單，關閉搜尋表單
                if (_showCreateForm) {
                  _showSearchForm = false;
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              setState(() {
                _showSearchForm = !_showSearchForm;
                // 如果打開搜尋表單，關閉創建表單
                if (_showSearchForm) {
                  _showCreateForm = false;
                  _createRoomController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 主內容列表
                Column(
                  children: [
                    // 搜尋框 - 在最上面，當出現時會推下列表
                    if (_showSearchForm)
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: FrostedGlassTextField(
                                controller: _searchController,
                                placeholder: 'Search room name...',
                                onChanged: (_) {
                                  setState(() {}); // 即時更新UI
                                },
                              ),
                            ),
                            SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showSearchForm = false;
                                  _searchController.clear();
                                });
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Color(0xFF064E3B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Color(0xFF064E3B).withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close,
                                  color: Color(0xFF064E3B),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_showCreateForm)
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Column(
                          children: [
                            FrostedGlassTextField(
                              controller: _createRoomController,
                              placeholder: 'Enter room name...',
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FrostedGlassButton(
                                    label: 'Create',
                                    onPressed: _createRoom,
                                    isPrimary: true,
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: FrostedGlassButton(
                                    label: 'Cancel',
                                    onPressed: () {
                                      setState(() => _showCreateForm = false);
                                      _createRoomController.clear();
                                    },
                                    isPrimary: false,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    Expanded(
                      child: pinnedRooms.isEmpty && unpinnedRooms.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'No rooms yet. Create one to get started!'
                                    : 'No rooms found',
                                style: TextStyle(
                                  color: kTextGray,
                                  fontFamily: 'Boska',
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (pinnedRooms.isNotEmpty) ...[
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 16, 16, 8),
                                      child: Text(
                                        'Pinned',
                                        style: TextStyle(
                                          fontFamily: 'Boska',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kTextGray,
                                        ),
                                      ),
                                    ),
                                    ...pinnedRooms
                                        .map((room) => _buildRoomTile(room))
                                        .toList(),
                                    SizedBox(height: 8),
                                  ],
                                  if (unpinnedRooms.isNotEmpty) ...[
                                    Padding(
                                      padding:
                                          EdgeInsets.fromLTRB(16, 8, 16, 8),
                                      child: Text(
                                        'All Rooms',
                                        style: TextStyle(
                                          fontFamily: 'Boska',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: kTextGray,
                                        ),
                                      ),
                                    ),
                                    ...unpinnedRooms
                                        .map((room) => _buildRoomTile(room))
                                        .toList(),
                                  ],
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
                // 只保留 Stack 容器
              ],
            ),
    );
  }
}
