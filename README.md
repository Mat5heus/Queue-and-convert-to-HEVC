# Video Conversion to HEVC Script with VAAPI/QSV Support

## Overview

This repository contains scripts and functions designed for video conversion to the HEVC format using hardware acceleration via VAAPI/QSV, a multimedia API available on Linux systems. The project includes utility scripts to manage disk space checks, command validation, progress tracking, device detection, and file processing.

## Key Features:

1. **Disk Space Check**: Monitors free space in specified directories before starting video conversion tasks.
2. **Command Validation**: Ensures essential tools (awk, bc) are available on the system.
3. **Progress Tracking**: Dynamically updates a progress bar based on conversion tasks using HEVC encoding.
4. **Device Detection for VAAPI**: Validates the presence and read permissions of the VAAPI GPU device required for hardware acceleration.
5. **File Handling & Validation**: Lists, compares, and processes video files recursively to ensure they are in a compatible format (HEVC) before conversion.
6. **Time Efficiency**: Uses `ffprobe` for quick duration estimation of input files without decoding them completely, minimizing processing time.
7. **HEVC Codec Detection**: Verifies if the target video files already utilize the HEVC codec and provides warnings otherwise.
8. **Incremental Logging & Reporting**: Maintains a log file (`output`) detailing script activities with appropriate error or warning messages for unsuccessful operations.
9. **TUI Integration (Terminal User Interface)**: Provides an interactive terminal display to visualize conversion progress, durations, and space savings in real time.

## Usage

To run the scripts efficiently, you should:

1. Make sure your system has `ffprobe` from FFmpeg installed. It's typically available with most multimedia packages on Linux distributions like Ubuntu.
   
2. Ensure VAAPI-capable hardware is present and correctly configured in your system’s kernel or drivers. If unsure, verify through the terminal by running:
   ```bash
   lspci -k | grep VGA
   ```
   Look for a VGA card with "VAAPI Decoding" marked under its properties.

3. Source this project into a directory named `video_conversion`:

   ```bash
   mkdir video_conversion && cd video_conversion
   git clone https://github.com/your-username/video-conversion.git .
   ```

4. Configure essential variables in the main script (`main.sh`) before execution:

   - `VAAPI_DEVICE` should point to your VAAPI device file (e.g., `/dev/dri/card0`).
   
   Example for Ubuntu:
   ```bash
   export VAAPI_DEVICE=/dev/dri/card0
   ```

5. Run the main script, setting up desired options such as the path to store logs (`LOG_FILE`) and the directory where you want to start processing videos (`INPUT_DIR`).

   ```bash
   ./main.sh --log-file output.log --input-dir /path/to/videos
   ```

6. View progress, errors, or warnings in real time using TUI via:

   - On Unix systems like Linux and macOS, open your terminal and navigate to the directory where `output.log` is located:

     ```bash
     cd /path/to/video_conversion
     tail -f output.log
     ```

   Alternatively, use a tool like `tail -f` in combination with `less`:
   ```bash
   watch -n 2 'less output.log'
   ```

## Additional Notes

- The script will exit non-zero if it encounters unsuccessful operations (e.g., required tools missing, directory not accessible).
- For more control and customization, modify the `utils.sh` file for additional functionality like custom metrics or extended reporting.
- To ensure security and prevent unauthorized usage, keep this repository private unless intended for public use as a shared resource.

## License & Contributing

This project is licensed under the MIT license; see the LICENSE file for details. Contributions are welcome! Feel free to create pull requests with new features or improvements. Please adhere to any coding standards and guidelines set forth in this repository.

---

Happy coding, and enjoy your smooth HEVC video conversion!