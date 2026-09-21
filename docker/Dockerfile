# syntax=docker/dockerfile:1
#
# PX4 SITL + Micro XRCE-DDS Agent + a ROS 2 offboard control node, all in one
# image. Gazebo itself is NOT built or run in this image -- it runs on the
# host and this container connects to it over the network. See ARCHITECTURE.md
# (not committed -- ask Dominick) or the README quick start for why.
FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive \
    ROS2_WS=/opt/ros2_ws \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_IGNORE_INSTALLED=1

# --- Version pins ------------------------------------------------------
# Bump deliberately. "latest main" is tracked by re-pinning these SHAs, not by
# floating branch names, so builds stay reproducible.
ARG PX4_AUTOPILOT_REF=2fc441493eb887199c279e2eff990f3f4cd0deef
ARG PX4_MSGS_REF=72fcfaa2750306c9fde8e30e14b5a6d67eb3264f
ARG MICRO_XRCE_DDS_AGENT_TAG=v2.4.3

# --- Base build tooling --------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        wget \
        curl \
        build-essential \
        cmake \
        ninja-build \
        python3-pip \
        python3-colcon-common-extensions \
        sudo \
    && rm -rf /var/lib/apt/lists/*

# --- PX4-Autopilot: fetch + toolchain + build ----------------------------
# ubuntu.sh installs PX4's own build dependencies, including the Gazebo
# Harmonic *development* libraries the SITL Gazebo bridge links against at
# build time (distinct from actually running `gz sim`, which happens on the
# host). --no-nuttx skips the ARM/embedded toolchain since this image only
# ever builds and runs SITL, never targets real flight-controller hardware.
RUN git clone https://github.com/PX4/PX4-Autopilot.git --recursive /opt/PX4-Autopilot \
    && cd /opt/PX4-Autopilot \
    && git checkout ${PX4_AUTOPILOT_REF} \
    && git submodule update --init --recursive \
    && RUNS_IN_DOCKER=true bash ./Tools/setup/ubuntu.sh --no-nuttx

# The pinned commit's gz_x500 airframe still defaults to NAV_DLL_ACT=2,
# which requires an active GCS/RC data link to arm -- fine for a real GCS
# workflow, but this image's whole point is arming via a ROS 2/DDS offboard
# node with no GCS present. Upstream fixed this for gz_x500 in a later
# commit (PX4/PX4-Autopilot#28721); apply the same two parameter defaults
# here rather than waiting for that to land in whatever commit we're pinned
# to. Verified via a live SITL run that arming is rejected without this.
RUN sed -i 's/^param set-default NAV_DLL_ACT 2$/param set-default NAV_DLL_ACT 0\nparam set-default CBRK_SUPPLY_CHK 894281/' \
        /opt/PX4-Autopilot/ROMFS/px4fmu_common/init.d-posix/airframes/4001_gz_x500 \
    && grep -q "NAV_DLL_ACT 0" /opt/PX4-Autopilot/ROMFS/px4fmu_common/init.d-posix/airframes/4001_gz_x500

# Build the SITL binary (and the Gazebo bridge plugin) now, at image build
# time, so container startup doesn't have to compile anything.
RUN cd /opt/PX4-Autopilot && make px4_sitl_default

# --- Micro XRCE-DDS Agent (bridges PX4's internal uORB bus to ROS 2 DDS) --
RUN git clone -b ${MICRO_XRCE_DDS_AGENT_TAG} \
        https://github.com/eProsima/Micro-XRCE-DDS-Agent.git /opt/Micro-XRCE-DDS-Agent \
    && cd /opt/Micro-XRCE-DDS-Agent \
    && mkdir build && cd build \
    && cmake .. \
    && make -j"$(nproc)" \
    && make install \
    && ldconfig /usr/local/lib/

# --- ROS 2 workspace: px4_msgs + our offboard control package -----------
RUN mkdir -p ${ROS2_WS}/src
WORKDIR ${ROS2_WS}/src

RUN git clone https://github.com/PX4/px4_msgs.git \
    && cd px4_msgs \
    && git checkout ${PX4_MSGS_REF}

COPY ros2_ws/src/px4_offboard_control ${ROS2_WS}/src/px4_offboard_control

WORKDIR ${ROS2_WS}
RUN . /opt/ros/jazzy/setup.sh \
    && colcon build --symlink-install

# --- Runtime defaults ------------------------------------------------------
# gz_x500 / 4001 is PX4's stock quadrotor model + its airframe autostart ID.
# Change both together if you swap models. PX4_INSTANCE/ROS_DOMAIN_ID are
# wired through for a future multi-agent setup; single-agent use can ignore
# them.
ENV PX4_SIM_MODEL=gz_x500 \
    PX4_SYS_AUTOSTART=4001 \
    PX4_GZ_WORLD=default \
    PX4_INSTANCE=0 \
    XRCE_DDS_PORT=8888 \
    ROS_DOMAIN_ID=0 \
    GZ_PARTITION=px4

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR ${ROS2_WS}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sitl"]
