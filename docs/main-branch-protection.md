# main branch protection policy

`main` は常にデプロイ可能な状態を維持する。

## Required workflow checks

Repository Ruleset で次のチェックを Required Status Checks に設定する。

- `PR Gate / lint`
- `PR Gate / generate`

## Ruleset policy

- Pull Request 経由の変更を必須にする
- Required Status Checks の成功を必須にする
- force push を禁止する
- branch deletion を禁止する
- solo repository のため human approval 1名必須は当面設定しない

## Merge flow

```text
feature branch
    ↓
Pull Request
    ↓
PR Gate / lint
PR Gate / generate
    ↓
merge main
    ↓
production deploy
```

## Repository settings

この文書とCI workflowをマージした後、GitHub の Repository Ruleset で上記のルールを有効化する。

Ruleset はリポジトリ設定のためコードレビューだけでは強制できない。設定変更後は direct push が拒否され、Required Check が失敗したPRはmergeできないことを確認する。
