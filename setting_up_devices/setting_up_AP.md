# Setting up the lab Wi‑Fi AP for testing and debugging

The **Wi‑Fi access point** in the coexistence RF bench provides the network the DUT joins for throughput, scan, and debug runs. This guide covers **how to set up and use that AP** when **configuration is done over telnet** from the test PC.

Default SSIDs and script flags used on the bench are listed below. For a Python environment on the test PC, see [Setting up a venv](../setting_up_softwares/setting_up_venv.md).

## Role in coexistence testing

| Item                 | Notes                                                                                                                                                                                                                         |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Location**   | AP sits in **RF box 1** with the nRF5340 BLE peer; RF is attenuated into the DUT path.                                                                                                                                  |
| **Automation** | `coex_test.py` / `wifi_coex_sweep.py` expect an AP the DUT can **scan** and **connect** to; they use `-s` / `--ssid` (defaults include **`Driver_team_2_4`** and **`Driver_team_5GHz`**). |
| **Security**   | Test scripts assume an **OPEN** network unless you change DUT connect steps.                                                                                                                                            |
| **Gateway**    | After association, DUT logs often show **`Router: 192.168.1.50`** — the AP’s LAN address should match your iperf and routing plan.                                                                                  |

Before running sweeps, the AP must broadcast the **same SSID(s)** you pass to the Python scripts, on the expected **band** (2.4 or 5 GHz).

---

## Prerequisites

1. Test PC on the **same L2/L3 network** as the AP management interface (lab VLAN/subnet).
2. **Telnet enabled** on the AP (on many lab ASUS units this is turned on in the admin UI; use your site runbook).
3. AP **management IP** (example used in recent coex runs: **`192.168.1.50`**).
4. **Login credentials** for the telnet shell (lab-stored; not committed in this repo).

Ping or `telnet <ip>` from the test PC before you change RF or attenuator settings.

---

## Configure the AP using telnet

Lab APs are configured from the test PC with the **`telnet`** client. Telnet opens a **TCP session to port 23** (unless your AP documents another port) and gives an **interactive shell** on the AP — the same place you run interface and Wi‑Fi commands.

### 1. Open a telnet session

From the test PC:

```bash
telnet 192.168.1.50
```

Replace **`192.168.1.50`** with your AP’s management IP. If your AP uses a non-default port:

```bash
telnet 192.168.1.50 <port>
```

You should see a login prompt or shell banner. Connection is **plaintext** — use only on the isolated lab network.

### 2. Log in

Enter the AP **username** and **password** when prompted. On a typical lab **ASUS** unit you land in a root shell, for example:

```text
admin@RT-AX88U-C208:/tmp/home/root#
```

Exact hostname and path depend on the firmware image.

### 3. Inspect current Wi‑Fi configuration

Before changing anything, confirm what the AP is already broadcasting:

```bash
iw dev
```

Example output shape (two radios, two BSSIDs):

```text
phy#0  Interface eth6   ssid ASUS_RTAX88U_58_ND219   type AP
phy#1  Interface eth7   ssid ASUS_RTAX88U_34_ND219   type AP
```

Note each interface’s **SSID**, **MAC (BSSID)**, and **phy** — you will match these against DUT `wifi scan` output and against `--ssid` in automation.

On **Broadcom-based** lab routers you also have the **`wl`** utility for low-level radio and protocol options (channel, band, HE/MBO, etc.). Run `wl` with no arguments or `wl help` on the AP for the command list available on that firmware.

Use the **`-i`** interface name from `iw dev` for the radio you are testing (examples below use **`eth3`**; on some units it is **`eth6`** / **`eth7`** instead).

**TX power and RSSI (telnet on the AP):**

```bash
# Read current TX power
wl -i eth3 txpwr1

# Read measured RSSI for an associated DUT (use the DUT Wi‑Fi MAC)
wl -i eth3 rssi <DUT_MAC_addr>

# Set TX power
wl -i eth3 txpwr1 -d <power>
```

