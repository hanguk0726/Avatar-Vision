# Avatar Vision — 아키텍처 & 파이프라인 평가

> Rust 코어(`rust/src`)의 캡처·인코딩·렌더링 파이프라인에 대한 코드 리뷰 기반 평가.
> 코드 변경 없이 현 구조를 정리하고 개선 우선순위를 제시하는 문서입니다.

## 1. 전체 구조

```
Flutter UI  ──(irondash method channels)──┐
                                           │  채널별 background thread + RunLoop 5개
   ┌───────────────────────────────────────┴────────────────────────────┐
   │ camera / audio / texture / recording / rendering  핸들러             │
   └────────────────────────────────────────────────────────────────────┘

[비디오]
 nokhwa CallbackCamera ──try_send_realtime──▶ rendering ch (bounded 1)
        │                                          │
        │                            texture handler recv loop
        │                          ┌───────────────┴─────────────┐
        │              (recording?) send clone            tokio(8) decode_to_rgb
        │                     ▼                                    ▼
        │              recording ch (bounded 1)            render_buffer(Mutex) ─▶ Flutter texture
        │                     ▼
        │        [start_recording] rayon 2-scope:
        │          A: recv ─▶ Vec<(Buffer,Instant)> (Mutex)
        │          B: Vec.clone() ─▶ batch(24fps 정렬) ─▶ encoding ch (unbounded)
        │                     ▼
        │        [start_encording] rayon 2-scope:
        │          A: recv ─▶ tokio(2→8) decode_to_rgb ─▶ rgba_to_yuv ─▶ OrdQueue(index)
        │          B: encode_to_h264(openh264) ─▶ temp.h264
        │                     ▼
        │          fs::read(temp.h264) ─▶ to_mp4(minimp4 + temp.pcm) ─▶ .mp4 + 썸네일
[오디오]
 cpal input ─▶ i16 LE ─▶ buffer(Mutex) ─100KB─▶ temp.pcm
```

### 구성 요소

| 채널 핸들러 | 파일 | 역할 |
|---|---|---|
| camera | `message_channel/camera_message_channel.rs` | 장치 열거/선택, 스트림 open/stop, 해상도 |
| texture | `message_channel/texture_message_channel.rs` | 렌더링 채널 소비 → 디코드 → 프리뷰 버퍼, 녹화 시 recording 채널로 분기 |
| recording | `message_channel/recording_message_channel.rs` | 프레임 수집·24fps 정형화(batch), 인코딩·먹싱·저장 오케스트레이션 |
| rendering | `message_channel/rendering_message_channel.rs` | Flutter 텍스처 갱신 신호 |
| audio | `message_channel/audio_message_channel.rs` + `domain/audio.rs` | cpal 입력 캡처 → temp.pcm |

공유 상태는 `Arc<Mutex<…>>` / `Arc<AtomicBool>`, 스레드 간 프레임 전달은 `kanal` 채널(`domain/channel.rs`).

## 2. 잘 된 점

- **도메인 분리가 명확하다.** 각 채널이 독립 핸들러·RunLoop·kanal 채널을 가져 irondash 패턴에 잘 맞는다.
- **OrdQueue**(`tools/ordqueue.rs`, gifski 차용)로 스레드풀에서 순서가 뒤섞인 인코딩 결과를 프레임 인덱스로 재정렬한다 — 병렬 디코딩과 순차 인코딩을 안전하게 잇는 좋은 설계.
- **미리보기 최신 프레임 우선.** `texture_message_channel.rs`의 인덱스 기반 outdated-drop과 rendering/recording 채널의 `bounded(1)` 백프레셔로 프리뷰 지연을 억제한다.
- **ffmpeg 비의존 스택**(openh264 + minimp4 + nokhwa + cpal)으로 캡처·인코딩·먹싱을 자체 구성 — 스코프가 크다.

## 3. 문제점 (심각도순)

