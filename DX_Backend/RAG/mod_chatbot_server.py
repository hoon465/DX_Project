import os
from pathlib import Path
import time
import subprocess
import sys
import re
import pathlib
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import List, Optional
from dotenv import load_dotenv
from supabase import create_client, Client
import google.generativeai as genai
from google.api_core import exceptions
from google.api_core.exceptions import ResourceExhausted

# ==========================================
# 1. 환경 설정 및 초기화
# ==========================================
# 상위 폴더의 .env 파일 로드 (프로젝트 루트에 있는 경우)
env_path = pathlib.Path(__file__).parent.parent / '.env'
load_dotenv(dotenv_path=env_path)
# 현재 폴더의 .env도 시도 (하위 호환성)
load_dotenv()

# API 키 및 URL 로드
SUPABASE_URL = "https://wzafalbctqkylhyzlfej.supabase.co"
SUPABASE_KEY = os.getenv("supbase_service_role")
GOOGLE_API_KEY = os.getenv("GEMINI_API_KEY")
FIREBASE_KEY_PATH = r"C:\dxfirebasekey\serviceAccountKey.json"

if not all([SUPABASE_URL, SUPABASE_KEY, GOOGLE_API_KEY]):
    raise ValueError("❌ 환경변수(.env) 설정을 확인해주세요.")

# 1-1. 파이어베이스 초기화
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate(FIREBASE_KEY_PATH)
        firebase_admin.initialize_app(cred)
        print("🔥 파이어베이스 연결 성공!")
    except Exception as e:
        print(f"❌ 파이어베이스 키 파일 오류: {e}")
        pass

db = firestore.client()

# 1-2. Supabase & Gemini 초기화
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
genai.configure(api_key=GOOGLE_API_KEY)

# 모델 설정 (최신 모델 적용)
EMBEDDING_MODEL = "models/text-embedding-004"
# 만약 2.5 접근 권한이 있으시면 "gemini-2.5-flash"로 바꾸세요.
GENERATION_MODEL_ID = "gemini-2.5-flash" 
GENERATION_MODEL = genai.GenerativeModel(GENERATION_MODEL_ID)

print(f"🚀 AI 모델 로드 완료: {GENERATION_MODEL_ID}")


# ==========================================
# 2. 헬퍼 함수들
# ==========================================

def save_to_firebase(user_id: str, sender: str, text: str, room_id: Optional[str] = None, msg_type: str = "TEXT"):
    try:
        # room_id가 제공되지 않으면 기본값 사용 (하위 호환성)
        if room_id is None:
            room_id = f"room_{user_id}"
        doc_ref = db.collection("chat_rooms").document(room_id).collection("messages")
        message_data = {
            "sender": sender,
            "text": text,              # 메시지 내용 (통일된 필드명)
            "message_type": "chat",    # 메시지 타입: 'chat' (텍스트 챗봇)
            "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")  # 형식: "2025-12-05 14:38:02"
        }
        doc_ref.add(message_data)
        print(f"💾 [Firebase] 저장 완료 - room: {room_id}, sender: {sender}, text: {text[:30]}...")
        print(f"💾 [Firebase] 저장 경로: chat_rooms/{room_id}/messages")
        print(f"💾 [Firebase] 저장된 데이터: {message_data}")
        print(f"💾 [Firebase] Flutter 앱에서 읽을 경로: chat_rooms/{room_id}/messages")
    except Exception as e:
        print(f"❌ [Firebase] 저장 실패: {e}")
        import traceback
        traceback.print_exc()

def get_embedding(text: str):
    try:
        result = genai.embed_content(
            model=EMBEDDING_MODEL,
            content=text,
            task_type="retrieval_query"
        )
        return result['embedding']
    except Exception as e:
        print(f"❌ 임베딩 생성 실패: {e}")
        return None

