# PX4-ROS2-Offboard-Controls

Dockerized ROS 2 + PX4 SITL offboard control stack. One container runs PX4
SITL, the Micro XRCE-DDS Agent, and ROS 2 control nodes (takeoff/land,
square, circle, survey) that fly a simulated vehicle. Gazebo runs natively on
the host and the container connects to it over the network.

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

**4. Run a control node** (pick one from the table below):
```bash
docker exec -it px4-ros2-offboard-controls bash -c \
    "source /opt/ros/jazzy/setup.bash && source /opt/ros2_ws/install/setup.bash && ros2 run px4_offboard_control <node>"
```
Replace `<node>` with one of the executables below. Every node arms, takes
off, flies its trajectory, lands, and exits on its own. Run one at a time,
and wait for the vehicle to disarm before starting the next.

| Node | What it does |
|---|---|
| `offboard_control` | Takes off to 5 m, holds, lands (bringup check) |
| `square_trajectory` | Flies a square, returns to start, lands |
| `circle_trajectory` | Flies a circle, lands |
| `survey_trajectory` | Flies a lawnmower survey over a rectangle, returns, lands |

**5. Shut down:**
```bash
docker stop px4-ros2-offboard-controls   # then Ctrl+C in the Gazebo terminal
```

## Control node parameters

The trajectory nodes take ROS parameters, set by appending `--ros-args -p name:=value`
to the `ros2 run` command. All are optional. Example:
```bash
docker exec -it px4-ros2-offboard-controls bash -c \
    "source /opt/ros/jazzy/setup.bash && source /opt/ros2_ws/install/setup.bash && ros2 run px4_offboard_control square_trajectory --ros-args -p side:=15.0 -p speed:=1.5"
```

All trajectory nodes (not `offboard_control`):

| Parameter | Default | Meaning |
|---|---|---|
| `altitude` | `5.0` | Flight height above the start, metres |
| `speed` | `2.0` | Speed along the path, m/s |

Per node:

| Node | Parameter | Default | Meaning |
|---|---|---|---|
| `square_trajectory` | `side` | `10.0` | Side length, m |
| | `laps` | `1` | Number of laps |
| | `acceptance_radius` | `0.5` | How close counts as reaching a corner, m |
| `circle_trajectory` | `radius` | `5.0` | Circle radius, m |
| | `revolutions` | `2.0` | Number of full circles |
| `survey_trajectory` | `length` | `30.0` | Lane length (North), m |
| | `width` | `20.0` | Survey width (East), m |
| | `lane_spacing` | `5.0` | Distance between lanes, m |
| | `acceptance_radius` | `0.5` | How close counts as reaching a waypoint, m |

Paths are relative to where the vehicle armed (North/East). The circle passes
through the arming point with its centre to the East.

## Changing or adding a control node

The workspace is copied into the image and built at `docker build` time, so
edits to `ros2_ws/` only show up after rebuilding (step 1) and restarting the
container (step 3). New nodes also need an entry in `setup.py`
(`entry_points` -> `console_scripts`). Shared logic (arming, takeoff,
landing) lives in `trajectory_base.py`; a new trajectory only needs to
implement `trajectory_step()` or `build_waypoints()`.

## Troubleshooting

- **PX4 hangs on `Waiting for Gazebo world...`** -- you're on Docker
  Desktop. Run `docker context use default` and retry.
- **`docker exec ... ros2 ...` fails with `executable file not found in
  $PATH`** -- `ros2` isn't sourced in a fresh `exec` session. Use the full
  command in step 4 (or source `/opt/ros/jazzy/setup.bash` and
  `/opt/ros2_ws/install/setup.bash` yourself first).
- **`gz sim` segfaults on launch** -- usually a stale `libprotobuf` from an
  in-place OS upgrade. Run `sudo apt full-upgrade` and retry.
