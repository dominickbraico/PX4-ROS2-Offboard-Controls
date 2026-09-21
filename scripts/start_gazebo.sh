#!/usr/bin/env bash
# Runs on the HOST (not in Docker). Launches Gazebo Harmonic with PX4's
# standard models/worlds via PX4's own helper script, which is fetched into
# .gazebo-sim/ on first run (gitignored -- it's a runtime download, not repo
# content).
set -euo pipefail

# If ROS 2 is sourced in this shell (e.g. via .bashrc), its `gz` CLI stub
# (gz_tools_vendor) shadows the real, apt-installed Gazebo Harmonic on PATH
# and doesn't know where to find the `sim` plugin, so `gz sim` silently
# fails to resolve. Force the system install explicitly rather than relying
# on whatever `gz`/GZ_CONFIG_PATH happens to be first on PATH.
export PATH="/usr/bin:${PATH}"
export GZ_CONFIG_PATH="/usr/share/gz"

# Gazebo Transport's discovery defaults to a per-user partition string, to
# stop different users on a shared lab machine from cross-talking. Since the
# container runs as root (a different "user" from whoever runs this script),
# the two sides won't discover each other at all unless both are pinned to
# the SAME explicit partition. Must match GZ_PARTITION in docker/entrypoint.sh.
export GZ_PARTITION="${GZ_PARTITION:-px4}"

if ! /usr/bin/gz sim --help &>/dev/null 2>&1; then
    echo "Gazebo Harmonic ('gz sim') was not found at /usr/bin/gz." >&2
    echo "Install it first -- see README.md 'Host prerequisites'." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${SCRIPT_DIR}/.gazebo-sim"
mkdir -p "${CACHE_DIR}"

if [ ! -f "${CACHE_DIR}/simulation-gazebo" ]; then
    echo "Fetching PX4's simulation-gazebo launcher script..."
    wget -q -O "${CACHE_DIR}/simulation-gazebo" \
        https://raw.githubusercontent.com/PX4/PX4-gazebo-models/main/simulation-gazebo
fi

cd "${CACHE_DIR}"
echo "Starting Gazebo (world: ${PX4_GZ_WORLD:-default}, partition: ${GZ_PARTITION})..."
python3 simulation-gazebo --world "${PX4_GZ_WORLD:-default}" --gz_partition "${GZ_PARTITION}"