def generate_with_retry(prompt: str, max_retries: int = 3, initial_delay: float = 1.0) -> Optional[str]:
    """
    Gemini API 호출을 재시도 로직과 함께 실행합니다.
    ResourceExhausted 에러 발생 시 지수 백오프로 재시도합니다.
    """
    for attempt in range(max_retries):
        try:
            response = GENERATION_MODEL.generate_content(prompt)
            return response.text.strip() if response.text else None
        except ResourceExhausted as e:
            error_str = str(e)
            # 재시도 대기 시간 추출 (에러 메시지에서)
            retry_delay = initial_delay * (2 ** attempt)  # 지수 백오프
            
            # 에러 메시지에서 retry_delay 정보 추출 시도
            if "retry in" in error_str.lower() or "retry_delay" in error_str.lower():
                try:
                    # 에러 메시지에서 seconds 정보 추출
                    delay_match = re.search(r'(\d+\.?\d*)\s*seconds?', error_str, re.IGNORECASE)
                    if delay_match:
                        retry_delay = float(delay_match.group(1))
                except:
                    pass
            
            if attempt < max_retries - 1:
                print(f"⚠️ [재시도 {attempt + 1}/{max_retries}] API 할당량 초과. {retry_delay:.1f}초 후 재시도...")
                time.sleep(retry_delay)
            else:
                print(f"❌ [최종 실패] API 할당량 초과. 재시도 횟수 초과.")
                raise
        except Exception as e:
            print(f"❌ API 호출 실패: {e}")
            raise
    
    return None

def optimize_search_query(original_query: str) -> str:
    """사용자 질문을 검색용 키워드로 변환 (쿼리 확장)"""
    try:
        prompt = f"""
        규칙: 문장이 아닌 **키워드 나열** 형태. LG 세탁기 용어 적극 활용.
        
        사용자: "{original_query}"
        변환:
        """
        result = generate_with_retry(prompt, max_retries=2, initial_delay=2.0)
        if result:
            return result
        else:
            print(f"⚠️ 쿼리 확장 실패: 원본 쿼리 사용")
            return original_query
    except ResourceExhausted as e:
        print(f"⚠️ 쿼리 확장 실패 (할당량 초과): 원본 쿼리 사용")
        return original_query
    except Exception as e:
        print(f"⚠️ 쿼리 확장 실패: {e} - 원본 쿼리 사용")
        return original_query


# ==========================================
# 3. FastAPI 서버 설정
# ==========================================
from fastapi.staticfiles import StaticFiles
import asyncio
import socket

app = FastAPI()

# 정적 파일 서빙 설정 (assets_generate 폴더를 /assets 경로로 노출)
assets_path = Path(__file__).parent.parent / "generate" / "assets_generate"
assets_path.mkdir(parents=True, exist_ok=True) # 폴더가 없으면 생성
app.mount("/assets", StaticFiles(directory=str(assets_path)), name="assets")

# [서버 IP 가져오기 함수]
def get_host_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Google DNS 서버에 접속 시도하여 내 IP 확인 (실제 접속은 안함)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

# 고정 IP를 우선 사용하고, 환경변수 SERVER_IP가 "auto"면 자동 탐지
SERVER_IP = os.getenv("SERVER_IP") or "192.168.0.20"
if SERVER_IP == "auto":
    SERVER_IP = get_host_ip()

print(f"🌐 Server IP: {SERVER_IP}")


# [비디오 감시 태스크]
# assets 폴더를 감시하다가 새 비디오가 생기면 Firestore에 메시지를 남깁니다.
# 이렇게 하면 Firebase Storage 없이도 앱에서 비디오가 뜹니다.
processed_files = set()

