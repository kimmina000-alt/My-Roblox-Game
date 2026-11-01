# 슬라임 게임 새 프로젝트

이 폴더는 Roblox Studio에서 올바른 서비스 트리로 동기화하기 위한 Rojo 프로젝트 소스입니다. `.luau` 파일을 통째로 Workspace에 끌어다 놓는 방식으로 적용하지 않습니다.

## 폴더가 들어갈 Explorer 위치

| 컴퓨터의 경로 | Studio Explorer |
|---|---|
| `src/ReplicatedStorage/Shared` | `ReplicatedStorage/Shared` (ModuleScript) |
| `src/ServerScriptService/Bootstrap.server.luau` | `ServerScriptService/Bootstrap` (Script) |
| `src/ServerScriptService/Services` | `ServerScriptService/Services` (ModuleScript들) |
| `src/StarterPlayer/StarterPlayerScripts` | `StarterPlayer/StarterPlayerScripts` (LocalScript) |

## 파일 종류 구분

파일 이름 끝부분이 Roblox 인스턴스 종류를 정합니다. 파일 확장자 `.luau`는 소스 코드 형식이고, `Bootstrap.server` / `.client`가 실행 위치와 종류를 구분합니다.

| 파일 | Roblox에서 만들 인스턴스 종류 | 위치 |
|---|---|---|
| `Bootstrap.server.luau` | **Script** (서버에서 실행) | `ServerScriptService` |
| `SlimeGameController.client.luau` | **LocalScript** (플레이어 화면에서 실행) | `StarterPlayer > StarterPlayerScripts` |
| `DisplayShelfController.client.luau` | **LocalScript** | `StarterPlayer > StarterPlayerScripts` |
| `SlimeInteractionController.client.luau` | **LocalScript** | `StarterPlayer > StarterPlayerScripts` |
| `PumpController.client.luau` | **LocalScript** | `StarterPlayer > StarterPlayerScripts` |
| `CollectionBookController.client.luau` | **LocalScript** | `StarterPlayer > StarterPlayerScripts` |
| `Services` 폴더 안의 모든 `.luau` | **ModuleScript** (직접 실행하지 않고 `require`로 불러옴) | `ServerScriptService > Services` |
| `Shared` 폴더 안의 모든 `.luau` | **ModuleScript** | `ReplicatedStorage > Shared` |

Rojo로 동기화하면 위 종류와 위치를 자동으로 만들어 줍니다. 수동으로 Studio에 만들 때는 위 표대로 먼저 `Script`, `LocalScript`, `ModuleScript`를 만들고, 해당 파일의 코드를 각각 붙여 넣어야 합니다. 특히 `Services` 폴더 안의 파일은 Script나 LocalScript가 아니라 전부 ModuleScript입니다.

`Workspace`에 스크립트가 통째로 들어가는 구조가 아닙니다. 서버 기능은 `ServerScriptService`, 공용 설정은 `ReplicatedStorage`, 화면 코드는 `StarterPlayerScripts`에서 실행됩니다. `WorldSetupService`만 테스트용 맵 파트를 자동으로 `Workspace`에 만듭니다.

## 처음 열기

1. Roblox Studio에서 빈 Baseplate place를 엽니다.
2. Rojo CLI와 Studio용 Rojo 플러그인을 설치합니다. Rojo 공식 문서의 프로젝트 형식 및 시작 안내를 따릅니다.
3. PowerShell에서 이 폴더로 이동해 `rojo serve`를 실행합니다.
4. Studio에서 Rojo 플러그인을 열어 연결한 뒤, 동기화된 Explorer 트리를 확인합니다.
5. Studio의 **View > Output**을 켜고 Play를 눌러 첫 오류를 확인합니다.

Rojo CLI가 있는 환경에서는 `rojo build -o SlimeGame_Rebuild.rbxlx`로 Studio에서 열 수 있는 place 파일을 만들 수도 있습니다. 현재 이 작업 환경에는 Rojo CLI가 설치되지 않아 `.rbxlx` 빌드와 Studio 실행 검증은 하지 않았습니다.

