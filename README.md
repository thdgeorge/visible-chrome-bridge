# Visible Chrome Bridge

> **Preview: real Windows installation and Chrome/ChatGPT acceptance remain release gates. This is not yet validated for production use.**

A per-user Windows bridge from ChatGPT to your already-running Google Chrome. It connects official [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) to the official [OpenAI tunnel client](https://github.com/openai/tunnel-client) over stdio, with Secure MCP Tunnels carrying requests over outbound HTTPS.

## Recommended tunnel and plugin names

Each developer creates a **separate** tunnel and private ChatGPT plugin. To make setup predictable, use these suggested display names and replace `<YOUR_NAME>` with your name (for example, `George`):

| Where | Name to enter |
| --- | --- |
| OpenAI Platform tunnel | `Visible Chrome Bridge - <YOUR_NAME>` |
| ChatGPT custom MCP plugin | `Visible Chrome - <YOUR_NAME>` |

For suggested **descriptions** and precise fields to copy, see [ChatGPT setup — names and descriptions](docs/CHATGPT-SETUP.md#recommended-names-and-descriptions). Append ` - QA` for an isolated test connection or ` - Work` when you need to distinguish work from personal connections. These are labels, not credentials: the actual connection uses **your own tunnel ID**, runtime key, and workspace association.

## Start here

You need Windows 10/11 x64, Windows PowerShell 5.1 or PowerShell 7, supported Node.js LTS with npm, and Chrome 144+. Platform tunnel permissions and ChatGPT custom MCP permissions are separate; check [account eligibility](docs/CHATGPT-SETUP.md) first.

1. Create your personal tunnel and restricted runtime key using [ChatGPT setup](docs/CHATGPT-SETUP.md).
2. Clone this repository or extract a reviewed archive. Open PowerShell in its directory:

   ```powershell
   .\Install-Windows.ps1
   ```

3. Enter your tunnel ID and key at the secure local prompts. Installation does not start the bridge. [Prepare Chrome](docs/INSTALLATION.md#prepare-chrome), then run:

   ```powershell
   .\Start-Bridge.ps1
   .\Get-BridgeStatus.ps1
   ```

4. Add your private ChatGPT custom MCP connection, review tools, and make a harmless browser call. Chrome consent and a successful call are required to verify the complete connection.

The bridge uses `--autoConnect`. It never launches or restarts Chrome, creates a browser profile, or configures a Chrome debugging port. Read the [browser access boundary](docs/SECURITY.md#browser-and-tool-access) before use.

## Daily commands

Run these from the checkout or installed `app` directory under `%LOCALAPPDATA%\VisibleChromeBridge`:

```powershell
.\Get-BridgeStatus.ps1
.\Check-Updates.ps1
.\Stop-Bridge.ps1
.\Update-Bridge.ps1
.\Start-Bridge.ps1
```

Updates and rollback require a stopped bridge and never restart it automatically. Default policy is `Manual`; optional scheduled checking and explicit unattended opt-in are explained in [updates](docs/UPDATES.md).

Configuration, DPAPI-encrypted credentials, installed payloads, and bounded lifecycle state live outside the checkout. Each developer owns their own tunnel, credentials, bridge, ChatGPT connection, and browser session. Never publish shared access to a personal browser.

## Documentation

- [Installation, prerequisites, startup, and removal](docs/INSTALLATION.md)
- [ChatGPT, permissions, and first tool call](docs/CHATGPT-SETUP.md)
- [Architecture and validation boundaries](docs/ARCHITECTURE.md)
- [Updates, rollback, and tool review](docs/UPDATES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Security](docs/SECURITY.md)
- [Contributing and manual acceptance checklist](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [Third-party notices](THIRD-PARTY-NOTICES.md)
- [Executed checks and remaining acceptance gates](docs/VALIDATION.md)

Run isolated PowerShell checks with `.\tests\Run-Tests.ps1`; no Pester installation is needed. Automated checks cannot prove real tunnel authentication, Chrome consent, or a working ChatGPT tool call.

This project is independent and **not affiliated with or endorsed by OpenAI or Google**.

## License

The wrapper is [MIT licensed](LICENSE). Upstream software retains its own licenses; see [third-party notices](THIRD-PARTY-NOTICES.md).