| # | 심각도 | 위치 | 문제 |
|---|---|---|---|
| 1 | 높음 | 전역 (`unwrap` 다수) | **패닉 기반 에러 처리.** `map.get().unwrap()`, `resolution[0].parse().unwrap()`, 채널 send/lock `.unwrap()` 등. 장치 특이값·포이즌된 뮤텍스·닫힌 채널 하나로 앱 전체가 죽고, irondash가 패닉을 삼켜 **Flutter가 에러 없이 종료**된다(`domain/textrue.rs`의 `get_payload` 주석이 이 동작을 인정). |
| 2 | 높음 | `recording_message_channel.rs` `start_recording` Task B | **매 폴링마다 큐 전체 `.clone()`.** 대기 중 `Vec<(Buffer,Instant)>`(각 Buffer가 풀 프레임)를 통째로 복제하고 그동안 락을 점유. 프레임 누적 시 O(n) 깊은 복사가 반복된다. |
| 3 | 높음 | `domain/channel.rs`(encoding) | **인코딩 채널이 unbounded.** 인코더가 캡처를 못 따라가면(초반 워커 2개) 세션 전체 raw 프레임이 RAM에 무한 축적. 긴 녹화·저사양에서 메모리 폭증 위험. |
| 4 | 중간 | texture `decode()` + recording `decode_to_rgb()` | **같은 프레임을 두 번 디코드.** 프리뷰용 1회, 인코딩용 1회. 한 번 디코드해 공유 가능. 카메라 원본이 YUV면 YUV→RGB→YUV 왕복으로 CPU·화질 손해. |
| 5 | 중간 | `recording_message_channel.rs` `start_encording` | **인코딩 중 tokio 런타임 재생성.** 2워커로 시작해 Saving 되면 8워커 런타임을 새로 build하고 기존 것 drop → 이미 spawn된 태스크 유실 가능. rayon 전역풀 + tokio 2개 + 채널 RunLoop 5개 + cpal + nokhwa 스레드 → 저사양 오버서브스크립션. |
| 6 | 중간 | `recording_message_channel.rs` `batch()` | **수동 타임스탬프 레이트 컨트롤.** PTS가 아니라 도착 시각으로 24fps를 맞추고 모자라면 마지막 프레임 재전송. `1000/24=41ms`, ×24=984ms로 초당 약 16ms 드리프트 → A/V 싱크 소지. 코드도 "not ideal" 자인. |
| 7 | 중간 | `recording.rs` `to_mp4`, `domain/audio.rs` | **하드코딩 상대경로 `temp.pcm`/`temp.h264`.** CWD 의존, 동시 녹화 불가, 읽기전용 CWD면 파손. 또 `to_mp4`는 인자 `audio: Pcm`의 샘플을 안 쓰고 파일을 다시 읽어 **진실 출처가 이원화**된다. |
| 8 | 낮음 | `domain/textrue.rs` `get_payload`, texture `decode()` | **프레임마다 풀버퍼 복제.** pull마다 `data.to_owned()`; decode도 락 잡고 통째 교체. |
| 9 | 낮음 | `recording.rs` `encoder()` | **비트레이트 360kbps 고정.** 해상도 무관 → 1080p에서 블록 노이즈. `RateControlMode::Timestamp`인데 실제 PTS 미전달. |
| 10 | 낮음 | `domain/channel.rs` `reset_*` | 다른 스레드가 옛 sender/receiver 클론을 든 채 채널을 락 밑에서 교체 → 고아 채널로 프레임 전송 레이스. |
| 11 | 위생 | 전역 | 오타·데드코드: `infate_camera`, `inflate_camera_conection`, `start_encording`, `textrue`, `#[cfg(unsued)]`(오타라 영원히 비컴파일), `channles`. **Rust 유닛 테스트 0개** — 바이트 민감 변환인데 회귀 방지 장치가 없다. |
| 12 | 낮음 | `rendering_message_channel.rs` `start_rendering` | **표시 루프가 프레임 도착과 분리.** 24fps 고정 타이머가 `render_buffer`를 무조건 긁어 `mark_frame_available` 호출. 카메라가 더 빠르면 디코드해놓고 안 보여주는 프레임이 생기고, 버퍼가 안 바뀌어도 동일 프레임을 또 복사·업로드한다. (§4 참조) |

## 4. 렌더링(표시) 경로 심층

프리뷰 표시는 **최종 Flutter 합성만 GPU이고 나머지는 전부 CPU**다. GPU가 아닌 것 자체는 이 규모의 웹캠 프리뷰에선 정석적이고 합리적인 선택이지만, 경로에 제거 가능한 낭비가 있다.

### 프레임 1장당 실제 흐름

```
카메라 CPU 버퍼 ─▶ rendering ch
  ─▶ tokio(8) decode_to_rgb            ← [CPU 변환 ①] MJPEG/YUYV/NV12 → RGBA
  ─▶ render_buffer: Mutex<Vec<u8>> (move)
        ↑ 여기까지가 "프레임 도착" 시점
  [별도 스레드] 24fps 고정 타이머 (rendering_message_channel.rs)
     ─▶ mark_frame_available()
        ─▶ Flutter가 get_payload() 호출
           ─▶ data.to_owned()          ← [CPU 풀프레임 복사 ②] (domain/textrue.rs, 락 안에서)
           ─▶ SimplePixelData
              ─▶ 엔진이 픽셀버퍼를 GPU 텍스처로 업로드  ← [CPU→GPU 업로드 ③] 매 프레임
                 ─▶ GPU 합성
```

GPU는 마지막 합성에만 관여하고, 디코드·색변환·스테이징은 CPU + 풀프레임 복사 2회 + 업로드 1회로 처리된다.

### 진짜 비용은 "CPU라서"가 아니라 낭비

