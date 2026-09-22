# PX4-ROS2-Offboard-Controls

Dockerized ROS 2 + PX4 SITL offboard control stack. One container runs PX4
SITL, the Micro XRCE-DDS Agent, and a ROS 2 node that arms, takes off,
holds, and lands a simulated vehicle. Gazebo runs natively on the host and
the container connects to it over the network.

## Requirements

- Linux with the native Docker Engine (`docker-ce`) -- **not** Docker
  Desktop, which breaks host networking (see Troubleshooting)
- Your user in the `docker` group: `sudo usermod -aG docker $USER` (then log
  out/in)
- [Gazebo Harmonic](https://gazebosim.org/docs/harmonic/install_ubuntu/)
  installed on the host (not in Docker)

## Running it

Each step is its own terminal.

**1. Build the image** (one-time):
```bash
docker build -f docker/Dockerfile -t px4-ros2-offboard-controls:latest .
```

**2. Start Gazebo:**
```bash
./scripts/start_gazebo.sh
```

**3. Start the container** (PX4 SITL + DDS agent, connects to Gazebo):
```bash
./scripts/run_container.sh
```
The vehicle should spawn in the Gazebo window.

**4. Run the offboard control example:**
```bash
docker exec -it px4-ros2-offboard-controls bash -c \
    "source /opt/ros/jazzy/setup.bash && source /opt/ros2_ws/install/setup.bash && ros2 run px4_offboard_control offboard_control"
```
The vehicle arms, takes off to 5 m, holds, then lands.

**5. Shut down:**
```bash
docker stop px4-ros2-offboard-controls   # then Ctrl+C in the Gazebo terminal
```

## Troubleshooting

- **PX4 hangs on `Waiting for Gazebo world...`** -- you're on Docker
  Desktop. Run `docker context use default` and retry.
- **`docker exec ... ros2 ...` fails with `executable file not found in
  $PATH`** -- `ros2` isn't sourced in a fresh `exec` session. Use the full
  command in step 4 (or source `/opt/ros/jazzy/setup.bash` and
  `/opt/ros2_ws/install/setup.bash` yourself first).
- **`gz sim` segfaults on launch** -- usually a stale `libprotobuf` from an
  in-place OS upgrade. Run `sudo apt full-upgrade` and retry.
