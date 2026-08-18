---
title: Platform Engineering MVP Phase 2 bootstrap — Terraform remote state を先に用意する
description: Phase 2 で必要になる S3 + DynamoDB / Azure Storage の bootstrap 手順。鶏と卵問題をどう解くか
img: https://images.unsplash.com/photo-1558494949-ef010cbdcc31?auto=format&fit=crop&w=800&q=60
alt: terraform remote state bootstrap
author:
  name: Fujikeeeen
  bio: All about Fujikeeeen and what he does and where he works
  img: https://images.ctfassets.net/k075a6skjkal/4WuuFsyxjAWaUSr2kW1kGF/33e2adcabde6ded15c44f52520549a96/profile.JPG
tags:
  - web development
---

## はじめに

[Phase 2 構想記事](/blog/platform-engineering-mvp-phase2) で書いた通り、  
ローカル Docker から AWS ECS / Azure App Service に行くと **Terraform の state をリモートに置く** のが現実的になる。

Phase 1 なら `generated/terraform.tfstate` が手元にあれば足りた。  
Phase 2 では **S3 + DynamoDB**（AWS）か **Storage Account**（Azure）が先に要る。

これが **bootstrap** — 「Terraform 本体より先に、state を置く場所だけ1回用意する」手順。

まだ Phase 2 本体は未実装。bootstrap 手順のメモ。  
リポジトリ README に載せる前に、ブログに整理しておく。

## bootstrap とは何か

```text
terraform apply  →  state を S3 に保存したい
                      ↓
                   でも S3 バケットがまだない
                      ↓
                   先にバケットを作る = bootstrap
```

**bootstrap で作るもの**（AWS の例）:

| リソース | 用途 |
|----------|------|
| S3 バケット | `terraform.tfstate` の保存先 |
| DynamoDB テーブル | state の **ロック**（同時 apply 防止） |
| （任意）KMS | state の暗号化 |

Phase 2 の README イメージ:

```text
bootstrap/          … アカウント基盤（初回1回、人間 or 管理者）
domain/service.edn  … アプリの意図（Compiler の入力）
generated/          … アプリのインフラ + backend 参照
```

**bootstrap 自体は `service.edn` には入れない** ことが多い。  
state バケットはアカウント単位で1回、アプリ定義はサービス単位、だから。

## AWS bootstrap（CLI 手動）

いちばんわかりやすい方法。初回だけ実行。

### 1. 変数を決める

```bash
export AWS_REGION=ap-northeast-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export TF_STATE_BUCKET="platform-mvp-tfstate-${ACCOUNT_ID}"
export TF_STATE_LOCK_TABLE="platform-mvp-tfstate-lock"
export TF_STATE_KEY="env/dev/platform-mvp-web/terraform.tfstate"
```

### 2. S3 バケット作成

```bash
aws s3api create-bucket \
  --bucket "$TF_STATE_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# バージョニング（state 復旧用）
aws s3api put-bucket-versioning \
  --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# 公開ブロック
aws s3api put-public-access-block \
  --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 3. DynamoDB ロックテーブル作成

```bash
aws dynamodb create-table \
  --table-name "$TF_STATE_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$AWS_REGION"
```

### 4. 生成 Terraform に backend を足す

Phase 2 の Compiler が `generated/main.tf.json` に backend ブロックを埋め込む想定:

```json
{
  "terraform": {
    "backend": {
      "s3": {
        "bucket": "platform-mvp-tfstate-123456789012",
        "key": "env/dev/platform-mvp-web/terraform.tfstate",
        "region": "ap-northeast-1",
        "dynamodb_table": "platform-mvp-tfstate-lock",
        "encrypt": true
      }
    }
  }
}
```

`service.edn` に `:backend` を足して Compiler が埋める、という設計もアリ:

```clojure
{:platform :aws
 :region "ap-northeast-1"
 :backend
 {:bucket "platform-mvp-tfstate-123456789012"
  :dynamodb-table "platform-mvp-tfstate-lock"
  :key "env/dev/platform-mvp-web/terraform.tfstate"}}
