import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String sender;      // 'user' 또는 'ai'
  final String text;        // 대화 내용
  final DateTime timestamp; // 시간
  final String? source;     // 메시지 출처: 'chat' (채팅), 'live' (라이브), null (기본값)

  ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.source,
  });

  // 파이어베이스 문서(Document)를 자바스크립트 객체처럼 변환
  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    // sender 필드 직접 사용 ('user' 또는 'ai')
    String sender = '';
    
    // 1. sender 필드가 있으면 우선 사용
    if (data['sender'] != null) {
      sender = data['sender'].toString().trim();
      // gemini는 ai로 변환
      if (sender == 'gemini') {
        sender = 'ai';
      }
    }
    
    // 2. sender가 'user' 또는 'ai'가 아니면 message_type으로 변환 시도
    if (sender != 'user' && sender != 'ai') {
      if (data['message_type'] != null) {
        final messageType = data['message_type'].toString();
        if (messageType == 'chat_bot' || messageType == 'ai' || messageType == 'assistant' || messageType == 'gemini') {
          sender = 'ai';
        } else if (messageType == 'user' || messageType == 'chat') {
          // message_type이 'user' 또는 'chat'이면 사용자 메시지
          sender = 'user';
        } else if (messageType == 'live') {
          // message_type이 'live'인 경우 sender 필드를 다시 확인
          if (data['sender'] != null) {
            final liveSender = data['sender'].toString().trim();
            if (liveSender == 'gemini') {
              sender = 'ai';
            } else if (liveSender == 'user' || liveSender.isEmpty) {
              sender = 'user';
            } else {
              sender = liveSender; // 다른 값이면 그대로 사용
            }
          } else {
            sender = 'user'; // sender가 없으면 기본적으로 user
          }
        }
      }
    }
    
    // 3. 최종적으로 'user' 또는 'ai'가 아니면 기본값 설정
    if (sender != 'user' && sender != 'ai') {
      // sender 필드가 있으면 그대로 사용
      if (data['sender'] != null && data['sender'].toString().trim().isNotEmpty) {
        sender = data['sender'].toString().trim();
        // gemini는 ai로 변환
        if (sender == 'gemini') {
          sender = 'ai';
        }
      } else {
        // sender 필드가 없으면 message_type 기반으로 추정
        if (data['message_type'] == 'chat') {
          sender = 'user'; // chat 타입은 기본적으로 사용자 메시지
        } else {
          sender = 'unknown';
        }
      }
    }
    
    // text 필드만 사용 (content 필드는 사용하지 않음)
    final text = data['text'] ?? '';
    
    // timestamp 필드 처리 (여러 형식 지원)
    DateTime timestamp = DateTime.now();
    if (data['timestamp'] != null) {
      if (data['timestamp'] is Timestamp) {
        // Firestore Timestamp 타입
        timestamp = (data['timestamp'] as Timestamp).toDate();
      } else if (data['timestamp'] is String) {
        try {
          timestamp = DateTime.parse(data['timestamp'] as String);
        } catch (e) {
          print('⚠️ [ChatMessage] timestamp 파싱 실패: ${data['timestamp']}');
        }
      }
    } else if (data['created_at'] != null) {
      // timestamp가 없고 created_at만 있는 경우
      if (data['created_at'] is Timestamp) {
        timestamp = (data['created_at'] as Timestamp).toDate();
      } else if (data['created_at'] is int) {
        // 밀리초 타임스탬프
        timestamp = DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int);
      }
    }
    
    return ChatMessage(
      sender: sender,
      text: text,
      timestamp: timestamp,
      source: data['source'], // 'chat' 또는 'live'
    );
  }
}