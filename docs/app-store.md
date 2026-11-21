# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.002（枠の使い回し。App Store Connect の App はじぶん実験室のものを、asc の metadata で上書きする） |
| アプリ名 | まわる塔とかくれ猫 / Twirl Tower: Hidden Cats（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261121-twirl-tower/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261121-twirl-tower/blob/main/PRIVACY.md |
| 年齢区分の答え（下書き） | すべて「なし」（暴力・ギャンブル・Web・生成 AI・ユーザー間の交流なし）。4+ 相当の見込み。入力は本人 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：パズルゲーム（錯視の建物 × 猫探し）。懐中電灯・効果音・壁紙・タイマー・占いなどではない。前日までの毎日のアプリと遊び・見た目・部品が違う（Theme・部品は新しく作った）
- 既存のアプリとの意味のある違い：1 枚絵の猫探しと違い、塔を回して見え方と道を変えながら探す。錯視のパズルと違い、向きをそろえるのではなく「探す・歩く」
- 長く使える価値（4.2）：毎日ちがう今日の塔（解けることを作るときに確かめる）、塔 36、猫図鑑 40 匹、続けた日数と灯りの評価
- 他社の名前・商標・見た目を使っていないか：使っていない。錯視の建物を回す仕組みだけを借り、塔の形・色・猫・旅人・名前はオリジナル（Canvas の自作の絵）
- Apple Intelligence：使わない
- 課金の審査：Pro（com.enludus.daily.002.pro、じぶん実験室の商品を使い回し、名前・説明・価格を products で更新）は、このバージョンと一緒に審査に出す（提出は本人）

## 収益の道筋（本人が選ぶ）

- 選んだ形：買い切りの Pro ¥480（非消耗型・家族共有）。広告なし
- 理由と比べた表・勝算の表：README の「課金」

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない、解析・広告 SDK なし、保存は端末の UserDefaults だけ）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。足りない画面は本人と相談。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する