async def watch_new_videos():
    print("👀 Video Watcher Started...")
    
    # 초기 상태: 이미 있는 파일은 처리된 것으로 간주 (원하면 제거 가능)
    if assets_path.exists():
        for f in assets_path.glob("*.mp4"):
            processed_files.add(f.name)
            
    while True:
        try:
            if assets_path.exists():
                # 현재 모든 mp4 파일
                current_files = list(assets_path.glob("*.mp4"))
                
                for file_path in current_files:
                    if file_path.name not in processed_files:
                        # 새 파일 발견!
                        print(f"🎬 New Video Detected: {file_path.name}")
                        
                        # 파일이 완전히 써질 때까지 잠시 대기 (옵션)
                        await asyncio.sleep(2)
                        
                        # 1. 로컬 URL 생성
                        # 예: http://192.168.0.x:8000/assets/filename.mp4
                        video_url = f"http://{SERVER_IP}:8000/assets/{file_path.name}"
                        
                        # 2. Firestore에 메시지 강제 저장
                        # (데모용: 가장 최근 방이나 기본 방에 저장)
                        # 실제로는 generate.py에서 session_id를 파일명에 넣거나 별도 전달해야 정확함
                        # 여기서는 'room_user_001' 등 고정값 또는 가장 최근 수정된 방을 찾음
                        
                        target_room_id = "room_user_001" # Default
                        
                        # [고급] 가장 최근 대화가 있었던 방 찾기
                        try:
                            # 최근 메시지가 있는 방 찾기 (복잡하므로 생략하거나 간단히 구현)
                            # 여기서는 간단히 고정 ID 사용하되, 필요시 로직 추가
                            pass
                        except: pass

                        print(f"📤 Sending video message to {target_room_id}...")
                        
                        # DB 저장
                        doc_ref = db.collection("chat_rooms").document(target_room_id).collection("messages")
                        doc_ref.add({
                            "sender": "ai",
                            "text": "솔루션 영상을 생성했습니다. (Local Server)",
                            "video_url": video_url,
                            "message_type": "VIDEO",
                            "timestamp": firestore.SERVER_TIMESTAMP
                        })
                        
                        print(f"✅ Saved video message: {video_url}")
                        
                        # 처리 목록에 추가
                        processed_files.add(file_path.name)
                        
        except Exception as e:
            print(f"⚠️ Watcher Error: {e}")
            
        await asyncio.sleep(3) # 3초마다 확인

@app.on_event("startup")
async def startup_event():
    # 백그라운드 태스크로 감시 시작
    asyncio.create_task(watch_new_videos())


class ChatRequest(BaseModel):
    user_message: str
    user_id: str
    session_id: Optional[str] = None  # room_id (예: room_user_001, room_user_002)

class ChatResponse(BaseModel):
    answer: str
    sources: List[str]

class DeleteRoomRequest(BaseModel):
    userId: str
    roomId: Optional[str] = None

class DeleteRoomResponse(BaseModel):
    success: bool
    message: str
    newRoomId: Optional[str] = None

