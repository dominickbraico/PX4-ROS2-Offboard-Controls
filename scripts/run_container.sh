#!/usr/bin/env bash
# Runs on the HOST. Thin wrapper around `docker run` with the flags this
# image needs (host networking so PX4 SITL can reach Gazebo on the host --
# see README.md
set -euo pipefail

IMAGE="${PX4_ROS2_IMAGE:-px4-ros2-offboard-controls:latest}"

exec docker run -it --rm \
    --network host \
    --name px4-ros2-offboard-controls \
    "${IMAGE}" "$@"