```

### 5. 通常フロー（2回目以降）

```bash
clojure -M:generate
cd generated
terraform init -reconfigure
terraform plan
terraform apply
```

## AWS bootstrap（Terraform 版）

CLI より本番っぽくするなら、リポジトリに **bootstrap 専用ディレクトリ** を置く:

```text
platform-engineering-mvp/
  bootstrap/aws/          ← state は local のみ
    main.tf               ← S3 + DynamoDB だけ
  generated/              ← ECS 本体（remote state 使用）
    main.tf.json
```

`bootstrap/aws/main.tf` の概念:

```hcl
resource "aws_s3_bucket" "tfstate" {
  bucket = "platform-mvp-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "platform-mvp-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

実行順:

```bash
cd bootstrap/aws
terraform init
terraform apply          # ← この state だけ local

cd ../../generated
terraform init -reconfigure
terraform apply          # ← ここから S3 backend
```

**注意**: bootstrap 用 Terraform は **自分自身の state を同じ S3 に置けない**（鶏と卵）。  
bootstrap だけ local state、または別アカウントの state バケット、が定石。

## Azure bootstrap（折りたたみ）

`:platform :azure` で行く場合。S3 の代わりに **Storage Account + Blob Container**。

```bash
RG=platform-mvp-bootstrap
SA=platformmvptfstate   # グローバル一意、小文字英数字のみ
CONTAINER=tfstate

az group create -n $RG -l japaneast
az storage account create -g $RG -n $SA -l japaneast --sku Standard_LRS
az storage container create --name $CONTAINER --account-name $SA
```

backend 設定（azurerm）:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "platform-mvp-bootstrap"
    storage_account_name = "platformmvptfstate"
    container_name       = "tfstate"
    key                  = "dev/platform-mvp-web.terraform.tfstate"
  }
}
```

Azure も `bootstrap/azure/` に小さな Terraform / CLI スクリプトを置く形になる。

## Phase 2 README に書く章立て（案）

```markdown
## Prerequisites（Phase 2）
- AWS CLI / Azure CLI 認証済み
- bootstrap 済み（初回のみ）

## Bootstrap（初回のみ）
→ 詳細: https://www.theshibsters.com/blog/platform-engineering-mvp-phase2-bootstrap

### AWS
1. `scripts/bootstrap-aws-state.sh` を実行
2. 出力された bucket / table 名を確認
3. `clojure -M:generate` で backend 付き Terraform JSON を生成

### 通常フロー（2回目以降）
clojure -M:generate → cd generated → terraform init → plan → apply
```

## よくある落とし穴

| 落とし穴 | 対策 |
|----------|------|
| bootstrap を service.edn に混ぜる | アカウント基盤とアプリ定義を分離 |
| bootstrap も remote state にする | bootstrap だけ local state |
| `terraform init` 忘れ | backend 変更後は `init -reconfigure` |
| state バケットを公開 | Public Access Block 必須 |
| ロックなし | チーム/CI 運用なら DynamoDB ロック推奨 |

## おわりに

Phase 2 で増えるのは **Adapter 差し替え** だけじゃなくて、  
**「state を置く場所を先に1回作る」** という Day-0 ステップ。

Phase 1 の `cd generated && terraform apply` の前に、  
bootstrap → generate → init → apply という順番が増える。

実装再開するとき、この記事と [Phase 2 構想](/blog/platform-engineering-mvp-phase2) をセットで README にリンクする予定。

## 関連リンク

- [Phase 2 構想記事](/blog/platform-engineering-mvp-phase2)
- [Phase 1 記事](/blog/platform-engineering-mvp)
- リポジトリ: https://github.com/FuJiK/platform-engineering-mvp