Replace **`<DUT_MAC_addr>`** with the station address (from DUT `wifi status` or scan **BSSID** when the DUT is the client). Replace **`<power>`** with the value your AP firmware expects (see `wl txpwr1` help on the device). Re-read with `wl -i eth3 txpwr1` after changes.

### 4. Set parameters needed for coexistence tests

Align the AP with what the DUT and scripts expect:

| Setting                  | Target for coex automation                                                                                   |
| ------------------------ | ------------------------------------------------------------------------------------------------------------ |
| **SSID (2.4 GHz)** | e.g. **`Driver_team_2_4`** (or the exact name you pass with `-s`)                                  |
| **SSID (5 GHz)**   | e.g. **`Driver_team_5GHz`**                                                                          |
| **Security**       | **OPEN** for default script flow                                                                       |
| **Channel**        | Fixed channel is fine; note channel number for debug (`wifi scan` on DUT shows it)                         |
| **LAN IP / DHCP**  | AP as default gateway (e.g. **`192.168.1.50`**) so the DUT gets a routable address to the iperf host |

**How you apply changes** depends on the AP model and firmware:

- **ASUS / Broadcom lab APs:** use the combination of **`nvram`**, **`wl`**, and/or vendor scripts your team documents for that router. Telnet is where those commands are run; there is no separate “configuration app” on the PC.
- After changes, **commit / restart Wi‑Fi or reboot** as required by that procedure so beacons show the new SSID.

Do not leave the AP on unrelated SSIDs (e.g. default `ASUS_RTAX88U_*` names) if automation is still pointed at **`Driver_team_*`**.

### 5. Re-check from telnet

After apply/reboot, connect with telnet again and run:

```bash
iw dev
```

Confirm SSID, band, and that both radios (if used) match your test plan.

### 6. Close the telnet session

1. **Ctrl+]** — escape to the telnet prompt (`telnet>`).
2. Type **`quit`** and press Enter.

Avoid leaving stray telnet sessions open while long-running sweeps use the same AP.

---

## Verify the AP from the DUT (debugging)

Configuration over telnet is not enough until the **DUT** sees the network.

1. On the nRF7120 (coexistence_shell UART):

   ```text
   wifi scan
   ```
2. Confirm your configured SSID appears with **OPEN** and expected **channel / BSSID** (compare to `iw dev` on the AP).
3. Manual connect (when not using automation):

   ```text
   wifi connect -s <SSID>
   ```
