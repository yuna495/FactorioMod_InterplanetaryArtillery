# Stage 3 検証結果

検証日: 2026-09-05。対象実行環境: Factorio 2.0.77。

## 結論

製造 → 内部装填 → 発射時に1発消費 → 300 tick後に着弾 → 再製造、
という射撃処理のループをheadless実行で確認した。
飛翔中に実際に保存し、別のFactorioプロセスで読み込んでも予定tickを維持した。
通常プレイヤーのキー入力とマウス操作は実機確認が必要。

| 検証項目 | 判定 | 根拠・制限 |
| --- | --- | --- |
| Cannon targeting | 実現可能 | custom-inputで砲を明示指定し、selection-toolの座標を受け取る。実際のキー入力・クリックは未検証。 |
| Delayed impact | 実現可能 | 保存された予約を300 tick後に処理。爆発entity生成、敵へのダメージを実エンジンで確認。 |
| Long-range same-surface fire | 制限あり | 約14,000タイル離れた座標 (10016, 10016) で確認。武器の射程制限はないが、生成済み地形とマップ座標範囲が必要。 |
| Uncharted target | 制限あり | 生成済み・未chartの座標への射撃と、着弾でchartしないことを確認。未生成領域は弾薬を消費せず拒否。黒いマップ上のクリック可否は実機確認が必要。 |
| Save/load | 実現可能 | 飛翔中の3発を保存して別プロセスで再開。全弾の期限、着弾、削除と、生存中の別設備のattachmentを確認。 |

## 操作

1. Foundationで試験弾を製造する。
2. 中央のCannonにカーソルを合わせて `Control + Shift + F`。
3. 射撃元の砲番号と残弾のメッセージを確認する。
4. 照準ツールで同一surfaceの地面を選択する。ドラッグした場合は範囲中央が目標。
5. 発射時に1発減り、通常速度で5秒後に着弾する。ツールを戻すと照準終了。

補助コマンド:

```text
/monolith-fire-test 100 100
/monolith-shot-status
/monolith-status
```

射撃コマンドは照準モードで明示指定した砲だけを使う。近くの別の砲へ自動変更しない。
コマンドの座標はプレイヤーが現在操作しているsurfaceに属する。
射撃元とは違うsurfaceなら拒否する。サーバーコンソールからの射撃は対象外。
照準キーはFactorioの操作設定で変更できる。

## 射撃stateと性能

`storage.in_flight_shots[id]` が予約本体。
IDは `storage.next_shot_id` で単調増加させる。
各予約に砲・基礎のunit number、source force index、source/target surface index、
コピーしたsource/target position、player index、fire_tick、impact_tickを格納する。
source entityへの参照は保存せず、着弾時にも参照しない。

`storage.shots_by_tick[impact_tick]` はそのtickに着弾するIDの配列。
毎tickの射撃処理は現在tickのbucketを1回参照するだけ。
着弾がある場合のみ、そのbucketの弾を処理し、各目標周辺を検索する。
処理済み予約はdamageイベントを起こす前に削除し、二重処理を防ぐ。

射撃待機コストはFoundation総数・飛翔中の総弾数に依存しない。
着弾コストは同じtickの弾数と着弾範囲内entity数に依存する。
保存領域は飛翔中の弾数に比例する。
既存の生産処理は引き続き60 tickごとに生産監視対象のFoundationのみを確認する。
surface削除・force統合時と状態表示コマンドでは、必要に応じて飛翔中の弾を走査する。
多数の同時着弾による負荷集中は、次段階で負荷測定が必要。

## ダメージと地形

仮設定は半径6、250 explosion damage。baseの `big-explosion` を再利用する。
自軍・中立・友好・停戦相手は除外し、残る陣営の破壊可能な有耐久entityへダメージを与える。
source forceをダメージ帰属に使い、友好・停戦関係は着弾時点で評価する。
通常の耐性は適用される。爆発の画像データや音声データの複製はしていない。

生成済みとchart済みは別の状態。射撃処理はchart済みであることを要求しない。
ただし着弾範囲が触れるチャンク（現在の半径では最大4個）がすべて生成済みである必要がある。
未生成地形に対する生成要求、強制生成、地形破壊、マップ開示は実装していない。
生成APIは存在するが、`force_generate_chunk_requests()` は未完了の生成要求全体を
同期処理するため、射撃処理に組み込むと停止時間を発生させ得る。
将来の生成方式は、対象範囲と負荷上限を決めてから追加する。

座標は有限数か確認し、原点から各方向100万タイルの上限と有限マップ寸法を考慮する。
着弾範囲全体が境界内に収まる必要がある。
飛翔中に目標surfaceが削除・クリアされた場合、または着弾チャンクが失われた場合は
返金なしで取り消す。force統合では帰属先を移す。
これらの例外経路は実装とAPI照合までで、今回の自動テストには含めていない。

## 変更ファイル

