# Security

## Browser and tool access

Treat the ChatGPT connection as privileged access to your signed-in browser. DevTools tools can read page content and perform actions with your session. Review [upstream privacy guidance](https://github.com/ChromeDevTools/chrome-devtools-mcp#disclaimers). Page text can contain malicious instructions; it is not authorization to send messages, change accounts, buy items, or reveal information.

Automatic connection covers every window in the selected default profile. The wrapper provides no per-tab isolation, browser sandbox, or fine-grained site permissions. Review open pages before consent and revoke access when finished. Keep each developer's key, tunnel, connection, and browser separate. Never publish a personal browser tool to a workspace.

## Local credential protection

The installer uses secure interactive input and current-user Windows DPAPI. Credentials live outside the checkout under a protected ACL granting access to the owning user and SYSTEM. The tunnel ID is private configuration, although it does not replace authentication.

The worker decrypts values in memory for the official client. Plaintext briefly exists in memory and the tunnel child's environment. The MCP child must not inherit the runtime API key. No secret is intentionally placed in process arguments or raw persisted logs. These measures do not protect against malware running as the same user, administrators, debuggers, memory dumps, or a compromised browser session. Avoid shell transcripts during credential entry and do not share the private root.

Rotate a suspected key in Platform, stop the bridge, then rerun installation with `-ReplaceCredentials` to enter a restricted replacement. Local uninstall does not revoke remote credentials or remove ChatGPT connections.

## Process and network boundaries

A hidden worker owns the tunnel/MCP tree through a Windows Job Object. Stop signals that instance; it never finds processes by name or terminates Chrome. Installation does not import or alter other tunnel-client profiles. There is no inbound internet listener or Chrome debugging port; the tunnel health/admin listener binds only to loopback on an allocated port.

Stop the bridge when you do not want tools available. Closing a console does not reliably stop its hidden worker. Review company policy before making company browser content available to an external AI service.

## Dependencies and supply chain

Only official upstream GitHub releases and the official npm package are used. The installer checks tunnel archive SHA-256 metadata and npm integrity, disables npm lifecycle scripts, and records exact versions. Missing verification metadata fails closed. HTTPS metadata and checksums are not independent signatures and cannot eliminate upstream compromise risk. Review release notes before changing pins.

Default updates are manual. Optional unattended activation requires a stopped bridge; no policy may stop a running bridge to update it. See [updates](UPDATES.md) for rollback limits and manual tool review.

Review data collection for each chosen MCP version. Upstream documents usage statistics and performance-related external requests; Chrome's own metrics preference does not govern the MCP package. Compare the installed wrapper's arguments with the upstream [privacy and statistics documentation](https://github.com/ChromeDevTools/chrome-devtools-mcp#usage-statistics).

The wrapper supplies `--no-usage-statistics` and `--no-performance-crux` and
disables upstream background update checks. The environment-only Node launcher
removes runtime credentials and configuration overrides before starting the
official MCP server with inherited stdio; it does not implement an MCP protocol.
The loopback admin UI may expose sensitive operational information to other local
processes. Loopback is not an authentication boundary against local users.

## Reporting a security problem

Do not open public issues containing credentials, browser data, or exploit details against an active personal installation. Use GitHub Security reporting if available; otherwise contact the maintainer privately to arrange a secure report. If no private channel exists, request one in an issue without sensitive details. Revoke exposed keys promptly.

This beta completed a **limited real-PC QA** with a separate tunnel, Chrome consent, user-confirmed read-only ChatGPT tool use, and isolated stop/coexistence. **Clean Windows 10/11 installs, negative permission and consent cases, logon startup, real upgrades/rollback, and broader release acceptance remain outstanding.** Automated tests and one happy-path QA run are not a security audit or a production-readiness claim. See [validation](VALIDATION.md).
