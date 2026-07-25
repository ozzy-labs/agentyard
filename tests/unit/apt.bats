#!/usr/bin/env bats
# =======================================================================
# tests/unit/apt.bats
# -----------------------------------------------------------------------
# scripts/lib/apt.sh のヘルパー関数を sudo / apt-get / dpkg / command を
# モックして検証する。実際の apt 操作は行わない。
# =======================================================================

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/apt.sh"

  # モック呼び出しログのファイル
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"

  # apt_ppa_registered がホスト実体（/etc/apt/sources.list.d）を見ないように
  # テスト専用ディレクトリへ差し替える
  export _APT_SOURCES_LIST_D="$BATS_TEST_TMPDIR/sources.list.d"
  mkdir -p "$_APT_SOURCES_LIST_D"
}

# モック: sudo は引数をそのままログして 0 を返す
sudo() {
  echo "sudo $*" >>"$MOCK_LOG"
  return 0
}
export -f sudo

# モック: apt-get は引数をログして 0 を返す
apt-get() {
  echo "apt-get $*" >>"$MOCK_LOG"
  return 0
}
export -f apt-get

# ------------------------------------------------------------------
# apt_install_or_upgrade: コマンド未存在 → install
# ------------------------------------------------------------------

@test "apt_install_or_upgrade: installs when command is missing" {
  # command -v をモックして「未存在」を返す
  command() {
    if [ "$1" = "-v" ]; then
      return 1
    fi
    builtin command "$@"
  }
  export -f command

  run apt_install_or_upgrade "tree" "tree" "tree-missing-command"
  [ "$status" -eq 0 ]
  [[ "$output" == *"インストール完了"* ]]
  grep -q "apt-get install -y tree" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# apt_install_or_upgrade: コマンド存在 → upgrade
# ------------------------------------------------------------------

@test "apt_install_or_upgrade: upgrades when command exists" {
  # command -v をモックして「存在」を返す（必ず /bin/true 等の実在コマンドを使う）
  run apt_install_or_upgrade "bash" "bash" "bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"最新版です"* ]]
  grep -q "apt-get install -y --only-upgrade bash" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# apt_install_or_upgrade: display_name 省略時は package_name を表示
# ------------------------------------------------------------------

@test "apt_install_or_upgrade: defaults display_name to package_name" {
  run apt_install_or_upgrade "bash"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bash"* ]]
}

# ------------------------------------------------------------------
# apt_add_ppa: 正常系 — keyserver からの鍵取得 + sources.list.d への書き込みを行う
# ------------------------------------------------------------------

@test "apt_add_ppa: registers PPA via keyserver and launchpadcontent" {
  lsb_release() { echo "jammy"; }
  export -f lsb_release

  curl() {
    echo "curl $*" >>"$MOCK_LOG"
    return 0
  }
  export -f curl

  run apt_add_ppa "git-core" "ppa" "DEADBEEFCAFEBABE" "git-core"
  [ "$status" -eq 0 ]
  grep -q "curl.*keyserver.ubuntu.com.*0xDEADBEEFCAFEBABE" "$MOCK_LOG"
  grep -q "sudo gpg --dearmor -o /usr/share/keyrings/git-core.gpg" "$MOCK_LOG"
  grep -q "sudo tee /etc/apt/sources.list.d/git-core.list" "$MOCK_LOG"
  grep -q "sudo chmod go+r /usr/share/keyrings/git-core.gpg" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# apt_add_ppa: codename 取得失敗 → 非 0
# ------------------------------------------------------------------

@test "apt_add_ppa: fails when lsb_release returns empty codename" {
  lsb_release() { echo ""; }
  export -f lsb_release

  run apt_add_ppa "git-core" "ppa" "DEADBEEF" "git-core"
  [ "$status" -ne 0 ]
  [[ "$output" == *"codename を取得できません"* ]]
}

# ------------------------------------------------------------------
# apt_add_ppa: 鍵取得失敗 → 非 0
# ------------------------------------------------------------------

@test "apt_add_ppa: fails when key fetch fails" {
  lsb_release() { echo "jammy"; }
  export -f lsb_release

  # codename 対応判定（launchpadcontent の Release）は成功させ、
  # keyserver からの鍵取得だけを失敗させる
  curl() {
    echo "curl $*" >>"$MOCK_LOG"
    case "$*" in
    *keyserver.ubuntu.com*) return 1 ;;
    *) return 0 ;;
    esac
  }
  export -f curl

  run apt_add_ppa "git-core" "ppa" "DEADBEEF" "git-core"
  [ "$status" -ne 0 ]
  [[ "$output" == *"取得に失敗"* ]]
}

# ------------------------------------------------------------------
# apt_ppa_supports_codename: codename 別 Release ファイルの URL を叩く
#
# Ubuntu devel の新 codename（例: stonking）に PPA が未対応な期間、
# 登録前にこの判定で弾かないと以後の apt-get update が全滅する。
# ------------------------------------------------------------------

@test "apt_ppa_supports_codename: probes the codename-specific Release URL" {
  curl() {
    echo "curl $*" >>"$MOCK_LOG"
    return 0
  }
  export -f curl

  run apt_ppa_supports_codename "git-core" "ppa" "noble"
  [ "$status" -eq 0 ]
  grep -q "ppa.launchpadcontent.net/git-core/ppa/ubuntu/dists/noble/Release" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# apt_ppa_supports_codename: Release が無い（未対応 codename）→ 非 0
# ------------------------------------------------------------------

@test "apt_ppa_supports_codename: returns non-zero when Release is missing" {
  curl() { return 22; } # curl -f の HTTP エラー終了コード
  export -f curl

  run apt_ppa_supports_codename "git-core" "ppa" "stonking"
  [ "$status" -ne 0 ]
}

# ------------------------------------------------------------------
# apt_add_ppa: 未対応 codename では登録せず rc=2 を返す（回帰: canary devel 失敗）
#
# 未対応 codename の source を書き込むと以後の apt-get update が
# "does not have a Release file" で失敗し、apt 依存の導入が全停止する。
# 書き込みを一切行わないことを sudo tee の不在で検証する。
# ------------------------------------------------------------------

@test "apt_add_ppa: skips registration with rc=2 when codename is unsupported" {
  lsb_release() { echo "stonking"; }
  export -f lsb_release

  # Release 取得のみ失敗させる（鍵取得まで到達しないことも併せて確認）
  curl() {
    echo "curl $*" >>"$MOCK_LOG"
    case "$*" in
    *ppa.launchpadcontent.net*) return 22 ;;
    *) return 0 ;;
    esac
  }
  export -f curl

  run apt_add_ppa "git-core" "ppa" "DEADBEEF" "git-core"
  [ "$status" -eq 2 ]
  [[ "$output" == *"stonking に未対応"* ]]
  # sources.list.d への書き込みも keyserver へのアクセスも発生していないこと
  ! grep -q "sudo tee" "$MOCK_LOG"
  ! grep -q "keyserver.ubuntu.com" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# apt_ppa_registered: 直接書き込み形式（.list）の存在を検出
# ------------------------------------------------------------------

@test "apt_ppa_registered: detects directly-written .list" {
  : >"$_APT_SOURCES_LIST_D/git-core.list"
  run apt_ppa_registered "git-core" "git-core"
  [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# apt_ppa_registered: add-apt-repository 由来の deb822 .sources を検出
# （これが今回のリグレッションの本丸: 旧 install.sh が残した .sources を見逃すと
# apt_add_ppa が再登録してしまい Signed-By 競合で apt-get update が失敗する）
# ------------------------------------------------------------------

@test "apt_ppa_registered: detects add-apt-repository .sources (deb822)" {
  : >"$_APT_SOURCES_LIST_D/git-core-ubuntu-ppa-noble.sources"
  run apt_ppa_registered "git-core" "git-core"
  [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# apt_ppa_registered: add-apt-repository 由来の旧 .list（22.04 以前）も検出
# ------------------------------------------------------------------

@test "apt_ppa_registered: detects add-apt-repository .list" {
  : >"$_APT_SOURCES_LIST_D/git-core-ubuntu-ppa-jammy.list"
  run apt_ppa_registered "git-core" "git-core"
  [ "$status" -eq 0 ]
}

# ------------------------------------------------------------------
# apt_ppa_registered: 何も無ければ未登録
# ------------------------------------------------------------------

@test "apt_ppa_registered: returns non-zero when nothing matches" {
  run apt_ppa_registered "git-core" "git-core"
  [ "$status" -ne 0 ]
}

# ------------------------------------------------------------------
# apt_add_ppa: 既登録（.sources のみ）なら何もせず短絡終了する
# curl / gpg / tee いずれも呼ばれないことを保証する
# ------------------------------------------------------------------

@test "apt_add_ppa: short-circuits when .sources already exists" {
  : >"$_APT_SOURCES_LIST_D/git-core-ubuntu-ppa-noble.sources"

  lsb_release() { echo "noble"; }
  export -f lsb_release

  curl() {
    echo "curl $*" >>"$MOCK_LOG"
    return 0
  }
  export -f curl

  run apt_add_ppa "git-core" "ppa" "DEADBEEF" "git-core"
  [ "$status" -eq 0 ]
  ! grep -q "curl" "$MOCK_LOG"
  ! grep -q "sudo gpg --dearmor" "$MOCK_LOG"
  ! grep -q "sudo tee /etc/apt/sources.list.d/git-core.list" "$MOCK_LOG"
}