| ファイル | 役割 |
| --- | --- |
| SPEC.md | Stage 3、検証済み製造方式、射撃・未生成地形・取消条件を明記。Out of Scopeとの矛盾を整理。 |
| control.lua | 射撃モジュールの初期化とイベント登録、生産再開関数の接続。 |
| scripts/firing.lua | 砲指定、照準、発射検証、消費、予約、着弾、例外処理、補助コマンド。 |
| data.lua | custom-inputとカーソル専用selection-tool、砲の選択優先度。 |
| locale/en/interplanetary-artillery.cfg | 英語の操作名・通知。 |
| locale/ja/interplanetary-artillery.cfg | 日本語の操作名・通知。 |
| tests/bootstrap.lua | 隔離コピーだけでテストコードを読み込む入口。 |
| tests/stage3.lua | 実エンジン上の製造・射撃・保存テスト。 |
| tests/run-stage3.ps1 | 専用MOD一覧・設定・保存先を作ってテストを起動。 |
| tests/server-settings.json | 公開・LAN通知を無効化するローカル試験設定。 |
| STAGE3-VALIDATION.md | この報告。 |

通常のcontrol.luaからtestsは読み込まれない。依存MODは追加していない。
共有ナレッジには `Notes/Factorio/persistent-delayed-actions.md` を追加した。

## 自動検証

baseのみ、およびSpace Age・quality・elevated-rails有効の構成で実行。
通常のセーブ・MOD一覧とは独立した `.codex-test-output/` 内の環境を使用した。
テスト用の呼び出し元はLuaPlayer相当の最小adapterで、実際の接続プレイヤーではない。
電力も試験用に直接供給する。レシピの進行・材料消費・出力変換・予約・爆発・damage・
tick・保存ファイル・再読み込みは実際のFactorio処理を使用する。

確認した内容:

* 新規マップロード、タイル条件による設置許可・拒否、砲と基礎の相互関連付け。
* 鉄板からの2発製造、2発時の生産停止。
* 0発、別surface、存在しない砲、force不一致、未生成座標、NaN、無限大、境界外の拒否。
* 不正要求で残弾が変わらないこと、1発ずつの消費、連続2発と3発目拒否。
* 砲だけの削除で基礎が残ること、基礎削除時の砲cleanup。
* 発射元を削除した3発が予定tickより前にはダメージを与えず、予定tickに着弾すること。
* 爆発entityの生成、敵へのdamage、友好・中立・停戦・自軍の除外。
* 未chartの遠距離座標への着弾とchart状態の維持。
* 飛翔中の保存、別プロセスでの読み込み、3発の期限保持と一度だけの着弾。
* 生存中の別設備の関連付けが読み込み後も保持されること。
* 発射後に実際の製造が進み、再び内部装填されること。

Lua構文、require先、baseのsprite・爆発prototype、差分の空白エラーも確認した。
再実行は `tests/run-stage3.ps1`、Space Age構成は `tests/run-stage3.ps1 -SpaceAge`。
テストはローカル接続のみで起動し、完了マーカーを確認後に試験プロセスを停止する。

## 実機確認・未解決事項

* 砲のhover → キー入力 → ツール取得 → 地面クリック／ドラッグの一連の操作。
* マップ・リモートビューでの操作surface、未chart領域でのクリック可否。
* 実際のコマンド通知・日本語表示、カーソルの戻し操作、満杯インベントリ。
* 複数クライアントから同じ砲を操作した場合。処理は逐次検証し、player stateは個別保存するが、クライアント間の同期テストは未実施。
* 既存プレイヤーセーブでの移行。storageは追加初期化方式で既存loaded_shotsを削除しないが、ユーザーのセーブ自体は変更・試験していない。
* robot採掘・建設、ghost、blueprint、基礎下タイルの採掘復元は既存処理を維持し、今回の自動試験では未再検証。
* 既存SPEC 4.3はタイルの置換も扱うが、現在の保護処理は採掘イベントが中心で、別タイルでの上書きや他MODによるset_tilesを保証していない。この既存差異は射撃実装では変更していない。
* 未生成目標への生成許可・生成量、最終AoE・友軍誤射規則・飛翔時間、同時着弾の負荷上限は次段階の仕様決定事項。

Stage 3で選択した射撃方式と制限はSPEC 9.2に反映した。
惑星間砲撃・充電・自動索敵・最終弾薬・最終演出はFuture Scopeのまま。

## API根拠

参照時点のオンライン最新ドキュメントは2.1.17だったため、新APIであることを
根拠に2.0への対応を推測せず、採用した実装をローカル2.0.77でロード・実行した。
selection-toolの定義形式と画像参照はローカルbase sourceも確認した。

* [SelectionToolPrototype](https://lua-api.factorio.com/latest/prototypes/SelectionToolPrototype.html) と [SelectionModeFlags](https://lua-api.factorio.com/latest/types/SelectionModeFlags.html): `nothing` でentityやtileを列挙せず領域を選択。
* [on_player_selected_area](https://lua-api.factorio.com/latest/events.html#on_player_selected_area): 選択surfaceとareaを受け取る。
* [CustomInputPrototype](https://lua-api.factorio.com/latest/prototypes/CustomInputPrototype.html): 砲を明示指定するキー入力。
* [LuaSurface](https://lua-api.factorio.com/latest/classes/LuaSurface.html): chunk生成状態確認、entity生成・検索と生成API。
* [MapGenSettings](https://lua-api.factorio.com/latest/concepts/MapGenSettings.html): 有限マップ寸法と原点から各方向100万タイルの上限。
* [LuaForce](https://lua-api.factorio.com/latest/classes/LuaForce.html): 友好・停戦関係によるダメージ対象の判定。
* [LuaGameScript.server_save](https://lua-api.factorio.com/latest/classes/LuaGameScript.html#server_save): multiplayerでの実保存。