# -------------------------------------------------------
# [API 1] 텍스트 챗봇 (하이브리드 검색 적용)
# -------------------------------------------------------
@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(req: ChatRequest):
    # room_id 결정: session_id가 있으면 사용, 없으면 기본값 사용 (하위 호환성)
    room_id = req.session_id if req.session_id else f"room_{req.user_id}"
    print(f"📩 [Python] 요청 도착 - userId: {req.user_id}, sessionId: {req.session_id}, roomId: {room_id}, message: {req.user_message[:50]}...")
    
    try:
        # 1. 사용자 질문 저장은 프론트엔드에서 이미 저장하므로 여기서는 저장하지 않음
        # (프론트엔드에서 Optimistic Update로 저장함)
        # 백엔드에서도 저장하면 중복 저장이 발생하므로 제거
        print(f"💾 [Python] 사용자 메시지는 프론트엔드에서 이미 저장되었으므로 저장 생략 (중복 방지)")

        # 2. 쿼리 확장 (키워드 검색용)
        search_keyword = optimize_search_query(req.user_message)
        print(f"✨ [쿼리 확장] '{req.user_message}' -> '{search_keyword}'")

        # 3. 임베딩 생성 (벡터 검색용)
        query_vector = get_embedding(search_keyword)
        if not query_vector: raise Exception("임베딩 실패")

        # 🔥 [핵심] 하이브리드 검색 RPC 호출
        # (Supabase에 hybrid_search 함수가 만들어져 있어야 함)
        rpc_response = supabase.rpc("hybrid_search", {
            "query_text": search_keyword,    # 텍스트 매칭용
            "query_embedding": query_vector, # 의미 검색용
            "match_threshold": 0.1,          # 기준 점수
            "match_count": 5,                # 가져올 개수
            "w_vector": 0.9,                 # 벡터 가중치 (0.0~1.0)
            "w_keyword": 0.1                 # 키워드 가중치 (0.0~1.0)
        }).execute()
        
        search_results = rpc_response.data
        
        if not search_results:
            final_answer = "죄송합니다. 매뉴얼에서 관련 내용을 찾을 수 없습니다. 고객센터에 문의해주세요."
            source_titles = []
        else:
            # 5. 프롬프트 구성 (하이브리드 결과 사용)
            context_list = []
            for item in search_results:
                # hybrid_search 함수는 'content_text'로 리턴함
                text = item.get('content_text') or item.get('content') or ""
                title = item.get('section_title') or "정보"
                context_list.append(f"- {text} (출처: {title})")
            
            context_text = "\n\n".join(context_list)
            source_titles = list(set([item.get('section_title', '제목없음') for item in search_results]))

            prompt = f"""
            당신은 LG전자 가전제품 전문 상담원 'ThinQ 봇'입니다.
            사용자의 질문에 대해 아래 제공된 [매뉴얼 데이터]를 기반으로 친절하고 정확하게 답변해 주세요.
            답변을 할 때는 사용자와 친근한 느낌으로 답변해주세요
            세탁방법에 대해 물었는데 메뉴얼에 없다면 다른 특정 세탁기의 기능은 말하지 말고 특정 세탁기가 없어도 누구나 적용가능한 방법을 너가 알고 있는 최대한 정확한 지식으로 친절하게 답변해줘
            메뉴얼에 없는 내용은 메뉴얼에 없는 내용이라고 말하지말고 자연스럽게 너가 알고 있는 지식으로 친절하게 답변해줘
            [지침]
            1. 표 내용은 문장으로 자연스럽게 풀어서 설명하세요.
            2. 사용자가 '통돌이', '드럼' 등 구어체를 써도, 매뉴얼의 해당 제품군 내용으로 답변하세요.
            3. 질문에 '띵큐'가 있다면 답변할 때 'LG ThinQ'로 바꿔서 말해주세요.
            4. 답변을 줄때는 너무 길게 말하지말고 간결하게 답변해줘
            
            [매뉴얼 데이터]:
            {context_text}
            
            [사용자 질문]: {req.user_message}
            (참고: '{search_keyword}' 관련 내용을 검색했습니다.)
            
            [답변]:
            """
            
            # 6. 답변 생성 (재시도 로직 포함)
            try:
                final_answer = generate_with_retry(prompt, max_retries=3, initial_delay=5.0)
                if not final_answer:
                    raise Exception("답변 생성 실패: 빈 응답")
            except ResourceExhausted as e:
                error_msg = str(e)
                retry_seconds = 60  # 기본값
                
                # 에러 메시지에서 재시도 시간 추출
                delay_match = re.search(r'(\d+\.?\d*)\s*seconds?', error_msg, re.IGNORECASE)
                if delay_match:
                    retry_seconds = int(float(delay_match.group(1)))
                
                final_answer = f"""죄송합니다. 현재 AI 서비스의 일일 사용 한도에 도달했습니다. 

일일 무료 사용량(20회)을 초과하여 서비스를 일시적으로 사용할 수 없습니다. 
약 {retry_seconds}초 후에 다시 시도해주시거나, 내일 다시 이용해주세요.

더 많은 사용량이 필요하시다면 Google AI Studio에서 유료 플랜으로 업그레이드하시기 바랍니다.
고객센터: https://ai.google.dev/gemini-api/docs/rate-limits"""
                
                print(f"❌ API 할당량 초과로 인한 오류 발생. 사용자에게 안내 메시지 전송.")
            except Exception as e:
                print(f"❌ 답변 생성 중 오류: {e}")
                raise

        # 7. 답변 저장
        print(f"💾 [Python] AI 답변 Firebase 저장 시작...")
        save_to_firebase(req.user_id, "ai", final_answer, room_id)
        print(f"✅ [Python] 답변 완료 및 저장 완료: {final_answer[:30]}...")
        print(f"📤 [Python] 응답 반환 준비 - answer 길이: {len(final_answer)}, sources 개수: {len(source_titles)}")

        response = ChatResponse(
            answer=final_answer,
            sources=source_titles
        )
        print(f"✅ [Python] 응답 반환 완료!")
        return response

    except ResourceExhausted as e:
        error_msg = str(e)
        retry_seconds = 60  # 기본값
        
        # 에러 메시지에서 재시도 시간 추출
        delay_match = re.search(r'(\d+\.?\d*)\s*seconds?', error_msg, re.IGNORECASE)
        if delay_match:
            retry_seconds = int(float(delay_match.group(1)))
        
        print(f"❌ 서버 에러 (할당량 초과): {e}")
        import traceback
        traceback.print_exc()
        
        quota_message = f"""죄송합니다. 현재 AI 서비스의 일일 사용 한도에 도달했습니다.

일일 무료 사용량(20회)을 초과하여 서비스를 일시적으로 사용할 수 없습니다.
약 {retry_seconds}초 후에 다시 시도해주시거나, 내일 다시 이용해주세요.

더 많은 사용량이 필요하시다면 Google AI Studio에서 유료 플랜으로 업그레이드하시기 바랍니다.
고객센터: https://ai.google.dev/gemini-api/docs/rate-limits"""
        
        return ChatResponse(
            answer=quota_message,
            sources=[]
        )
    except Exception as e:
        print(f"❌ 서버 에러: {e}")
        import traceback
        traceback.print_exc()
        return ChatResponse(
            answer=f"죄송합니다. 오류가 발생했습니다. ({str(e)})",
            sources=[]
        )

