import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class LiveCameraService {
  // 🔥 핫스팟 연결 시: PC IP 주소를 ipconfig로 확인 후 아래 IP를 변경하세요!
  // 💡 핫스팟별 IP 대역:
  //    - iPhone 핫스팟: 172.20.10.x
  //    - Android 핫스팟: 192.168.43.x 또는 192.168.137.x
  //    - 일반 Wi-Fi: 192.168.0.x 또는 192.168.1.x
  static const String REAL_DEVICE_IP = "192.168.0.20"; // PC IP 주소 (ipconfig로 확인)
  static const String WS_URL = "ws://$REAL_DEVICE_IP:8001/ws/chat"; // test.py는 포트 8001 사용
  
  CameraController? _cameraController;
  WebSocketChannel? _channel;
  StreamSubscription? _websocketSubscription;
  Timer? _videoTimer;
  Timer? _audioTimer;
  AudioRecorder? _audioRecorder;
  StreamSubscription? _audioStreamSubscription;
  AudioPlayer? _audioPlayer; // AI 오디오 재생용
  final List<File> _audioQueue = []; // 오디오 재생 큐
  bool _isPlayingAudio = false; // 오디오 재생 중 플래그
  // 공식 예제 패턴: 오디오 청크를 끝까지 이어붙이는 버퍼
  final List<Uint8List> _pendingAudioChunks = [];
  Timer? _audioFlushTimer; // 오디오 버퍼 플러시 타이머
  // 공식 예제 패턴: 현재 턴의 모든 오디오 청크를 누적 (끝까지 받기)
  Uint8List? _currentTurnAudioBuffer; // 현재 턴의 오디오 버퍼
  // 사용자 말하기 감지용 타이머
  Timer? _userSpeechTimer; // 사용자가 말을 멈췄는지 감지
  DateTime? _lastAudioSentTime; // 마지막 오디오 전송 시간
  
  bool _isStreaming = false;
  String? _sessionId;
  String? _roomId; // chat_room ID (room_user_001 형식)
  VoidCallback? _onExitRequested; // 엘리홈으로 이동 콜백
  
  // Firebase에 텍스트 저장 (chat_rooms에 저장)
  Future<void> _saveToFirebase(String sender, String text) async {
    try {
      if (_roomId == null) {
        print("⚠️ [LiveCamera] roomId가 없어 Firebase에 저장할 수 없습니다.");
        return;
      }
      
      // 빈 텍스트 체크
      if (text.isEmpty || text.trim().isEmpty) {
        print("⚠️ [LiveCamera] 빈 텍스트는 저장하지 않습니다.");
        return;
      }
      
      // AI 응답인 경우 영어만 있는 텍스트는 저장하지 않음 (한국어만 저장)
      if (sender == 'gemini') {
        if (_isEnglishOnly(text)) {
          print("⚠️ [LiveCamera] 영어만 포함된 AI 응답은 저장하지 않습니다: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
          return;
        }
        // 한국어가 포함되어 있으면 저장
        if (!_containsKorean(text)) {
          print("⚠️ [LiveCamera] 한국어가 포함되지 않은 AI 응답은 저장하지 않습니다: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
          return;
        }
      }
      
      final timestamp = DateTime.now();
      
      // 타임아웃 설정으로 방화벽 문제 완화
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .add({
        'sender': sender,
        'text': text,
        'message_type': 'live', // 라이브 대화는 모두 'live'로 저장
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': timestamp.millisecondsSinceEpoch,
        'timezone': 'KST',
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Firebase 저장 시간 초과 (방화벽 문제 가능성)');
        },
      );
      
      print("✅ [LiveCamera] Firebase 저장 성공 (chat_rooms/$_roomId/messages) - sender: $sender, text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
    } on TimeoutException catch (e) {
      print("⏱️ [LiveCamera] Firebase 저장 시간 초과: $e");
      print("   방화벽이 Firebase 연결을 차단하고 있을 수 있습니다.");
      print("   Windows 방화벽에서 Firebase 도메인을 허용하거나, 네트워크 설정을 확인하세요.");
    } catch (e) {
      print("❌ [LiveCamera] Firebase 저장 실패: $e");
      // 방화벽 관련 에러 메시지 확인
      if (e.toString().contains('firewall') || 
          e.toString().contains('방화벽') ||
          e.toString().contains('network') ||
          e.toString().contains('unreachable')) {
        print("   🔥 방화벽 문제로 보입니다. 다음을 확인하세요:");
        print("   1. Windows 방화벽에서 Firebase 도메인 허용");
        print("   2. 네트워크 연결 상태 확인");
        print("   3. VPN이나 프록시 설정 확인");
      }
    }
  }
  
  // 권한 요청 (BuildContext를 받아서 다이얼로그 표시 가능)
  Future<bool> requestPermissions(BuildContext? context) async {
    try {
      print("🔐 [LiveCamera] 권한 요청 시작");
      
      // 먼저 현재 권한 상태 확인
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      
      print("🔐 [LiveCamera] 현재 권한 상태 - 카메라: $cameraStatus, 마이크: $microphoneStatus");
      
      // 이미 권한이 있으면 바로 반환
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        print("✅ [LiveCamera] 권한 이미 승인됨");
        return true;
      }
      
      // 권한이 영구적으로 거부된 경우 설정으로 이동
      if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
        print("⚠️ [LiveCamera] 권한이 영구적으로 거부됨 - 설정으로 이동 필요");
        if (context != null && context.mounted) {
          _showPermissionDialog(context);
        }
        return false;
      }
      
      // 권한 요청 (순차적으로 요청하여 충돌 방지)
      print("🔐 [LiveCamera] 카메라 권한 요청 중...");
      PermissionStatus cameraResult = cameraStatus;
      if (!cameraStatus.isGranted) {
        cameraResult = await Permission.camera.request();
        print("🔐 [LiveCamera] 카메라 권한 결과: $cameraResult");
      }
      
      // 잠시 대기 (권한 팝업이 겹치지 않도록)
      await Future.delayed(const Duration(milliseconds: 300));
      
      print("🔐 [LiveCamera] 마이크 권한 요청 중...");
      PermissionStatus microphoneResult = microphoneStatus;
      if (!microphoneStatus.isGranted) {
        microphoneResult = await Permission.microphone.request();
        print("🔐 [LiveCamera] 마이크 권한 결과: $microphoneResult");
      }
      
      // 최종 권한 상태 확인
      final finalCameraStatus = await Permission.camera.status;
      final finalMicrophoneStatus = await Permission.microphone.status;
      
      if (finalCameraStatus.isGranted && finalMicrophoneStatus.isGranted) {
        print("✅ [LiveCamera] 권한 승인 완료");
        return true;
      } else {
        print("❌ [LiveCamera] 권한 거부됨 - 카메라: $finalCameraStatus, 마이크: $finalMicrophoneStatus");
        
        // 권한이 거부되었고, 영구적으로 거부되지 않은 경우 다시 요청
        if (finalCameraStatus.isPermanentlyDenied || finalMicrophoneStatus.isPermanentlyDenied) {
          // 영구적으로 거부된 경우 설정으로 이동
          if (context != null && context.mounted) {
            _showPermissionDialog(context);
          }
        } else {
          // 일시적으로 거부된 경우 안내 메시지
          if (context != null && context.mounted) {
            _showPermissionDeniedDialog(context);
          }
        }
        return false;
      }
    } catch (e, stackTrace) {
      print("❌ [LiveCamera] 권한 요청 실패: $e");
      print("❌ [LiveCamera] 스택 트레이스: $stackTrace");
      if (context != null && context.mounted) {
        _showPermissionErrorDialog(context, e.toString());
      }
      return false;
    }
  }
  
  // 권한 거부 다이얼로그 (설정으로 이동)
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('권한 필요'),
          content: const Text(
            '카메라와 마이크 권한이 필요합니다.\n\n'
            '설정에서 권한을 허용해주세요:\n'
            '1. "설정으로 이동" 버튼 클릭\n'
            '2. 권한 > 카메라 허용\n'
            '3. 권한 > 마이크 허용\n'
            '4. 앱으로 돌아와서 다시 시도',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('나중에'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }
  
  // 권한 거부 다이얼로그 (일시적 거부)
  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('권한 필요'),
          content: const Text(
            '카메라와 마이크 권한이 필요합니다.\n\n'
            '다시 시도하면 권한 요청 팝업이 나타납니다.\n'
            '팝업에서 "허용"을 선택해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
  
  // 권한 요청 에러 다이얼로그
  void _showPermissionErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text('권한 요청 중 오류가 발생했습니다.\n\n오류: $error\n\n앱을 재시작하거나 설정에서 직접 권한을 허용해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        );
      },
    );
  }
  
  // 카메라 초기화
  Future<bool> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("❌ [LiveCamera] 사용 가능한 카메라가 없습니다.");
        return false;
      }
      
      // 후면 카메라 우선, 없으면 전면 카메라
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      print("📹 [LiveCamera] 선택된 카메라: ${camera.lensDirection == CameraLensDirection.back ? '후면' : '전면'}");
      
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high, // was medium
        enableAudio: true,
      );
      
      await _cameraController!.initialize();
      print("✅ [LiveCamera] 카메라 초기화 완료 (${camera.lensDirection == CameraLensDirection.back ? '후면' : '전면'})");
      return true;
    } catch (e) {
      print("❌ [LiveCamera] 카메라 초기화 실패: $e");
      return false;
    }
  }
  
  // WebSocket 연결 테스트
  Future<bool> _testWebSocketConnection() async {
    try {
      print("🔍 [LiveCamera] 백엔드 연결 테스트 중: $WS_URL");
      final testChannel = WebSocketChannel.connect(Uri.parse(WS_URL));
      
      // 연결 타임아웃 설정 (5초)
      await testChannel.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          testChannel.sink.close();
          throw TimeoutException('백엔드 서버 연결 시간 초과 (5초)');
        },
      );
      
      await testChannel.sink.close();
      print("✅ [LiveCamera] 백엔드 연결 테스트 성공");
      return true;
    } on TimeoutException catch (e) {
      print("❌ [LiveCamera] 백엔드 연결 시간 초과: $e");
      return false;
    } on SocketException catch (e) {
      print("❌ [LiveCamera] 네트워크 연결 실패: $e");
      return false;
    } catch (e) {
      print("❌ [LiveCamera] 백엔드 연결 테스트 실패: $e");
      return false;
    }
  }
  
  // WebSocket 연결 및 스트리밍 시작
  Future<bool> startStreaming(BuildContext? context) async {
    try {
      // 1단계: 권한 확인
      print("🔐 [LiveCamera] 1단계: 권한 확인");
      if (!await requestPermissions(context)) {
        print("❌ [LiveCamera] 권한 요청 실패");
        return false;
      }
      print("✅ [LiveCamera] 권한 확인 완료");
      
      // 2단계: 카메라 초기화
      print("📹 [LiveCamera] 2단계: 카메라 초기화");
      if (!await initializeCamera()) {
        print("❌ [LiveCamera] 카메라 초기화 실패");
        return false;
      }
      print("✅ [LiveCamera] 카메라 초기화 완료");
      
      // 3단계: 백엔드 서버 연결 확인
      print("🔍 [LiveCamera] 3단계: 백엔드 서버 연결 확인");
      final backendAvailable = await _testWebSocketConnection();
      if (!backendAvailable) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('백엔드 서버 연결 실패. 카메라는 작동하지만 스트리밍은 불가능합니다.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        print("⚠️ [LiveCamera] 백엔드 서버 연결 실패 - 카메라는 작동하지만 스트리밍 불가");
        return true;
      }
      print("✅ [LiveCamera] 백엔드 서버 연결 확인 완료");
      
      // 4단계: WebSocket 연결
      print("🌐 [LiveCamera] 4단계: WebSocket 연결");
      try {
        _channel = WebSocketChannel.connect(Uri.parse(WS_URL));
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (_channel != null) {
          try {
            await _channel!.ready.timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                throw TimeoutException('WebSocket 연결 시간 초과');
              },
            );
            print("✅ [LiveCamera] WebSocket 연결 완료: $WS_URL");
          } catch (e) {
            print("⚠️ [LiveCamera] WebSocket 연결 확인 실패: $e");
            _channel?.sink.close();
            _channel = null;
          }
        }
      } catch (e) {
        print("⚠️ [LiveCamera] WebSocket 연결 실패: $e");
        _channel?.sink.close();
        _channel = null;
      }
      
      // 세션 ID 생성
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      const userId = 'user_001';
      _roomId = 'room_$userId';
      
      // Firebase chat_room 생성
      try {
        final roomRef = FirebaseFirestore.instance.collection('chat_rooms').doc(_roomId);
        final roomDoc = await roomRef.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Firebase 연결 시간 초과'),
        );
        
        if (!roomDoc.exists) {
          await roomRef.set({
            'user_id': userId,
            'created_at': FieldValue.serverTimestamp(),
            'last_message_at': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));
          print("✅ [LiveCamera] Firebase chat_room 생성: $_roomId");
        } else {
          await roomRef.update({
            'last_message_at': FieldValue.serverTimestamp(),
          }).timeout(const Duration(seconds: 10));
          print("✅ [LiveCamera] Firebase chat_room 사용: $_roomId");
        }
      } catch (e) {
        print("⚠️ [LiveCamera] Firebase chat_room 생성/업데이트 실패: $e");
      }
      
      _isStreaming = true;
      
      // 백엔드 연결된 경우에만 WebSocket 메시지 수신 및 스트리밍 시작
      if (_channel != null) {
        // 오디오 플레이어 초기화
        try {
          _audioPlayer = AudioPlayer();
          await _audioPlayer!.setAudioContext(AudioContext(
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              audioMode: AndroidAudioMode.inCommunication,
              stayAwake: false,
              contentType: AndroidContentType.speech,
              usageType: AndroidUsageType.voiceCommunication,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck, // 재생 시 포커스 요청하되 마이크는 유지
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playAndRecord,
              options: {
                AVAudioSessionOptions.defaultToSpeaker,
                AVAudioSessionOptions.mixWithOthers,
              },
            ),
          ));
          _audioPlayer!.setPlayerMode(PlayerMode.lowLatency);
          
          // ⭐ 중요: 오디오 재생 완료 후 자동으로 릴리즈하지 않음
          // 이렇게 하면 오디오 포커스를 계속 유지하여 녹음을 방해하지 않음
          await _audioPlayer!.setReleaseMode(ReleaseMode.stop);

          // 재생 상태를 추적하여 큐 처리 재개
          _audioPlayer!.onPlayerStateChanged.listen((state) {
            _isPlayingAudio = state == PlayerState.playing;
            if (!_isPlayingAudio) {
              _processAudioQueue();
            }
          });
          _audioPlayer!.onPlayerComplete.listen((_) {
            _isPlayingAudio = false;
            _processAudioQueue();
          });
          
          _isPlayingAudio = false;
          print("🔊 [LiveCamera] 오디오 플레이어 초기화 완료 (lowLatency 모드, 녹음 방해 방지)");
        } catch (e) {
          print("⚠️ [LiveCamera] 오디오 플레이어 초기화 실패: $e");
        }
        
        // WebSocket 메시지 수신
        _websocketSubscription = _channel!.stream.listen(
          (message) {
            try {
              final data = jsonDecode(message);
              
              // 텍스트 메시지 처리
              if (data['type'] == 'text' && data['data'] != null) {
                final text = data['data'] as String;
                if (text.isNotEmpty && text.trim().isNotEmpty) {
                  print("📝 [LiveCamera] AI 응답 수신: $text");
                  _saveToFirebase('gemini', text);
                }
              }
              
              // 오디오 메시지 처리 (공식 예제 패턴: response.data를 끝까지 이어붙임)
              if (data['type'] == 'audio' && data['data'] != null) {
                try {
                  final audioBase64 = data['data'] as String;
                  final audioBytes = base64Decode(audioBase64);
                  
                  // 공식 예제 패턴: 오디오 청크를 턴 버퍼에 이어붙임
                  _appendAudioChunk(audioBytes);
                } catch (e) {
                  print("⚠️ [LiveCamera] 오디오 처리 실패: $e");
                }
              }
              
              // 턴 완료 신호 처리
              // X 버튼을 누르기 전까지는 오디오를 정상적으로 재생
              // X 버튼을 누르면 오디오 재생을 중단하고 홈으로 이동
              if (data['type'] == 'turn_complete') {
                final shouldExit = data['exit'] ?? false;
                print("✅ [LiveCamera] 턴 완료 신호 수신 (exit: $shouldExit)");
                
                if (shouldExit) {
                  // X 버튼을 누른 경우: 오디오 재생 중단 및 홈으로 이동
                  print("✅ [LiveCamera] X 버튼 클릭 감지 - 오디오 재생 중단 및 홈으로 이동");
                  
                  // 1. 현재 재생 중인 오디오 중단
                  _audioPlayer?.stop();
                  _isPlayingAudio = false;
                  
                  // 2. 오디오 큐 초기화
                  _audioQueue.clear();
                  _currentTurnAudioBuffer = null;
                  
                  // 3. 엘리홈으로 이동
                  if (_onExitRequested != null) {
                    _onExitRequested!();
                  }
                } else {
                  // 일반 turn_complete (X 버튼을 누르지 않은 경우)
                  // 오디오를 정상적으로 재생 (계속 대화 가능)
                  print("✅ [LiveCamera] 일반 턴 완료 - 오디오 재생 시작 (계속 대화 가능)");
                  // 이전 재생이 꼬여 있으면 정리 후 새 턴 재생
                  _audioPlayer?.stop();
                  _isPlayingAudio = false;
                  _audioQueue.clear();
                  // 비동기 함수이지만 await 없이 호출 (백그라운드 실행)
                  _finalizeAndPlayCurrentTurn();
                }
              }
            } catch (e) {
              print("⚠️ [LiveCamera] 메시지 파싱 실패: $e");
            }
          },
          onError: (error) {
            if (error.toString().contains('1011') || error.toString().contains('internal error')) {
              print("⚠️ [LiveCamera] 백엔드 서버 오류 (1011)");
              _channel?.sink.close();
              _channel = null;
              _websocketSubscription?.cancel();
              _websocketSubscription = null;
            } else {
              print("❌ [LiveCamera] WebSocket 에러: $error");
            }
          },
          onDone: () {
            print("🔌 [LiveCamera] WebSocket 연결 종료");
            _channel = null;
            _websocketSubscription = null;
          },
          cancelOnError: true,
        );
        
        // 오디오 레코더 초기화
        print("🎤 [LiveCamera] 오디오 레코더 초기화");
        try {
          _audioRecorder = AudioRecorder();
          final hasPermission = await _audioRecorder!.hasPermission();
          if (!hasPermission) {
            print("⚠️ [LiveCamera] 오디오 권한이 없습니다. 비디오만 스트리밍합니다.");
          } else {
            // 공식 예제 패턴: 16kHz, 16비트 PCM, 모노 오디오 전송
            // 공식 문서: "오디오를 16비트 PCM, 16kHz, 모노 형식으로 변환하여 전송"
            // ⭐ autoGain: false - 자동 게인을 비활성화하여 오디오 포커스 문제 완화
            // ⭐ echoCancel: false - 에코 캔슬을 비활성화 (AI 재생 중에도 녹음 가능)
            // ⭐ noiseSuppress: false - 노이즈 억제를 비활성화 (AI 재생 중에도 녹음 가능)
            const config = RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000, // 공식 문서: 입력은 16kHz
              numChannels: 1, // 모노
              autoGain: false, // 자동 게인 비활성화
              echoCancel: false, // 에코 캔슬 비활성화 (AI 재생 중에도 녹음)
              noiseSuppress: false, // 노이즈 억제 비활성화 (AI 재생 중에도 녹음)
              audioInterruption: AudioInterruptionMode.none, // 포커스 변동 시 자동 pause 방지
              androidConfig: AndroidRecordConfig(
                audioSource: AndroidAudioSource.voiceCommunication,
                speakerphone: true,
                audioManagerMode: AudioManagerMode.modeInCommunication,
              ),
            );
            
            Stream<Uint8List> stream;
            try {
              stream = await _audioRecorder!.startStream(config);
            } catch (e) {
              // 일부 기기에서 voiceCommunication 소스가 실패할 수 있으므로 기본 설정으로 재시도
              print("⚠️ [LiveCamera] 맞춤 녹음 설정 실패, 기본 설정으로 재시도: $e");
              stream = await _audioRecorder!.startStream(const RecordConfig(
                encoder: AudioEncoder.pcm16bits,
                sampleRate: 16000,
                numChannels: 1,
                autoGain: false,
                echoCancel: false,
                noiseSuppress: false,
              ));
            }
            print("✅ [LiveCamera] 오디오 스트림 시작 (에코 캔슬 OFF, AI 재생 중에도 녹음 가능)");
            
            // 오디오 데이터 전송 (사용자 말하기 감지 포함)
            _audioStreamSubscription = stream.listen(
              (data) {
                if (_isStreaming && _channel != null) {
                  try {
                    // 오디오 데이터가 너무 작으면 스킵 (노이즈 방지)
                    // PCM 16비트 = 2 bytes per sample, 16kHz = 16000 samples/sec
                    // 최소 160 samples (10ms) 이상인 경우만 전송
                    if (data.length < 320) { // 160 samples * 2 bytes = 320 bytes
                      return; // 너무 작은 오디오는 전송하지 않음
                    }
                    
                    final base64Audio = base64Encode(data);
                    _channel!.sink.add(jsonEncode({
                      'type': 'audio',
                      'data': base64Audio,
                    }));
                    
                    // 사용자 말하기 감지: 마지막 오디오 전송 시간 업데이트
                    _lastAudioSentTime = DateTime.now();
                    
                    // 사용자 말하기 타이머 재설정 (2초 동안 오디오가 없으면 말을 멈춘 것으로 간주)
                    _userSpeechTimer?.cancel();
                    _userSpeechTimer = Timer(const Duration(seconds: 2), () async {
                      // 2초 동안 오디오가 없으면 사용자가 말을 멈춘 것으로 간주
                      if (_isStreaming && _channel != null && _lastAudioSentTime != null) {
                        final timeSinceLastAudio = DateTime.now().difference(_lastAudioSentTime!);
                        if (timeSinceLastAudio.inSeconds >= 2) {
                          // 사용자 말하기 종료 신호 전송
                          try {
                            _channel!.sink.add(jsonEncode({'type': 'user_speech_end'}));
                            print("✅ [LiveCamera] 사용자 말하기 종료 감지 - user_speech_end 신호 전송");
                            _lastAudioSentTime = null; // 리셋
                          } catch (e) {
                            print("⚠️ [LiveCamera] 사용자 말하기 종료 신호 전송 실패: $e");
                          }
                        }
                      }
                    });
                  } catch (e) {
                    print("⚠️ [LiveCamera] 오디오 전송 실패: $e");
                  }
                }
              },
              onError: (error) {
                print("❌ [LiveCamera] 오디오 스트림 에러: $error");
                // 오디오 스트림 에러 발생 시 재시작 시도
                print("🔄 [LiveCamera] 오디오 스트림 재시작 시도...");
              },
            );
          }
        } catch (e) {
          print("⚠️ [LiveCamera] 오디오 레코더 초기화 실패: $e");
        }
        
        // 비디오 프레임 전송 (0.5초마다)
        _videoTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (!_isStreaming || _cameraController == null || !_cameraController!.value.isInitialized || _channel == null) {
            return;
          }
          
          try {
            final image = await _cameraController!.takePicture().timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('카메라 이미지 캡처 시간 초과'),
            );
            
            final imageFile = File(image.path);
            if (!await imageFile.exists()) {
              return;
            }
            
            final imageBytes = await imageFile.readAsBytes().timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('이미지 파일 읽기 시간 초과'),
            );
            
            final base64Image = base64Encode(imageBytes);
            _channel!.sink.add(jsonEncode({
              'type': 'image',
              'data': base64Image,
            }));
          } catch (e) {
            // 에러 무시하고 계속 진행
          }
        });
      } else {
        print("⚠️ [LiveCamera] 백엔드 연결이 없어 스트리밍을 시작하지 않습니다.");
      }
      
      print("✅ [LiveCamera] 스트리밍 시작 완료");
      return true;
    } catch (e) {
      print("❌ [LiveCamera] 스트리밍 시작 실패: $e");
      return false;
    }
  }
  
  Timer? _audioPlaybackTimer; // 오디오 재생 타이머 (일정 시간 후 자동 재생)
  
  // 공식 예제 패턴: 오디오 청크를 현재 턴 버퍼에 계속 이어붙임
  // Python 예제의 wf.writeframes(response.data)와 동일한 패턴
  void _appendAudioChunk(Uint8List audioBytes) {
    try {
      // 오디오가 너무 작으면 스킵 (노이즈 방지)
      if (audioBytes.length < 100) {
        return;
      }

      // 공식 예제 패턴: 현재 턴 버퍼가 없으면 초기화 (새 턴 시작)
      if (_currentTurnAudioBuffer == null) {
        _currentTurnAudioBuffer = Uint8List(0);
        print("🔊 [LiveCamera] 새 턴 시작 - 오디오 버퍼 초기화 (이전 턴 완료)");
      }

      // 공식 예제 패턴: 청크를 버퍼에 이어붙임 (끝까지 계속 누적)
      final newBuffer = Uint8List(_currentTurnAudioBuffer!.length + audioBytes.length);
      newBuffer.setRange(0, _currentTurnAudioBuffer!.length, _currentTurnAudioBuffer!);
      newBuffer.setRange(_currentTurnAudioBuffer!.length, newBuffer.length, audioBytes);
      _currentTurnAudioBuffer = newBuffer;

      print("🔊 [LiveCamera] 오디오 청크 추가: ${audioBytes.length} bytes (누적: ${_currentTurnAudioBuffer!.length} bytes)");
      
      // 오디오 청크가 오면 기존 타이머 취소하고 새 타이머 시작
      // 일정 시간(예: 1초) 동안 오디오 청크가 오지 않으면 자동으로 재생 시작
      _audioPlaybackTimer?.cancel();
      _audioPlaybackTimer = Timer(const Duration(seconds: 1), () {
        // 1초 동안 오디오 청크가 오지 않으면 자동으로 재생 시작
        if (_currentTurnAudioBuffer != null && _currentTurnAudioBuffer!.isNotEmpty && !_isPlayingAudio) {
          print("🔊 [LiveCamera] 오디오 청크 수신 중단 감지 - 자동 재생 시작");
          _finalizeAndPlayCurrentTurn();
        }
      });
    } catch (e) {
      print("❌ [LiveCamera] 오디오 청크 추가 실패: $e");
    }
  }
  
  // 공식 예제 패턴: 턴이 끝날 때까지 받은 모든 오디오를 WAV로 변환하고 재생
  // Python 예제의 wf.close()와 재생 시작에 해당
  Future<void> _finalizeAndPlayCurrentTurn() async {
    try {
      if (_currentTurnAudioBuffer == null || _currentTurnAudioBuffer!.isEmpty) {
        print("⚠️ [LiveCamera] 현재 턴에 오디오 데이터가 없습니다.");
        return;
      }

      if (_audioPlayer == null) {
        print("⚠️ [LiveCamera] 오디오 플레이어가 초기화되지 않았습니다.");
        return;
      }

      // 공식 예제 패턴: 출력은 24kHz PCM
      // 공식 문서: "출력은 샘플링 레이트 24kHz를 사용합니다"
      // 버퍼를 사용하기 전에 복사 (버퍼를 null로 설정하기 전에 사용)
      final bufferToUse = _currentTurnAudioBuffer!;
      final wavBytes = _pcmToWav(bufferToUse, sampleRate: 24000, channels: 1, bitsPerSample: 16);
      
      // 임시 파일로 저장
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ai_audio_turn_${DateTime.now().millisecondsSinceEpoch}.wav');
      await tempFile.writeAsBytes(wavBytes);
      
      print("🔊 [LiveCamera] 턴 완료 - 오디오 파일 생성: ${wavBytes.length} bytes (원본 PCM: ${bufferToUse.length} bytes)");
      
      // 중요: WAV 파일을 만든 후 즉시 버퍼를 null로 설정하여 다음 턴을 준비
      // 다음 오디오 청크가 오면 _appendAudioChunk에서 자동으로 새 버퍼를 초기화함
      _currentTurnAudioBuffer = null; // 다음 턴을 위해 즉시 초기화
      print("🔊 [LiveCamera] 오디오 버퍼 초기화 완료 (다음 턴 준비, 재생은 계속됨)");
      
      // 공식 예제 패턴: 중간에 stop/reset 하지 않고 끝까지 재생
      // 재생 중이 아니면 즉시 재생, 재생 중이면 큐에 추가
      if (!_isPlayingAudio) {
        _isPlayingAudio = true;
        
        // ⭐ 중요: 볼륨을 낮춰서 재생 (0.7 = 70%)
        // 이렇게 하면 오디오 포커스를 덜 공격적으로 요청하여 녹음이 계속됩니다
        await _audioPlayer!.play(DeviceFileSource(tempFile.path), volume: 0.7);
        print("🔊 [LiveCamera] 오디오 재생 시작: ${wavBytes.length} bytes (볼륨: 70%)");
        
        // 재생 완료 이벤트 등록
        _audioPlayer!.onPlayerComplete.first.then((_) {
          print("✅ [LiveCamera] 오디오 재생 완료");
          tempFile.delete().catchError((_) => tempFile);
          _isPlayingAudio = false;
          
          // 버퍼는 이미 _finalizeAndPlayCurrentTurn에서 초기화되었으므로 여기서는 초기화하지 않음
          
          // 큐에 대기 중인 오디오가 있으면 재생
          if (_audioQueue.isNotEmpty) {
            _processAudioQueue();
          }
        }).catchError((error) {
          print("❌ [LiveCamera] 오디오 재생 완료 이벤트 에러: $error");
          _isPlayingAudio = false;
          // 에러가 나도 버퍼는 이미 초기화되었으므로 다시 초기화할 필요 없음
        });
      } else {
        // 재생 중이면 큐에 추가 (연속 재생)
        _audioQueue.add(tempFile);
        print("🔊 [LiveCamera] 오디오 큐에 추가 (재생 중, 큐 크기: ${_audioQueue.length})");
      }
      
      // 버퍼는 이미 위에서 null로 초기화되었으므로 여기서는 추가 작업 불필요
    } catch (e) {
      print("❌ [LiveCamera] 턴 완료 처리 실패: $e");
      _currentTurnAudioBuffer = null;
      _isPlayingAudio = false;
    }
  }

  
  // 오디오 큐 처리 (연속 재생)
  Future<void> _processAudioQueue() async {
    if (_isPlayingAudio || _audioQueue.isEmpty) {
      return;
    }
    
    _isPlayingAudio = true;
    
    try {
      await _playNextAudio();
    } catch (e) {
      print("❌ [LiveCamera] 오디오 큐 처리 실패: $e");
      _isPlayingAudio = false;
    }
  }
  
  // 다음 오디오 재생 (내부 함수)
  Future<void> _playNextAudio() async {
    if (_audioQueue.isEmpty || _audioPlayer == null) {
      _isPlayingAudio = false;
      print("⚠️ [LiveCamera] 오디오 큐가 비어있거나 플레이어가 없습니다");
      return;
    }
    
    final audioFile = _audioQueue.removeAt(0);
    final fileSize = await audioFile.length();
    
    try {
      // 재생 시작 (볼륨 70%로 재생하여 녹음 방해 최소화)
      await _audioPlayer!.play(DeviceFileSource(audioFile.path), volume: 0.7);
      print("🔊 [LiveCamera] 오디오 재생 시작: ${fileSize} bytes (큐 남은 개수: ${_audioQueue.length}, 볼륨: 70%)");
      
      // 재생 완료 이벤트 등록 (한 번만 실행)
      _audioPlayer!.onPlayerComplete.first.then((_) {
        print("✅ [LiveCamera] 오디오 재생 완료: ${fileSize} bytes");
        
        // 파일 삭제
        audioFile.delete().catchError((_) {
          return audioFile;
        });

        // 다음 오디오 재생 (즉시)
        if (_audioQueue.isNotEmpty) {
          print("🔄 [LiveCamera] 다음 오디오 재생 시작 (큐: ${_audioQueue.length}개)");
          _playNextAudio();
        } else {
          _isPlayingAudio = false;
          print("✅ [LiveCamera] 오디오 큐 재생 완료 (모든 파일 재생됨)");
        }
      }).catchError((error) {
        print("❌ [LiveCamera] 오디오 재생 완료 이벤트 에러: $error");
        // 에러가 나도 다음 오디오 재생 시도
        if (_audioQueue.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 50), () {
            _playNextAudio();
          });
        } else {
          _isPlayingAudio = false;
        }
      });
    } catch (e) {
      print("❌ [LiveCamera] 오디오 파일 재생 실패: $e");
      audioFile.delete().catchError((_) {
        return audioFile;
      });
      
      // 재생 실패 시 다음 오디오 재생 시도 (짧은 지연)
      if (_audioQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 50));
        await _playNextAudio();
      } else {
        _isPlayingAudio = false;
      }
    }
  }
  
  
  // 스트리밍 중지
  Future<void> stopStreaming({bool closeWebSocket = true}) async {
    _isStreaming = false;
    
    _videoTimer?.cancel();
    _videoTimer = null;
    
    _audioTimer?.cancel();
    _audioTimer = null;
    
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    
    await _audioRecorder?.stop();
    await _audioRecorder?.dispose();
    _audioRecorder = null;
    
    if (closeWebSocket) {
      await _websocketSubscription?.cancel();
      _websocketSubscription = null;

      await _channel?.sink.close();
      _channel = null;
    }
    
    await _cameraController?.dispose();
    _cameraController = null;
    
    // 오디오 큐 초기화
    _audioQueue.clear();
    _pendingAudioChunks.clear();
    _audioFlushTimer?.cancel();
    _audioFlushTimer = null;
    
    // 공식 예제 패턴: 현재 턴 버퍼 초기화
    _currentTurnAudioBuffer = null;
    
    // 사용자 말하기 감지 타이머 초기화
    _userSpeechTimer?.cancel();
    _userSpeechTimer = null;
    _lastAudioSentTime = null;
    
    // Firebase 세션 상태 업데이트
    if (_sessionId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('sessions')
            .doc(_sessionId)
            .update({'status': 'completed'});
      } catch (e) {
        // 에러 무시
      }
    }
    
    print("✅ [LiveCamera] 스트리밍 중지 완료");
  }
  
  // 카메라 컨트롤러 반환
  CameraController? get cameraController => _cameraController;
  
  // 한국어만 포함하는지 확인
  bool _containsKorean(String text) {
    final koreanRegex = RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]');
    return koreanRegex.hasMatch(text);
  }
  
  // 영어만 있는지 확인
  bool _isEnglishOnly(String text) {
    final englishOnlyRegex = RegExp(r"^[a-zA-Z0-9\s\.,!?;:\-()]+$");
    return englishOnlyRegex.hasMatch(text.trim()) && !_containsKorean(text);
  }
  
  // PCM을 WAV로 변환
  Uint8List _pcmToWav(Uint8List pcmData, {required int sampleRate, required int channels, required int bitsPerSample}) {
    final dataSize = pcmData.length;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    
    final wavHeader = Uint8List(44);
    var offset = 0;
    
    void writeInt(int value, int bytes) {
      for (int i = 0; i < bytes; i++) {
        wavHeader[offset + i] = (value >> (i * 8)) & 0xFF;
      }
      offset += bytes;
    }
    
    void writeString(String str) {
      for (int i = 0; i < str.length; i++) {
        wavHeader[offset + i] = str.codeUnitAt(i);
      }
      offset += str.length;
    }
    
    writeString('RIFF');
    writeInt(dataSize + 36, 4);
    writeString('WAVE');
    writeString('fmt ');
    writeInt(16, 4);
    writeInt(1, 2);
    writeInt(channels, 2);
    writeInt(sampleRate, 4);
    writeInt(byteRate, 4);
    writeInt(blockAlign, 2);
    writeInt(bitsPerSample, 2);
    writeString('data');
    writeInt(dataSize, 4);
    
    return Uint8List.fromList([...wavHeader, ...pcmData]);
  }
  
  // 스트리밍 상태
  bool get isStreaming => _isStreaming;
  
  // 엘리홈으로 이동 콜백 설정
  void setOnExitRequested(VoidCallback? callback) {
    _onExitRequested = callback;
  }
  
  // X 버튼 클릭 시 호출: 진단 화면 종료 신호 전송
  void closeDiagnosisAndExit() {
    if (_channel != null) {
      try {
        _channel!.sink.add(jsonEncode({
          'type': 'close_diagnosis',
        }));
        print("✅ [LiveCamera] 진단 화면 종료 신호 전송 (X 버튼 클릭)");
      } catch (e) {
        print("❌ [LiveCamera] 종료 신호 전송 실패: $e");
      }
    } else {
      print("⚠️ [LiveCamera] WebSocket 연결이 없어 종료 신호를 전송할 수 없습니다.");
    }
  }
}
