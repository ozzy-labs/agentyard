#!/bin/bash
# scripts/lib/components/docker.sh
# Opt-in container runtime (ADR-0007 §4, §6).
# Linux: Docker Engine from the official apt repository (deb822 + docker.asc).
#   https://docs.docker.com/engine/install/ubuntu/
#   Skipped when Docker Desktop's WSL integration is detected (running both
#   conflicts: https://docs.docker.com/desktop/features/wsl/).
# macOS: Docker Desktop / OrbStack / Colima via Homebrew.

# Heuristics: Docker documents no official detection method, so check the
# integration mount, the docker binary location, and the current context.
docker_desktop_detected() {
  [ -d /mnt/wsl/docker-desktop ] && return 0
  if has_cmd docker; then
    case "$(readlink -f "$(command -v docker)" 2>/dev/null)" in
    */mnt/wsl/docker-desktop* | *"Docker/host"*) return 0 ;;
    esac
    case "$(docker context show 2>/dev/null)" in
    desktop-linux) return 0 ;;
    esac
  fi
  return 1
}

systemd_running() {
  [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]
}

_docker_wsl_enable_systemd() {
  log_warn "WSL で systemd が無効です。Docker Engine の起動には systemd が必要です。"
  if ask_yes_no "/etc/wsl.conf に [boot] systemd=true を追加しますか？" n; then
    if grep -q '^\[boot\]' /etc/wsl.conf 2>/dev/null; then
      log_warn "/etc/wsl.conf に既に [boot] セクションがあります。systemd=true を手動で設定してください。"
    else
      printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf >/dev/null
      log_ok "/etc/wsl.conf に systemd=true を追加しました"
    fi
  fi
  log_info "Windows の PowerShell で 'wsl --shutdown' を実行し、WSL を起動し直してから、agentyard を再実行してください。"
  log_info "Docker のインストールだけを中断します（再実行すると続きから入ります）。"
}

_docker_linux() {
  if docker_desktop_detected; then
    log_skip "Docker Desktop の WSL 連携を検出しました。Docker Engine は入れません（併用すると衝突します）"
    return 0
  fi
  if is_wsl && ! systemd_running; then
    _docker_wsl_enable_systemd
    return 0
  fi
  if apt_pkg_installed docker.io || apt_pkg_installed podman-docker; then
    log_warn "Ubuntu の docker.io / podman-docker が入っています。Docker 公式の手順では先にアンインストールが必要なため、スキップします。"
    return 0
  fi
  apt_repo_add docker https://download.docker.com/linux/ubuntu @codename stable \
    https://download.docker.com/linux/ubuntu/gpg docker.asc || return 1
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1
  if systemd_running; then
    sudo systemctl enable --now docker >/dev/null 2>&1 && log_ok "docker サービスを有効化しました"
  fi
  state_add component docker
  _docker_group_consent
}

_docker_group_consent() {
  if id -nG "$(id -un)" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    log_skip "既に docker グループに所属しています"
    return 0
  fi
  log_warn "docker グループに入ると、実質的に root 権限を持つことになります。"
  log_warn "エージェントがシェルを使えると、docker 経由でサンドボックスを迂回できます。"
  log_info "参考: https://docs.docker.com/engine/install/linux-postinstall/"
  local add=1
  if is_non_interactive; then
    [ "${AGENTYARD_DOCKER_GROUP:-0}" = "1" ] || add=0
  else
    ask_yes_no "docker グループに $(id -un) を追加しますか（sudo なしで docker を使えるようになります）？" y || add=0
  fi
  if [ "$add" = "1" ]; then
    sudo usermod -aG docker "$(id -un)"
    state_add setting docker-group "$(id -un)"
    log_ok "docker グループに追加しました（次回ログインから有効）"
  else
    log_skip "docker グループには追加しません（sudo docker で使えます）"
  fi
}

_docker_macos() {
  if has_cmd docker; then
    log_skip "docker コマンドは既にあります"
    return 0
  fi
  local choice="${AGENTYARD_MACOS_DOCKER:-}"
  if [ -z "$choice" ]; then
    if is_non_interactive; then
      choice=colima
    else
      printf '  コンテナ環境を選んでください: 1) Docker Desktop  2) OrbStack  3) Colima [3]: '
      read -r choice || true
      case "$choice" in
      1) choice=docker-desktop ;;
      2) choice=orbstack ;;
      *) choice=colima ;;
      esac
    fi
  fi
  case "$choice" in
  docker-desktop) brew_install cask docker-desktop ;;
  orbstack) brew_install cask orbstack ;;
  colima) brew_install formula colima && brew_install formula docker ;;
  *)
    log_warn "AGENTYARD_MACOS_DOCKER は docker-desktop / orbstack / colima のいずれかを指定してください"
    return 1
    ;;
  esac
  state_add component docker
  case "$choice" in
  docker-desktop | orbstack)
    log_info "初回の起動（ライセンスへの同意や権限の許可）は、アプリを開いて行ってください。"
    ;;
  colima) log_info "'colima start' で起動してください。" ;;
  esac
}

install_docker() {
  log_section "Docker"
  case "$(os_kind)" in
  linux) _docker_linux ;;
  macos) _docker_macos ;;
  esac
}
