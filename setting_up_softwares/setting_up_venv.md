# Setting up a Python virtual environment

Use a **virtual environment (venv)** on the test PC so coexistence automation and other Python tools do not depend on the system Python or conflict with the **NCS toolchain** Python.

Typical packages for this workspace:

| Area                                               | Python deps (examples)                                                                       |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **coex_test** / **wifi_coex_sweep.py** | `pyserial` (required); `openpyxl`, `matplotlib` (XLSX/plots in `wifi_coex_sweep.py`) |
| **Nordic AI Skills Library CLI**             | Run via **uv** (see [uv](#uv) below) — ephemeral env created by `uv run`             |

With the venv active, set **`PYTHONPATH`** to the parent of the `coex_test` package (typically `test_utilities/nrf71/phy` in your workspace clone) before running automation scripts.

---

## Standard library `venv`

Works everywhere Python 3 is installed; no extra tools.

```bash
cd /path/to/your/workspace   # e.g. coex_shell

python3 -m venv .venv
source .venv/bin/activate

python -m pip install -U pip
pip install pyserial openpyxl matplotlib
```

Run scripts with the venv active:

```bash
export PYTHONPATH="/path/to/test_utilities/nrf71/phy:${PYTHONPATH}"
cd test_utilities/nrf71/phy/coex_test
python3 wifi_coex_sweep.py --help
```

Deactivate when done: `deactivate`.

Add **`.venv/`** to `.gitignore` if you create the venv inside a repo (do not commit the environment).

---

## uv

**[uv](https://docs.astral.sh/uv/)** is a fast Python package and project manager (install, venv, `pip`-compatible installs, one-off script runs). Nordic’s [AI Skills Library](setting_up_AI.md#nordic-ai-skills-library) installer expects `uv` on your PATH.

### Install uv

Official installer (Linux/macOS):

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh

#or

snap install astral-uv --classic
```

Restart the shell or `source` your profile so `uv` is on `PATH`. Check:

```bash
uv --version
```

Docs: [Installing uv](https://docs.astral.sh/uv/getting-started/installation/).

### Create and use a venv with uv

Equivalent to `python3 -m venv` + `pip install`:

```bash
cd /path/to/coex_shell

uv venv .venv
source .venv/bin/activate

uv pip install pyserial openpyxl matplotlib
```

Or without activating — run commands with an explicit interpreter:

```bash
uv run --directory test_utilities/nrf71/phy/coex_test python wifi_coex_sweep.py --help
```

(`uv run` uses the project/venv Python when a `.venv` exists in the current tree; otherwise it may create an isolated env for that invocation.)

### `uv run` (ephemeral / one-shot)

**`uv run`** can execute a tool or remote script without you managing a long-lived venv. Example from [setting_up_AI.md](setting_up_AI.md):

```bash
uv run https://skills-library.az.nordicsemi.no/cli.py install agent/code-review --target cursor
```

uv resolves dependencies for that script run automatically. Use this for Nordic catalog installs and similar CLIs; use a **dedicated `.venv`** for day-to-day `wifi_coex_sweep.py` / `coex_test.py` work on the bench.

### uv vs NCS toolchain Python

| Python                                                     | Use for                                                                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **NCS nrfutil toolchain** (`west`, Zephyr scripts) | Building and flashing — launch via `nrfutil sdk-manager toolchain launch`                                                    |
| **Lab venv** (stdlib or **uv**)                | `coex_test`, serial automation, plotting — keep separate from toolchain `PATH` unless you know you need a specific version |

Do not `pip install` coexistence test deps into the locked NCS toolchain environment unless your team standard says otherwise.

---

## Related docs

- [Setting up AI (skills, Nordic library CLI)](setting_up_AI.md)
- [Lab Wi‑Fi AP](../setting_up_devices/setting_up_AP.md)
- [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md) — toolchain Python and `west`
