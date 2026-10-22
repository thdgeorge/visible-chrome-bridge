# ChatGPT setup

Official setup and availability checked on 2026-10-22. UI and access policies can change; follow linked official guidance if labels differ. This repository is public source code; the browser connection you create is private to you.

## Confirm both sets of permissions

OpenAI's [Secure MCP Tunnel guide](https://developers.openai.com/api/docs/guides/secure-mcp-tunnels) separates Platform permissions from ChatGPT workspace access:

| Operation | Platform tunnel permissions |
| --- | --- |
| Create or edit your tunnel | Tunnels Read + Manage |
| Run client or select tunnel in ChatGPT | Tunnels Read + Use |

Ask your Platform organization owner/RBAC administrator for the appropriate role. Associate the tunnel with the intended ChatGPT workspace as well as its Platform organization. A working API key alone does not grant ChatGPT custom MCP creation rights.

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

1. Open [Platform tunnel settings](https://platform.openai.com/settings/organization/tunnels) in the intended organization and create a separate tunnel for this bridge. Use the [recommended name and optional description](#recommended-names-and-descriptions).
2. Confirm workspace association and obtain its tunnel ID privately.
3. Create a restricted runtime API key with the runtime permissions above. Keep administration credentials separate.
4. Follow [installation](INSTALLATION.md), entering values only at its local secure prompts. Keep the bridge running during discovery and use.

Do not reuse another developer's tunnel, key, installation, browser, or ChatGPT connection. An organization may manage policy centrally while every developer keeps separate browser access.

## Add the private connection

In the current ChatGPT Plugins experience:

1. Open **Plugins**, select **+**, then **Add custom MCP server**.
2. Use the [recommended plugin name and optional description](#recommended-names-and-descriptions) (or customize them consistently).
3. Under **Connection**, choose **Tunnel** and select your tunnel or enter its ID.
4. For this stdio MCP bridge, choose **None** for server authentication if asked. Tunnel runtime authentication is separate and handled by the local bridge. Do not paste its API key into a URL or description.
5. Review the risk notice and discovered tools, then create the plugin.

The current flow does not require enabling Developer Mode first. Legacy interfaces may expose custom app creation and **Scan Tools**; consult the official Help Center. Do not publish your browser connection to the workspace or public plugin directory.

## Prove the complete path

With Chrome prepared and the bridge running, select the connection in a fresh ChatGPT conversation. Ask it to list open pages, then inspect a harmless public test page you opened yourself. Accept Chrome's prompt only when expected. Confirm that the result matches the intended profile and page. Avoid purchases, account changes, private pages, and destructive actions for this first test.

Record success only after the browser tool result returns. Local health or a tool list does not prove the whole path. Follow [troubleshooting](TROUBLESHOOTING.md) if the test fails.

After dependency updates, manually review/rescan tools with your ChatGPT interface's controls. No documented public automatic tool-catalog refresh API was found in the reviewed setup documentation. The bridge does not claim to refresh ChatGPT for you.
