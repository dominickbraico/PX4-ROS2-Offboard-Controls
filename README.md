# PX4-ROS2-Offboard-Controls

A Dockerized ROS 2 + PX4 SITL offboard control stack, built for quick lab bringups:
`docker build`, start Gazebo, `docker run`, fly.

## Host prerequisites

Check these before you start -- most first-run failures trace back to one of them.

1. **Linux**, with the **native Docker Engine (`docker-ce`)**, not Docker
   Desktop for Linux. Docker Desktop -- even its Linux build -- runs
   containers inside a hidden VM, so `--network host` (step 3 below) only
   shares that VM's network, not your actual machine's. PX4 SITL inside the
   container then can never reach Gazebo on the host, and hangs forever on
   `Waiting for Gazebo world...` with no error.

   Check your context, and switch if needed:
   ```bash
   docker context ls
   docker context use default   # only if `desktop-linux` shows as current (*)
   ```
   `run_container.sh` (step 3) checks for this itself and refuses to start
   rather than hang if it detects Docker Desktop.

2. Your user is in the `docker` group, so you don't need `sudo` for docker
   commands:
   ```bash
   sudo usermod -aG docker $USER   # then log out and back in
   ```

3. **Gazebo Harmonic**, installed natively on the host (not in Docker --
   see "Why Gazebo runs on the host" below):
   ```bash
   sudo curl https://packages.osrfoundation.org/gazebo.gpg \
       --output /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
       https://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
       | sudo tee /etc/apt/sources.list.d/gazebo-stable.list
   sudo apt-get update
   sudo apt-get install gz-harmonic
   ```
   An NVIDIA GPU + NVIDIA Container Toolkit are *not* required (Gazebo's
   rendering happens entirely on the host, outside Docker), but a GPU on the
   host will make rendering smoother.

## Quick start

Run these steps in order, each in its own terminal.

**1. Build the image** (one-time; takes a while, it compiles PX4 SITL from
source):
```bash
docker build -f docker/Dockerfile -t px4-ros2-offboard-controls:latest .
```

**2. Terminal 1 -- start Gazebo on the host:**
```bash
./scripts/start_gazebo.sh
```
Leave this running. A Gazebo window should open with the default world.

**3. Terminal 2 -- start the container:**
```bash
./scripts/run_container.sh
```
This brings up the Micro XRCE-DDS Agent and PX4 SITL, and connects to the
Gazebo instance from step 2. Leave this running too. You should see PX4 SITL
boot and the vehicle spawn in the Gazebo window from step 2. If it instead
hangs on `Waiting for Gazebo world...`, see [Host prerequisites](#host-prerequisites)
step 1.

**4. Terminal 3 -- run the offboard control example:**
```bash
docker exec -it px4-ros2-offboard-controls bash -c \
    "source /opt/ros/jazzy/setup.bash && source /opt/ros2_ws/install/setup.bash && ros2 run px4_offboard_control offboard_control"
```
The vehicle should arm, take off to 5 m, hold, then land automatically.

Note the `source ...` before `ros2 run`: a plain
`docker exec -it px4-ros2-offboard-controls ros2 run ...` will fail with
`exec: "ros2": executable file not found in $PATH`. The container's
entrypoint process sources ROS 2's `setup.bash` and the workspace overlay
for *itself* on startup, but that doesn't carry over to a separate
`docker exec` session -- each one needs to source both files itself, in
every new terminal.

**5. When you're done, stop the container and Gazebo:**
```bash
docker stop px4-ros2-offboard-controls   # Terminal 2's process exits
# Ctrl+C in Terminal 1 to stop Gazebo
```

## Troubleshooting

**`docker exec ... ros2 ...` fails with `exec: "ros2": executable file not
found in $PATH`**: you ran `ros2` directly instead of sourcing ROS 2 first.
Use the full command from step 4 above, or drop into a shell and source it
once per session:
```bash
docker exec -it px4-ros2-offboard-controls bash
source /opt/ros/jazzy/setup.bash && source /opt/ros2_ws/install/setup.bash
ros2 run px4_offboard_control offboard_control
```

**`./scripts/start_gazebo.sh` / `gz sim` segfaults immediately** (often
inside `libprotobuf`): this shows up on machines that were upgraded in
place from an older Ubuntu release (e.g. 22.04 -> 24.04) rather than
freshly installed. Some of the `gz-harmonic` package set (and its `dart`/
`ogre-next` dependencies) can get stuck on stale jammy-era builds that link
an old `libprotobuf23`, while the rest of the system uses the newer noble
`libprotobuf`. Loading both generations of protobuf in one process crashes.
Check for stragglers and upgrade them:
```bash
apt list --installed 2>/dev/null | grep -iE "jammy" | grep -iE "gz-|ignition|dart|ogre"
sudo apt update && sudo apt full-upgrade
```
Review what `full-upgrade` proposes before confirming if you have other
jammy-targeted software installed (e.g. ROS 2 Humble) that you want to keep.

**PX4 SITL prints `Waiting for Gazebo world...` forever and the vehicle
never spawns**: this is almost always the Docker Desktop networking issue
described in [Host prerequisites](#host-prerequisites) step 1 -- confirm
`docker context ls` shows `default` (native engine) as current, not
`desktop-linux`.

## Architecture at a glance

One container holds:
- **PX4 SITL** (the PX4 flight-control firmware, built from source, running as
  a simulated vehicle instead of on real hardware)
- **Micro XRCE-DDS Agent** (bridges PX4's internal messages to ROS 2 topics
  under `/fmu/in/...` and `/fmu/out/...`)
- **A ROS 2 offboard control package** (`px4_offboard_control`) with an
  example node that arms the vehicle, takes off, holds, and lands

### Why Gazebo runs on the host, not inside the container

PX4 SITL and Gazebo already talk to each other over a network protocol even
in a normal native install, so this isn't a workaround -- it's PX4's own
supported "standalone" mode. Keeping Gazebo on the host avoids GPU/GUI
passthrough entirely inside the image, and keeps the container
simulator-agnostic: the same container is meant to later plug into other
simulators (Isaac Sim, Cosys-AirSim, etc.) behind the same interface, not
just Gazebo.

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

## Repo layout

```
docker/                    Dockerfile + container entrypoint
ros2_ws/src/px4_offboard_control/   Our ROS 2 package (the actual application)
scripts/                   Host-side helper scripts (start Gazebo, run container)
```

PX4-Autopilot, px4_msgs, and the Micro XRCE-DDS Agent are cloned and built
*inside* the Docker image at build time (pinned to specific commits in the
Dockerfile) -- they are not vendored into this repo.
