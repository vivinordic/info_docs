# Building and flashing with West (nRF Connect SDK)

This guide describes how to build and program firmware in this West workspace using the **nRF Connect SDK (NCS) toolchain** and **`west`**. It focuses on the nRF7120 DK workflow used in this tree, but most steps apply to other Nordic boards.

## Requirements

### Hardware and host

| Item                      | Notes                                                                                                                                                                               |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Development kit** | e.g. nRF7120 DK connected via USB (J-Link)                                                                                                                                          |
| **Linux**           | Ubuntu 20.04+ or similar (other OS supported with different launch flags)                                                                                                           |
| **SEGGER J-Link**   | Required for`west flash` with the `nrfutil` runner; Nordic docs often recommend a recent J-Link (toolchain bundles are tested against newer versions than many legacy installs) |

### Software

| Item                              | Minimum / recommended                                                                                                                                                               |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **nrfutil** (core)          | Install from[Nordic downloads](https://www.nordicsemi.com/Products/Development-tools/nRF-Util)                                                                                       |
| **nrfutil `sdk-manager`** | `nrfutil install sdk-manager`                                                                                                                                                     |
| **NCS + toolchain**         | e.g.`nrfutil sdk-manager install --ncs-version v3.4.0` (SDK under `~/ncs/`, toolchain under `~/ncs/toolchains/`)                                                              |
| **Python**                  | **3.12** from the toolchain bundle (Zephyr west scripts need **3.10+**; NCS recommends **3.12**)                                                                  |
| **West**                    | From the toolchain`PATH`, not a separate `pip install west` on system Python 3.8                                                                                                |
| **nrfutil `device`**      | **≥ 2.21.0** for **nRF71** (`--family nrf71`); v3.4.0 toolchain may ship an older plugin—upgrade if flashing nRF7120 fails (see [Troubleshooting](#troubleshooting)) |
| **CMake / Ninja**           | Provided by the toolchain                                                                                                                                                           |

### Workspace

- Run commands from the **sample or application directory** (where `CMakeLists.txt` / `sysbuild.cmake` live), or pass `-s` / `-d` to `west build`.
- This repository is a full NCS West workspace (`zephyr/`, `nrf/`, `modules/`, …).

---

## One-time setup

1. Install nrfutil and the sdk-manager plugin:

   ```bash
   nrfutil install sdk-manager
   ```
2. Install the SDK and matching toolchain (example: v3.4.0):

   ```bash
   nrfutil sdk-manager install --ncs-version v3.4.0
   nrfutil sdk-manager list
   nrfutil sdk-manager toolchain list
   ```
3. Upgrade **`nrfutil device`** if you program **nRF7120** (see troubleshooting). After upgrading outside the locked toolchain home:

   ```bash
   nrfutil install device=2.22.0 --force
   ```

---

## Initialize the West workspace

West manages all NCS repositories from the **manifest** in `nrf/west.yml`. The manifest repository is `sdk-nrf` (the `nrf/` directory). Zephyr lives in `zephyr/`; other projects live under `modules/`, `bootloader/`, and so on.

Run **`west init`**, **`west update`**, and **`west zephyr-export`** from the **toolchain environment** (see next section) so the correct `west` and Python are used.

### Git remotes for `sdk-nrf` (`nrf/`)

The West manifest lives in **`nrf/`** (the [sdk-nrf](https://github.com/nrfconnect/sdk-nrf) repository). Configure remotes so **`origin`** is the team fork and **`upstream`** is Nordic’s official repo:

| Remote             | URL                                           | Use                                                |
| ------------------ | --------------------------------------------- | -------------------------------------------------- |
| **origin**   | `https://github.com/vivinordic/sdk-nrf.git` | Push branches, pull your fork’s tracking branches |
| **upstream** | `https://github.com/nrfconnect/sdk-nrf.git` | Fetch official tags, releases, and`main`         |

After **`west init`** from the fork (Option B), add **upstream** once:

```bash
git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git
git -C nrf remote -v
```

If **`nrf/`** was cloned from Nordic and **`origin`** still points at nrfconnect, reconfigure:

```bash
cd nrf
git remote rename origin upstream
git remote add origin https://github.com/vivinordic/sdk-nrf.git
git fetch --all
```

### Related Bitbucket repositories (not in West)

Wi-Fi firmware, tests, and shared utilities live in **separate Git repositories** (not part of the West manifest). Clone them with SSH access to Nordic Bitbucket (`bitbucket.nordicsemi.no`):

| Repository                       | SSH URL                                                                 |
| -------------------------------- | ----------------------------------------------------------------------- |
| **`wifi_firmware`**      | `ssh://git@bitbucket.nordicsemi.no:7999/~vivi/wifi_firmware.git`      |
| **`wifi_firmware_test`** | `ssh://git@bitbucket.nordicsemi.no:7999/~vivi/wifi_firmware_test.git` |
| **`test_utilities`**     | `ssh://git@bitbucket.nordicsemi.no:7999/~vivi/test_utilities.git`     |

```bash
# siblings of the West workspace (typical layout)
cd /path/to/parent
git clone ssh://git@bitbucket.nordicsemi.no:7999/~vivi/wifi_firmware.git
git clone ssh://git@bitbucket.nordicsemi.no:7999/~vivi/wifi_firmware_test.git
git clone ssh://git@bitbucket.nordicsemi.no:7999/~vivi/test_utilities.git
```

Register your SSH key with Bitbucket Server. Use each repository’s README for build, test, and flash steps that apply to nRF71 Wi-Fi.

**Radio test extension pack** (internal PHY/shell opcodes 64+, `wifi_radio_test_extn`): lives under **`test_utilities/nrf71/phy/radio_test/extn_cmds/`** after cloning `test_utilities`. Install into this workspace’s **`nrf/`** module — see [Radio test extension commands](#radio-test-extension-commands-wifi_radio_test_extn).

### Option A: Install SDK with sdk-manager (official release tree)

This creates a versioned tree under `~/ncs/` (Linux) and installs the matching toolchain:

```bash
nrfutil sdk-manager install --ncs-version v3.4.0
```

That layout is typically:

```text
~/ncs/
├── toolchains/
│   └── <hash>/          # compiler, Python 3.12, west, …
└── v3.4.0/              # west workspace
    ├── .west/
    ├── nrf/
    ├── zephyr/
    └── modules/
```

Enter the toolchain, then export Zephyr’s CMake package (once per machine):

```bash
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
cd ~/ncs/v3.4.0
west zephyr-export
```

No manual `west init` is required when you use `sdk-manager install` for that release.

### Option B: Create a new workspace with `west init`

Use this for a **custom directory name**, a **branch/tag** not installed by sdk-manager, or **manual** checkout:

```bash
mkdir -p ~/ncs && cd ~/ncs
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
```

Initialize from the **fork** (manifest checkout becomes **`nrf/`** with **`origin`** = fork):

```bash
# Release tag
west init -m https://github.com/vivinordic/sdk-nrf.git --mr v3.4.0 v3.4.0

# Development branch
west init -m https://github.com/vivinordic/sdk-nrf.git --mr main main
```

Add Nordic as **upstream**, then clone all projects listed in the manifest:

```bash
cd v3.4.0   # or `main`, matching the directory you passed to west init
git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git
west update
west zephyr-export
```

**Note:** If you need a **non-release branch** but the **latest toolchain**, Nordic recommends installing the latest release via sdk-manager for the toolchain, then using `west init` / `git checkout` for the branch you want (`nrf/doc/nrf/installation/install_ncs.rst`).

### Option C: Clone or use an existing workspace (this repo)

This tree is already a West workspace: `.west/config` points at `nrf/west.yml`:

```ini
[manifest]
path = nrf
file = west.yml

[zephyr]
base = zephyr
```

Use a workspace whose **`nrf/`** remote **`origin`** is the fork, and add **`upstream`** as in [Git remotes for `sdk-nrf`](#git-remotes-for-sdk-nrf-nrf). After cloning or copying the full workspace:

```bash
cd /path/to/git_branch
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git 2>/dev/null || true
west update
west zephyr-export
```

If you cloned **only** the manifest from the fork and do not yet have `.west/`:

```bash
cd /path/to/parent
git clone https://github.com/vivinordic/sdk-nrf.git nrf
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
west init -l nrf
git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git 2>/dev/null || true
west update
west zephyr-export
```

### What each command does

| Command                                 | Purpose                                                                    |
| --------------------------------------- | -------------------------------------------------------------------------- |
| `west init -m <url> --mr <rev> [dir]` | Create`.west/` and clone the manifest repo (`nrf`) at revision `rev` |
| `west init -l <manifest-repo-dir>`    | Register an**existing** local manifest repository                    |
| `west update`                         | Fetch/checkout all projects to revisions in the current`nrf/west.yml`    |
| `west zephyr-export`                  | Install Zephyr CMake package metadata so`west build` finds Zephyr        |

`west update` can take several minutes and requires network access to Git remotes in the manifest.

---

## Update the workspace

Update **inside the toolchain shell**, from the **workspace root** (directory that contains `.west/`).

### Stay on the same NCS version (sync manifest pins)

When `nrf/` was updated on your fork (e.g. `git pull`) and `west.yml` changed:

```bash
cd /path/to/git_branch
git -C nrf fetch origin
git -C nrf pull    # or checkout your tracking branch on the fork
west update
```

After a large jump, do a **pristine rebuild** of applications (`west build -p`).

### Switch to another release, tag, or branch

Manifest version is defined by the **`nrf`** Git revision. Change it, then sync:

```bash
cd /path/to/git_branch/nrf
git fetch upstream
git checkout v3.4.0          # tag or branch name from upstream
cd ..
west update
west zephyr-export           # if west or Zephyr export path changed
```

Examples (official Nordic revisions via **upstream**):

```bash
# Release
git -C nrf fetch upstream && git -C nrf checkout v3.4.0 && west update

# Tip of upstream main (then merge/rebase onto your fork branch if needed)
git -C nrf fetch upstream && git -C nrf checkout upstream/main && west update
```

### Update SDK and toolchain with sdk-manager

To add or refresh an **installed** NCS version and its toolchain (under `~/ncs/`):

```bash
nrfutil sdk-manager search
nrfutil sdk-manager install --ncs-version v3.4.0
```

Use `nrfutil sdk-manager toolchain launch --ncs-version <version> --shell` matching the version you build against.

### Python dependencies

The toolchain bundle includes Python packages for NCS. If you see missing-module errors after `west update`, see `nrf/scripts/requirements.txt` and Nordic’s install guide; prefer fixing the **toolchain environment** rather than `pip install` on system Python 3.8.

### After updating

1. Match **toolchain version** to the NCS version you build (or the closest release toolchain for a dev branch).
2. Re-run **`west zephyr-export`** if prompted or after upgrading west.
3. **`west build -p`** for your application to avoid stale CMake cache.
4. Read **migration guides** when changing major NCS versions: `nrf/doc/nrf/releases_and_maturity/migration/`.

---

## Activate the toolchain environment

Always build and flash **inside** the NCS toolchain environment so `west`, Python 3.12, compilers, and the correct `nrfutil` are on `PATH`.

### Interactive shell (recommended)

```bash
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
```

Optional: start in your project directory:

```bash
nrfutil sdk-manager toolchain launch \
  --ncs-version v3.4.0 \
  --shell \
  --chdir /path/to/your/sample
```

The prompt may show `(v3.4.0)`—that is **not** a Python `venv`.

**Leave the environment:** run `exit` or press **Ctrl+D**.

### One-shot command (no subshell)

```bash
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --chdir /path/to/sample -- \
  west build -p -b nrf7120dk/nrf7120/cpuapp
```

### Source env in the current shell

```bash
eval "$(nrfutil sdk-manager toolchain env --ncs-version v3.4.0 --as-script sh)"
```

There is no `deactivate`; open a new terminal or run `exec $SHELL` to reset.

### Verify

```bash
python3 --version    # expect 3.12.x from toolchain
which west
west --version
nrfutil device --version
nrfutil device recover --help | grep 'possible values'   # must include nrf71 for nRF7120
```

---

## Building a Wi-Fi patch from `wifi_firmware`

NCS links **prebuilt LMAC/UMAC ROM images** and **patch binaries** from the West project **`nrfxlib`** (`nrf71_wifi/bins/`). To run Zephyr samples against **your own PHY/LMAC/UMAC patch** (from the separate [`wifi_firmware`](#related-bitbucket-repositories-not-in-west) clone), build the customer patch release, install the artifacts into `nrfxlib`, then **pristine-rebuild** the application.

### Prerequisites

- A **`wifi_firmware`** clone next to this workspace (see [Related Bitbucket repositories](#related-bitbucket-repositories-not-in-west)).
- **Wi-Fi toolkit** on the build host (`TOOLKIT_ROOT`, default `/opt/vpr/WIFITOOLKIT_0.22.10/` in `build_patch.bash`).
- **ROM images built** in `wifi_firmware` with the same **`TEST_SETUP`** (usually `SOC`) before patching:

  ```bash
  cd /path/to/wifi_firmware/build_scripts
  bash build.bash SOC
  ```

See `wifi_firmware/build_scripts/build_patch.bash` and `patch_release_common.bash` for options (`lmac` / `umac` only, custom slots, `--help`).

### 1. Build the customer patch release

From the **`wifi_firmware`** tree:

```bash
cd /path/to/wifi_firmware/build_scripts
bash build_patch.bash
```

With no extra arguments, this runs the **default customer release** at slot base **`0x100000`**. Outputs land in:

```text
wifi_firmware/build_scripts/patch_release/bin/slot_base_0x100000/
├── lmac_patch.bin
├── umac_patch.bin
├── manifest.json
└── nrf7120_wifi_patch.dtsi
```

The release script version in `build_patch.bash` is **`0.1.0`**, which matches the NCS install path below.

### 2. Copy patch artifacts into `nrfxlib`

From the **West workspace root** (directory containing `.west/`, `nrf/`, and `nrfxlib/`):

```bash
cp -f wifi_firmware/build_scripts/patch_release/bin/slot_base_0x100000/* \
  nrfxlib/nrf71_wifi/bins/0.1.0/
```

This overwrites the shipped **`0.1.0`** patch set (`lmac_patch.bin`, `umac_patch.bin`, `manifest.json`, `nrf7120_wifi_patch.dtsi`). The parent directory **`nrfxlib/nrf71_wifi/bins/`** still holds full ROM **`*.hex`** files used by the driver; only replace files under **`0.1.0/`** unless you intentionally change the version layout in `nrfxlib`.

Commit or stash changes in **`nrfxlib/`** if you need to track or revert custom bins.

### 3. Re-build with West

Use a **pristine** build so CMake picks up the new patch files and devicetree overlay:

```bash
cd nrf/samples/wifi/radio_test/single_domain   # or your application path
west build -p -b nrf7120dk/nrf7120/cpuapp
```

If you already built with **`CONFIG_WIFI_NRF71_PATCH=y`**, avoid passing a **second** copy of `nrf7120_wifi_patch.dtsi` via `-D` overlays—the updated file under **`nrfxlib/nrf71_wifi/bins/0.1.0/`** is the one the driver uses after copy.

Then flash as usual: `west flash` or `west flash --recover`.

---

## Building with West

### Example: Wi-Fi radio test (single domain) on nRF7120 DK

```bash
cd nrf/samples/wifi/radio_test/single_domain

west build -p -b nrf7120dk/nrf7120/cpuapp
```

- **`-p`**: pristine build (delete previous `build/` for this configuration).
- **`-b`**: board target.

### Extra Kconfig options (CMake `-D`)

Pass Kconfig fragments as CMake definitions after `--`:

```bash
west build -p -b nrf7120dk/nrf7120/cpuapp -- \
  -DCONFIG_NRF_WIFI_ALL_BAND=y \
  -DCONFIG_SOC_NRF71_WIFI_DAP=y
```

### Radio test extension commands (`wifi_radio_test_extn`)

Upstream NCS does not include internal RF/PHY radio-test opcodes (64+). The **extension pack** in **`test_utilities`** adds driver hooks, shell commands, and wire headers when **`CONFIG_NRF71_RADIO_TEST_EXTN=y`**.

Full pack notes (base commits, command list, uninstall):  
`test_utilities/nrf71/phy/radio_test/extn_cmds/README.md`

#### Install extension commands

From the **toolchain shell**, with **`test_utilities`** cloned (sibling of this workspace or any path):

```bash
export PACK=/path/to/test_utilities/nrf71/phy/radio_test/extn_cmds
export NRF_ROOT=/path/to/combined_repo/nrf   # West manifest repo in this workspace

"$PACK/install_extn.sh" "$NRF_ROOT"
```

The script:

1. Copies add-only files from **`extn_cmds/files/`** into **`nrf/`**.
2. Installs supplement headers under **`nrf/drivers/wifi/nrf71/inc/common/fw_if/`**.
3. Applies **`nrf71_radio_test_extn_hooks.patch`** (CMake/Kconfig/sample hooks), unless hooks are already present.

If the patch fails, **`nrf/`** HEAD may differ from the pack’s **`DRIVER_BASE_COMMIT`** — the installer prints a warning and exits; align driver changes manually or check out the base commit listed in **`extn_cmds/DRIVER_BASE_COMMIT`**. Re-run **`install_extn.sh`** after a hard reset of **`nrf/`** that removed the extension.

To remove the pack:

```bash
"$PACK/uninstall_extn.sh" "$NRF_ROOT"
```

Pair with **release Wi-Fi ROM + patch** from **`wifi_firmware`** (see [Building a Wi-Fi patch from `wifi_firmware`](#building-a-wi-fi-patch-from-wifi_firmware)) or the **`nrfxlib/nrf71_wifi/bins/`** images from **`west update`**.

#### Build with extension commands enabled

After a successful install, build the **single_domain** radio test sample with extension Kconfig (and the usual nRF71 Wi-Fi options):

```bash
cd nrf/samples/wifi/radio_test/single_domain

west build -p -b nrf7120dk/nrf7120/cpuapp -- \
  -DCONFIG_NRF_WIFI_ALL_BAND=y \
  -DCONFIG_SOC_NRF71_WIFI_DAP=y \
  -DCONFIG_NRF71_RADIO_TEST_EXTN=y
```

Use **`-p`** when toggling **`CONFIG_NRF71_RADIO_TEST_EXTN`** or after reinstalling the pack so CMake picks up new sources.

If you use a **custom patch** under **`nrfxlib/nrf71_wifi/bins/0.1.0/`**, avoid duplicating **`nrf7120_wifi_patch.dtsi`** via **`EXTRA_DTC_OVERLAY_FILE`** when **`CONFIG_WIFI_NRF71_PATCH=y`** already pulls it in (duplicate overlay errors). The extension pack README shows an alternate CMake line with explicit patch overlay for older layouts.

Shell: **`wifi_radio_test_extn`** (opcodes 64–103). Standard **`wifi_radio_test`** remains available when EXTN is off.

### Sysbuild / multi-image

Some samples use **sysbuild** (multiple images, e.g. application + UICR). The build directory layout may include domains such as `build/single_domain/`. Use the same board and toolchain; follow the sample’s `sample.yaml` or Nordic docs for shields and snippets.

### Rebuild without pristine

```bash
west build -b nrf7120dk/nrf7120/cpuapp
```

---

## Flashing with West

Connect **one** DK via USB (or be ready to pick a serial number when prompted).

```bash
west flash
```

### Recover and flash (erase / recover flow)

```bash
west flash --recover
```

West uses the **`nrfutil`** runner for many Nordic boards. It may:

1. Rebuild if needed (`-- west flash: rebuilding`).
2. Ask you to **select a device** if multiple J-Link serial numbers are connected.
3. Run **recover** then program the `.hex` under `build/.../zephyr/`.

### Specify runner / device (when needed)

```bash
west flash --runner nrfutil --snr <J-Link serial number>
```

For sysbuild with multiple domains, West may warn that runner options across domains are experimental; if flash fails, try `--domain <name>` as suggested in the log.

---

## Typical build output layout (nRF7120 single_domain)

After a successful build, the application image is often at:

```text
build/single_domain/zephyr/zephyr.nrf7120.hex
```

Exact paths depend on sysbuild domain names and board.

---

## Troubleshooting

### `SyntaxError: invalid syntax` on `match handler:` in `build_helpers.py`

**Cause:** `west` is running on **system Python 3.8** (e.g. `~/.local/bin/west`), while this Zephyr tree needs **Python 3.10+**.

**Fix:** Use the toolchain shell (`toolchain launch --shell`) or source `toolchain env`. Confirm `which west` and `python3 --version` point into `~/ncs/toolchains/...`.

---

### `invalid value 'nrf71' for '--family <FAMILY>'`

**Cause:** **`nrfutil device` is too old**. West passes `--x-family nrf71` for nRF7120; plugin versions before **2.21.0** do not list `nrf71`.

**Fix:**

```bash
nrfutil install device=2.22.0 --force
```

Ensure flash uses that nrfutil:

```bash
which nrfutil
nrfutil device recover --help | grep nrf71
```

If you use the v3.4.0 toolchain shell, its nrfutil home may be **locked** (`.../nrfutil/home/locked`), blocking upgrades. Either:

- Upgrade using a separate home: `export NRFUTIL_HOME=$HOME/.nrfutil` then install `device=2.22.0`, and put that `nrfutil` first on `PATH`, or
- Remove the `locked` file in the toolchain nrfutil home and upgrade there (modifies the toolchain install).

NCS **3.4.0** `tools-versions-linux.yml` references device **2.20.0**, which still may **not** include `nrf71`; for nRF7120 in this workspace, use **≥ 2.21.0**.

---

### `west is not recognized` / wrong compiler or missing Zephyr

**Cause:** Commands run outside the toolchain environment.

**Fix:** `nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell` before `west build` / `west flash`.

---

### Multiple boards connected

**Symptom:** Interactive prompt: `Please select one with desired serial number (1-N)`.

**Fix:** Select the correct index, or pass `--snr` to `west flash` to skip the prompt.

---

### `WARNING: Specifying runner options for multiple domains is experimental`

**Cause:** Sysbuild produces more than one domain (e.g. `single_domain`, `uicr`).

**Fix:** Usually harmless. If flash misbehaves, flash a single domain: `west flash --domain single_domain` (name from your `build/` layout).

---

### J-Link version warning from nrfutil

**Symptom:** Tested J-Link version differs from installed (e.g. 7.94 vs 9.24a).

**Fix:** Often still works for basic program/flash. If recover or SWD fails, install a J-Link version aligned with your NCS release notes.

---

### `libpython3.12.so.1.0: cannot open shared object file`

**Cause:** Running toolchain `python3.12` **without** sourcing the full toolchain environment (missing `LD_LIBRARY_PATH`).

**Fix:** Use `toolchain launch` or `toolchain env --as-script sh`, not the bare binary path alone.

---

### Cannot upgrade nrfutil inside toolchain: directory is locked

**Cause:** `.../nrfutil/home/locked` in the toolchain install.

**Fix:** Use `NRFUTIL_HOME=$HOME/.nrfutil` for user-managed plugins, or remove `locked` only if you intend to modify the toolchain bundle.

---

### `west update` fails (fetch, merge, or “unknown revision”)

**Cause:** Network or Git access to a manifest remote; detached or conflicting local changes in a west project; manifest points to a SHA/tag your clone has not fetched.

**Fix:**

- Run `west update` from the workspace root with the toolchain active.
- In the failing project directory, stash or commit local changes, or run `west update --fetch=always` (see `west update --help`).
- In `nrf/`, run `git fetch upstream` before checking out a new official tag/branch, then `west update` again.

---

### Manifest / project version mismatch after `git checkout` in `nrf/`

**Cause:** `west update` was not run after changing the manifest revision.

**Fix:** From workspace root: `west update`. If CMake still targets wrong Zephyr, run `west zephyr-export` and `west build -p`.

---

## Quick reference

| Task                        | Command                                                                                                                                                         |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Install SDK + toolchain     | `nrfutil sdk-manager install --ncs-version v3.4.0`                                                                                                            |
| New workspace (manual)      | `west init -m https://github.com/vivinordic/sdk-nrf.git --mr v3.4.0 v3.4.0` then `git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git` |
| Sync all repos              | `west update` (from workspace root)                                                                                                                           |
| Export Zephyr CMake package | `west zephyr-export`                                                                                                                                          |
| Switch NCS version          | `git -C nrf checkout <tag>` then `west update`                                                                                                              |
| Enter toolchain             | `nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell`                                                                                           |
| Exit toolchain shell        | `exit`                                                                                                                                                        |
| Wi-Fi patch release         | `cd wifi_firmware/build_scripts && bash build_patch.bash`                                                                                                     |
| Install patch into NCS      | `cp -f wifi_firmware/build_scripts/patch_release/bin/slot_base_0x100000/* nrfxlib/nrf71_wifi/bins/0.1.0/`                                                     |
| Install radio test EXTN     | `test_utilities/nrf71/phy/radio_test/extn_cmds/install_extn.sh nrf`                                                                                           |
| Build with EXTN             | `west build -p -b nrf7120dk/nrf7120/cpuapp -- -DCONFIG_NRF_WIFI_ALL_BAND=y -DCONFIG_SOC_NRF71_WIFI_DAP=y -DCONFIG_NRF71_RADIO_TEST_EXTN=y`                     |
| Pristine build              | `west build -p -b nrf7120dk/nrf7120/cpuapp`                                                                                                                   |
| Flash                       | `west flash`                                                                                                                                                  |
| Recover + flash             | `west flash --recover`                                                                                                                                        |
| Upgrade device for nRF71    | `nrfutil install device=2.22.0 --force`                                                                                                                       |

## Further reading

- NCS installation: `nrf/doc/nrf/installation/install_ncs.rst`
- Updating repos and toolchain: `nrf/doc/nrf/installation/updating.rst` (`updating_repos`, `using_toolchain_environment`)
- West manifest: `zephyr/doc/develop/west/index.rst`
- Nordic nrfutil sdk-manager: [Starting and inspecting the toolchain environment](https://docs.nordicsemi.com/bundle/nrfutil/page/nrfutil-sdk-manager/guides/sdk_manager_env_launch.html)
- Sample-specific docs: `nrf/samples/wifi/radio_test/single_domain/README_nrf71.rst`
- Bitbucket repos (clone separately): [Related Bitbucket repositories](#related-bitbucket-repositories-not-in-west) — `wifi_firmware`, `wifi_firmware_test`, `test_utilities`
- Custom Wi-Fi patch → NCS bins: [Building a Wi-Fi patch from `wifi_firmware`](#building-a-wi-fi-patch-from-wifi_firmware)
- Radio test extension pack: [Radio test extension commands](#radio-test-extension-commands-wifi_radio_test_extn) — `test_utilities/nrf71/phy/radio_test/extn_cmds/README.md`
