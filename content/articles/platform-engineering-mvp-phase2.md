---
title: Platform Engineering MVP Phase 2 構想 — Docker から ECS / App Service へ
description: Phase 1 完走後の次の一手。Adapter 差し替えでクラウドへ Provisioning を伸ばす構想メモ
img: https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=800&q=60
alt: platform engineering phase 2
author:
  name: Fujikeeeen
  bio: All about Fujikeeeen and what he does and where he works
  img: https://images.ctfassets.net/k075a6skjkal/4WuuFsyxjAWaUSr2kW1kGF/33e2adcabde6ded15c44f52520549a96/profile.JPG
tags:
  - web development
---

## はじめに

[Phase 1 の記事](/blog/platform-engineering-mvp) で書いた通り、  
「EDN 1 ファイル → Terraform + MCP」の最小ループはローカル Docker で動いた。

Phase 2 のゴールはシンプル:

> **Docker Adapter を AWS ECS または Azure App Service に差し替えて、同じ Domain Model のままクラウドへ Provisioning する**

まだ実装してない。構想メモ。笑  
でも「何を変えて、何を変えないか」はだいたい見えてるので書いておく。

## Phase 1 から引き継ぐもの

Phase 2 でも **変えない** 前提:

| レイヤ | Phase 1 | Phase 2 でも同じ |
|--------|---------|------------------|
| 入力 | `domain/service.edn` | ✅ 唯一の真実 |
| Compiler | Clojure | ✅ 生成ロジックの中心 |
| Provisioning 出力 | Terraform JSON | ✅ HCL を人間が書かない |
| Operations 出力 | ops-policy.json | ✅ MCP の権限境界 |
| セキュリティ原則 | 危険操作は DSL 未定義 | ✅ destroy/delete/shell なし |

つまり Phase 2 は **Compiler の中の Adapter 層** と **Terraform provider の差し替え** が主戦場。

## Phase 2 で変わるもの

### 1. Provisioning Adapter

Phase 1 の `build-terraform-json` は Docker provider 固定:

```clojure
;; 今: docker_image + docker_container
{:provider {:docker {}}
 :resource {:docker_image {...} :docker_container {...}}}
```

Phase 2 では `:platform` または `:adapter` キーで分岐させるイメージ:

```clojure
{:service :platform-mvp-web
 :environment :dev
 :platform :aws   ;; or :azure

 :container
 {:image "nginx:alpine"
  :cpu 256
  :memory 512
  :port 80}

 :operations {...}}
```

| Adapter | Terraform Target | コンテナ実行基盤 |
|---------|------------------|------------------|
| `:docker` | kreuzwerker/docker | ローカル Docker |
| `:aws` | aws_ecs_* + aws_ecr_* | ECS Fargate |
| `:azure` | azurerm_* | App Service / Container Apps |

**最初は AWS か Azure のどちらか一方** で十分。両方いきなりやると Compiler が太る。

### 2. Operations Adapter（MCP 側）

Phase 1 の MCP は `docker ps` / `docker logs` / `docker restart` 相当を ProcessBuilder で叩いてる。

クラウドに上げると Day-2 Ops の実装が変わる:

| 操作 | Docker (Phase 1) | AWS (Phase 2 案) | Azure (Phase 2 案) |
|------|------------------|------------------|---------------------|
| get_status | container running? | ECS service desired/running count | App Service state |
| get_logs | docker logs | CloudWatch Logs | Log Stream / App Insights |
| restart_service | docker restart | ECS force new deployment | App Service restart |

**ops-policy.json の形は維持** して、MCP Server 内部で Adapter を切り替える。

```text
tools/call "get_logs"
    → ops-policy で role チェック
    → adapter: docker | aws | azure
    → 各 SDK / CLI を引数配列で実行（shell 文字列禁止は継続）
```

### 3. Domain Model の拡張（最小）

Phase 1 の `:container` は `:host-port` 前提。クラウドでは:

```clojure
{:container
 {:image "nginx:alpine"
  :cpu 256
  :memory 512
  :port 80}

 :network
 {:public? true
  ;; AWS: target group / ALB
  ;; Azure: App Service の公開設定
  }

 :platform :aws
 :region "ap-northeast-1"}
```

`:operations` の `:roles` / `:approval` は **そのまま**。  
Provisioning が変わっても「誰が restart できるか」は Domain Model が決める、という Phase 1 の設計を守る。

