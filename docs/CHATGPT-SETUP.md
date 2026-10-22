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

These are **copy-and-customize suggestions**, not required literal strings. Replace `<YOUR_NAME>` with your own name (for example, `George`), not the angle brackets. If several devices or environments need separate connections, append a suffix such as ` - Work` or ` - QA`.

**OpenAI Platform — Create tunnel**

- **Name:** `Visible Chrome Bridge - <YOUR_NAME>`
- **Description** (if the field is shown):
  > Private tunnel from ChatGPT to my existing local Google Chrome through Chrome DevTools MCP.

**ChatGPT — Add custom MCP server**

- **Name:** `Visible Chrome - <YOUR_NAME>`
- **Description** (optional):
  > Connects ChatGPT to my existing local Google Chrome via Chrome DevTools MCP and a private Secure MCP Tunnel. Can inspect and interact with open tabs after Chrome consent. Requires my local bridge to be running.
- **Connection:** `Tunnel` — select **your own** tunnel created above.
- **Server authentication:** `None` for this bridge's stdio MCP server if the form asks; the restricted **tunnel runtime API key stays on your PC**, entered only in the secure installer prompt.
- **Sharing:** keep the custom plugin **private** to your account; never publish a personal browser connection to an entire workspace.

**Example for George:** Tunnel `Visible Chrome Bridge - George`; plugin `Visible Chrome - George`. For test use, `Visible Chrome Bridge - George - QA` and `Visible Chrome - George - QA`.

Names and descriptions are for identifying resources, **not** for authorizing or linking them. ChatGPT must select the same `tunnel_id` that the local installer uses, with the correct Platform-organization and ChatGPT-workspace association. No tunnel ID or runtime key belongs in a public description.

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
