# Visible Chrome Bridge

> **Beta / preview.** A real ChatGPT → Chrome tool call succeeded on the maintainer's Windows PC. Clean-machine installation, failure paths, logon startup and live updates/rollback still require QA. See [validation](docs/VALIDATION.md); this is not production-certified.

Use ChatGPT with your **existing, running Google Chrome** through the official [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) and [OpenAI Secure MCP Tunnel](https://github.com/openai/tunnel-client). The bridge does not create Chrome profiles, restart Chrome, or expose a public browser-debugging port.

## Quick start — first installation

**Requirements:** Windows 10/11 x64, Chrome 144+, Windows PowerShell 5.1 or PowerShell 7, and Node.js 22.12+ (22.x) or 24 LTS with npm. You also need an eligible ChatGPT workspace with custom-MCP permission. Install [Node.js](https://nodejs.org/en/download) and [Chrome](https://www.google.com/chrome/) first, if needed. Git is optional when using ZIP.

1. **Create your tunnel and runtime key.** Go to [OpenAI Platform → Tunnels](https://platform.openai.com/settings/organization/tunnels). Create a tunnel named `Visible Chrome Bridge` and associate it with your intended ChatGPT workspace. Keep its `tunnel_id` private. In [Platform API keys](https://platform.openai.com/settings/organization/api-keys), create a **separate restricted runtime API key** with **Tunnels Read + Use**; tunnel creation requires **Tunnels Read + Manage**. If you cannot find these permissions, see the [Platform setup guide](docs/CHATGPT-SETUP.md#create-your-personal-tunnel) and ask your administrator. Never paste credentials in chat.

2. **Get the source and install.** Open a normal **non-admin** PowerShell window:

   ```powershell
   git clone https://github.com/thdgeorge/visible-chrome-bridge.git
   cd visible-chrome-bridge
   .\Install-Windows.ps1 -TunnelVersion 0.0.17 -McpVersion 1.11.0
   ```

   These exact upstream versions reproduce the **tested beta combination**. Omitting both version flags on a fresh install instead selects the current stable upstream versions, which may not yet be validated here; see [version guidance](docs/UPDATES.md#tested-beta-baseline-versus-upstream-latest). Alternatively, on the [repository Code page](https://github.com/thdgeorge/visible-chrome-bridge), choose **Code → Download ZIP** for the current `main` source (or use a versioned archive from [Releases](https://github.com/thdgeorge/visible-chrome-bridge/releases)). Extract it, open PowerShell **inside the project folder**, and run the same installer command. You do not need Git for ZIP. The installer downloads official dependencies and asks for the tunnel ID and runtime key in **hidden local prompts**. It does not start the bridge.

3. **Prepare Chrome and start.** Open your usual Chrome profile, go to `chrome://inspect/#remote-debugging`, and enable remote debugging. From the project directory:

   ```powershell
   .\Start-Bridge.ps1
   .\Get-BridgeStatus.ps1
   ```

   You want `Running=True`, `Healthy=True` and `RuntimeReady=True`; if readiness is pending, check again shortly. **`BrowserVerified=False` is normal**, even after successful use: status cannot see ChatGPT calls. See [status field meanings](docs/INSTALLATION.md#verify-installation-and-first-browser-call). Leave Chrome open and approve its consent dialog when you make the first browser call.

4. **Create your private ChatGPT plugin.** In ChatGPT web, open **Plugins → + → Add custom MCP server**. Set **Name: `Visible Chrome`**, **Connection: Tunnel** and select your own `Visible Chrome Bridge` tunnel (or paste its ID). Use **Server authentication: None**, if asked, for this stdio MCP bridge. Acknowledge the risk warning, create the plugin, and review the discovered tools. **Do not publish it to the workspace.** [Copyable fields and descriptions](docs/CHATGPT-SETUP.md#recommended-names-and-descriptions).

5. **Prove it works.** Open [https://example.com/](https://example.com/) **manually** in the intended Chrome profile. In a fresh ChatGPT conversation using the `Visible Chrome` plugin, ask:

   > Find my already-open https://example.com/ tab and read its document title. Do not navigate, open, close, or change tabs.

   Expect **Example Domain**. A successful tool result, not local readiness alone, proves the full connection. See [troubleshooting](docs/TROUBLESHOOTING.md) if anything fails.

**Security:** Chrome DevTools tools can inspect and act on signed-in tabs after consent. Keep the connection private, review open tabs, and stop the bridge when finished. Never share tunnel credentials or browser session access. [Security details](docs/SECURITY.md).

## Recommended tunnel and plugin names

| Where | Suggested name |
| --- | --- |
| OpenAI Platform tunnel | `Visible Chrome Bridge` |
| ChatGPT custom MCP plugin | `Visible Chrome` |
| Optional isolated test tunnel | `Visible Chrome Bridge QA` |
| Optional isolated test plugin | `Visible Chrome QA` |

The names are **display labels**, not credentials. Each developer needs their **own** tunnel ID, runtime API key, local bridge and private ChatGPT plugin, even if labels match. [Descriptions and fields](docs/CHATGPT-SETUP.md#recommended-names-and-descriptions).

## Daily use

Run from the checkout or the installed `app` folder under `%LOCALAPPDATA%\VisibleChromeBridge`:

```powershell
.\Get-BridgeStatus.ps1
.\Stop-Bridge.ps1
.\Start-Bridge.ps1
.\Check-Updates.ps1
```

The hidden worker **continues after closing the PowerShell window**. Starting it automatically after a Windows login is **off by default**; see [optional startup](docs/INSTALLATION.md#optional-startup-and-update-policy). Updates and rollback require the bridge to be stopped. `Update-Bridge.ps1` updates upstream dependencies, **not the project wrapper**; see [updates](docs/UPDATES.md).

## Documentation

- [Installation, prerequisites, startup and uninstall](docs/INSTALLATION.md)
- [OpenAI tunnel, API key and ChatGPT setup](docs/CHATGPT-SETUP.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Updates and rollback](docs/UPDATES.md)
- [Security](docs/SECURITY.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Validation and remaining QA](docs/VALIDATION.md)
- [Contributing](CONTRIBUTING.md), [changelog](CHANGELOG.md), [third-party notices](THIRD-PARTY-NOTICES.md)

This is an independent project **not affiliated with or endorsed by OpenAI or Google**. Wrapper source: [MIT](LICENSE); downloaded dependencies have their own licenses.