## 想定アーキテクチャ（Phase 2）

```text
                 domain/service.edn
                   (+ :platform :region)
                        │
                        ▼
                Clojure Platform Core
                   /            \
          Adapter: AWS      Adapter: Azure
                 │                │
                 ▼                ▼
        main.tf.json (ECS)   main.tf.json (App Service)
                 │                │
                 ▼                ▼
           AWS ECS Fargate    Azure App Service
                 │                │
                 └────────┬───────┘
                          ▼
                   ops-policy.json
                          │
                          ▼
              MCP Server (role + adapter)
                          │
              get_status / get_logs / restart_service
```

## AWS vs Azure、どっちから？

個人的な Phase 2 第一候補は **AWS ECS Fargate**:

- Terraform の ECS リソースは情報が多い
- CloudWatch Logs との接続が素直
- Phase 3（IAM 生成）への道筋が見えやすい

Azure App Service もアリ。社内標準が Azure なら `:platform :azure` からでいい。  
**Adapter インターフェースを先に決める** のが Phase 2 の設計勝負。

## Phase 2 の完了条件（案）

- [ ] `domain/service.edn` に `:platform` を追加しても Phase 1（Docker）が壊れない
- [ ] `:platform :aws`（または `:azure`）で Terraform JSON が生成される
- [ ] `terraform apply` で nginx 相当がクラウド上で動く
- [ ] MCP の 3 操作（status / logs / restart）がクラウド Adapter 経由で動く
- [ ] Operator / SRE の role 分離と `approved=true` が Phase 1 同等に効く
- [ ] ユニットテスト + 手動 E2E

## ハマりそうなポイント（先に書いておく）

### State と環境

ローカル Docker は `terraform state` が手元で済む。  
クラウドは **remote state（S3 + DynamoDB / Azure Storage）** が現実的。  
Phase 2 の README に bootstrap 手順が必要になる。  
→ 手順の詳細は別記事: [Phase 2 bootstrap — Terraform remote state を先に用意する](/blog/platform-engineering-mvp-phase2-bootstrap)

### 認証

Phase 1 は Docker socket だけ。  
Phase 2 は `AWS_PROFILE` / `az login` / OIDC（GitHub Actions）あたりが絡む。  
Phase 3 で IAM を Domain Model から生成する前の **暫定認証** をどう置くか。

### コスト

Fargate / App Service は放置すると課金される。  
MVP 用に `:environment :dev` + `terraform destroy` 手順（人間が実行、MCP からは不可）を README に明記。

### ホットリロード問題の継続

Phase 1 と同じ:

```text
service.edn 変更 → generate → terraform apply（手動）
```

Phase 2 では apply 時間が伸びる。CI/CD パイプライン化は Phase 2.5 くらいの話。

## Phase 3 以降との接続

Phase 2 が動けば、次は README 通り:

```text
Phase 2: AWS ECS or Azure App Service   ← 今ここ（構想）
Phase 3: IAM / Managed Identity を Domain Model から生成
Phase 4: MCP Gateway + Catalog
Phase 5: Approval / Audit / Rate Limit
Phase 6: AI Operator
```

Phase 2 で `:platform` と Adapter 境界をきれいに切っておくと、Phase 3 の IAM 生成は **Adapter ごとの Policy テンプレート** として足せる。

## おわりに

Phase 2 は「クラウド対応」というより **Adapter パターンの証明**。

- Domain Model（EDN）は 1 つのまま
- Compiler が Provisioning / Operations の両方を生成
- 実行基盤だけ Docker → クラウドに差し替え

Phase 1 で「存在しない操作は存在しない」を固めたので、Phase 2 では **クラウドの便利機能に引っ張られて destroy ツールを足さない** のが精神継続。

実装はまだ。Issue 切ってから着手する予定。  
進捗出たらまたブログに書く。

## 関連リンク

- [Phase 2 bootstrap 手順](/blog/platform-engineering-mvp-phase2-bootstrap)
- [Phase 1 記事](/blog/platform-engineering-mvp)
- リポジトリ: https://github.com/FuJiK/platform-engineering-mvp
- Phase 1 journal: https://github.com/FuJiK/platform-engineering-mvp/blob/main/docs/phase1-journal.md