4. For throughput tests, ensure the DUT can reach the **iperf server** IP configured on the test PC — see [Run iperf (throughput)](#run-iperf-throughput) below.

If scan shows **AP not found** or connect fails, fix SSID/security on the AP via telnet first, then attenuation and cabling.

---

## Run iperf (throughput)

After the DUT is **associated through the AP**, Wi‑Fi throughput tests use **classic iperf2** (`iperf` on PATH, **not** `iperf3`). The DUT runs **zperf** via coexistence_shell; the **test PC** runs the matching **iperf2 server or client** on the same LAN (reachable through the AP).

| Item                              | Typical value                                                                                                           |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Port**                    | **5001** (scripts and DUT hints assume this)                                                                      |
| **PC IP (`<server-ip>`)** | IPv4 of the test PC on the AP subnet — automation uses the PC’s default-route address unless you set `--iperf-host` |
| **Gateway**                 | AP LAN IP (e.g. **`192.168.1.50`**) — DUT traffic to the PC routes via the AP                                  |

Install iperf2 if needed (`which iperf`). Override the binary with environment variable **`IPERF_CMD`**.

### Who runs server vs client

The DUT command **`wifi_run_tput`** sets direction; the PC runs the opposite iperf2 role (same roles as coexistence test automation on the PC):

| DUT (`wifi_run_tput`) | PC runs                        | Example iperf2 on PC                                       |
| ----------------------- | ------------------------------ | ---------------------------------------------------------- |
| **udp upload**    | UDP **server**           | `iperf -s -i 1 -u -p 5001`                               |
| **udp download**  | UDP **client** → DUT IP | `iperf -c <DUT-ip> -i 1 -t 20 -u -b 5M -p 5001`          |
| **tcp upload**    | TCP **server**           | `iperf -s -i 1 -p 5001`                                  |
| **tcp download**  | TCP **client** → DUT IP | `iperf -c <DUT-ip> -i 1 -t 20 --len 1024 -p 5001 -w 24K` |

Upload modes: DUT sends to **`<server-ip>`** (the PC). Download modes: DUT listens; start **`wifi_run_tput`** on the DUT first, then run **`iperf -c <DUT-ip>`** on the PC (the automation scripts handle ordering).

### Manual debug (UDP upload)

Common check after AP + `wifi connect`:

1. On the **test PC**, start the server (use the PC’s LAN IPv4, not `127.0.0.1`, as the target in the DUT command):

   ```bash
   iperf -s -i 1 -u -p 5001
   ```
2. On the **DUT** (coexistence_shell UART), run:

   ```text
   wifi_run_tput udp upload <server-ip> 5001 20 1K 5M
   ```

   Arguments: `<server-ip>` `<port>` `<duration-sec>` `<packet-size>` `<rate>`.
3. Read **throughput** on the PC iperf summary and/or the DUT UART log.

Stop the PC server with **Ctrl+C** when finished.

### Automation on the test PC

`coex_test.py` and `wifi_coex_sweep.py` start and stop iperf2 on the PC for each step (default: **UDP upload** server).

```bash
cd /path/to/test_utilities/nrf71/phy/coex_test
python3 coex_test.py -s Driver_team_5GHz
python3 wifi_coex_sweep.py --wifi-mode tcp-download --wifi-attenuator-ip <ip>
```

- **`--iperf-host`**: IP the DUT uses as server/client peer (must be reachable through the AP).
- **`--no-local-iperf`**: script does **not** start iperf — you must run the correct **server or client** manually on the PC (see table above). Example:

  ```bash
  # Terminal 1 on PC
  iperf -s -i 1 -u -p 5001

  # Terminal 2
  python3 coex_test.py --no-local-iperf --iperf-host 192.168.50.13
  ```

**Do not** leave a manual `iperf -s -p 5001` running while using the default automated mode — port **5001** would already be in use.

### iperf checklist (with AP)

1. AP SSID/security match; DUT **`wifi connect`** OK.
2. DUT can ping or associate with gateway (**`Router:`** in logs matches AP IP).
3. PC firewall allows **UDP/TCP 5001** on the AP-facing interface.
4. **`--iperf-host`** / `<server-ip>` is the PC’s address on the **same subnet** as the DUT (via AP DHCP).
5. Use **iperf2**; interval **`-i 1`** matches script parsing.

---

## Telnet troubleshooting (AP configuration)

| Symptom                                                 | What to check                                                                                            |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Connection refused**                            | Telnet disabled on AP, wrong IP, or wrong port — enable telnet in AP admin settings per site procedure. |
| **Timeout / no route**                            | PC subnet, cable, or AP offline after reboot.                                                            |
| **Login OK but `iw dev` unchanged after edits** | Configuration not saved or radio not restarted — repeat apply/reboot steps from team runbook.           |
| **DUT scan OK but script exits on missing SSID**  | `--ssid` on the PC must **exactly match** AP SSID (case-sensitive).                              |
| **Connected but no iperf**                        | Gateway/DHCP on AP; PC firewall; `--iperf-host` / local server IP.                                     |

---

## Related docs

- [Setting up a venv](../setting_up_softwares/setting_up_venv.md) — Python env for coexistence automation on the test PC
- [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md) — build, flash, and toolchain
