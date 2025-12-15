import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // ⚠️ [중요] 안드로이드 에뮬레이터에서는 localhost 대신 '10.0.2.2'를 써야 합니다.
  // (실제 폰이라면 컴퓨터 IP주소 ex: 192.168.0.27, 172.20.10.4, 192.168.43.100 등)
  // 실제 Android 기기 사용 시 아래 USE_REAL_DEVICE를 true로 변경하세요
  // 🔥 핫스팟 연결 시: PC IP 주소를 ipconfig로 확인 후 아래 IP를 변경하세요!
  static const bool USE_REAL_DEVICE = true; // 실제 기기 사용 시 true, 에뮬레이터 사용 시 false
  static const String REAL_DEVICE_IP = "192.168.0.20"; // PC IP 주소 (ipconfig로 확인)
  // 💡 핫스팟별 IP 대역:
  //    - iPhone 핫스팟: 172.20.10.x
  //    - Android 핫스팟: 192.168.43.x 또는 192.168.137.x
  //    - 일반 Wi-Fi: 192.168.0.x 또는 192.168.1.x
  
  static String get baseUrl {
    if (Platform.isAndroid) {
      if (USE_REAL_DEVICE) {
        // 실제 Android 기기 사용 시
        return "http://$REAL_DEVICE_IP:9090/api/chatbot/ask";
      } else {
        // Android 에뮬레이터 사용 시
        return "http://10.0.2.2:9090/api/chatbot/ask";
      }
    }
    // iOS 시뮬레이터나 다른 플랫폼
    return "http://localhost:9090/api/chatbot/ask";
  }

  // 서버 base URL (ask 엔드포인트 제외)
  static String get serverBaseUrl {
    if (Platform.isAndroid) {
      if (USE_REAL_DEVICE) {
        return "http://$REAL_DEVICE_IP:9090";
      } else {
        return "http://10.0.2.2:9090";
      }
    }
    return "http://localhost:9090";
  }

  // AI 답변 응답 모델
  static Future<String?> sendMessage(String userId, String message, {String? sessionId, String? source}) async {
    try {
      print("📤 [API] 질문 전송 시작");
      print("📤 [API] URL: $baseUrl");
      print("📤 [API] userId: $userId, message: $message, sessionId: $sessionId, source: $source");
      
      // 타임아웃 설정 (60초 = 1분)
      final client = http.Client();
      final requestBody = {
        "userId": userId,
        "message": message,
      };
      
      // 세션 ID가 있으면 추가
      if (sessionId != null) {
        requestBody["sessionId"] = sessionId;
      }
      
      // 메시지 출처가 있으면 추가 ('chat' 또는 'live')
      if (source != null) {
        requestBody["source"] = source;
      }
      
      final response = await client.post(
        Uri.parse(baseUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          client.close();
          throw Exception("서버 연결 시간 초과 (60초). 서버가 실행 중인지 확인하세요.");
        },
      );

      print("📤 [API] 응답 상태 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final answer = responseBody['answer'] as String?;
        print("✅ [API] 서버 전송 성공");
        print("📝 [API] AI 답변: ${answer ?? '답변 없음'}");
        print("📝 [API] 참고 출처: ${responseBody['sources'] ?? []}");
        return answer; // AI 답변 반환
      } else {
        print("❌ [API] 서버 에러: ${response.statusCode}");
        print("❌ [API] 응답 내용: ${response.body}");
        throw Exception("서버 에러: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ [API] 연결 실패: $e");
      print("❌ [API] 에러 타입: ${e.runtimeType}");
      print("❌ [API] 요청 URL: $baseUrl");
      
      // SocketException인 경우 더 자세한 정보 제공
      if (e is SocketException) {
        print("❌ [API] SocketException 발생 - 서버에 연결할 수 없습니다.");
        print("❌ [API] 가능한 원인:");
        print("   1. 서버가 실행 중이 아닙니다 (포트 8000 확인)");
        print("   2. PC IP 주소가 잘못되었습니다 (현재: $REAL_DEVICE_IP)");
        print("   3. 방화벽이 8000 포트를 차단하고 있습니다");
        print("   4. PC와 폰이 같은 Wi-Fi 네트워크에 연결되어 있지 않습니다");
        throw Exception("서버 연결 실패: $baseUrl에 연결할 수 없습니다. 서버가 실행 중인지, IP 주소가 올바른지 확인하세요.");
      }
      
      rethrow; // 에러를 상위로 전달하여 UI에서 처리할 수 있도록
    }
  }

  // 채팅방 삭제 (백엔드에서 room+1 생성 트리거)
  static Future<void> deleteChatRoom(String userId, String roomId) async {
    try {
      print("🗑️ [API] 채팅방 삭제 요청 시작");
      print("🗑️ [API] userId: $userId, roomId: $roomId");
      
      // 삭제 API 엔드포인트 (백엔드에 맞게 수정 가능)
      final deleteUrl = "$serverBaseUrl/api/chatbot/room/delete";
      print("🗑️ [API] URL: $deleteUrl");
      
      final client = http.Client();
      final requestBody = {
        "userId": userId,
        "roomId": roomId,
      };
      
      final response = await client.post(
        Uri.parse(deleteUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          client.close();
          throw Exception("서버 연결 시간 초과 (30초). 서버가 실행 중인지 확인하세요.");
        },
      );

      print("🗑️ [API] 응답 상태 코드: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        print("✅ [API] 채팅방 삭제 성공 - 백엔드에서 room+1 생성됨");
        final responseBody = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        print("📝 [API] 응답 내용: $responseBody");
      } else {
        print("❌ [API] 서버 에러: ${response.statusCode}");
        print("❌ [API] 응답 내용: ${response.body}");
        throw Exception("서버 에러: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ [API] 채팅방 삭제 실패: $e");
      print("❌ [API] 에러 타입: ${e.runtimeType}");
      
      // SocketException인 경우 더 자세한 정보 제공
      if (e is SocketException) {
        print("❌ [API] SocketException 발생 - 서버에 연결할 수 없습니다.");
        throw Exception("서버 연결 실패: 서버가 실행 중인지 확인하세요.");
      }
      
      rethrow; // 에러를 상위로 전달하여 UI에서 처리할 수 있도록
    }
  }
}