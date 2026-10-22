# Visible Chrome Bridge

> **Work in progress — no installer or stable release yet.**

A community-maintained Windows setup project for connecting ChatGPT to your **existing Google Chrome session** through the official [Chrome DevTools MCP](https://github.com/ChromeDevTools/chrome-devtools-mcp) and [OpenAI Secure MCP Tunnel client](https://github.com/openai/tunnel-client).

## Design goals

- Reuse the user's running Chrome and existing profile with `--autoConnect` (Chrome 144+); do not create a separate Chrome profile.
- Each developer uses their **own** Secure MCP Tunnel, runtime credentials, and ChatGPT custom MCP connection.
- Offer repeatable installation, health checks, controlled version updates, and rollback.
- Never store or commit secrets, session data, browser logs, or internal company files.

## Status

The initial implementation is being developed and tested. **Do not treat this repository as an installable production tool yet.** Setup and documentation will be added after Windows validation.

## References

- [Chrome DevTools MCP: advanced usage](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/advanced-usage.md)
- [OpenAI tunnel-client](https://github.com/openai/tunnel-client)
- [Connecting custom MCP servers in ChatGPT](https://help.openai.com/en/articles/12584461-connecting-custom-mcp-servers-in-chatgpt)

This project is independent and **not affiliated with or endorsed by OpenAI or Google**.

## License

MIT — see [LICENSE](LICENSE).
