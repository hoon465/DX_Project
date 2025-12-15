import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _userId = 'user_001'; // 사용자 ID (나중에 실제 사용자 ID로 변경 가능)
  // Firestore 경로: chat_rooms/room_{userId}/messages (Python 서버와 Spring Boot가 사용하는 경로)
  String _roomId = 'room_user_001'; // 채팅방 ID: room_user_001 형식 (state 변수로 변경)
  final String _chatRoomsCollection = 'chat_rooms';
  final String _messagesSubcollection = 'messages';
  bool _isSending = false; // 전송 중 플래그 (중복 전송 방지)
  String? _lastSentMessage; // 마지막 전송한 메시지 (중복 방지)
  DateTime? _lastSentTime; // 마지막 전송 시간
  String? _pendingUserMessage; // 전송 중인 사용자 메시지 (즉시 표시용)
  bool _isMenuOpen = false; // 메뉴 열림/닫힘 상태

  @override
  void initState() {
    super.initState();
    print('🚀 [ChatScreen] initState 호출됨');
    print('🚀 [ChatScreen] userId: $_userId, roomId: $_roomId');
    print('🚀 [ChatScreen] Firestore 경로: $_chatRoomsCollection/$_roomId/$_messagesSubcollection');
    
    // 화면 진입 시 새 room 생성 및 초기화
    _initializeNewRoom();
    
    // 화면이 로드되면 자동으로 키보드가 올라오도록
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFieldFocusNode.requestFocus();
      print('🚀 [ChatScreen] 포커스 요청 완료');
    });
  }
  
  // 기존 room 중 가장 높은 번호 찾아서 참조 (화면 진입 시 호출)
  Future<void> _initializeNewRoom() async {
    try {
      print('🔄 [ChatScreen] 기존 room 중 가장 높은 번호 찾기 시작');
      
      // 1. chat_rooms 컬렉션에서 room_user_로 시작하는 모든 문서 조회
      final roomsSnapshot = await _firestore
          .collection(_chatRoomsCollection)
          .get();
      
      print('📋 [ChatScreen] 전체 rooms 조회 완료: ${roomsSnapshot.docs.length}개');
      
      // 2. room_user_로 시작하는 문서들 중에서 숫자 부분 추출하여 가장 높은 번호 찾기
      int maxNumber = 0;
      String? maxRoomId;
      final roomUserPattern = RegExp(r'^room_user_(\d+)$');
      
      for (var doc in roomsSnapshot.docs) {
        final roomId = doc.id;
        final match = roomUserPattern.firstMatch(roomId);
        if (match != null) {
          final number = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (number > maxNumber) {
            maxNumber = number;
            maxRoomId = roomId;
          }
          print('📋 [ChatScreen] room 발견: $roomId (숫자: $number)');
        }
      }
      
      // 3. 가장 높은 번호의 room_id 사용 (room이 없으면 기본값 사용)
      final targetRoomId = maxRoomId ?? 'room_user_001';
      
      print('✅ [ChatScreen] 가장 높은 번호의 room_id 선택: $targetRoomId (최대값: $maxNumber)');
      
      // 4. _roomId 업데이트 및 화면 새로고침
      // _isSending 상태를 보존하기 위해 현재 상태를 저장
      final currentIsSending = _isSending;
      if (mounted) {
        setState(() {
          _roomId = targetRoomId;
          _isSending = currentIsSending; // 현재 상태 유지 (false면 false, true면 true)
          _pendingUserMessage = null;
          _lastSentMessage = null;
          _lastSentTime = null;
        });
        print('✅ [ChatScreen] room 초기화 완료: $_roomId (isSending 유지: $_isSending)');
      }
      
      print('✅ [ChatScreen] room 초기화 완료: $_roomId');
      print('✅ [ChatScreen] Firestore 경로: $_chatRoomsCollection/$_roomId/$_messagesSubcollection');
      
    } catch (e) {
      print('❌ [ChatScreen] room 초기화 실패: $e');
      // 초기화 실패 시 기본값 유지
      print('⚠️ [ChatScreen] 기본 room_id 사용: $_roomId');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // 메시지 전송
  Future<void> _sendMessage() async {
    print('🔵 [Flutter] _sendMessage 함수 호출됨!');
    final text = _messageController.text.trim();
    print('🔵 [Flutter] 입력된 텍스트: "$text" (길이: ${text.length})');
    if (text.isEmpty) {
      print('⚠️ [Flutter] 텍스트가 비어있어서 전송하지 않습니다.');
      return;
    }

    // 중복 전송 방지 1: 이미 전송 중인 경우
    if (_isSending) {
      print('⚠️ 이미 전송 중입니다. 중복 전송을 방지합니다.');
      return;
    }

    // 중복 전송 방지 2: 같은 메시지가 짧은 시간 내에 다시 전송되는 경우
    final now = DateTime.now();
    if (_lastSentMessage == text && 
        _lastSentTime != null && 
        now.difference(_lastSentTime!).inMilliseconds < 2000) {
      print('⚠️ 같은 메시지가 너무 빨리 전송되었습니다. 중복 전송을 방지합니다.');
      return;
    }

    // 입력 필드 즉시 초기화 (사용자 경험 개선)
    _messageController.clear();
    
    // 전송 시작 및 즉시 UI에 표시
    setState(() {
      _isSending = true;
      _pendingUserMessage = text; // 즉시 표시할 메시지 저장
    });
    print('🔄 [Flutter] _isSending = true 설정 완료');

    // 스크롤을 맨 아래로 (메시지가 표시되기 전에)
    _scrollToBottom();

    try {
      // 마지막 전송 정보 저장
      _lastSentMessage = text;
      _lastSentTime = DateTime.now();

      print('📤 [Flutter] 메시지 전송 시작 - userId: $_userId, roomId: $_roomId');
      print('📤 [Flutter] 메시지 내용: $text');

      // 1. 사용자 메시지를 즉시 Firebase에 저장 (Optimistic Update)
      // Python 서버와 동일한 경로: chat_rooms/room_user_001/messages
      print('💾 [Flutter] Firebase 저장 시작 - roomId: $_roomId');
      print('💾 [Flutter] 저장 경로: $_chatRoomsCollection/$_roomId/$_messagesSubcollection');
      
      try {
        // room 문서가 존재하는지 확인하고 없으면 생성
        final roomRef = _firestore.collection(_chatRoomsCollection).doc(_roomId);
        final roomDoc = await roomRef.get();
        if (!roomDoc.exists) {
          print('📝 [Flutter] room 문서가 없어서 생성합니다: $_roomId');
          await roomRef.set({
            'user_id': _userId,
            'created_at': FieldValue.serverTimestamp(),
            'last_message_at': FieldValue.serverTimestamp(),
          });
          print('✅ [Flutter] room 문서 생성 완료');
        }
        
        final userMessageRef = _firestore
            .collection(_chatRoomsCollection)
            .doc(_roomId)
            .collection(_messagesSubcollection)
            .doc();
        
        // timestamp를 "2025-12-07 00:43:59" 형식으로 포맷
        final now = DateTime.now().toLocal();
        final formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        
        final userMessageData = {
          'text': text,
          'sender': 'user',
          'message_type': 'chat',
          'timestamp': formattedTimestamp,
        };
        
        print('💾 [Flutter] 저장할 데이터: $userMessageData');
        await userMessageRef.set(userMessageData);
        print('✅ [Flutter] 사용자 메시지를 Firebase에 저장 완료 - 문서 ID: ${userMessageRef.id}');
        print('✅ [Flutter] 저장 경로: $_chatRoomsCollection/$_roomId/$_messagesSubcollection/${userMessageRef.id}');
        
        // room 문서의 last_message_at 업데이트
        await roomRef.update({
          'last_message_at': FieldValue.serverTimestamp(),
        });
        
        // Firebase 저장 완료 후 즉시 _pendingUserMessage 제거 (중복 표시 방지)
        // StreamBuilder가 Firebase에서 메시지를 받아서 표시할 것이므로
        // 하지만 _isSending은 명시적으로 true로 유지 (AI 답변을 기다리는 중이므로)
        if (mounted) {
          setState(() {
            _pendingUserMessage = null;
            _isSending = true; // 명시적으로 true로 유지 (로딩 인디케이터 표시)
          });
          print('✅ [Flutter] _pendingUserMessage 제거 완료 (Firebase 저장 완료)');
          print('⏳ [Flutter] _isSending = true 명시적으로 유지 (AI 답변 대기 중)');
        }
      } catch (firebaseError) {
        print('❌ [Flutter] Firebase 저장 실패: $firebaseError');
        print('❌ [Flutter] 에러 타입: ${firebaseError.runtimeType}');
        print('❌ [Flutter] 에러 상세: ${firebaseError.toString()}');
        // Firebase 저장 실패해도 백엔드로 전송은 계속 진행 (백엔드에서 저장할 수 있음)
        print('⚠️ [Flutter] Firebase 저장 실패했지만 백엔드로 전송 계속 진행');
        // 저장 실패 시에도 _pendingUserMessage는 유지 (백엔드에서 저장될 때까지 표시)
      }

      // 2. Spring Boot 서버로 메시지 전송 (백엔드가 AI 답변을 생성하고 Firebase에 저장함)
      // 프론트엔드에서는 AI 답변을 저장하지 않음 (백엔드가 저장하는 것을 기다림)
      print('📤 [Flutter] 서버로 메시지 전송 시작 (현재 _isSending: $_isSending)');
      await ApiService.sendMessage(_userId, text, sessionId: _roomId, source: 'chat');

      print('✅ [Flutter] 서버로 메시지 전송 완료');
      print('⏳ [Flutter] 백엔드에서 AI 답변을 생성하고 Firebase에 저장 중...');
      print('⏳ [Flutter] 현재 _isSending 상태: $_isSending (true여야 함)');
      
      // _isSending이 여전히 true인지 확인하고 강제로 유지
      if (!_isSending) {
        print('⚠️ [Flutter] 경고: _isSending이 false로 바뀌었습니다! 다시 true로 설정합니다.');
        if (mounted) {
          setState(() {
            _isSending = true;
          });
          print('✅ [Flutter] _isSending을 true로 재설정 완료');
        }
      } else {
        print('✅ [Flutter] _isSending이 true로 유지됨 - 로딩 인디케이터 표시 예정');
      }

      // AI 답변은 백엔드가 Firebase에 저장하므로, 여기서는 저장하지 않음
      // StreamBuilder가 Firebase 변경을 감지하여 자동으로 표시함
      // 로딩 상태는 AI 답변이 Firebase에 저장되면 자동으로 해제됨 (아래 로직 참고)
    } catch (e) {
      print('❌ [Flutter] 메시지 전송 실패: $e');
      print('❌ [Flutter] 에러 상세: ${e.toString()}');
      // 에러 발생 시 사용자에게 알림 및 전송 중인 메시지 제거
      if (mounted) {
        setState(() {
          _isSending = false;
          _pendingUserMessage = null; // 전송 실패 시 임시 메시지 제거
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('메시지 전송 실패: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    // 성공 시에는 _isSending을 false로 만들지 않음
    // AI 답변이 Firestore에 저장될 때까지 로딩 상태 유지
  }

    // 스크롤을 맨 아래로 이동
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 메시지 스트림 빌더 (orderBy 없이 읽고 클라이언트에서 정렬)
  Widget _buildMessagesStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(_chatRoomsCollection)
          .doc(_roomId)
          .collection(_messagesSubcollection)
          .snapshots(),
      builder: (context, snapshot) {
        // 디버깅 로그
        print('📡 [Firestore] StreamBuilder 상태: ${snapshot.connectionState}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ [Firestore] 데이터 로딩 중...');
        } else if (snapshot.connectionState == ConnectionState.active) {
          print('📡 [Firestore] 스트림 활성화 - roomId: $_roomId');
          if (snapshot.hasData) {
            print('📡 [Firestore] 메시지 개수: ${snapshot.data!.docs.length}');
            for (var doc in snapshot.data!.docs) {
              print('📡 [Firestore] 메시지 ID: ${doc.id}, 데이터: ${doc.data()}');
            }
          } else {
            print('📡 [Firestore] 데이터 없음 (hasData: false)');
          }
        }
        
        // 에러가 발생해도 화면을 깨뜨리지 않고 계속 진행
        // 일시적인 에러는 무시하고 기존 메시지나 빈 화면 표시
        if (snapshot.hasError) {
          print('⚠️ [Firestore] 읽기 오류 (무시하고 계속 진행): ${snapshot.error}');
          print('⚠️ [Firestore] 경로: $_chatRoomsCollection/$_roomId/$_messagesSubcollection');
          
          // 에러가 발생했지만 기존 데이터가 있으면 계속 표시
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            print('✅ [Firestore] 기존 데이터가 있으므로 계속 표시');
            // 아래 코드로 계속 진행
          } else {
            // 데이터가 없으면 빈 화면 표시 (에러 화면 대신)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
            return const Center(
              child: Text(
                '메시지를 입력해주세요',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            );
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              '메시지를 입력해주세요',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          );
        }

        // ChatMessage.fromFirestore 사용 (더 안전한 파싱)
        // 중복 제거: 문서 ID를 키로 사용하여 같은 문서는 하나만 파싱
        Map<String, ChatMessage> messageMap = {}; // 문서 ID -> 메시지
        final messages = snapshot.data!.docs
            .map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final message = ChatMessage.fromFirestore(data);
                
                // 같은 문서 ID로 이미 파싱했으면 스킵 (중복 방지)
                if (!messageMap.containsKey(doc.id)) {
                  messageMap[doc.id] = message;
                  return message;
                } else {
                  print('⚠️ [ChatScreen] 같은 문서 ID 중복 제거: ${doc.id}');
                  return null;
                }
              } catch (e) {
                print('❌ [ChatScreen] 메시지 파싱 오류: $e, 데이터: ${doc.data()}');
                return null;
              }
            })
            .where((msg) => msg != null)
            .cast<ChatMessage>()
            .toList();
        
        // 클라이언트에서 timestamp 기준으로 정렬
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // sender가 'user' 또는 'ai'인 경우만 필터링
        List<ChatMessage> filteredMessages = [];
        for (var message in messages) {
          // sender가 'user' 또는 'ai'인 경우만 표시
          if (message.sender != 'user' && message.sender != 'ai') {
            print('⚠️ [ChatScreen] 알 수 없는 sender 무시: ${message.sender}');
            continue;
          }
          
          // 텍스트가 비어있으면 무시
          if (message.text.trim().isEmpty) {
            print('⚠️ [ChatScreen] 빈 텍스트 메시지 무시');
            continue;
          }
          
          filteredMessages.add(message);
        }

        // 전송 중인 사용자 메시지가 있고, Firestore에 아직 저장되지 않았다면 추가
        // Firebase에서 같은 텍스트의 메시지가 이미 있으면 _pendingUserMessage는 추가하지 않음 (중복 방지)
        List<ChatMessage> displayMessages = List.from(filteredMessages);
        if (_pendingUserMessage != null) {
          // Firebase 메시지 목록에 같은 텍스트의 사용자 메시지가 있는지 확인
          final isInFirebase = filteredMessages.any((m) => 
            m.sender == 'user' && 
            m.text.trim() == _pendingUserMessage!.trim()
          );
          
          if (!isInFirebase) {
            // Firebase에 아직 없으면 임시 메시지로 표시
            displayMessages.add(ChatMessage(
              sender: 'user',
              text: _pendingUserMessage!,
              timestamp: DateTime.now(),
            ));
            print('📝 [ChatScreen] _pendingUserMessage 추가 (Firebase에 아직 없음): $_pendingUserMessage');
          } else {
            // Firebase에 이미 있으면 _pendingUserMessage 제거 (중복 방지)
            // 빌드 중에는 setState()를 호출할 수 없으므로 addPostFrameCallback 사용
            print('✅ [ChatScreen] _pendingUserMessage 제거 (Firebase에 이미 있음): $_pendingUserMessage');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _pendingUserMessage = null;
                });
              }
            });
          }
        }
        
        // AI 답변이 Firestore에 저장되었는지 확인 (로딩 상태 해제)
        // _isSending이 false이면 이미 로딩이 완료된 상태이므로 체크하지 않음
        if (_isSending) {
          print('⏳ [ChatScreen] AI 답변 대기 중... (filteredMessages: ${filteredMessages.length})');
          // 마지막 메시지가 AI 답변인지 확인 (sender가 'ai'인지만 체크)
          bool aiResponseReceived = false;
          if (filteredMessages.isNotEmpty) {
            final lastMessage = filteredMessages.last;
            print('📝 [ChatScreen] 마지막 메시지 확인 - sender: ${lastMessage.sender}, text: ${lastMessage.text.substring(0, lastMessage.text.length > 30 ? 30 : lastMessage.text.length)}...');
            // sender가 'ai'이면 AI 답변으로 간주
            if (lastMessage.sender == 'ai') {
              aiResponseReceived = true;
              print('✅ [ChatScreen] AI 답변 수신 확인 (sender: ai) - 로딩 상태 해제');
            }
          }
          
          // AI 답변을 받았으면 로딩 상태 해제
          if (aiResponseReceived) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                print('🔄 [ChatScreen] 로딩 상태 해제 중...');
                setState(() {
                  _isSending = false;
                  _pendingUserMessage = null;
                });
                print('✅ [ChatScreen] 로딩 상태 해제 완료');
              }
            });
          } else {
            print('⏳ [ChatScreen] 아직 AI 답변 없음 - 로딩 인디케이터 계속 표시');
          }
        } else {
          print('ℹ️ [ChatScreen] _isSending이 false - 로딩 상태가 아님');
        }

        // 메시지 로드 후 스크롤
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        // 로딩 상태 디버깅
        final shouldShowLoading = _isSending;
        final itemCount = displayMessages.length + (shouldShowLoading ? 1 : 0);
        print('📊 [ChatScreen] 로딩 상태 - _isSending: $_isSending, displayMessages: ${displayMessages.length}, itemCount: $itemCount, shouldShowLoading: $shouldShowLoading');
        
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // 로딩 인디케이터
            if (shouldShowLoading && index == displayMessages.length) {
              print('🔄 [ChatScreen] 로딩 인디케이터 표시 (index: $index, total: $itemCount, shouldShowLoading: $shouldShowLoading)');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/로고.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFF6F42EE),
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6F42EE)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            
            final message = displayMessages[index];
            final isUser = message.sender == 'user';

            if (isUser) {
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12, left: 50),
                  padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAEAEB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      height: 1.5,
                      letterSpacing: 0.011,
                    ),
                  ),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/로고.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 40,
                              height: 40,
                              color: const Color(0xFF6F42EE),
                              child: const Icon(
                                Icons.smart_toy,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F2FD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            height: 1.5,
                            letterSpacing: 0.011,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true, // 키보드가 올라올 때 화면 크기 조정
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(57),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFEAEAEB),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
              child: Row(
                children: [
                  // 뒤로가기 버튼
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  // ELLI 타이틀
                  const Text(
                    'ELLI',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  // 오른쪽 아이콘들 (Figma 디자인: interface-dashboard, play-list, menu)
                  Row(
                    children: [
                      // chat_room3 아이콘 (대시보드/레이아웃)
                      GestureDetector(
                        onTap: () {
                          // 대시보드 아이콘 클릭 이벤트 (필요시 구현)
                        },
                        child: SvgPicture.asset(
                          'assets/images/chat_room3.svg',
                          width: 21,
                          height: 21,
                        ),
                      ),
                      const SizedBox(width: 15),
                      // chat_room1 아이콘 (비디오/재생)
                      GestureDetector(
                        onTap: () {
                          // 비디오 아이콘 클릭 이벤트 (필요시 구현)
                        },
                        child: SvgPicture.asset(
                          'assets/images/chat_room1.svg',
                          width: 21,
                          height: 21,
                        ),
                      ),
                      const SizedBox(width: 15),
                      // chat_room2 아이콘 (메뉴)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isMenuOpen = true; // 메뉴 열기
                          });
                        },
                        child: SvgPicture.asset(
                          'assets/images/chat_room2.svg',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 채팅 메시지 영역
              Expanded(
                child: _buildMessagesStream(),
              ),
              // 입력 영역 (Figma 디자인)
              Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 13, 10, 13),
                child: InkWell(
                  onTap: () {
                    // 하단바 클릭 시 TextField에 포커스를 주어 키보드가 올라오도록
                    _textFieldFocusNode.requestFocus();
                    // 키보드가 확실히 올라오도록 약간의 지연 후 다시 포커스
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _textFieldFocusNode.requestFocus();
                    });
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F2FD), // 연한 보라색 배경
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        // 카메라 아이콘
                        Padding(
                          padding: const EdgeInsets.only(left: 16.18, right: 8),
                          child: GestureDetector(
                            onTap: () {
                              // 카메라 기능 (나중에 구현)
                            },
                            child: Container(
                              width: 35,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6F42EE), // 보라색 원형 배경
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        // 텍스트 입력 필드
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _textFieldFocusNode,
                            readOnly: false, // 읽기 전용 아님
                            enabled: true, // 활성화됨
                            decoration: const InputDecoration(
                              hintText: '메시지 입력...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9A9A9A),
                                fontSize: 11,
                                letterSpacing: 0.011,
                                height: 1.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 14,
                              ),
                              isDense: true,
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black,
                              height: 1.5,
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            keyboardType: TextInputType.text, // 텍스트 키보드 명시
                            onSubmitted: (value) {
                              print('🔵 [Flutter] 키보드 전송 버튼 클릭됨');
                              // 키보드 전송 버튼 클릭 시에도 중복 방지 로직이 적용됨
                              _sendMessage();
                            },
                            onTap: () {
                              // TextField 직접 클릭 시에도 포커스
                              _textFieldFocusNode.requestFocus();
                            },
                          ),
                        ),
                        // 전송 버튼 (보라색 종이비행기 아이콘)
                        Padding(
                          padding: const EdgeInsets.only(right: 16.06),
                          child: GestureDetector(
                            onTap: _isSending 
                                ? () {
                                    print('⚠️ [Flutter] 이미 전송 중이라서 버튼 클릭 무시');
                                  }
                                : () {
                                    print('🔵 [Flutter] 전송 버튼 클릭됨!');
                                    _sendMessage();
                                  },
                            child: _isSending
                                ? const SizedBox(
                                    width: 16.485,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6F42EE)),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    color: Color(0xFF6F42EE), // 보라색
                                    size: 16.485,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
          // 사이드 메뉴 (메뉴 아이콘 클릭 시 표시)
          if (_isMenuOpen) _buildSideMenu(context),
        ],
      ),
    );
  }

  // 사이드 메뉴 빌더
  Widget _buildSideMenu(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final scale = screenWidth / 360; // Figma 기준 360px

    return Stack(
      children: [
        // 어두운 오버레이 (화면 전체)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMenuOpen = false; // 메뉴 닫기
              });
            },
            child: Container(
              color: const Color.fromRGBO(0, 0, 0, 0.28),
            ),
          ),
        ),
        // 오른쪽 사이드 패널
        Positioned(
          left: 82 * scale,
          top: 24 * scale,
          bottom: 0,
          width: 278 * scale,
          child: GestureDetector(
            onTap: () {
              // 패널 내부 클릭은 메뉴를 닫지 않음
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(19 * scale),
                  bottomLeft: Radius.circular(19 * scale),
                ),
              ),
              child: _buildMenuContent(context, scale, screenWidth),
            ),
          ),
        ),
      ],
    );
  }

  // 메뉴 내용 빌더
  Widget _buildMenuContent(BuildContext context, double scale, double screenWidth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 검색 바
          Padding(
            padding: EdgeInsets.only(
              top: 21 * scale,
              left: 17 * scale,
              right: 17 * scale,
            ),
            child: Container(
              height: 36 * scale,
              width: 228 * scale,
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEB),
                borderRadius: BorderRadius.circular(10 * scale),
              ),
              child: Row(
                children: [
                  SizedBox(width: 8 * scale),
                  Icon(Icons.search, size: 17 * scale, color: const Color(0xFF9A9A9A)),
                  SizedBox(width: 8 * scale),
                  Text(
                    '검색',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9A9A9A),
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 아이콘들 (설정, 고객 센터, 채팅 나가기)
          Padding(
            padding: EdgeInsets.only(
              top: 32 * scale,
              left: 15 * scale,
              right: 15 * scale,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMenuIcon(scale, 'assets/images/Group 1686558373.svg', '설정'),
                _buildMenuIcon(scale, 'assets/images/Group 1686558371.svg', '고객 센터'),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isMenuOpen = false; // 메뉴 닫기
                    });
                    _showExitChatDialog(context); // 채팅 나가기 다이얼로그 표시
                  },
                  child: _buildMenuIcon(scale, 'assets/images/Exit.svg', '채팅 나가기'),
                ),
              ],
            ),
          ),
          // 대화 목록 제목
          Padding(
            padding: EdgeInsets.only(
              top: 66 * scale,
              left: 17 * scale,
              bottom: 8 * scale,
            ),
            child: Text(
              '대화 목록',
              style: TextStyle(
                fontFamily: 'Noto Sans',
                fontSize: 15 * scale,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF565656),
                letterSpacing: 0.2 * scale,
              ),
            ),
          ),
          // 대화 목록 항목들
          _buildConversationItem(scale, '세탁기 UE 오류 코드 해결', '12.12 금 오전 01:30', 'assets/images/Group 1686558395.svg'),
          _buildConversationItem(scale, '세탁 중 소음 발생 확인', '12.08 월 오후 10:12', 'assets/images/Group 1686558396.svg'),
          _buildConversationItem(scale, '니트류 세제 질문', '12.08 월 오후 10:04', 'assets/images/Group 1686558395.svg'),
          _buildConversationItem(scale, '세탁물 양에 맞는 세제 양 질문', '12.01 월 오후 01:30', 'assets/images/Group 1686558394.svg'),
          _buildConversationItem(scale, '세탁기 아기 옷 세탁 기능 추천', '11.28 금 오후 04:30', 'assets/images/Group 1686558396.svg'),
          _buildConversationItem(scale, '세탁기 관리제 구매 시기 알림', '11.01 토 오후 09:15', 'assets/images/Group 1686558394.svg'),
          _buildConversationItem(scale, '세탁기 첫 사용 방법', '11.01 토 오후 09:15', 'assets/images/Group 1686558394.svg'),
        ],
      ),
    );
  }

  // 메뉴 아이콘 빌더
  Widget _buildMenuIcon(double scale, String svgPath, String label) {
    return Column(
      children: [
        SvgPicture.asset(
          svgPath,
          width: 59 * scale,
          height: 59 * scale,
        ),
        SizedBox(height: 8 * scale),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Noto Sans',
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF696A6F),
            letterSpacing: 0.2 * scale,
          ),
        ),
      ],
    );
  }

  // 대화 목록 항목 빌더
  Widget _buildConversationItem(double scale, String title, String timestamp, String svgPath) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMenuOpen = false; // 항목 클릭 시 메뉴 닫기
        });
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 17 * scale, vertical: 4 * scale),
        padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFF0EDFB),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(10 * scale),
            bottomLeft: Radius.circular(10 * scale),
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            SvgPicture.asset(
              svgPath,
              width: 40 * scale,
              height: 40 * scale,
            ),
            SizedBox(width: 8 * scale),
            // 제목과 타임스탬프
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    timestamp,
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
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

  // 채팅 나가기 확인 다이얼로그
  void _showExitChatDialog(BuildContext context) {
    final parentContext = context; // 외부 context 저장
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28), // 어두운 오버레이
      builder: (BuildContext dialogContext) {
        final mediaQuery = MediaQuery.of(dialogContext);
        final screenWidth = mediaQuery.size.width;
        final scale = screenWidth / 360; // Figma 기준 360px

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 30 * scale),
          child: Container(
            width: 300 * scale,
            height: 184 * scale,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.22 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4 * scale,
                  offset: Offset(0, 4 * scale),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 제목
                Padding(
                  padding: EdgeInsets.only(bottom: 8 * scale),
                  child: Text(
                    '채팅을 삭제하시겠어요?',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ),
                // 메시지
                Padding(
                  padding: EdgeInsets.only(bottom: 20 * scale),
                  child: Text(
                    '나가기한 채팅은 복구가 불가능합니다.',
                    style: TextStyle(
                      fontFamily: 'Noto Sans',
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFA8A8A8),
                      letterSpacing: 0.2 * scale,
                    ),
                  ),
                ),
                // 버튼들
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 삭제 버튼 (빨간색)
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); // 다이얼로그 닫기
                        
                        // 백엔드에 삭제 요청 (room+1 생성 트리거)
                        // 방법 1: API 호출 시도
                        try {
                          print('🗑️ [ChatScreen] 채팅방 삭제 요청 - roomId: $_roomId');
                          await ApiService.deleteChatRoom(_userId, _roomId);
                          print('✅ [ChatScreen] 백엔드 삭제 요청 완료 - room+1 생성됨');
                        } catch (e) {
                          print('⚠️ [ChatScreen] API 삭제 요청 실패, Firestore로 트리거 시도: $e');
                          
                          // 방법 2: Firestore에 삭제 플래그 설정 (백엔드가 Firestore 리스너 사용 시)
                          try {
                            await _firestore
                                .collection(_chatRoomsCollection)
                                .doc(_roomId)
                                .update({
                                  'deleted': true,
                                  'deletedAt': FieldValue.serverTimestamp(),
                                  'userId': _userId,
                                });
                            print('✅ [ChatScreen] Firestore 삭제 플래그 설정 완료 - 백엔드가 room+1 생성할 것임');
                          } catch (firestoreError) {
                            print('❌ [ChatScreen] Firestore 업데이트 실패: $firestoreError');
                          }
                        }
                        
                        // 화면 뒤로 가기
                        if (Navigator.canPop(parentContext)) {
                          Navigator.pop(parentContext);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF0004),
                        padding: EdgeInsets.symmetric(
                          horizontal: 31 * scale,
                          vertical: 12 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40 * scale),
                        ),
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.13),
                      ),
                      child: Text(
                        '삭제',
                        style: TextStyle(
                          fontFamily: 'Noto Sans',
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: -0.8 * scale,
                        ),
                      ),
                    ),
                    SizedBox(width: 9 * scale),
                    // 취소 버튼 (회색)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext); // 다이얼로그만 닫기 (채팅 화면은 유지)
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEAEAEB),
                        padding: EdgeInsets.symmetric(
                          horizontal: 31 * scale,
                          vertical: 12 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40 * scale),
                        ),
                        elevation: 3,
                        shadowColor: Colors.black.withValues(alpha: 0.13),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontFamily: 'Noto Sans',
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF696A6F),
                          letterSpacing: -0.8 * scale,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
