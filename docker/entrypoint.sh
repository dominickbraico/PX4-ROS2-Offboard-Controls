#!/usr/bin/env bash
# Container entrypoint. Default mode ("sitl") brings up the Micro XRCE-DDS
# Agent and PX4 SITL, expecting Gazebo to already be running on the HOST
# (see README quick start). The ROS 2 offboard control node is intentionally
# NOT auto-started here -- run it yourself once SITL is up, via:
#   docker exec -it <container> ros2 run px4_offboard_control offboard_control
set -eo pipefail
# Deliberately not `set -u`: ROS 2's own setup.bash references variables
# (e.g. AMENT_TRACE_SETUP_FILES) that are unset on first source, and errors
# out under nounset. Everything after the sourcing below is still safe since
# our own variables (XRCE_DDS_PORT etc.) are always set via Dockerfile ENV.

# shellcheck disable=SC1091
source /opt/ros/jazzy/setup.bash
# shellcheck disable=SC1091
source "${ROS2_WS}/install/setup.bash"

start_agent() {
    echo "[entrypoint] starting Micro XRCE-DDS Agent on udp4:${XRCE_DDS_PORT}"
    MicroXRCEAgent udp4 -p "${XRCE_DDS_PORT}" &
}

start_sitl() {
    echo "[entrypoint] PX4_GZ_STANDALONE=1 -- expecting Gazebo already running on the host."
    echo "[entrypoint] (host) python3 simulation-gazebo   <-- run this first if you haven't."
    echo "[entrypoint] model=${PX4_SIM_MODEL} autostart=${PX4_SYS_AUTOSTART} world=${PX4_GZ_WORLD} partition=${GZ_PARTITION}"
    cd /opt/PX4-Autopilot
    exec env \
        PX4_GZ_STANDALONE=1 \
        PX4_SIM_MODEL="${PX4_SIM_MODEL}" \
        PX4_SYS_AUTOSTART="${PX4_SYS_AUTOSTART}" \
        PX4_GZ_WORLD="${PX4_GZ_WORLD}" \
        GZ_PARTITION="${GZ_PARTITION}" \
        make px4_sitl gz_x500
}

case "${1:-sitl}" in
    sitl)
        start_agent
        start_sitl
        ;;
    agent-only)
        echo "[entrypoint] starting Micro XRCE-DDS Agent only (foreground)."
        exec MicroXRCEAgent udp4 -p "${XRCE_DDS_PORT}"
        ;;
    bash|shell)
        exec bash
        ;;
    *)
        exec "$@"
        ;;
esac
