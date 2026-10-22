# ChatGPT setup

Official setup and availability checked on 2026-10-22. UI and access policies can change; follow linked official guidance if labels differ. This repository is public source code; the browser connection you create is private to you.

## Confirm both sets of permissions

OpenAI's [Secure MCP Tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) separates Platform permissions from ChatGPT workspace access:

| Operation | Platform tunnel permissions |
| --- | --- |
| Create or edit your tunnel | Tunnels Read + Manage |
| Run client or select tunnel in ChatGPT | Tunnels Read + Use |

Ask your Platform organization owner/RBAC administrator for the appropriate role. Associate the tunnel with the intended ChatGPT workspace as well as its Platform organization. A working API key alone does not grant ChatGPT custom MCP creation rights. **If you do not have the required permissions, ask an administrator before proceeding; running the installer cannot grant them.**

The current [ChatGPT Help Center](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt) describes custom MCP support on ChatGPT web for Business and Enterprise/Edu. Business creation is for admins/owners; Enterprise/Edu can authorize selected developers through RBAC. Verify workspace policy first. Do not assume a personal paid plan includes this capability.

## Recommended names and descriptions

These are **suggested copy-and-paste labels** for every developer. You do not need to add your personal name. The tunnel ID and restricted runtime API key remain **individual**, even when display names are identical.

**OpenAI Platform — Create tunnel**

- **Name:** `Visible Chrome Bridge`
- **Description** (if shown):
  > Private tunnel connecting ChatGPT to an existing local Google Chrome session through Chrome DevTools MCP.

**ChatGPT — Add custom MCP server**

- **Name:** `Visible Chrome`
- **Description** (optional):
  > Connects ChatGPT to the existing local Google Chrome via Chrome DevTools MCP and a private Secure MCP Tunnel. Can inspect and interact with open tabs after Chrome consent. Requires the local bridge to be running.
- **Connection:** `Tunnel` — select **your own** tunnel created above.
- **Server authentication:** `None` for this bridge's stdio MCP server, if asked. The restricted **tunnel runtime API key stays on the PC**, entered only in the installer's secure local prompt.
- **Sharing:** keep the custom plugin **private**; never publish personal browser access to a whole workspace.

**For isolated manual QA (optional):** use `Visible Chrome Bridge QA` for the tunnel and `Visible Chrome QA` for the plugin. Use unique test credentials and the appropriate isolated data directory.

Display names are labels only; they do not connect or authorize anything. ChatGPT must select the same `tunnel_id` configured in the local installer with the correct Platform organization and ChatGPT workspace association. If a shared organization has many identical tunnel names or enforces unique labels, use a short, recognizable optional suffix (for example, a device or environment name). Do not put tunnel IDs, runtime keys, or other secrets in names or public descriptions.

## Create your personal tunnel

1. Identify the **ChatGPT workspace** where you will add your private plugin and the **Platform organization** where the tunnel will live. These can have separate permissions.
2. Open [OpenAI Platform → Tunnels](https://platform.openai.com/settings/organization/tunnels). Create a **personal tunnel** with the [recommended name and description](#recommended-names-and-descriptions), and ensure it is associated with **both the intended Platform organization and ChatGPT workspace**. If you cannot select your workspace, ask the relevant administrator.
3. Record the new **`tunnel_id`** privately. This ID, not the display name, must be entered into the local installer and selected in ChatGPT.
4. Open [OpenAI Platform → API keys](https://platform.openai.com/settings/organization/api-keys) under the correct organization. Create a **separate, restricted runtime API key** with **Tunnels Read + Use**, or ask an administrator to issue one. Creating/managing the tunnel instead needs **Tunnels Read + Manage**; the runtime key should not need Manage. For UI differences, see the [official permissions guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels#permissions-and-access).
5. Keep the tunnel ID and key out of screenshots, chat, CLI arguments and tracked files. Enter them **only at the hidden local installer prompts** in [installation](INSTALLATION.md). **Start the bridge before plugin discovery** and keep it running through the first tool call.

**If your tunnel does not appear in ChatGPT:** confirm the tunnel includes the target **ChatGPT workspace**, not only its Platform organization, and that the plugin creator has Tunnels Read + Use. Do not create an unrelated tunnel to work around missing access.

Do not reuse another developer's tunnel, key, installation, browser, or ChatGPT connection. An organization may manage policy centrally while every developer keeps separate browser access.

## Add the private connection

In the current ChatGPT Plugins experience:

1. Open **Plugins**, select **+**, then **Add custom MCP server**.
2. Use the [recommended plugin name and optional description](#recommended-names-and-descriptions) (or customize them consistently).
3. Under **Connection**, choose **Tunnel** and select your tunnel or enter its ID.
4. For this stdio MCP bridge, choose **None** for server authentication if asked. Tunnel runtime authentication is separate and handled by the local bridge. Do not paste its API key into a URL or description.
5. Review the risk warning, select **I understand and want to continue**, then **Create as a plugin**, and review the discovered tools/metadata. Actual UI labels may vary by release. **Do not publish a browser connection to the workspace.**

The current flow does not require enabling Developer Mode first. Legacy interfaces may expose custom app creation and **Scan Tools**; consult the official Help Center. Do not publish your browser connection to the workspace or public plugin directory.

## Prove the complete path

With Chrome prepared and the bridge running, manually open [https://example.com/](https://example.com/) in the intended Chrome profile. Select the **Visible Chrome** plugin in a fresh ChatGPT conversation and ask:

> Find my already-open https://example.com/ tab and read its document title. Do not navigate, open, close, or change tabs.

Accept Chrome's permission prompt only if you expected it. The expected title is **Example Domain**. Confirm it is the intended Chrome profile and tab. Avoid purchases, account changes, private pages, and destructive actions for the first test. **`BrowserVerified=False` in the local status is expected even after success**: that field cannot observe ChatGPT's browser tool calls.

Record success only after the browser tool result returns. Local health or a tool list does not prove the whole path. Follow [troubleshooting](TROUBLESHOOTING.md) if the test fails.

After upstream dependency updates, the existing private plugin and tunnel remain valid. **If tool definitions changed**, refresh/review the existing custom MCP app's action catalog using the applicable ChatGPT workspace app settings (admin/manager permissions may be required); changes are not applied automatically. The bridge cannot refresh ChatGPT for you. See [OpenAI's refresh guidance](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt) and [the exact update workflow](UPDATES.md#updating-just-one-component).