## 새 place가 자동 생성하는 시험 맵

`WorldSetupService`는 `HousingPlots` 아래 시험용 plot 하나를 만들고, `PlotService`가 이를 최대 15개로 복제합니다. 시험 plot에는 Zone 1~3, 토핑 배치 패드, 진열장, 펌프, 캡슐 기계가 있습니다. 전역 세척 기계와 세척대도 생성됩니다. 아트 작업이 끝나면 이 시험용 생성 코드를 실제 맵 자산으로 교체하면 됩니다.

DataStore 저장을 시험하려면 Studio의 Game Settings에서 place를 게시하고 **Security > Enable Studio Access to API Services**를 켜야 합니다. 설정이 없으면 Studio 세션은 임시 데이터로 동작하고 저장하지 않습니다.

## 지금 포함된 기능

- 플레이어 데이터 로드/저장, 골드, 인벤토리, 옛 이름 데이터의 기본 변환
- 더러운 토핑 획득 및 세척 보상
- 더러운 토핑이 있을 때만 세척대 프롬프트가 보이며, 누른 채 드래그/터치한 지점만 부드러운 경계로 세척; 얼룩 전부와 전체 세척 영역을 닦으면 완료, 보상 토핑을 0.55초 보여 준 뒤 완료 효과
- 더러운 토핑은 받으면 Tool로 손에 들림
- 세척 보상인 깨끗한 토핑도 자동으로 손에 들리며, 인벤토리 선택창에서 다른 토핑으로 바꿔 들 수 있음
- 메인 메뉴의 `가방 보기` 창에서 세척 전 토핑과 베이스/토핑/염료/향료 등 Craft Basket 재료를 확인하고, 배치할 베이스나 토핑을 선택; 열린 가방 내용도 인벤토리 변경 이벤트로 실시간 갱신
- 세척 전 토핑도 가방에서 다시 선택 가능; 패드 배치는 서버에서도 손에 든 깨끗한 토핑 ID를 확인해 선택된 토핑만 배치 허용
- 세척 테스트 보상은 ItemCatalog의 `CleaningWeight` 설정으로 관리: 구슬 토핑 60, 크런치 폼볼 30, 바삭한 칩 10; 새 보상은 깨끗한 Craft 토핑에 가중치를 추가하면 자동 후보에 포함
- 중앙 하단 한 칸 토핑 슬롯에 선택 토핑과 수량 표시
- 구역마다 넓은 배치 영역 하나가 있으며, 슬롯에서 토핑을 고른 뒤 영역 안 원하는 위치를 클릭해 배치; 놓인 토핑을 클릭해 회수
- 노동자는 빈 베이스 패드에 고용 즉시 배치되며, 배치된 노동자는 해금된 구역의 패드들을 순찰하고 베이스 슬라임 위에서만 걸음 수익을 냄; 배치할 베이스가 없으면 인벤토리에 보관
- 개인 진열장 보관/회수
- 개인 진열장 GUI는 5열×2행 10칸(1~5 윗줄, 6~10 아랫줄)이며, 빈 칸을 누르면 손에 든 아이템이 들어가고 찬 칸을 누르면 회수; 월드 진열판도 같은 번호/위치로 표시
- 베이스 받침 영역은 납작한 구역 패드로 두고 베이스를 반투명하게 올린 뒤, 그 위 원하는 위치를 클릭해 토핑을 배치
- 베이스 회수 확인 후 해당 패드의 토핑과 베이스를 함께 가방으로 되돌림
- 베이스가 놓인 패드에서만 6스터드 이동할 때 걸음 보상 지급: 베이스 기본 0.4G에 토핑 등급별로 일반 +0.5G, 레어 +1G, 에픽 +1.5G, 레전더리 +2G, 신화 +2.5G를 각각 더함; 노동자도 같은 수익 계산을 사용하고 보상은 소유자의 골드로 합산
- 베이스 아이템별 토핑 중력 배율과 발소리 식별 키를 데이터로 설정; 실제 중력 물리와 사운드 재생은 물리 슬라임/오디오 에셋 작업 때 연결
- 개인 구역의 베이스 펌프: 가까이 가면 긴 읽기 전용 잔량 바 표시, 투명 통 속 액체 높이가 용량에 맞춰 변함. 펌프가 가득 차면 블록/액체 클릭 한 번에 베이스 1개를 받고 잔량은 비워짐. 용량/자동 충전 강화는 펌프 UI에서 가능.
- 넓은 구역 패드에 베이스를 반투명한 두께감 있는 충돌 파트로 깔고 실제로 그 위를 걸을 수 있음; 밟으면 베이스 파트가 눌렸다 복원, 같은 베이스 영역 내부를 클릭해 토핑 배치
- 베이스 재료별 ToppingGravityScale 설정을 토핑 표시물에도 저장; 토핑은 현재 고정 표시물이라 실제 중력 물리는 추후 물리 슬라임과 연결
- 플레이어나 노동자가 패드에서 걸음 보상을 받을 때 해당 아바타 뒤에 실제 적립량을 띄운 뒤 위로 올려 사라지게 표시
- 베이스 회수 확인창에서 패드 위 토핑 전체 회수를 안내하고, 승인하면 베이스와 토핑을 함께 바구니로 이동
- 무료 가챠 코인과 보호 보관함
- 골드 구역 해금 및 단계 환생
- 등급별 아이템 도감: 일반/레어/에픽/레전더리/신화 순서, 등급색 배경, 미발견 실루엣과 발견 후 아이콘, 스크롤 및 새 아이템 자동 분류

