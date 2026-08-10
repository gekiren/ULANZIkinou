# ULANZI CREATIVE DECK プラグイン開発 AIエージェント行動規範 (Project-Scoped Rules)

このプロジェクトで開発を行うAIエージェントは、以下のルールに従わなければなりません。

## 1. 開発フローの絶対遵守
- **ブランチ運用**: ローカルの `master` ブランチで直接開発作業を行ってはなりません。必ず `staging` ブランチで作業します。ユーザー承認後にのみ `master` へマージし、リモートへプッシュします。
- **事前承認**: コードの変更やコマンドの実行を行う前に、必ず日本語で「実装計画（`implementation_plan.md`）」を作成し、ユーザーの承認（Proceed）を得てください。
- **完了報告**: 作業完了時は「完了報告（`walkthrough.md`）」を更新・作成し、検証結果を提示してください。

## 2. 実装仕様の厳守
- **絶対パスの禁止**: プラグイン内部のコードで絶対パス（`C:\Users\...`）をハードコードすることは厳禁です。必ずプラグインルートからの相対パスで記述します。
- **SDKの適用**: コピーした `libs/` 内の共通ライブラリを適切に使用してください。
- **検証**: 動作確認は `KOUSIKI/UlanziDeckPlugin-SDK-main/UlanziDeckSimulator` を使用して行います。
- **実機プラグインフォルダの場所**: 実機検証や配置の際は、必ず以下の公式プラグインフォルダ（Windows環境）を使用してください：
  - `C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins`
- **アイコン画像標準解像度**: プラグインで画像（アイコン）を使用・生成する際は、以下の標準解像度を厳守すること（サイズが大きすぎると実機表示で `?` エラーの原因になります）：
  - プラグインメインアイコン (`icon.png`): **144 x 144 px**
  - アクション表示画像 (`actionDefaultImage.png`): **232 x 232 px**
  - カテゴリ用アイコン (`categoryIcon.png`): **196 x 196 px**
  - アクション用アイコン (`actionIcon.png`): **40 x 40 px**
- **エンコーダーレイアウト(layout.json)の必須キー仕様**:
  - 実機ディスプレイレンダラーが正常に画面描画を行うため、`layout.json` の `items` には必ず `key: "icon"`（画像要素）と `key: "title"`（テキスト要素）の両方のキーを標準配置（例: `rect: [31, 10, 64, 64]` と `rect: [0, 80, 126, 25]`）で揃えて定義しなければなりません。片方を削除したり構造を変更すると、実機側でレイアウトが認識されず描画がキャンセル（非表示・黒画面）されます。
- **プラグインフォルダ命名とUUID完全一致ルール**:
  - 実機プラグインフォルダ `C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins` に配置するプラグインフォルダ名は、必ず `manifest.json` 内の `UUID` と完全に一致させ、末尾に `.ulanziPlugin` を付与した名称（例: `UUID` が `com.ulanzi.videofullscreen` の場合は `com.ulanzi.videofullscreen.ulanziPlugin`）にしなければなりません。不一致や誤命名があると Ulanzi Studio が読み込みを完全に拒否・スキャンをスキップし、アクション一覧に表示されなくなります。
- **デプロイ後の物理ファイル配置検証ルール**:
  - スクリプト等で実機フォルダへデプロイした後は、コマンドの実行成功ログのみに依存せず、必ず `list_dir` 等のツールを用いてデプロイ先 `C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\{UUID}.ulanziPlugin` に `manifest.json` や `plugin/app.js` 等の必要ファイルが物理的にコピー・配置されていることを自律的に検証しなければなりません。
- **プラグイン認識のためのアプリ再起動案内ルール**:
  - 新規プラグインの追加や修正のデプロイ後は、必ずユーザーに対し「タスクバー通知領域（インジケーター）から Ulanzi Studio を完全に終了（Quit）した上で再起動する」よう案内を徹底してください。