# --- 비디오 상태 확인용 글로벌 변수 ---
# 실제로는 DB나 Redis를 써야 하지만, 간단한 데모를 위해 메모리에 상태 저장
# key: video_id (또는 user_id), value: {'status': '...', 'url': '...'}
video_generation_status = {}
_initial_mp4_count = None  # /generate/assets_generate 폴더의 초기 mp4 개수 기록용

@app.post("/generate-video")
async def generate_video_endpoint():
    try:
        # Current file directory: lgdx_backend/RAG
        current_dir = Path(__file__).parent
        # Target script: lgdx_backend/generate/generate.py
        script_path = current_dir.parent / "generate" / "generate.py"
        
        print(f"🎥 실행 요청: {script_path}")
        
        if not script_path.exists():
             raise HTTPException(status_code=404, detail=f"Script not found at {script_path}")

        # 상태를 'processing'으로 설정
        # 실제 앱에서는 user_id 등을 받아야 함. 여기선 'demo_video'라는 고정 ID 사용
        video_generation_status['demo_video'] = {'status': 'processing'}

        # 시작 시점에 mp4 파일 개수 기록
        global _initial_mp4_count
        assets_dir = current_dir.parent / "generate" / "assets_generate"
        assets_dir.mkdir(exist_ok=True)
        _initial_mp4_count = len(list(assets_dir.glob("*.mp4")))

        # Run the script asynchronously using subprocess
        # 스크립트가 완료되면 파일을 생성하거나 DB를 업데이트한다고 가정
        # 여기서는 단순히 스크립트를 실행하고, 폴링 시 파일 존재 여부를 확인할 수도 있음
        subprocess.Popen([sys.executable, str(script_path)])
        
        return {"status": "started", "message": "Video generation started in background"}
    except Exception as e:
        print(f"❌ 실행 실패: {e}")
        video_generation_status['demo_video'] = {'status': 'failed'}
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/check-video-status")
async def check_video_status():
    """
    assets_generate 폴더의 mp4 개수를 관찰하여
    초기 개수 대비 1개 이상 증가하면 생성 완료로 판단.
    """
    try:
        base_dir = Path(__file__).parent.parent / "generate" / "assets_generate"
        if not base_dir.exists():
            return {"status": "processing"}

        mp4_files = list(base_dir.glob("*.mp4"))
        current_count = len(mp4_files)

        global _initial_mp4_count
        if _initial_mp4_count is None:
            # generate-video가 먼저 호출되지 않은 경우 대비해서 초기값 설정
            _initial_mp4_count = current_count
            return {"status": "processing"}

        if current_count <= _initial_mp4_count:
            return {"status": "processing"}

        # 개수가 증가했으면 가장 최신 파일을 완료된 결과로 간주
        latest_file = max(mp4_files, key=os.path.getctime)
        size = os.path.getsize(latest_file)
        created_at_iso = datetime.fromtimestamp(os.path.getmtime(latest_file)).isoformat()

        return {
            "status": "completed",
            "video_url": f"/assets/{latest_file.name}",
            "video_created_at": created_at_iso,
            "video_size": size,
        }

    except Exception as e:
        print(f"Check status error: {e}")
        return {"status": "failed"}