## 개발 순서: 내 슬라임 구역부터 완성, PvP는 마지막

1. **수집/보관 루프**: 토핑 기계 → 세척 → 바구니/한 칸 선택 → 토핑 패드 배치 및 회수. 이어서 베이스 펌프 → 베이스 선택 → 전용 베이스 패드 배치 및 회수를 연결한다.
2. **도감과 확장 데이터**: ItemCatalog에 아이템을 추가하면 등급별 도감과 보유 목록에 자동 노출되도록 유지한다. 시험용 토핑은 일반/레어/에픽 세 종류로 시작하고, 추후 레전더리/신화를 추가한다.
3. **슬라임 제작**: 베이스와 응고제를 조합하는 구역 내 제작기를 만들고, 배합 비율로 점도/단단함/토핑 수용량 및 생산량을 계산한다. UI와 수치는 코드와 분리된 설정값으로 둔다.
4. **구역 성장**: 제작한 슬라임을 진열/성장시키고, 토핑 효과·노동자·구역 확장이 실제 제작물과 연결되도록 한다.
5. **구역 플레이 마감**: 펌프/세척/배치/제작/회수/저장 흐름을 Studio에서 플레이하며 Output 오류와 모바일 입력을 확인한다. 실제 ASMR 사운드와 최종 비주얼을 연결한다.
6. **환생 규칙 확정**: 기존 구현은 골드, 재료, 배치물, 구역, 펌프를 초기화할 수 있으므로 플레이어 소지 아이템 보존 정책을 확정한 다음 손실 범위를 맞춘다. 도감/한정 보관함/누적 골드/환생 보너스는 보존하는 안을 권장한다.
7. **PvP**: 개인 구역의 수집-제작-성장과 저장이 안정된 다음 별도 작업으로 시작한다.

현재 베이스 펌프는 클리어 베이스를 퍼 줍니다. 다른 베이스/응고제/염료는 카탈로그와 바구니 지원을 준비했으며, 조합 제작기와 효과 계산은 아직 구현 전입니다. 대전 모드와 ASMR 오디오 자산은 아직 연결하지 않았습니다. 임의의 사운드 ID나 유료 상품 ID를 넣지 않았습니다.
