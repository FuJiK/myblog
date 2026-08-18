---
title: EDN 1 ファイルから Terraform と MCP を生やす Platform Engineering MVP を作った話
description: Clojure + EDN + Terraform + MCP で Phase 1 を完走した Platform Engineering MVP のまとめ
img: https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=800&q=60
alt: platform engineering mvp
author:
  name: Fujikeeeen
  bio: All about Fujikeeeen and what he does and where he works
  img: https://images.ctfassets.net/k075a6skjkal/4WuuFsyxjAWaUSr2kW1kGF/33e2adcabde6ded15c44f52520549a96/profile.JPG
tags:
  - web development
---

## はじめに

Platform Engineering って、だいたいこういう話になる。

- 開発者は「アプリを動かしたい」
- インフラ屋は「安全に・再現可能に・権限付きで」
- SRE は「壊れたら直したいけど、delete はさせたくない」

この三者の要求を、**1 つの Domain Model から Provisioning（作る）と Operations（運用する）の両方を生成する**、という発想で小さく実証する MVP を Clojure で作った。リポジトリは [FuJiK/platform-engineering-mvp](https://github.com/FuJiK/platform-engineering-mvp)。

Phase 1 はローカル Docker + nginx で完走済み。  
正直、しばらくメンテしてない。笑 でも「何を証明しようとしたか」は README と journal に残ってるので、久々に整理しておく。

## この MVP で証明したかったこと

利用者（開発者・AI Agent 含む）が **Terraform を直接書かず**、EDN で「意図」を宣言するだけで:

1. **Provisioning Plane** — Terraform JSON → Docker コンテナ
2. **Operations Plane** — ops-policy.json → MCP Server（ロール別ツール公開）

の 2 本が同時に生える、という流れ。

さらにセキュリティ上の意図として:

| 原則 | 内容 |
|------|------|
| 危険操作は DSL 未定義 | `delete` / `destroy` / 任意 shell は Domain Model に存在しない |
| Tool として未実装 | MCP にそもそも載せない |
| 一覧にも出さない | `tools/list` に含めない |
| 実行時再検証 | role を毎回チェック |
| shell 文字列禁止 | `ProcessBuilder` に引数配列で渡す |

「権限がないからダメ」だけでなく、**存在しない操作は存在しない**、という設計。

## アーキテクチャ（Phase 1）

```text
                 domain/service.edn
                        │
                        ▼
                Clojure Platform Core
                        │
           ┌────────────┴────────────┐
           ▼                         ▼
 generated/main.tf.json      generated/ops-policy.json
           │                         │
           ▼                         ▼
       Terraform                 MCP Server
           │                         │
           ▼                         ▼
      Docker / nginx        status / logs / restart
```

**唯一の入力**は `domain/service.edn`:

```clojure
{:service :platform-mvp-web
 :environment :local

 :container
 {:image "nginx:alpine"
  :host-port 8080
  :container-port 80}

 :operations
 {:get-status
  {:roles #{:operator :sre}}

  :get-logs
  {:roles #{:operator :sre}
   :max-lines 200}

  :restart-service
  {:roles #{:sre}
   :approval :required}}}
```

ここから Clojure Compiler が:

- `generated/main.tf.json` — Docker provider で nginx コンテナ
- `generated/ops-policy.json` — ロール別 Operations Policy

を生成する。

## ロール別 MCP の挙動

MCP Server は `PLATFORM_ROLE` 環境変数で起動ロールを切り替える。

### Operator

```bash
PLATFORM_ROLE=operator clojure -M:mcp
```

公開ツール: `get_status`, `get_logs` のみ。  
`restart_service` は `tools/list` に出ない。直接 `tools/call` されてもサーバー側で拒否。

### SRE

```bash
PLATFORM_ROLE=sre clojure -M:mcp
```

公開ツール: `get_status`, `get_logs`, `restart_service`。  
`restart_service` は **`approved=true` 必須**:

```json
{
  "name": "restart_service",
  "arguments": {
    "approved": true
  }
}
```

「SRE だからいきなり再起動できる」ではなく、**明示承認を引数で要求する**のが Phase 1 のルール。

## 動かし方（最短）

```bash
# 1. 生成
clojure -M:generate

# 2. Provisioning
cd generated && terraform init && terraform apply

# 3. 確認
curl http://localhost:8080

# 4. テスト
clojure -M:test
```

MCP は stdio の JSON-RPC。Cursor から使うなら `mcp-client-config.example.json` を参考に Server 登録。

## 開発でハマったところ（journal より）

[docs/phase1-journal.md](https://github.com/FuJiK/platform-engineering-mvp/blob/main/docs/phase1-journal.md) に詳細あるけど、要点だけ。

### Clojure CLI の罠

`apt install clojure` だと古い JVM ラッパーで、`deps.edn` の `-M:alias` が使えない。  
**公式 Clojure CLI**（clojure.org）が必要。地味にここで時間取った。

### MCP の role 比較バグ

`ops-policy.json` の role は文字列 `"operator"`、実行時 role はキーワード `:operator`。  
`contains?` で直接比較してたら常に失敗 → `tools/list` が空、`get_status` も拒否。

修正: `policy.clj` で `role-name` 正規化して比較。回帰テスト `role-allowed-matches-json-string-roles` 追加。

### ホットリロードはない

`service.edn` を変えても自動反映されない。

```text
service.edn 変更
    → clj -M:generate（手動）
    → terraform apply（手動、コンテナ再作成）
```

Platform Engineering あるある。Phase 2 以降で CI/CD や watch 系を考える余地あり。

## Phase 1 完了条件（全部クリア済み）

- EDN から Terraform JSON / ops-policy を生成
- Terraform で nginx コンテナをプロビジョニング
- MCP Server がロール別にツール公開
- 危険操作がツールとして存在しない
- `restart_service` が SRE + 明示承認のみ
- ユニットテスト通過
- E2E 動作確認（Provisioning + Operations）

## 今後のロードマップ（README より）

```text
Phase 1: Docker + nginx      ← 今ここ（完了）
Phase 2: AWS ECS or Azure App Service
Phase 3: IAM / Managed Identity を Domain Model から生成
Phase 4: MCP Gateway + Catalog
Phase 5: Approval / Audit / Rate Limit
Phase 6: AI Operator
```

本番化するときは Cloud IAM / Managed Identity、OIDC、監査ログ、Rate Limit、Approval Service、MCP Gateway / Catalog を足す想定。

## 技術スタック

| レイヤ | 技術 |
|--------|------|
| Domain Model | EDN (Clojure data) |
| Compiler / Policy | Clojure 1.12 |
| Provisioning | Terraform JSON + Docker provider |
| Operations | MCP (stdio JSON-RPC) |
| 検証 | nginx:alpine on localhost:8080 |

License: MIT — Copyright (c) 2026 K_fujiokA

## おわりに

「Platform Engineering を語る前に、**1 ファイルの EDN から Provisioning と Day-2 Ops が分岐する**最小ループを動かす」——それが Phase 1 のゴールだった。

メンテはサボってるけど、Phase 1 としては動く。  
次に手を入れるなら Phase 2（Docker Adapter → ECS / App Service 差し替え）か、MCP Gateway 周りが自然な続き。

興味ある人は [リポジトリ](https://github.com/FuJiK/platform-engineering-mvp) 見てみて。Issue や PR も welcome。

## 関連リンク

- リポジトリ: https://github.com/FuJiK/platform-engineering-mvp
- Phase 1 開発 journal: https://github.com/FuJiK/platform-engineering-mvp/blob/main/docs/phase1-journal.md
- MCP 手動疎通例: リポジトリ README の「5. MCPを手動で疎通確認」
