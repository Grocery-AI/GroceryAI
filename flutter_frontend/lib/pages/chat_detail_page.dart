import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../models/message.dart';
import '../models/ai_event.dart';
import '../themes/colors.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/image_service.dart';
import '../services/storage_service.dart';
import '../widgets/frosted_glass_textfield.dart';
import '../widgets/ai_event_card.dart';

class ChatDetailPage extends StatefulWidget {
  final String roomId;
  final String roomName;

  const ChatDetailPage({required this.roomId, required this.roomName});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  // late WebSocketChannel _channel; // Removed

  final _messageController = TextEditingController();
  final _messages =
      <dynamic>[]; // Changed to dynamic to hold both Message and AIEvent
  late String _currentUsername;
  bool _isConnecting = true;
  bool _hasError = false;
  String _errorMessage = '';
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeChat();
  }

  @override
  void didUpdateWidget(ChatDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If roomId changed, reconnect to new room
    if (oldWidget.roomId != widget.roomId) {
      apiClient.disconnectWebSocket();
      _messages.clear();
      _hasError = false;
      _isConnecting = true;
      _initializeChat();
    }
  }

  @override
  void dispose() {
    apiClient.disconnectWebSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      final storageService = getStorageService();
      final token = await storageService.read(key: 'auth_token');
      if (token == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Token not found, please login again';
            _isConnecting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage)),
          );
        }
        return;
      }

      _currentUsername = getUsernameFromToken(token) ?? 'User';

      try {
        // Connect via ApiClient
        apiClient.connectWebSocket(int.parse(widget.roomId));

        await _loadMessages();

        // Listen to AI events
        apiClient.aiEventStream.listen((event) {
          if (mounted) {
            setState(() {
              _messages.add(event);
            });
            _scrollToBottom();
          }
        });

        // Listen to Chat messages
        apiClient.messageStream.listen((msgData) {
          if (mounted) {
            final msg = Message.fromJson(msgData);
            if (msg.content.startsWith('AI_EVENT_JSON:')) {
              try {
                final jsonStr = msg.content.substring('AI_EVENT_JSON:'.length);
                final eventData = jsonDecode(jsonStr);
                setState(() {
                  _messages.add(AIEvent.fromJson(eventData));
                });
              } catch (e) {
                print('Error parsing AI event from stream: $e');
                setState(() {
                  _messages.add(msg);
                });
              }
            } else {
              setState(() {
                _messages.add(msg);
              });
            }
            _scrollToBottom();
          }
        });

        if (mounted) {
          setState(() => _isConnecting = false);
        }
      } catch (e) {
        print('[ChatPage] Failed to connect to WebSocket: $e');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Failed to connect to chat: $e';
            _isConnecting = false;
          });
        }
      }
    } catch (e) {
      print('[ChatPage] Error in _initializeChat: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Initialization error: $e';
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await apiClient.getRoomMessages(int.parse(widget.roomId));
      _messages.clear();
      for (var item in res) {
        final msg = Message.fromJson(item);
        if (msg.content.startsWith('AI_EVENT_JSON:')) {
          try {
            final jsonStr = msg.content.substring('AI_EVENT_JSON:'.length);
            final eventData = jsonDecode(jsonStr);
            _messages.add(AIEvent.fromJson(eventData));
          } catch (e) {
            print('Error parsing AI event from message: $e');
            _messages.add(msg);
          }
        } else {
          _messages.add(msg);
        }
      }
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  // _handleWebSocketMessage removed as it is replaced by stream listeners

  Future<void> _scrollToBottom() async {
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

    // Check if message starts with @plan or @match command
    if (text.startsWith('@plan')) {
      await _handlePlanCommand(text);
      return;
    }

    if (text.startsWith('@match')) {
      await _handleMatchCommand(text);
      return;
    }

    // Regular message
    try {
      print('[Chat] Room ID: ${widget.roomId}');
      final result =
          await apiClient.postRoomMessage(int.parse(widget.roomId), text);
      print('[Chat] Message sent successfully: $result');
      _scrollToBottom();
    } catch (e) {
      print('[Chat] Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _handlePlanCommand(String message) async {
    // Extract goal from message: "@plan <goal>"
    final goal = message.replaceFirst('@plan', '').trim();
    print('[Chat] Executing @plan command with goal: $goal');

    try {
      final roomId = int.parse(widget.roomId);
      final result = await apiClient.generateAIPlan(roomId,
          goal: goal.isNotEmpty ? goal : null);
      print('[Chat] Plan result: $result');

      // Show result in dialog
      if (mounted) {
        _showAIResult(
          title: 'AI Plan',
          result: result,
        );
      }
    } catch (e) {
      print('[Chat] Error in @plan command: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan generation failed: $e')),
        );
      }
    }
  }

  Future<void> _handleMatchCommand(String message) async {
    // Extract goal from message: "@match <optional goal>"
    final goal = message.replaceFirst('@match', '').trim();
    print('[Chat] Executing @match command with goal: $goal');

    try {
      final roomId = int.parse(widget.roomId);
      final result = await apiClient.generateAISuggestion(roomId,
          goal: goal.isNotEmpty ? goal : null);
      print('[Chat] Suggestion result: $result');

      // Show result in dialog
      if (mounted) {
        _showAIResult(
          title: 'AI Matching',
          result: result,
        );
      }
    } catch (e) {
      print('[Chat] Error in @match command: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Matching suggestion failed: $e')),
        );
      }
    }
  }

  void _showAIResult(
      {required String title, required Map<String, dynamic> result}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.containsKey('plan')) ...[
                _buildPlanContent(result['plan']),
              ] else if (result.containsKey('suggestions')) ...[
                _buildSuggestionContent(result['suggestions']),
              ] else ...[
                Text('Response: ${jsonEncode(result)}'),
              ]
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanContent(dynamic plan) {
    if (plan is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan['event'] != null) ...[
            Text(
              'Event: ${plan['event']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
          if (plan['items'] != null && (plan['items'] is List)) ...[
            const Text(
              'Items:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...(plan['items'] as List).map((item) {
              final itemText = item is Map
                  ? '${item['name']} - ${item['assigned_to'] ?? 'Unassigned'}'
                  : item.toString();
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4),
                child: Text('• $itemText'),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (plan['timeline'] != null && (plan['timeline'] is List)) ...[
            const Text(
              'Timeline:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...(plan['timeline'] as List).map((time) {
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4),
                child: Text('• $time'),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (plan['narrative'] != null) ...[
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(plan['narrative'].toString()),
          ],
        ],
      );
    }
    return Text('Plan: ${plan.toString()}');
  }

  Widget _buildSuggestionContent(dynamic suggestions) {
    if (suggestions is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (suggestions['suggested_invites'] != null) ...[
            const Text(
              'Suggested Invites:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...(suggestions['suggested_invites'] as List).map((invite) {
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4),
                child: Text('• $invite'),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (suggestions['missing_roles'] != null) ...[
            const Text(
              'Missing Roles:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...(suggestions['missing_roles'] as List).map((role) {
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4),
                child: Text('• $role'),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (suggestions['narrative'] != null) ...[
            const Text(
              'Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(suggestions['narrative'].toString()),
          ],
        ],
      );
    }
    return Text('Suggestions: ${suggestions.toString()}');
  }

  List<TextSpan> _buildMessageSpans(String content) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@[\w]+');

    int lastIndex = 0;
    for (final match in mentionRegex.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: TextStyle(
              fontSize: 16,
              color: kTextDark,
              fontFamily: 'Satoshi',
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontSize: 16,
            color: kTextDark,
            fontFamily: 'Satoshi',
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: TextStyle(
            fontSize: 16,
            color: kTextDark,
            fontFamily: 'Satoshi',
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: content,
          style: TextStyle(
            fontSize: 16,
            color: kTextDark,
            fontFamily: 'Satoshi',
          ),
        ),
      );
    }

    return spans;
  }

  Future<void> _uploadImage() async {
    try {
      final imageFile = await ImageService.showImagePickerDialog(context);
      if (imageFile != null) {
        final isValid = await ImageService.isImageSizeValid(imageFile);
        if (!isValid) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image size must be less than 5MB')),
            );
          }
          return;
        }

        // TODO: upload image to server and send as message
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
  Widget build(BuildContext context) {
    // If there's an error during initialization, show error message
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Chat - ${widget.roomName}'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Connection Error',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextGray, fontFamily: 'Boska'),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

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
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: Text(
                widget.roomName,
                style: TextStyle(
                  fontFamily: 'Boska',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: true,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Icon(Icons.person_add),
                  onPressed: _showInviteDialog,
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;

          return Center(
            child: Container(
              width: maxWidth,
              child: Column(
                children: [
                  Expanded(
                    child: _isConnecting
                        ? Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? Center(
                                child: Text(
                                  'No messages yet',
                                  style: TextStyle(
                                      color: kTextGray, fontFamily: 'Satoshi'),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                reverse: false,
                                itemCount: _messages.length,
                                itemBuilder: (_, i) {
                                  final item = _messages[i];

                                  if (item is AIEvent) {
                                    return AIEventCard(event: item);
                                  }

                                  final msg = item as Message;
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
                                        color: isCurrentUser
                                            ? kUserBubble
                                            : kBotBubble,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.75,
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
                                          RichText(
                                            text: TextSpan(
                                              children: _buildMessageSpans(
                                                  msg.content),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            msg.formattedTime,
                                            style: TextStyle(
                                              fontFamily: 'Satoshi',
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
                                fontFamily: 'Satoshi',
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
                              child: Icon(Icons.image,
                                  color: kSecondary, size: 20),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: FrostedGlassTextField(
                            controller: _messageController,
                            placeholder:
                                'Try: @gro analyze, @gro menu, @gro restock, @gro plan',
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
            ),
          );
        },
      ),
    );
  }
}
