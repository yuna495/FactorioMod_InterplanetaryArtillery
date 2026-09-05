# Stage 4 - Inter-surface Firing Validation

検証日: 2026-09-05。対象実行環境: Factorio **2.0.77**。

## 結論

**成立。** 同じ `firing.fire()` と既存shot予約表で、Nauvisから
Vulcanus・Glebaへの射撃、900 tick後の指定座標への着弾を確認した。
base-onlyでも別のtest surfaceを使って成立した。同一surfaceは300 tickを維持。
本番GUI、充電、弾薬バランス、惑星間距離、可視飛翔体は追加していない。

## Targeting API

- 第一候補のselection-toolを維持。選択イベントの `surface` と `area` の中心を
  目標として渡す。発射元のsurfaceで上書きしない。
  [公式選択イベント](https://lua-api.factorio.com/latest/events.html#on_player_selected_area)
- `player.surface` は現在のcontroller側、`player.physical_surface` はphysical controller側の
  surfaceを表す。目標をphysical側から推定せず、イベントのsurfaceを採用する。
  [LuaControl](https://lua-api.factorio.com/latest/classes/LuaControl.html#surface)、
  [LuaPlayer](https://lua-api.factorio.com/latest/classes/LuaPlayer.html#physical_surface)
- remote controllerへ切り替える `set_controller` APIは存在するが、今回は視点移動を
  強制しない。planet一覧と、地上を操作するremote viewは同じ入力画面ではない。
  [set_controller](https://lua-api.factorio.com/latest/classes/LuaPlayer.html#set_controller)
- selection-toolがremote viewで実際に操作できるか、custom cursorがplanet切替を
  またいで維持されるか、そこでイベントが発生するかは**マウス操作未確認**。
  イベントの契約だけで一連のUXを実証したとは扱わない。
- playerごとの `storage.player_cannon_targets` は視点・surface・受動的cursor変更で
  消さない。砲をhoverして照準キーを押すと明示的に選択し、hover無しなら保持した砲で
  ツールを再装備する。再装備時と発射時に砲・基礎・forceを検証する。
- 明示的なclear-cursor操作（標準Q）をlinked custom-inputで検知して解除する。
  他playerの選択には触れない。キー割当変更にはゲーム側のcontrol linkageが追従する。
  [CustomInputPrototype](https://lua-api.factorio.com/latest/prototypes/CustomInputPrototype.html#linked_game_control)
- 単体テストでは、別surfaceイベントの転送、2人の選択分離、再装備、取消、無効砲・別force、
  コマンド解析を確認。これはGUIや実際の複数クライアントのテストではない。

### 操作確認用

1. 装填済み砲身にカーソルを合わせ、Control + Shift + Fで射撃元を指定する。
2. `/monolith-shot-status` で指定砲を確認する。ここまででQを押すと指定は解除される。
3. 既存かつ着弾範囲が生成済みの座標に対して、例えば
   `/monolith-fire-surface-test vulcanus 100 100` を実行する。
4. 成功通知にsurface名・15秒・残弾が出る。着弾後は着弾通知を確認する。

上の座標は例であり、通常セーブで生成済みとは限らない。コマンドはsurfaceやchunkを
生成せず、通常経路で1発消費する。surface番号、空白を含む名前（任意で二重引用符）にも対応。
名前が番号と同じ場合は名前を優先する。未指定砲を近隣探索して代用することはない。
remote viewでツールが外れた場合は、砲をhoverせず照準キーで再装備を試せる。

## Inter-surface Shot State

既存の `storage.in_flight_shots[id]` を維持し、次を値として保存する。

```lua
source_force_index, source_surface_index, source_position,
target_surface_index, target_position, player_index,
fire_tick, impact_tick, cannon_unit_number, foundation_unit_number
```

entity番号は履歴であり、着弾にentity参照を要求しない。source/targetは別々に保存済みだったため、
不要な再設計はせずsurface同一制限と飛翔時間選択のみを変更した。
着弾時のforce関係（自軍・friend・cease-fire・neutral除外、enemyへの仮ダメージ）も維持。
目標surfaceの削除・clearは取消、返金なし。発射元だけのsurface削除・clearは取消条件ではない。
取消後のbucket内IDは予定tickに回収され、着弾処理は呼ばれない。

## Chunk Generation

|状態|今回の扱い|
|---|---|
|generated / charted|通常射撃可能|
|generated / uncharted|射撃可能。着弾でもchartしない。実機自動テスト済み|
|ungenerated|半径6の範囲に1chunkでもあれば弾薬消費前に拒否|

有限座標、NaN/無限大、マップ境界と着弾範囲全体の境界チェックを維持。
着弾前にchunkがなくなった場合も着弾時再検証で取消する。

|候補|API上の方式と判断|
|---|---|
|A 発射時に生成済みを要求|今回採用。負荷と結果が予測可能|
|B 発射時に生成要求だけ登録|`request_to_generate_chunks(position, 0)` と後続 `on_chunk_generated` は利用可能。隔離テストで強制生成なしの完了を確認|
|C 着弾前に生成要求|同APIを前倒しで使えるが、指定tickまでの完了保証はない。要求数上限と未完了時の取消・延期仕様が必要|
|D 着弾時に同期生成|`force_generate_chunk_requests()` は待機を伴い、保留要求をまとめて処理する。UPS低下・停止時間の懸念から非推奨|

request-onlyはLua内の同期完了待ちを避けられるが、生成負荷そのものがゼロになるわけではない。
将来候補は重複をまとめたchunk単位要求、要求数上限、生成イベントでの準備完了判定。
今回の生成試験は1要求のみで、大規模負荷や完了期限を保証しない。本番射撃に生成処理は追加していない。
[LuaSurface生成API](https://lua-api.factorio.com/latest/classes/LuaSurface.html#request_to_generate_chunks)、
[生成イベント](https://lua-api.factorio.com/latest/events.html#on_chunk_generated)

## 未訪問Planet

Space Age新規テストでは `game.planets.vulcanus.surface == nil` を確認した。
テストfixtureだけで `LuaPlanet.create_surface()` を実行し、実Vulcanus/Glebaに関連付いた
surfaceを取得、必要chunkを生成して射撃した。プレイヤーの降下は行っていない。
surface作成後も `is_space_location_unlocked("vulcanus") == false` を確認。
したがってsurfaceの存在とforceの解放状態は別条件であり、未訪問でも既存surfaceへの
script着弾は可能。ただし通常プレイでの自然なsurface作成時期やremote viewへのアクセス、
未chart地点のクリック可否までは、このfixtureから結論できない。
本番は存在するsurfaceにのみアクセスし、惑星解放・生成・chartを行わない。
[LuaPlanet](https://lua-api.factorio.com/latest/classes/LuaPlanet.html)、
[force解放状態](https://lua-api.factorio.com/latest/classes/LuaForce.html#is_space_location_unlocked)

## Save/Load

発射100 tick後に実セーブし、別Factorioプロセスで再ロードした。
4発のsurface index、座標、impact tickを照合し、再ロード後の指定surface着弾を確認。
この保存時点では発射元Cannon、別のFoundation、さらに別のsource surfaceを既に削除済み。
既存shotの構造と絶対impact tickは変更せず、Stage 3の飛翔中stateに移行処理は不要。
ただし旧リリースのユーザー実セーブを直接読み込む移行試験は未実施。

## Performance

毎tickは `storage.shots_by_tick[current_tick]` のlookupのみ。期限が来たshotだけ処理する。
全surface・全Foundation・全shotの毎tick走査は追加していない。
surface削除・clearイベントでは既存方式で全shotを走査するが毎tickではない。
生産側の60 tick周期処理は変更なし。同tick多数着弾時の探索・damage負荷は今後の測定対象。

## 自動検証

以下を実際に起動して実行。テスト用MODコピーとセーブは `.codex-test-output` 配下に隔離した。

```powershell
./tests/run-stage3.ps1 -Stage 3
./tests/run-stage3.ps1 -Stage 3 -SpaceAge
./tests/run-stage3.ps1 -Stage 4
./tests/run-stage3.ps1 -Stage 4 -SpaceAge
lua tests/targeting-unit.lua
```

- Stage 3: base-only / Space Ageの新規作成、起動、save/reloadを含め通過。
  tile条件、attachment、2発停止、発射消費、再製造、境界・NaN・無限大拒否、外交除外も回帰確認。
- Stage 4: 両環境で生成・起動・初回試験・save/reloadを含め通過。
  3種類の目標surfaceへ同時予約、期限前無傷、期限時の座標・爆発・damage、source独立性、
  target削除・clear取消、未生成拒否、未chart維持、全shot/bucket回収、再製造を確認。
- Space Age: Nauvis -> Vulcanus / Gleba、同時にNauvis -> Nauvis。
- request-only生成は別test surfaceで完了イベントを確認。武器処理とは分離。
- handler単体テスト通過。Lua構文、require経路、locale、data/runtime分離、差分を静的確認。

headlessの射撃呼出元はplayer index/force/printのアダプタであり、接続済みLuaPlayerではない。
entity、surface、planet、製造、予約tick、damage、セーブは実エンジンを使用した。
耐久値は浮動小数誤差を含むため、ダメージ試験は0.01未満の誤差を許容する。

最終成功ログ（各ディレクトリの `create.log`, `initial.log`, `reload.log`）:

|試験|`.codex-test-output` 内のディレクトリ|
|---|---|
|Stage 3 base|`stage3-0c3fd1448e824bb784b92a87ba832e47`|
|Stage 3 Space Age|`stage3-8f4fef03fef0481abd4e8b69c5058bc3`|
|Stage 4 base|`stage4-7895ab597e3e46bb84dd0b4c79d37ec9`|
|Stage 4 Space Age|`stage4-cdfbcc6c2f5440fe9d1ebd5d1997f068`|

## 実機未確認

- Cannon hoverから照準キー、remote viewへの移動、selection-tool持ち越し。
- planet切替後の実際のマウス選択イベント、地面クリックと矩形選択の体感。
- 未chart地点のmapクリック、planet解放状態ごとのremote viewアクセス。
- 標準Q・再割当clear-cursorによる取消と、planet切替後の再装備。
- 実際の複数クライアント接続。player単位stateの分離は単体テストのみ。
- robot建設・採掘、手動採掘の返却、Blueprintの操作回帰は今回再実施していない。

## 変更ファイル・設計判断

- `SPEC.md`: Stage 4と検証済み構造、取消、暫定的target要件を記録。
- `scripts/firing.lua`: 異surface許可、300/900 tick、照準元保持、通常経路debug command。
- `data.lua`: 明示取消を拾うlinked custom-inputのみ追加。既存graphics・entityは変更なし。
- `locale/en/interplanetary-artillery.cfg`, `locale/ja/interplanetary-artillery.cfg`: surfaceと時間の通知。
- `tests/stage4.lua`, `tests/bootstrap-stage4.lua`: 隔離エンジン試験。
- `tests/targeting-unit.lua`: handlerのsurface転送とplayer分離試験。
- `tests/run-stage3.ps1`, `tests/stage3.lua`: Stage切替と古い異surface拒否テストの更新。
- 本書: API・実測・未確認事項を分離して記録。`control.lua` は変更不要。
- 共有知識 `Notes/Factorio/persistent-delayed-actions.md`: 検証済み生成要求とplanetの注意を追記。

## 未解決事項・SPECとの差異

Stage 4の新規挙動はSPECへ反映済み。remote操作の成立は未検証として残した。
最終planet選択UI、未訪問/未解放planetへの権限、未生成targetの生成方針・上限・期限超過処理、
最終飛翔時間・damage・friendly fireは未確定。surface index指定では惑星以外の既存surfaceも
対象になり得るが、最終的な対象種別制限は今回決めていない。
既存のtile保護は採掘イベント中心で、tile上書き等の完全保護までは未保証。Stage 4とは
別の建設仕様検証として残す。大規模同時着弾のUPS測定も未実施。

公式オンライン `latest` は調査時2.1.17だった。2.0.77への適用は実際の2.0.77起動・API呼出しで
確認し、remote UIなど実行できていない部分はAPIの契約と候補に留めた。
