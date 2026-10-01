#!/usr/bin/env bash
# Runs on the HOST. Thin wrapper around `docker run` with the flags this
# image needs (host networking so PX4 SITL can reach Gazebo on the host --
# see README.md
set -euo pipefail

IMAGE="${PX4_ROS2_IMAGE:-px4-ros2-offboard-controls:latest}"

# Docker Desktop (even its Linux build) runs containers inside a hidden VM,
# so `--network host` below only shares that VM's network stack -- not this
# machine's. PX4 SITL would then never see Gazebo's discovery traffic and
# hang forever on "Waiting for Gazebo world..." with no error at all. Fail
# fast instead. See README.md "Host prerequisites" / "Troubleshooting".
DOCKER_OS="$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || true)"
if [ "${DOCKER_OS}" = "Docker Desktop" ]; then
    echo "ERROR: docker is currently using Docker Desktop (context: $(docker context show 2>/dev/null))." >&2
    echo "       --network host will not reach this machine from inside Docker Desktop's VM." >&2
    echo "       Switch to the native Docker Engine first:" >&2
    echo "           docker context use default" >&2
    echo "       See README.md 'Host prerequisites' for details." >&2
    exit 1
fi

exec docker run -it --rm \
    --network host \
    --name px4-ros2-offboard-controls \
    -e PX4_GZ_WORLD="${PX4_GZ_WORLD:-default}" \
    "${IMAGE}" "$@"
