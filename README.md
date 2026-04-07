# WalkFlow

AirPodsでAIエージェント（OpenClaw）をハンズフリー操作し、歩きながらタスクを完了させるiOSアプリ。

## コンセプト

音声でタスクを指示 → AIがプランを提案 → うなずいて承認 / 首を振って修正 → タスク完了

移動中でもメール送信、Slack投稿、Notion更新などの複雑なタスクを、AirPodsだけで完結できます。

## 操作体系

| ジェスチャー | アクション |
|-------------|-----------|
| **うなずき (Nod)** | AIの提案を承認・実行 |
| **首振り (Shake)** | 却下 → 音声で修正指示 |
| **シングルタップ** | 音声入力 開始/確定 |

## 技術スタック

- **iOS 17+** / Swift 6 / SwiftUI
- **PodStickKit** — AirPodsモーション検出（Nod/Shake）+ タップ検出
- **Speech Framework** — 日本語音声認識（SFSpeechRecognizer）
- **AVSpeechSynthesizer** — TTS応答読み上げ
- **OpenClaw Gateway** — AIエージェントWebSocket通信
- **Zeabur** — OpenClawホスティング（Hetzner K3s）

## アーキテクチャ

```
AirPods (Nod/Shake/Tap)
    ↓ PodStickKit
音声入力 (Speech Framework)
    ↓
TaskOrchestrator (状態マシン)
    ↓ WebSocket
OpenClaw Gateway (Zeabur)
    ↓
Gmail / Slack / Notion / Web
```

### 状態遷移

```
idle ──[Tap]──▶ listening（録音開始）
listening ──[Tap]──▶ sendingToAgent（確定・送信）
sendingToAgent ──[承認要求]──▶ awaitingApproval
awaitingApproval ──[Nod]──▶ executing
awaitingApproval ──[Shake]──▶ listeningModification
executing ──[完了]──▶ taskComplete ──[3秒]──▶ idle
```

## セットアップ

### 前提条件

- Xcode 26+
- XcodeGen (`brew install xcodegen`)
- AirPods Pro/Max（モーション検出対応）
- OpenClaw Gatewayが稼働中（Zeabur等）

### ビルド

```bash
cd WalkFlow
xcodegen generate
open WalkFlow.xcodeproj
```

### 設定

`WalkFlow/App/Config.swift` でOpenClaw Gateway URLとトークンを設定：

```swift
enum Config {
    static let openClawGatewayURL = "wss://your-domain.zeabur.app/"
    static let openClawGatewayToken = "your-gateway-token"
}
```

### テスト

```bash
xcodebuild test -project WalkFlow.xcodeproj -scheme WalkFlow \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## プロジェクト構成

```
WalkFlow/
├── project.yml                          # XcodeGen設定
├── WalkFlow/
│   ├── App/
│   │   ├── WalkFlowApp.swift            # エントリポイント
│   │   └── Config.swift                 # Gateway URL/トークン設定
│   ├── Models/
│   │   ├── TaskState.swift              # 状態マシンenum
│   │   └── OpenClawMessage.swift        # WebSocket JSON型
│   ├── Services/
│   │   ├── OpenClawClient.swift         # WebSocket通信 (actor)
│   │   ├── VoiceInputService.swift      # 音声認識
│   │   ├── SpeechOutputService.swift    # TTS読み上げ
│   │   ├── AudioSessionCoordinator.swift # AudioSession管理
│   │   └── KeychainService.swift        # トークン保存
│   ├── ViewModels/
│   │   └── TaskOrchestrator.swift       # 全サービス統合・状態遷移
│   └── Views/
│       ├── TaskFlowView.swift           # メイン画面
│       ├── ListeningView.swift          # 音声入力UI
│       └── ApprovalView.swift           # 承認待ちUI
└── WalkFlowTests/                       # 51テスト
```

## Phase 2（予定）

- マップ上にタスク実行ピンを表示
- 他ユーザーのタスクフロー閲覧
- タスク実行者とのチャット機能
- バックエンド：Zeabur上に構築

## ライセンス

Private
