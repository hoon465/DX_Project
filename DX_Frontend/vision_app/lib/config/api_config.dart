class ApiConfig {
  // *** 중요: 실제 기기(폰)에서 테스트할 때는 이 값을 컴퓨터의 IP 주소로 바꾸세요! ***
  // 예: static const String _realDeviceIp = '192.168.0.15';
  static const String _realDeviceIp = '192.168.0.20';

  static String get baseUrl {
    // 실제 기기(갤럭시/아이폰)에서 테스트 중이시라면 아래 코드를 사용하세요.
    // 주의: 주소 앞에 'http://'가 꼭 있어야 합니다!
    return 'http://$_realDeviceIp:9090';

    /* 
    // 원래의 에뮬레이터/시뮬레이터용 코드는 아래와 같습니다.
    // 다시 에뮬레이터를 쓰실 때는 위의 return을 지우고 아래 주석을 해제하세요.
    
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8000';
    } else {
      return 'http://$_realDeviceIp:8000';
    }
    */
  }
}