1. **`get_payload`의 `data.to_owned()`** (`domain/textrue.rs`) — pull마다 풀프레임 통째 복사. 더블버퍼/스왑으로 제거 가능. (§3 #8)
2. **표시 루프가 도착과 분리** (`rendering_message_channel.rs`) — 24fps 고정 폴링이라 카메라가 더 빠르면 디코드하고도 안 보여주는 프레임 발생, 버퍼 불변 시 동일 프레임 재복사·재업로드. (§3 #12)
3. **프리뷰·인코딩 이중 디코드** — 같은 프레임을 texture에서 1회, 인코딩에서 1회. (§3 #4)
4. **색변환이 스칼라 CPU** — `decode_to_rgb`가 프리뷰 매 프레임 실행. `rgba_to_yuv`처럼 SIMD/캐시 최적화 여지 있음.

### GPU로 가야 하는가 — 순서

**바로 가지 말 것.** 먼저 위 낭비(①②③)를 제거하고 측정한다. 대부분의 오버헤드가 여기서 사라진다.

그래도 1080p+에서 코어가 포화되면:
- 색변환을 셰이더/D3D11 Video Processor로 오프로드 + **GPU 텍스처 provider**로 제로카피 핸드오프.
- 또는 Media Foundation/DXVA **하드웨어 디코드**.

두 가지 제약을 전제로 판단해야 한다:
- **nokhwa가 프레임을 이미 CPU 메모리로 전달**하므로 GPU 경로여도 CPU→GPU 업로드는 남는다. GPU가 이득 보려면 업로드 후 변환·스케일을 GPU에 두고 합성까지 그대로 넘겨야 한다.
- **irondash_texture의 대상 플랫폼(Windows) GPU 텍스처 지원 여부를 먼저 확인**해야 한다. 현재는 CPU `PixelDataProvider`만 사용 중이며, 지원이 없으면 GPU 경로는 플랫폼 인터롭 대공사가 된다.

**요약:** 렌더가 CPU인 것은 정당하다. 우선순위는 GPU 이식이 아니라 **`to_owned` 복사 제거 + 표시 루프를 프레임 도착에 연동 + 1회 디코드 공유**다. 그걸 다 하고도 고해상도에서 부족할 때 비로소 GPU 텍스처/하드웨어 디코드가 답이다.

## 5. 개선 우선순위 로드맵

### 1순위 — 안정성 (사용자 체감 크래시 제거)
- 핫패스 `.unwrap()` → `Result`/`match`로 교체하고 채널 핸들러에서 에러를 UI로 반환. 특히 `map.get`, `parse`, 채널 send, mutex lock.
- 뮤텍스 포이즌 복구 또는 `parking_lot` 도입 검토.

### 2순위 — 메모리/복사 (긴 녹화 안정성)
- 인코딩 채널을 `bounded`로 바꿔 백프레셔 확보 → RAM 폭증 차단 (#3).
- `webcam_frame_queue`를 `Vec` 통째 clone 대신 `VecDeque` + `pop_front` 소비 (#2).
- 프레임 1회 디코드 후 프리뷰·인코딩 공유, 가능하면 카메라 네이티브 YUV 직결 (#4).
- 렌더 경로 낭비 제거: `get_payload`의 `to_owned` 스왑, 표시 루프를 프레임 도착에 연동 (#8, #12, §4).

### 3순위 — 파이프라인 정확도
- PTS 기반 레이트 컨트롤로 `batch()` 대체, fps 드리프트·재전송 패딩 제거 (#6).
- temp 파일을 세션별 임시 디렉터리로, `to_mp4`의 오디오 출처 일원화 (#7).
- 런타임 재생성 제거, 스레드풀 통합 (#5).

### 4순위 — 품질/위생
- 비트레이트를 해상도·목표품질 함수로 (#9).
- `tools/image_processing.rs`·`tools/ordqueue.rs`·`batch()`에 Rust 유닛 테스트 추가 (#11).

## 6. 참고 — 이미 반영된 성능 개선

브랜치 `claude/lerobot-video-reader-perf-wt007v`에서 **출력 바이트를 바꾸지 않는** 세 가지 최적화가 적용됨:

| 변경 | 파일 | 효과 |
|---|---|---|
| `rgba_to_yuv` 캐시 지역성(열→행 우선) 재작성 | `tools/image_processing.rs` | 1080p 색공간 변환 34.9ms → 18.3ms (1.9×), 출력 바이트 동일 |
| h264 프레임당 `flush()` → 종료 시 1회 | `domain/recording.rs` | write() 시스콜 감소, 출력 파일 바이트 동일 |
| PCM 오디오 직접 읽기(u16 왕복 루프 제거) | `domain/recording.rs` | 불필요한 복사·홀수 길이 패닉 제거, 전수(65536) 항등 검증 |
