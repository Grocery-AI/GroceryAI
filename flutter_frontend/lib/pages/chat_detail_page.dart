import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../models/message.dart';
import '../themes/colors.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../widgets/frosted_glass_textfield.dart';

class ChatDetailPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatDetailPage({required this.roomId, required this.roomName});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late WebSocketChannel _channel;
  final _messageController = TextEditingController();
  final _messages = <Message>[];
  late String _currentUsername;
  bool _isConnecting = true;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final storageService = getStorageService();
      final token = await storageService.read(key: 'token');
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Token not found, please login again')),
        );
        return;
      }

      _currentUsername = getUsernameFromToken(token) ?? 'User';

      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token&room_id=${widget.roomId}'),
      );

      await _loadMessages();

      _channel.stream.listen(
        (event) {
          _handleWebSocketMessage(event);
        },
        onError: (error) {
          print('WebSocket error: $error');
        },
        onDone: () {
          print('WebSocket closed');
        },
      );

      if (mounted) {
        setState(() => _isConnecting = false);
      }
    } catch (e) {
      print('Error initializing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await apiClient.getRoomMessages(int.parse(widget.roomId));
      _messages.clear();
      for (var item in res) {
        _messages.add(Message.fromJson(item));
      }
      if (mounted) {
        setState(() {});
        // 加載訊息後自動滾動到最新訊息
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  void _handleWebSocketMessage(dynamic event) {
    try {
      final data = jsonDecode(event);

      if (data['type'] == 'message') {
        final msg = Message.fromJson(data['message']);
        if (mounted) {
          setState(() {
            _messages.add(msg);
          });
          // 接收新訊息時也自動滾動到底部
          _scrollToBottom();
        }
      }
    } catch (e) {
      print('Error parsing WebSocket message: $e');
    }
  }

  Future<void> _scrollToBottom() async {
    // 延遲一下確保 ListView 已經更新
    await Future.delayed(Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    print('[Chat] Sending message: $text');
    _messageController.clear();

    try {
      print('[Chat] Room ID: ${widget.roomId}');
      final result =
          await apiClient.postRoomMessage(int.parse(widget.roomId), text);
      print('[Chat] Message sent successfully: $result');
      // 自動滾動到最新訊息
      _scrollToBottom();
    } catch (e) {
      print('[Chat] Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    try {
      final imageFile = await ImageService.showImagePickerDialog(context);
      if (imageFile != null) {
        // 檢查圖片大小
        final isValid = await ImageService.isImageSizeValid(imageFile);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image size must be less than 5MB')),
            );
          }
          return;
        }

        // TODO: 上傳圖片到後端
        // final base64Image = await ImageService.imageToBase64(imageFile);
        // await apiClient.postRoomMessage(int.parse(widget.roomId), base64Image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image uploaded successfully')),
          );
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  void _showInviteDialog() {
    final inviteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite User to Room'),
        content: TextField(
          controller: inviteController,
          decoration: InputDecoration(
            hintText: 'Enter username',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final username = inviteController.text.trim();
              if (username.isNotEmpty) {
                await _inviteUser(username);
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text('Invite'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteUser(String username) async {
    try {
      await apiClient.inviteToRoom(int.parse(widget.roomId), username);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $username invited successfully')),
        );
      }
    } catch (e) {
      print('Error inviting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to invite user: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat - ${widget.roomName}'),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isConnecting
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet',
                          style:
                              TextStyle(color: kTextGray, fontFamily: 'Boska'),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: false,
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isCurrentUser =
                              msg.username == _currentUsername;

                          return Align(
                            alignment: isCurrentUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 12,
                              ),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentUser ? kUserBubble : kBotBubble,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Column(
                                crossAxisAlignment: isCurrentUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser)
                                    Text(
                                      msg.username,
                                      style: TextStyle(
                                        fontFamily: 'Boska',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: kTextDark,
                                      ),
                                    ),
                                  SizedBox(height: 4),
                                  Text(
                                    msg.content,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: kTextDark,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    msg.formattedTime,
                                    style: TextStyle(
                                      fontFamily: 'Boska',
                                      fontSize: 11,
                                      color: kTextGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // LLM 提示信息
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kSecondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: kSecondary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Type "@gro " to ask the AI assistant',
                      style: TextStyle(
                        fontSize: 12,
                        color: kSecondary,
                        fontFamily: 'Boska',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // 圖片上傳按鈕
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _uploadImage,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: kSecondary.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.image, color: kSecondary, size: 20),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: FrostedGlassTextField(
                    controller: _messageController,
                    placeholder: 'Type a message...',
                  ),
                ),
                SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sendMessage,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
