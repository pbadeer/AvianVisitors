# this should only contain functions and assignments, ie source install.sh should not have side effects.

ensure_uv () {
  if command -v uv &>/dev/null; then
    UV="$(command -v uv)"
  elif [ -x "$HOME/.local/bin/uv" ]; then
    UV="$HOME/.local/bin/uv"
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh
    UV="$HOME/.local/bin/uv"
  fi
  export UV
}

sync_birdnet_env () {
  ensure_uv
  cd "$HOME/BirdNET-Pi" || return 1
  export UV_PROJECT_ENVIRONMENT=birdnet
  export UV_PYTHON_DOWNLOADS=never
  local python_bin="${1:-$(command -v python3)}"
  local sync_args=(sync --python "$python_bin" --no-dev)
  if [ -f uv.lock ]; then
    sync_args+=(--frozen)
  fi
  "$UV" "${sync_args[@]}"
}

install_birdnet_mount() {
  TMP_MOUNT=$(systemd-escape -p --suffix=mount "$RECS_DIR/StreamData")
  cat << EOF > $HOME/BirdNET-Pi/templates/$TMP_MOUNT
[Unit]
Description=Birdnet tmpfs for transient files
ConditionPathExists=$RECS_DIR/StreamData

[Mount]
What=tmpfs
Where=$RECS_DIR/StreamData
Type=tmpfs
Options=mode=1777,nosuid,nodev

[Install]
WantedBy=multi-user.target
EOF
  ln -sf $HOME/BirdNET-Pi/templates/$TMP_MOUNT /usr/lib/systemd/system
}

install_tmp_mount() {
  STATE=$(systemctl is-enabled tmp.mount 2>&1 | grep -E '(enabled|disabled|static)')
  ! [ -f /usr/share/systemd/tmp.mount ] && echo "Warning: no /usr/share/systemd/tmp.mount found"
  if [ -z $STATE ]; then
    cp -f /usr/share/systemd/tmp.mount /etc/systemd/system/tmp.mount
    systemctl daemon-reload
    systemctl enable tmp.mount
  else
    echo "tmp.mount is $STATE, skipping"
  fi
}
