import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/message.dart';
import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? serviceId;
  final String? serviceTitle;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.serviceId,
    this.serviceTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _imagePicker = ImagePicker();
  late ChatService _chatService;
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    _chatService = ChatService(_userId);
    
    // تحديث حالة قراءة الرسائل عند فتح المحادثة
    _markChatAsRead();
    
    // إضافة مستمع للتمرير لتحديث حالة القراءة عند التمرير في المحادثة
    _scrollController.addListener(() {
      // تحديث حالة القراءة عند التمرير لضمان قراءة جميع الرسائل
      if (_scrollController.hasClients && 
          _scrollController.offset >= _scrollController.position.minScrollExtent &&
          !_scrollController.position.outOfRange) {
        _markChatAsRead();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  void _markChatAsRead() {
    if (_userId.isNotEmpty) {
      // قم بتعليم المحادثة كمقروءة بعد انتظار قصير للتأكد من تحميل واجهة المستخدم أولاً
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _chatService.markChatAsRead(widget.chatId).then((_) {
            // عدم الحاجة للإشعار البصري هنا لأن ذلك يحدث تلقائيًا عند دخول المحادثة
          });
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.sendMessage(
        widget.chatId,
        widget.otherUserId,
        message,
      );
      _messageController.clear();

      // تمرير القائمة إلى أحدث رسالة
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة')));
      print('Error sending message: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
      });

      await _chatService.sendImageMessage(
        widget.chatId,
        widget.otherUserId,
        File(pickedFile.path),
      );

      // تمرير القائمة إلى أحدث رسالة
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء إرسال الصورة')));
      print('Error sending image: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.otherUserName),
            if (widget.serviceTitle != null)
              Text(
                widget.serviceTitle!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // عرض المعلومات الإضافية عن الخدمة
          if (widget.serviceTitle != null)
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.purple.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذه المحادثة متعلقة بالخدمة: ${widget.serviceTitle}',
                      style: TextStyle(color: Colors.purple[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // قائمة الرسائل
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد رسائل حتى الآن',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ابدأ المحادثة بإرسال رسالة',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // عرض الرسائل من الحديثة للقديمة
                  padding: EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isMe = message.senderId == _userId;

                    // التحقق من وجود رسالة في اليوم التالي
                    bool showDateHeader = false;
                    if (index < messages.length - 1) {
                      final DateTime currentDate = DateTime(
                        message.timestamp.year,
                        message.timestamp.month,
                        message.timestamp.day,
                      );
                      final DateTime nextDate = DateTime(
                        messages[index + 1].timestamp.year,
                        messages[index + 1].timestamp.month,
                        messages[index + 1].timestamp.day,
                      );
                      showDateHeader = currentDate != nextDate;
                    } else if (index == messages.length - 1) {
                      // آخر رسالة في المحادثة
                      showDateHeader = true;
                    }

                    return Column(
                      children: [
                        if (showDateHeader) _buildDateHeader(message.timestamp),
                        _buildMessageItem(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // مؤشر التحميل
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),

          // منطقة إدخال الرسائل
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // زر إضافة صورة
                IconButton(
                  icon: Icon(Icons.photo, color: Colors.purple),
                  onPressed: _sendImage,
                ),
                // حقل إدخال النص
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    // Removed TextDirection to fix compilation error
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة هنا...',
                      // Removed hintTextDirection to fix compilation error
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                // زر إرسال
                Material(
                  color: Colors.purple,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _sendMessage,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send, color: Colors.white, size: 20),
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

  Widget _buildDateHeader(DateTime timestamp) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              DateFormat.yMMMd('ar').format(timestamp),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, bool isMe) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    final time = DateFormat.jm('ar').format(message.timestamp);

    // إظهار فقاعة رسالة مختلفة بناءً على نوع الرسالة ومرسلها
    return Container(
      margin: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: isMe ? 40 : 0,
        right: isMe ? 0 : 40,
      ),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding:
                message.imageUrl != null
                    ? EdgeInsets.all(4)
                    : EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? Colors.purple[100] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child:
                message.imageUrl != null
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            message.imageUrl!,
                            width: maxWidth,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return SizedBox(
                                width: maxWidth,
                                height: 150,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: maxWidth,
                                height: 150,
                                color: Colors.grey[200],
                                child: Icon(Icons.error, color: Colors.red),
                              );
                            },
                          ),
                        ),
                        if (message.text != 'صورة')
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              message.text,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                      ],
                    )
                    : Text(message.text, style: TextStyle(fontSize: 16)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
                SizedBox(width: 4),
                if (isMe)
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? Colors.blue : Colors.grey[600],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
