# Setting up AI (Cursor Agent Skills)

**Agent Skills** teach Cursor how to run team-specific workflows: lab bench steps, doc style, commit conventions, coexistence test automation, and similar tasks. A skill is a directory with a **`SKILL.md`** file; the agent reads it when the task matches the skill description or you ask explicitly.

This guide covers **where to put skills**, **how to author `SKILL.md`**, and **how to use them** alongside this workspace.

---

## Nordic AI Skills Library

Nordic hosts a central catalog of Agent Skills for Cursor and related AI tooling:

**[Nordic AI Skills Library](https://skills-library.az.nordicsemi.no/)** — `https://skills-library.az.nordicsemi.no/`

Use it to **browse, discover, and install** skills that follow Nordic team conventions (NCS, lab workflows, internal tooling, and similar). Prefer skills from the library when one already matches your task; add **personal** or **project** skills (below) only for gaps or coexistence-specific runbooks (for example linking to [setting_up_AP.md](../setting_up_devices/setting_up_AP.md) in **info_docs**).

Access may require **Nordic network / SSO** depending on site policy. If the page is unavailable, retry on VPN or corporate network and follow any on-site install instructions shown there.

### Install and update from the library (examples)

The library provides a CLI (via **[uv](https://docs.astral.sh/uv/)**). Run from any directory on a machine that can reach the library URL.

**Install** (first time):

```bash
uv run https://skills-library.az.nordicsemi.no/cli.py install agent/code-review --target cursor
```

**Update** (refresh an already-installed catalog skill):

```bash
uv run https://skills-library.az.nordicsemi.no/cli.py update agent/code-review
```

| Part                  | Meaning                                                                           |
| --------------------- | --------------------------------------------------------------------------------- |
| `agent/code-review` | Skill path in the Nordic catalog (swap for other skills listed on the site)       |
| `--target cursor`   | **Install only** — target Cursor’s skill layout (personal / synced store) |

After install, use **Agent** chat and refer to code review (or the skill name shown in Cursor) so the agent loads the skill. Install or update other catalog skills the same way: change the catalog path (see [Useful AI skills](#useful-ai-skills)) to the path given on [skills-library.az.nordicsemi.no](https://skills-library.az.nordicsemi.no/).

---

## Useful AI skills

Curated entries from the [Nordic AI Skills Library](https://skills-library.az.nordicsemi.no/) that are commonly useful in firmware and lab workflows. Install or update with **`uv`** as in [Install and update from the library](#install-and-update-from-the-library-examples); use **`--target cursor`** on **install** only.

| Catalog path                    | Kind  | Use when                                                                   |
| ------------------------------- | ----- | -------------------------------------------------------------------------- |
| **`agent/code-review`** | Agent | Reviewing diffs, PRs, or local changes with Nordic code-review conventions |
| **`group/atlassian`**   | Group | Jira tasks, Confluence updates, Bitbucket/Atlassian MCP integration        |

### `agent/code-review`

Adds a **code-review** agent configuration under `.cursor/` (for example `.cursor/agents/code-review.md`).

```bash
uv run https://skills-library.az.nordicsemi.no/cli.py install agent/code-review --target cursor
uv run https://skills-library.az.nordicsemi.no/cli.py update agent/code-review
```

In **Agent** chat, ask for a **code review** of your branch or uncommitted changes so the installed agent is used.

### `group/atlassian`

Installs a **bundle** of related MCP servers, skills, and rules (not a single `SKILL.md`). Typical members include **Atlassian** and **Bitbucket** MCP entries in `.cursor/mcp.json`, plus skills such as **create-jira-task**, **create-jira-embedded-bug**, **confluence-update**, and **analyze-test-coverage** (exact set follows the group version on the library).

```bash
uv run https://skills-library.az.nordicsemi.no/cli.py install group/atlassian --target cursor
uv run https://skills-library.az.nordicsemi.no/cli.py update group/atlassian
```

Requires **corporate network / SSO** and valid Atlassian credentials where MCP prompts for them. After install, configure MCP in Cursor if prompted and use Agent for Jira/Confluence-oriented tasks described in each skill’s description.

---

## Skill locations

| Type               | Path                                                                       | Scope                                                           |
| ------------------ | -------------------------------------------------------------------------- | --------------------------------------------------------------- |
| **Personal** | `skills/<skill-name>/SKILL.md` in your **Cursor user Agent Store** | Available in every project when you use the same Cursor account |
| **Project**  | `.cursor/skills/<skill-name>/SKILL.md` in a git repo                     | Shared with everyone who clones the repository                  |

Optional files next to `SKILL.md`: `reference.md`, `examples.md`, `scripts/`.

**Do not** add custom skills under **`~/.cursor/skills-cursor/`** — that tree is reserved for Cursor built-in skills.

If the user Agent Store is not available on a machine, you can place a personal skill under **`~/.cursor/skills/<skill-name>/`** locally until the store syncs.

---

## Create a skill

### 1. Choose a name

Use lowercase letters, numbers, and hyphens only (max 64 characters), for example:

- `coex-ap-setup`
- `wifi-coex-sweep`

### 2. Add `SKILL.md`

Every skill needs YAML frontmatter and a short markdown body. Keep **`SKILL.md` under ~500 lines**; move long reference material to linked files.

```markdown
---
name: coex-ap-setup
description: >-
  Documents lab Wi‑Fi AP telnet configuration, wl TX power/RSSI, and iperf2
  for coexistence bench testing. Use when setting up an AP, telnet, wl, or
  coexistence throughput on the RF bench.
disable-model-invocation: true
---

# Coexistence lab AP

## Instructions

1. Follow [setting_up_AP.md](../setting_up_devices/setting_up_AP.md) for telnet and wl.
2. Match automation SSIDs to `coex_test.py` / `wifi_coex_sweep.py` `-s` / `--ssid`.
3. Run `nrfjprog --com` before fixing UART `--port` / `--peer-port` (ttyACM numbers change after USB re-enumeration).

## Examples

- User: "Configure AP for Driver_team_5GHz" → open telnet, `iw dev`, align SSID and OPEN security.
```

### 3. Write the description carefully

The **`description`** field is how the agent decides when to apply the skill. Write it in **third person**, and include both:

- **WHAT** the skill does
- **WHEN** to use it (keywords: AP, telnet, `wifi_coex_sweep`, NCS west, etc.)

### 4. `disable-model-invocation`

| Value                                    | Behavior                                                          |
| ---------------------------------------- | ----------------------------------------------------------------- |
| **`true`** (recommended default) | Skill loads when you @mention it or ask explicitly                |
| omitted / **`false`**            | Agent may consider the skill from ambient context (use sparingly) |

---

## Project skill in this workspace (optional)

To version a skill with **coex_shell** or **info_docs**:

```text
coex_shell/
└── .cursor/
    └── skills/
        └── my-team-skill/
            └── SKILL.md
```

Commit and push like any other project file. Prefer **project** skills for bench workflows everyone should share; use **personal** skills for individual preferences.

---

## Using skills in Cursor

1. Ensure the skill exists in the user store or `.cursor/skills/`.
2. In **Agent** chat, describe the task using terms from the skill **description**, or refer to the skill by name.
3. For lab docs in **info_docs**, link skills only to **`setting_up_workspace/`**, **`setting_up_devices/`**, and **`setting_up_softwares/`** (not **`projects/`**). Example targets:| Directory                 | Example                                                                    |
   | ------------------------- | -------------------------------------------------------------------------- |
   | `setting_up_workspace/` | [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md) |
   | `setting_up_devices/`   | [Lab AP setup](../setting_up_devices/setting_up_AP.md)                      |
   | `setting_up_softwares/` | [Setting up a venv](setting_up_venv.md)                                     |

---

## Authoring checklist

- [ ] `name` and `description` in frontmatter are valid and specific
- [ ] Instructions are concise (assume the agent knows general programming)
- [ ] File links are one level deep from `SKILL.md` where possible
- [ ] No secrets, tokens, or lab passwords in the skill (link to runbooks instead)
- [ ] Supporting scripts, if any, use repo-relative paths (not Windows `\` paths)

---

## Related docs

- [Nordic AI Skills Library](https://skills-library.az.nordicsemi.no/)
- [Setting up a venv](setting_up_venv.md) — install **uv** for the skills library CLI
- [Lab Wi‑Fi AP](../setting_up_devices/setting_up_AP.md)
- [nRF7120 NCS West guide](../setting_up_workspace/nrf7120-ncs-west-guide.md)