# -------------------------------------------------------
# [API 2] 채팅 내역 불러오기 (History)
# -------------------------------------------------------
@app.get("/chat/history")
async def get_chat_history(user_id: str):
    """
    특정 사용자(user_id)의 채팅 내역을 시간순으로 가져옵니다.
    """
    try:
        room_id = f"room_{user_id}"
        print(f"📂 [History] Fetching history for {room_id}")

        # Firestore 쿼리 (timestamp 오름차순)
        docs = db.collection("chat_rooms").document(room_id).collection("messages")\
            .order_by("timestamp").stream()

        messages = []
        for doc in docs:
            data = doc.to_dict()
            
            # Timestamp 처리 (JSON 직렬화를 위해 문자열 변환)
            if "timestamp" in data and data["timestamp"]:
                # Datetime 객체인 경우
                if hasattr(data["timestamp"], "isoformat"):
                    data["timestamp"] = data["timestamp"].isoformat()
                else:
                    data["timestamp"] = str(data["timestamp"])
            
            messages.append(data)

        return {"messages": messages}

    except Exception as e:
        print(f"❌ History Error: {e}")
        return {"messages": []}
# -------------------------------------------------------
# [API 2] 채팅방 삭제 및 새 room 생성 (room+1)
# -------------------------------------------------------
@app.post("/room/delete", response_model=DeleteRoomResponse)
async def delete_room_endpoint(req: DeleteRoomRequest):
    try:
        print(f"🗑️ [Python] 채팅방 삭제 요청 - userId: {req.userId}, roomId: {req.roomId}")
        
        if not req.userId or req.userId.strip() == "":
            raise HTTPException(status_code=400, detail="userId가 필요합니다.")
        
        # 1. 기존 room_user_XXX 형태의 모든 room 조회
        rooms_ref = db.collection("chat_rooms")
        rooms_snapshot = rooms_ref.stream()
        
        print(f"📋 [Python] 전체 rooms 조회 시작...")
        
        # 2. room_user_로 시작하는 문서들 중에서 가장 큰 숫자 찾기
        import re
        max_number = 0
        pattern = re.compile(r"^room_user_(\d+)$")
        
        room_count = 0
        for doc in rooms_snapshot:
            room_count += 1
            doc_id = doc.id
            match = pattern.match(doc_id)
            if match:
                try:
                    number = int(match.group(1))
                    if number > max_number:
                        max_number = number
                    print(f"📋 [Python] room 발견: {doc_id} (숫자: {number})")
                except ValueError:
                    print(f"⚠️ [Python] 숫자 파싱 실패: {doc_id}")
        
        print(f"📋 [Python] 전체 rooms 조회 완료: {room_count}개, 최대값: {max_number}")
        
        # 3. 새로운 room_id 생성 (가장 큰 숫자 + 1)
        new_room_number = max_number + 1
        new_room_id = f"room_user_{new_room_number:03d}"  # 001, 002 형식
        
        print(f"✅ [Python] 새 room_id 생성: {new_room_id} (이전 최대값: {max_number})")
        
        # 4. 새로운 room 문서 생성 (messages 서브컬렉션은 자동으로 생성됨)
        new_room_data = {
            "createdAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "updatedAt": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "userId": req.userId
        }
        
        rooms_ref.document(new_room_id).set(new_room_data)
        
        print(f"✅ [Python] 새 room 문서 생성 완료: {new_room_id}")
        print(f"✅ [Python] Firebase 경로: chat_rooms/{new_room_id}")
        
        return DeleteRoomResponse(
            success=True,
            message="채팅방이 삭제되었고 새 채팅방이 생성되었습니다.",
            newRoomId=new_room_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ [Python] 채팅방 삭제 실패: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"채팅방 삭제 실패: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)