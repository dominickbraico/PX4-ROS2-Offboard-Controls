# PX4-ROS2-Offboard-Controls

A Dockerized ROS 2 + PX4 SITL offboard control stack, built for quick lab bringups:
`docker build`, start Gazebo, `docker run`, fly.

## Architecture at a glance

One container holds:
- **PX4 SITL** (the PX4 flight-control firmware, built from source, running as
  a simulated vehicle instead of on real hardware)
- **Micro XRCE-DDS Agent** (bridges PX4's internal messages to ROS 2 topics
  under `/fmu/in/...` and `/fmu/out/...`)
- **A ROS 2 offboard control package** (`px4_offboard_control`) with an
  example node that arms the vehicle, takes off, holds, and lands

**Gazebo itself runs on the host, not inside the container.** PX4 SITL and
Gazebo already talk to each other over a network protocol even in a normal
native install, so this isn't a workaround -- it's PX4's own supported
"standalone" mode. Keeping Gazebo on the host avoids GPU/GUI passthrough
entirely inside the image, and keeps the container simulator-agnostic: the
same container is meant to later plug into other simulators (Isaac Sim,
Cosys-AirSim, etc.) behind the same interface, not just Gazebo.

**Host networking is required** (`--network host`, Linux only) so PX4 SITL
inside the container can discover the Gazebo instance running on the host.

## Roadmap (not yet implemented)

- **Multiple simulator backends** -- swap Gazebo for Isaac Sim or
  Cosys-AirSim behind the same PX4 SITL container.
- **Multi-agent simulation** with a wireless communication degradation
  layer -- a separate service that shapes (delays/drops/throttles) the
  inter-agent and agent-to-ground-station traffic to emulate real RF
  conditions, while leaving each agent's simulator connection untouched.
  Ports, PX4 instance IDs, and DDS domain IDs are already parameterized as
  container env vars in anticipation of this, but the actual multi-container
  networking for it isn't built yet.

## Host prerequisites

- Linux (host networking is required; this won't work cleanly on Mac/Windows
  Docker Desktop)
- Docker
- **Gazebo Harmonic** installed natively on the host (not in Docker):
  ```bash
  sudo curl https://packages.osrfoundation.org/gazebo.gpg \
      --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
      https://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/gazebo-stable.list
  sudo apt-get update
  sudo apt-get install gz-harmonic
  ```
- An NVIDIA GPU + the NVIDIA Container Toolkit are *not* required for this
  container (Gazebo's rendering happens entirely on the host), but you'll
  want a GPU on the host for smooth Gazebo rendering.

## Quick start

**1. Build the image** (takes a while the first time -- it compiles PX4 SITL
from source):
```bash
docker build -f docker/Dockerfile -t px4-ros2-offboard-controls:latest .
```

**2. Start Gazebo on the host:**
```bash
./scripts/start_gazebo.sh
```

**3. In another terminal, start the container** (brings up the DDS agent +
PX4 SITL, connects to the Gazebo instance from step 2):
```bash
./scripts/run_container.sh
```
You should see PX4 SITL boot and the vehicle spawn in the Gazebo window.

**4. In a third terminal, run the offboard control example:**
```bash
docker exec -it px4-ros2-offboard-controls \
    ros2 run px4_offboard_control offboard_control
```
The vehicle should arm, take off to 5 m, hold, then land automatically.

## Repo layout

```
docker/                    Dockerfile + container entrypoint
ros2_ws/src/px4_offboard_control/   Our ROS 2 package (the actual application)
scripts/                   Host-side helper scripts (start Gazebo, run container)
```

PX4-Autopilot, px4_msgs, and the Micro XRCE-DDS Agent are cloned and built
*inside* the Docker image at build time (pinned to specific commits in the
Dockerfile) -- they are not vendored into this repo.
