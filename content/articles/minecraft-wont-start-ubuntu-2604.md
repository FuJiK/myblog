---
title: Minecraft が起動しない — Ubuntu 26.04 で公式 .deb が死ぬ話
description: MacBookPro11,1 を Ubuntu 26.04 にしたあと、公式 Minecraft.deb が入らない。原因は libgdk-pixbuf のパッケージ名変更。tar.gz で回避する。
img: https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=800&q=80
alt: old computer troubleshooting
author:
  name: Fujikeeeen
  bio: All about Fujikeeeen and what he does and where he works
  img: https://images.ctfassets.net/k075a6skjkal/4WuuFsyxjAWaUSr2kW1kGF/33e2adcabde6ded15c44f52520549a96/profile.JPG
tags:
  - linux
---

## はじめに

[MacBookPro11,1 を Ubuntu 26.04 にクリーンインストールした](https://github.com/FuJiK/macbookpro11_1_ubuntu2604_migration)あと、Minecraft Java Edition を入れようとした。

公式サイトの `Minecraft.deb` を叩いたら、ランチャーが起動しない。  
インストール自体が依存関係で転けるか、入ったように見えてもアイコンを押しても何も起きない。

原因はゲーム側というより、**Ubuntu 26.04 のパッケージ名変更に公式 .deb が追いついていない**ことだった。メモ。

対象機:

```text
Model Identifier: MacBookPro11,1
CPU: Dual-Core Intel Core i5 2.4GHz
Memory: 8GB
GPU: Intel HD Graphics (Haswell / Mesa)
OS: Ubuntu 26.04 LTS
```

Java は移行スクリプトで `openjdk-21-jdk` まで入っている。ゲーム本体の話ではなく、**ランチャーの入れ方**の話。

## このリポジトリで起動する

ローカル Linux x86_64 では、リポジトリからランチャーを入れて起動できる。

```bash
yarn
yarn minecraft
```

`yarn minecraft` は **Prism Launcher**（Qt）を開く。公式 CEF ランチャーは GPU のない環境でウィンドウが出ないことがあるので、ローカル起動の既定はこちら。

公式 bootstrap も一緒に入る。Ubuntu 26.04 の `.deb` 回避と同じ経路を試すなら:

```bash
yarn minecraft:official
```

初回の `scripts/minecraft/install.sh` が置くもの:

| パス | 中身 |
|---|---|
| `~/.local/opt/prismlauncher` | Prism Launcher portable |
| `~/.local/bin/minecraft` | `yarn minecraft` 用ラッパー |
| `~/.local/opt/minecraft-launcher` | 公式 tar.gz bootstrap |
| `~/.local/bin/minecraft-official` | Mesa / CEF flags 付き公式ラッパー |

ゲームへのログインは Microsoft アカウントが必要。スクリプトはランチャーまで。

## 症状

よくあるパターンはこれ。

```bash
sudo dpkg -i ~/Downloads/Minecraft.deb
sudo apt --fix-broken install
```

出てくるエラー:

```text
minecraft-launcher depends on libgdk-pixbuf2.0-0 (>= 2.22.0); however:
  Package libgdk-pixbuf2.0-0 is not installed.
```

`apt --fix-broken install` は壊れたパッケージを直すのではなく、**minecraft-launcher を削除して終わる**。  
App Center から入れると "Installing..." のまま固まる、という報告もある。

確認:

```bash
apt-cache policy libgdk-pixbuf2.0-0
apt-cache policy libgdk-pixbuf-2.0-0
```

Ubuntu 26.04 ではだいたいこうなる。

| パッケージ | 結果 |
|---|---|
| `libgdk-pixbuf2.0-0` | Candidate: (none) 。存在しない |
| `libgdk-pixbuf-2.0-0` | 入っている。名前の途中にハイフンが1つ増えた |

古い名前を Depends に書いている公式 .deb は、新規インストールの 26.04 では構成できない。

24.04 からアップグレードしたマシンだと、古いパッケージが残っていて「前は動いてたのに入れ直したら死んだ」になりやすい。クリーンインストールだと最初から詰まる。

Mojang 側のチケット:

- [MCL-26579](https://bugs.mojang.com/browse/MCL/issues/MCL-26579) — Ubuntu 25.10 / 26.04 で DEB が入れられない
- [MCL-26603](https://bugs.mojang.com/browse/MCL/issues/MCL-26603) — `libgdk-pixbuf2.0-0` → `libgdk-pixbuf-2.0-0` のリネーム

## 回避策 1: 公式 tar.gz（おすすめ）

手でやるなら同じことをする。このリポジトリでは `yarn minecraft` がこれを自動化している。

Minecraft のダウンロードページには **Other Distributions** 用の tarball がある。  
`.deb` の Depends を無視して、ランチャー本体だけ展開して起動する。

```bash
curl -L -o ~/Downloads/Minecraft.tar.gz \
  https://launcher.mojang.com/download/Minecraft.tar.gz

mkdir -p ~/opt
tar -xzf ~/Downloads/Minecraft.tar.gz -C ~/opt
chmod +x ~/opt/minecraft-launcher/minecraft-launcher

~/opt/minecraft-launcher/minecraft-launcher
```

中身はこれだけ。

```text
minecraft-launcher/
minecraft-launcher/minecraft-launcher
```

起動したらランチャーがランタイムとゲーム本体を `~/.minecraft` に取る。  
Java もランチャーが用意するので、apt の OpenJDK と無理に混ぜない。

デスクトップから開きたい場合:

```bash
cat > ~/.local/share/applications/minecraft-launcher.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Minecraft Launcher
Exec=/home/REPLACE_ME/opt/minecraft-launcher/minecraft-launcher
Icon=minecraft-launcher
Terminal=false
Categories=Game;
EOF
sed -i "s|REPLACE_ME|$HOME|" ~/.local/share/applications/minecraft-launcher.desktop
```

## 回避策 2: .deb の Depends を直して入れ直す

公式パッケージのまま apt 管理したい人向け。依存名を今の Ubuntu に合わせて詰め直す。

```bash
cd ~/Downloads
dpkg-deb -x Minecraft.deb mcl_fix
dpkg-deb -e Minecraft.deb mcl_fix/DEBIAN

# Depends の libgdk-pixbuf2.0-0 を libgdk-pixbuf-2.0-0 に直す
sed -i 's/libgdk-pixbuf2.0-0/libgdk-pixbuf-2.0-0/g' mcl_fix/DEBIAN/control

# default-jre が無いとここでも転ける
sudo apt install -y default-jre

dpkg-deb -b mcl_fix minecraft_fixed.deb
sudo apt install ./minecraft_fixed.deb
```

`control` の Depends は、将来公式が `libgdk-pixbuf2.0-0 | libgdk-pixbuf-2.0-0` の OR 依存に直してくる想定。それまでは自前修正。

## ランチャーは入ったのに画面が出ないとき

Intel + Mesa の Linux で、起動直後に落ちる既知バグがある。[MCL-26138](https://mojira.dev/MCL-26138)。Haswell iGPU だと当たりやすい。

```bash
__GLX_VENDOR_LIBRARY_NAME=mesa ~/opt/minecraft-launcher/minecraft-launcher
```

まだダメなら Wayland を疑う。Ubuntu 26.04 の GNOME は Wayland が既定。

```bash
echo "$XDG_SESSION_TYPE"
GDK_BACKEND=x11 __GLX_VENDOR_LIBRARY_NAME=mesa \
  ~/opt/minecraft-launcher/minecraft-launcher
```

ログイン画面で **Ubuntu on Xorg** に切り替えるのも手。

GPU と OpenGL の確認:

```bash
glxinfo | grep -E "OpenGL vendor|OpenGL renderer|OpenGL version"
```

`mesa-utils` が無ければ `sudo apt install mesa-utils`。  
Minecraft 1.17 以降は OpenGL 3.2 以上。Haswell + 最近の Mesa なら通常は足りる。

## ログの場所

ランチャーが黙って死ぬときは、ここを見る。

| ファイル | 中身 |
|---|---|
| `~/.minecraft/launcher_log.txt` | ランチャー本体 |
| `~/.minecraft/logs/latest.log` | ゲーム起動後 |
| `journalctl --user -xe` | GUI から起動したときの systemd / desktop |

`libgdk-pixbuf` ならインストール失敗。`GLX` / `libX11` / segfault なら Mesa 側の回避を先に試す。

## 8GB マシンの JVM

MacBookPro11,1 はメモリ 8GB。GNOME を載せるとゲームに 4GB は渡せない。

ランチャーのインストール設定で JVM 引数を抑える。

```text
-Xms512M -Xmx2G
```

4G を指定すると swap に落ちて「起動しない」に見えることがある。古い Intel Mac あるある。

## 使わないもの

- Snap / App Center の Minecraft — 26.04 では Installing のまま固まる報告がある
- 非公式 Flatpak を最初の手段にする — 動くこともあるが、今回の原因は公式 .deb の Depends なので tar.gz で足りる
- apt の OpenJDK をゲーム用 Java に指定する — ランチャーが runtime を取る。混ぜるとバージョン不一致が増える

## まとめ

Ubuntu 26.04 で Minecraft が起動しないとき、ゲーム本体より先にランチャーの入れ方を疑う。

1. 公式 `.deb` は `libgdk-pixbuf2.0-0` という**もう無いパッケージ名**に依存している
2. `yarn minecraft`（Prism Launcher）で起動するのが最短。公式 `.deb` 回避だけ見るなら `yarn minecraft:official`
3. Intel + Mesa なら `__GLX_VENDOR_LIBRARY_NAME=mesa` を足す
4. 8GB 機は `-Xmx2G` までに抑える

移行手順の本体は [macbookpro11_1_ubuntu2604_migration](https://github.com/FuJiK/macbookpro11_1_ubuntu2604_migration)。  
こちらは「Ubuntu にしたあと、遊びが起動しない」側のメモ。
