#!/bin/bash
# scripts/lib/apt.sh
# apt-get の冪等インストール/アップグレードヘルパー。
# このファイルは source して利用する。

# パッケージを冪等にインストール、または既存なら最新化する
# $1: package_name（apt パッケージ名）
# $2: display_name（表示名、省略時は package_name）
# $3: detect_command（コマンド存在確認用、省略時は package_name）
#
# 戻り値: 0 = 成功、非 0 = 失敗
apt_install_or_upgrade() {
  local pkg="$1"
  local display="${2:-$1}"
  local cmd="${3:-$1}"

  if ! command -v "$cmd" &>/dev/null; then
    sudo apt-get install -y "$pkg"
    echo "  ✅ $display インストール完了"
  else
    sudo apt-get install -y --only-upgrade "$pkg" >/dev/null 2>&1
    echo "  ⏭️  $display は最新版です"
  fi
}

# 指定 PPA owner が既にホストへ登録されているかを判定する。
# 過去に add-apt-repository 由来で deb822 形式の `.sources` が作られているケースと、
# 直接書き込みの `.list` が共存しうるため、両形式を網羅的にチェックする。
#
# $1: PPA owner（例: git-core）
# $2: 直接書き込み時の basename（例: git-core）
#
# 環境変数:
#   _APT_SOURCES_LIST_D — テスト時に sources.list.d パスを差し替えるためのシーム
#
# 戻り値: 0 = 既に登録済み、1 = 未登録
apt_ppa_registered() {
  local owner="$1"
  local basename="$2"
  local dir="${_APT_SOURCES_LIST_D:-/etc/apt/sources.list.d}"

  # 直接書き込み方式（apt_add_ppa が作成）
  [ -f "${dir}/${basename}.list" ] && return 0
  # add-apt-repository 由来（旧 install.sh が作成、Ubuntu 22.04+ は deb822 .sources）
  compgen -G "${dir}/${owner}-ubuntu-*.list" >/dev/null 2>&1 && return 0
  compgen -G "${dir}/${owner}-ubuntu-*.sources" >/dev/null 2>&1 && return 0
  return 1
}

# PPA が指定 codename 向けのパッケージを実際に配信しているかを判定する。
#
# Ubuntu devel / rolling は次期リリースのコードネーム（例: stonking）が
# announce された直後から使われるが、サードパーティ PPA が対応するまでには
# ラグがある。未対応の codename を sources.list.d に書き込むと、以後すべての
# `apt-get update` が
#   E: The repository '.../ubuntu <codename> Release' does not have a Release file.
# で失敗し、apt に依存する後続インストールが丸ごと停止する。
# 登録前に Release ファイルの存在を確認することで、この失敗モードを恒久的に断つ。
#
# $1: PPA owner（例: git-core）
# $2: PPA name（例: ppa）
# $3: codename（例: noble）
#
# 環境変数:
#   _APT_PPA_BASE_URL — テスト時に PPA ホストを差し替えるためのシーム
#
# 戻り値: 0 = 配信あり（登録可）、非 0 = 未対応または到達不能
apt_ppa_supports_codename() {
  local owner="$1"
  local name="$2"
  local codename="$3"
  local base="${_APT_PPA_BASE_URL:-https://ppa.launchpadcontent.net}"

  curl -fsSL --max-time 20 -o /dev/null \
    "${base}/${owner}/${name}/ubuntu/dists/${codename}/Release"
}

# PPA を Launchpad の API を経由せず直接登録する。
# add-apt-repository は api.launchpad.net に問い合わせて鍵 ID と URL を解決するが、
# その API は間欠的に到達不能になるため、ここでは
#   - GPG 鍵を keyserver.ubuntu.com から直接取得
#   - APT source を /etc/apt/sources.list.d/ に直接書き込む
# ことで api.launchpad.net への依存を排除する。
#
# $1: PPA owner（例: git-core）
# $2: PPA name（例: ppa）
# $3: GPG key fingerprint（40 桁 16 進、例: F911AB184317630C59970973E363C90F8F1B6217）
# $4: keyring / list の basename（例: git-core）
#
# 戻り値:
#   0 = 成功（新規登録または既登録の検出）
#   2 = 当該 codename に PPA が未対応（呼び出し側は distro 標準版へフォールバックする）
#   1 = その他の失敗（codename 取得不可 / 鍵取得失敗）
apt_add_ppa() {
  local owner="$1"
  local name="$2"
  local key_id="$3"
  local basename="$4"

  # 既に登録済み（旧 add-apt-repository 由来の .sources を含む）なら何もしない。
  # 同一 PPA を異なる Signed-By で重複登録すると apt-get update が
  # "Conflicting values set for option Signed-By" で失敗する。
  if apt_ppa_registered "$owner" "$basename"; then
    return 0
  fi

  local keyring="/usr/share/keyrings/${basename}.gpg"
  local list="/etc/apt/sources.list.d/${basename}.list"
  local codename
  codename=$(lsb_release -cs 2>/dev/null || echo "")

  if [ -z "$codename" ]; then
    echo "  ❌ ディストリ codename を取得できません（lsb_release が必要）" >&2
    return 1
  fi

  # 未対応 codename を登録すると以後の apt-get update が全滅するため、
  # 登録せずに 2 を返して呼び出し側にフォールバックさせる。
  if ! apt_ppa_supports_codename "$owner" "$name" "$codename"; then
    echo "  ⏭️  ppa:${owner}/${name} は ${codename} に未対応のため登録をスキップします"
    return 2
  fi

  local tmpkey
  tmpkey=$(mktemp)
  if ! curl -fsSL -o "$tmpkey" "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${key_id}"; then
    rm -f "$tmpkey"
    echo "  ❌ GPG 鍵 ${key_id} の取得に失敗しました（keyserver.ubuntu.com 到達不能の可能性）" >&2
    return 1
  fi
  sudo gpg --dearmor -o "$keyring" <"$tmpkey"
  rm -f "$tmpkey"
  sudo chmod go+r "$keyring"

  echo "deb [signed-by=${keyring}] https://ppa.launchpadcontent.net/${owner}/${name}/ubuntu ${codename} main" |
    sudo tee "$list" >/dev/null
}

# dpkg のインストール状態をベースにした冪等インストール（コマンドではなくパッケージで判定）
# build-essential のような複合パッケージ向け
apt_install_pkg() {
  local pkg="$1"
  local display="${2:-$1}"

  if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
    sudo apt-get install -y "$pkg"
    echo "  ✅ $display インストール完了"
  else
    sudo apt-get install -y --only-upgrade "$pkg" >/dev/null 2>&1
    echo "  ⏭️  $display は最新版です"
  fi
}
