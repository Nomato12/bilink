import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/message.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late ChatService _chatService;
  final _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(_userId);
    // تهيئة الترجمة العربية لمكتبة timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  @override
  Widget build(BuildContext context) {
    if (_userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('المحادثات'), centerTitle: true),
        body: const Center(child: Text('يجب تسجيل الدخول لعرض المحادثات')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('المحادثات'), centerTitle: true),
      body: StreamBuilder<List<Chat>>(
        stream: _chatService.getChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد محادثات',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ابدأ محادثة مع مزود خدمة أو عميل',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _buildChatItem(chat);
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<int>(
        stream: _chatService.getUnreadMessageCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          
          // إظهار زر تحديث فقط إذا كان هناك رسائل غير مقروءة
          if (unreadCount > 0) {
            return FloatingActionButton(
              onPressed: () async {
                // تعليم جميع المحادثات كمقروءة
                final markedChats = await _chatService.markAllChatsAsRead();
                
                if (markedChats > 0 && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث حالة القراءة لـ $markedChats محادثات'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              backgroundColor: Colors.purple,
              child: const Icon(Icons.mark_chat_read),
              tooltip: 'تعليم الكل كمقروء',
            );
          }
          
          return const SizedBox.shrink(); // عدم إظهار أي زر إذا لم تكن هناك رسائل غير مقروءة
        },
      ),
    );
  }  Widget _buildChatItem(Chat chat) {
    // دالة مساعدة لتنسيق وقت آخر رسالة
    String formatLastMessageTime(DateTime time) {
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays > 7) {
        // إذا كان أكثر من أسبوع، نعرض التاريخ فقط
        return DateFormat.yMd('ar').format(time);
      } else {
        // خلال الأسبوع الأخير، استخدم صيغة "منذ..."
        return timeago.format(time, locale: 'ar');
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              otherUserId: chat.otherUserId,
              otherUserName: chat.otherUserName,
              serviceId: chat.serviceId,
              serviceTitle: chat.serviceTitle,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            // صورة المستخدم
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                image:
                    chat.otherUserImage != null
                        ? DecorationImage(
                          image: NetworkImage(chat.otherUserImage!),
                          fit: BoxFit.cover,
                        )
                        : null,
              ),
              child:
                  chat.otherUserImage == null
                      ? Icon(Icons.person, size: 36, color: Colors.grey[400])
                      : null,
            ),
            const SizedBox(width: 12),

            // معلومات المحادثة
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم المستخدم وزمن آخر رسالة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.otherUserName,
                        style: TextStyle(
                          fontWeight:
                              chat.hasUnreadMessages
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatLastMessageTime(chat.lastMessageTime),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // آخر رسالة وعلامة الرسائل غير المقروءة
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? 'بدء محادثة جديدة'
                              : chat.lastMessage,
                          style: TextStyle(
                            color:
                                chat.hasUnreadMessages
                                    ? Colors.black
                                    : Colors.grey[600],
                            fontWeight:
                                chat.hasUnreadMessages
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.hasUnreadMessages)
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.purple,
                          ),
                        ),
                    ],
                  ),

                  // عنوان الخدمة إذا كان متوفراً
                  if (chat.serviceTitle != null &&
                      chat.serviceTitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'بخصوص: ${chat.serviceTitle}',
                        style: TextStyle(
                          color: Colors.purple[300],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
