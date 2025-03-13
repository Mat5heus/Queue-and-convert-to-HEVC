# HEVC Video Converter with QSV

## Project Overview

This is an initiative, or **Project**, designed for streamlined video file transcoding—specifically, converting all video files in a directory and its subdirectories into the High Efficiency Video Coding (HEVC) codec. By consolidating your multimedia assets under this format, you can significantly optimize storage usage by potentially reducing gigabytes of space previously occupied by less efficient codecs.

### Key Features:

1. **Recursive Transcoding**: The project traverses a specified directory and its subdirectories, targeting all video files for transcoding. This ensures no file is overlooked in the quest to maximize storage efficiency.

2. **HEVC Conversion**: Utilizes state-of-the-art HEVC codec for superior compression rates compared to many older standards like H.264 or AVCHD. As a result, you'll enjoy substantial space savings while maintaining excellent video quality.

3. **Ease of Use**: Leveraging the simplicity and power of bash scripting, this project is built with your convenience in mind. It's designed to be straightforward to install and run on compatible systems without requiring extensive setup or configuration beyond ensuring the necessary dependencies are installed (see the 'Dependencies' section below).

4. **Modular and Extensible**: The script components have been organized into modular, manageable chunks within `utils.sh`, facilitating easy updates, bug fixes, and potentially integration with additional functionalities in the future.

## Use Cases

### Home Servers & Streaming on [Jellyfin](https://github.com/jellyfin/jellyfin), [Emby](https://github.com/MediaBrowser/Emby) or [Plex](https://www.plex.tv/):
- **Storage Optimization**: By converting video files to HEVC within your home server, you can dramatically decrease disk usage. This freed space enhances library capacity without sacrificing performance.

### Content Creators:
- **Space Efficiency**: Reduce storage footprint by transcoding older format videos into HEVC for your video archive. Keep high-quality content accessible while optimizing physical media.

### Backup Specialists:
- **Efficient Backups**: Optimize backup processes by minimizing space consumption for multimedia data, thanks to HEVC's superior compression efficiency.

### Data Archival Professionals:
- **Enhanced Storage Utilization**: Preserve extensive video collections on more compact media by converting them to HEVC. Maintain access while maximizing storage space.

In essence, this project empowers users to transform their digital repositories into leaner, cost-effective systems without compromising the superior viewing experience HEVC is known for.

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

## Dependencies

### bash, zsh (or any other POSIX-compliant shell)
This script is written primarily for Bash. However, if you prefer a different shell like Zsh, make sure it meets the requirements for the commands used.

### FFmpeg and LibVA (for hardware acceleration)
FFmpeg is a powerful tool for handling multimedia files. To utilize video processing capabilities via VAAPI (Video Acceleration API), you must have:
- FFmpeg installed on your system. For Ubuntu/Debian, run `sudo apt install -y ffmpeg`. For CentOS/Fedora, use `sudo yum install -y libva-utils`.

### Gawk (GNU awk)
Gawk is required for processing the output of certain commands and for running scripts that make heavy use of pattern matching. It can usually be installed via package managers:
- On Ubuntu/Debian, run `sudo apt install -y gawk`.
- On CentOS/Fedora, use `sudo yum install -y gawk`.

## Usage

The `hevc_converter` script is a powerful tool for converting video files from various formats (default: MP4) to the high-efficiency video coding (HEVC) format (`-e mp4` or `-e your_extension`) while leveraging hardware acceleration via VAAPI devices (default: `/dev/dri/renderD128`).

You can customize several aspects of the conversion process through command-line options. Here's a detailed breakdown using `./main.sh`:

### Basic Conversion without Dry Run (`-n` option)
```bash
./main.sh -e mp4 -b 3000 -m 1080 -a aac -d /mnt/your_hd -f 5 -l hevc_conversion.log
```
- **`-e` or `--extension`**: Sets the output video file extension (default: `mp4`).
  - Example: `-e mp4` (or `-e your_extension`)

- **`-b` or `--bitrate`**: Specifies bitrates for VBR mode. Default is medium value (3).
  - Example: `-b 3000`

- **`-m` or `--max_height`**: Defines the maximum height of converted videos in pixels, defaulting to 1080.
  - Example: `-m 720`

- **`-a` or `--audio_codec`**: Chooses audio codec (default: `aac`).
  - Example: `-a he-ac3` for Dolby Digital Plus. (Only tested with `aac`)

- **`-d` or `--input_directory`**: Points to the root directory containing input videos, defaulted to `/mnt/your_hd`.
  - Example: `-d /media/your_user`

- **`-f` or `--min_free_space`**: Sets the minimum free space on the drive in GB (default: 5).
  - Example: `-f 10` for more ample storage conditions

- **`-l` or `--log_file`**: Specifies the path to a log file for recording process details. Defaults to `$HOME/hevc_conversion.log`.
  - Example: `-l /path/to/custom_logfile`

- **`-v` or `--vaaapi_device`**: Identifies the device using VAAPI (e.g., `/dev/dri/renderD128`).
  - Example: If your system uses a different VAAPI driver, use `-v /dev/xvmc-nvidia`

- **`-n` or `--dry_run`** : Activates a "dry run" mode where the script simulates conversions without making actual changes.
  - Example: Use this for assessing options before executing conversion operations with `-n` omitted.

### Dry Run (`-n` option)
If you want to verify how these settings would transform video files without modifying any files, use the `dry_run` mode by appending `-n`:
```bash
./main.sh -e mp4 -b 3000 -m 1080 -a aac -d /mnt/your_hd -f 5 -l hevc_conversion.log -n
```
This command will print out the steps that would have been taken for each input file without actually performing any conversions or logging them to a file. 

Refer to the script's configuration section (`config.sh`) for further customization options, including setting up different audio coding modes and handling multiple files in parallel using threads. For now, this is the core functionality of `hevc_converter` when executed with `./main.sh`.

## Additional Notes

- The script will exit non-zero if it encounters unsuccessful operations (e.g., required tools missing, directory not accessible).
- For more control and customization, modify the `utils.sh` file for additional functionality like custom metrics or extended reporting.
- To ensure security and prevent unauthorized usage, keep this repository private unless intended for public use as a shared resource.

## License & Contributing

This project is licensed under the GNU 3 license; see the LICENSE file for details. Contributions are welcome! Feel free to create pull requests with new features or improvements. Please adhere to any coding standards and guidelines set forth in this repository.

---

Happy coding, and enjoy your smooth HEVC video conversion!