#!/usr/bin/env bash

WITH_FRAME=0
FRAME_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --with-frame) WITH_FRAME=1; shift ;;
    *) FRAME_ARGS+=("$1"); shift ;;
  esac
done

if [ "$EUID" == 0 ]
  then echo "Please run as a non-root user."
  exit
fi

if [ "$(uname -m)" != "aarch64" ] && [ "$(uname -m)" != "x86_64" ];then
  echo "BirdNET-Pi requires a 64-bit OS.
It looks like your operating system is using $(uname -m),
but would need to be aarch64."
  exit 1
fi

PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info[0]}{sys.version_info[1]}')")
if [ "${PY_VERSION}" == "39" ] ;then
  echo "### BirdNET-Pi requires a newer OS. Bullseye is deprecated, please use Bookworm. ###"
  [ -z "${FORCE_BULLSEYE}" ] && exit
fi

# we require passwordless sudo
sudo -K
if ! sudo -n true; then
    echo "Passwordless sudo is not working. Aborting"
    exit
fi

# Simple new installer
HOME=$HOME
USER=$USER

export HOME=$HOME
export USER=$USER

PACKAGES_MISSING=
for cmd in git jq curl ; do
  if ! which $cmd &> /dev/null;then
      PACKAGES_MISSING="${PACKAGES_MISSING} $cmd"
  fi
done
if [[ ! -z $PACKAGES_MISSING ]] ; then
  sudo apt update
  sudo apt -y install $PACKAGES_MISSING
fi

branch=avian-visitors
repo_url=https://github.com/Twarner491/AvianVisitors.git
install_dir=${HOME}/BirdNET-Pi

if [ -d "${install_dir}/.git" ]; then
  git -C "${install_dir}" fetch origin "${branch}"
  git -C "${install_dir}" checkout "${branch}"
  git -C "${install_dir}" reset --hard "origin/${branch}"
else
  git clone -b "${branch}" --depth=1 "${repo_url}" "${install_dir}"
fi

"${install_dir}/scripts/install_birdnet.sh"
if [ $? -ne 0 ]; then
  echo "The installation exited unsuccessfully."
  exit 1
fi

if [ "$WITH_FRAME" = 1 ]; then
  FRAME_INSTALL_ARGS=("${FRAME_ARGS[@]}")
  if [ ${#FRAME_INSTALL_ARGS[@]} -eq 0 ]; then
    FRAME_INSTALL_ARGS=(--base-url "http://localhost")
  fi
  BIRDFRAME_DEFER_REBOOT=1 "${install_dir}/frame/install.sh" "${FRAME_INSTALL_ARGS[@]}" || {
    echo "BirdNET installed, but the frame install failed."
    exit 1
  }
fi

echo "Installation completed successfully"
sudo reboot
