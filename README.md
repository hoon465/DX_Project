# DX_Backend

## 구성 개요
- RAG FastAPI 서버 (챗봇/문서 검색)
- Vision FastAPI 서버 (실시간 음성/비전 처리)
- Spring Boot 서버 (Java 백엔드/API)

## 파일 가이드

### 챗봇/RAG 서버 구동
- `RAG/chatbot_server.py`: RAG 챗봇 서버.


### 문서 업로드(1회성 작업)
- `RAG/upload_manual.py`: 새 매뉴얼 PDF를 벡터화해서 넣을 때 실행.
- `RAG/upload_manual_supabase.py`: Supabase에 직접 올릴 때 벡터화 처리.

### 실시간 음성/비전 처리 서버
- `vision/live.py`: 오디오/비전 실시간 처리 FastAPI 서버.
- `vision/user_buffer.txt`: 세션/사용자 입력 버퍼 저장용(보통 수정 불필요).

### Java 백엔드
- `SpringBoot/demo`: Java 기반 API 서버(앱 ↔ Python 서버 연결).

