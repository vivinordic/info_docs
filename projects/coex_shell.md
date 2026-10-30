# Coexistence shell sample

Notes for building and working with the **coexistence shell** sample in nRF Connect SDK (NCS).

## Where the sample lives (until upstream merge)

The coexistence shell sample is **not** on Nordic’s official **sdk-nrf** repository yet. Until it is merged into **upstream**, use the development fork and branch below.

| Source | URL / branch | Role |
| ------ | ------------ | ---- |
| **Manifest (temporary)** | [https://github.com/muraliThokala/sdk-nrf.git](https://github.com/muraliThokala/sdk-nrf.git), branch **`coexistence_shell_sample`** | West manifest and sample sources for the coexistence shell |
| **upstream** (official) | [https://github.com/nrfconnect/sdk-nrf.git](https://github.com/nrfconnect/sdk-nrf.git) | Official tags, releases, and **`main`** — sample **not** available here yet |

After the sample is merged to **upstream**, initialize or update workspaces from **nrfconnect/sdk-nrf** (or your team fork tracking **upstream**) on a release tag or **`main`**, as described in the [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md).

## West workspace (current workflow)

Use the NCS toolchain shell, then point **`west init`** at the temporary manifest and branch (example: workspace in the current directory):

```bash
nrfutil sdk-manager toolchain launch --ncs-version v3.4.0 --shell
cd /path/to/your/workspace

# Remove a broken partial init if west update reports "local configuration file not found":
# rm -rf .west

west init -m https://github.com/muraliThokala/sdk-nrf.git --mr coexistence_shell_sample .
west update
west zephyr-export
```

Optional: add **upstream** on **`nrf/`** so you can fetch official tags and **`main`** alongside the feature branch:

```bash
git -C nrf remote add upstream https://github.com/nrfconnect/sdk-nrf.git
git -C nrf remote -v
```

General build, flash, and toolchain setup: [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md).

---

## Building the DUT application (nRF7120 DK)

| Item | Value |
| ---- | ----- |
| **Sample** | `nrf/samples/wifi/coexistence_shell` |

From the sample directory (with the NCS toolchain environment active):

```bash
cd nrf/samples/wifi/coexistence_shell
west build -p -b nrf7120dk/nrf7120/cpuapp -- -DSB_CONFIG_WIFI_NRF70=n -DCONFIG_NRF71_SR_COEX_DRIVER=y
west flash
```

---

## Building the peer application (nRF5340 DK)

| Item | Value |
| ---- | ----- |
| **Sample** | `nrf/samples/bluetooth/throughput` |

From the sample directory:

```bash
cd nrf/samples/bluetooth/throughput
west build -p -b nrf5340dk/nrf5340/cpuapp
west flash
```

---

## Test procedure

1. Flash the **coexistence_shell** sample onto the **DUT** (nRF7120 DK).
2. Flash the **Bluetooth throughput** sample onto the **peer** (nRF5340 DK).
3. On the **peer**, start the Peripheral role:

   ```text
   peripheral
   ```

4. On the **test PC**, start the iPerf UDP server:

   ```bash
   iperf -s -i 1 -u -p 5001
   ```

5. On the **DUT**:

   - Connect to the Wi-Fi access point (use **5 GHz**):

     ```text
     wifi connect -s <SSID> -k 1 -p <PASSWORD>
     ```

   - Establish a BLE connection — DUT as **Central**, peer as **Peripheral**:

     ```text
     bt_cfg_tput 1
     ```

   - Start the Wi-Fi throughput test:

     ```text
     wifi_run_tput udp upload <server-ip> 5001 20 1K 5M
     ```

     Arguments: `<server-ip>` `<port>` `<duration-sec>` `<packet-size>` `<rate>`

   - Start the BLE throughput test (duration in seconds):

     ```text
     bt_run_tput 20
     ```
