Title: Web

URL Source: https://opencode.ai/docs/web/

Markdown Content:
Web | OpenCode
===============
[Skip to content](https://opencode.ai/docs/web/#_top)

[![Image 1](https://opencode.ai/docs/_astro/logo-dark.DOStV66V.svg)![Image 2](https://opencode.ai/docs/_astro/logo-light.B0yzR0O5.svg) OpenCode](https://opencode.ai/docs/)

[app.header.home](https://opencode.ai/)[app.header.docs](https://opencode.ai/docs/)

[](https://github.com/anomalyco/opencode)[](https://opencode.ai/discord)

Search Ctrl K

 Cancel 

*   [Intro](https://opencode.ai/docs/)
*   [Config](https://opencode.ai/docs/config/)
*   [Providers](https://opencode.ai/docs/providers/)
*   [Network](https://opencode.ai/docs/network/)
*   [Enterprise](https://opencode.ai/docs/enterprise/)
*   [Troubleshooting](https://opencode.ai/docs/troubleshooting/)
*   [Windows (WSL)](https://opencode.ai/docs/windows-wsl/)
*   
Usage 
    *   [TUI](https://opencode.ai/docs/tui/)
    *   [CLI](https://opencode.ai/docs/cli/)
    *   [Web](https://opencode.ai/docs/web/)
    *   [IDE](https://opencode.ai/docs/ide/)
    *   [Zen](https://opencode.ai/docs/zen/)
    *   [Share](https://opencode.ai/docs/share/)
    *   [GitHub](https://opencode.ai/docs/github/)
    *   [GitLab](https://opencode.ai/docs/gitlab/)

*   
Configure 
    *   [Tools](https://opencode.ai/docs/tools/)
    *   [Rules](https://opencode.ai/docs/rules/)
    *   [Agents](https://opencode.ai/docs/agents/)
    *   [Models](https://opencode.ai/docs/models/)
    *   [Themes](https://opencode.ai/docs/themes/)
    *   [Keybinds](https://opencode.ai/docs/keybinds/)
    *   [Commands](https://opencode.ai/docs/commands/)
    *   [Formatters](https://opencode.ai/docs/formatters/)
    *   [Permissions](https://opencode.ai/docs/permissions/)
    *   [LSP Servers](https://opencode.ai/docs/lsp/)
    *   [MCP servers](https://opencode.ai/docs/mcp-servers/)
    *   [ACP Support](https://opencode.ai/docs/acp/)
    *   [Agent Skills](https://opencode.ai/docs/skills/)
    *   [Custom Tools](https://opencode.ai/docs/custom-tools/)

*   
Develop 
    *   [SDK](https://opencode.ai/docs/sdk/)
    *   [Server](https://opencode.ai/docs/server/)
    *   [Plugins](https://opencode.ai/docs/plugins/)
    *   [Ecosystem](https://opencode.ai/docs/ecosystem/)

[GitHub](https://github.com/anomalyco/opencode)[Discord](https://opencode.ai/discord)

Select theme Select language 

On this page

*   [Overview](https://opencode.ai/docs/web/#_top)
*   [Getting Started](https://opencode.ai/docs/web/#getting-started)
*   [Configuration](https://opencode.ai/docs/web/#configuration)
    *   [Port](https://opencode.ai/docs/web/#port)
    *   [Hostname](https://opencode.ai/docs/web/#hostname)
    *   [mDNS Discovery](https://opencode.ai/docs/web/#mdns-discovery)
    *   [CORS](https://opencode.ai/docs/web/#cors)
    *   [Authentication](https://opencode.ai/docs/web/#authentication)

*   [Using the Web Interface](https://opencode.ai/docs/web/#using-the-web-interface)
    *   [Sessions](https://opencode.ai/docs/web/#sessions)
    *   [Server Status](https://opencode.ai/docs/web/#server-status)

*   [Attaching a Terminal](https://opencode.ai/docs/web/#attaching-a-terminal)
*   [Config File](https://opencode.ai/docs/web/#config-file)

On this page
------------

*   [Overview](https://opencode.ai/docs/web/#_top)
*   [Getting Started](https://opencode.ai/docs/web/#getting-started)
*   [Configuration](https://opencode.ai/docs/web/#configuration)
    *   [Port](https://opencode.ai/docs/web/#port)
    *   [Hostname](https://opencode.ai/docs/web/#hostname)
    *   [mDNS Discovery](https://opencode.ai/docs/web/#mdns-discovery)
    *   [CORS](https://opencode.ai/docs/web/#cors)
    *   [Authentication](https://opencode.ai/docs/web/#authentication)

*   [Using the Web Interface](https://opencode.ai/docs/web/#using-the-web-interface)
    *   [Sessions](https://opencode.ai/docs/web/#sessions)
    *   [Server Status](https://opencode.ai/docs/web/#server-status)

*   [Attaching a Terminal](https://opencode.ai/docs/web/#attaching-a-terminal)
*   [Config File](https://opencode.ai/docs/web/#config-file)

Web
===

Using OpenCode in your browser.

OpenCode can run as a web application in your browser, providing the same powerful AI coding experience without needing a terminal.

![Image 3: OpenCode Web - New Session](https://opencode.ai/docs/_astro/web-homepage-new-session.BB1mEdgo_Z1AT1v3.webp)

[Getting Started](https://opencode.ai/docs/web/#getting-started)
----------------------------------------------------------------

Start the web interface by running:

Terminal window

`opencode web`

This starts a local server on `127.0.0.1` with a random available port and automatically opens OpenCode in your default browser.

Caution

If `OPENCODE_SERVER_PASSWORD` is not set, the server will be unsecured. This is fine for local use but should be set for network access.

Windows Users

For the best experience, run `opencode web` from [WSL](https://opencode.ai/docs/windows-wsl) rather than PowerShell. This ensures proper file system access and terminal integration.

* * *

[Configuration](https://opencode.ai/docs/web/#configuration)
------------------------------------------------------------

You can configure the web server using command line flags or in your [config file](https://opencode.ai/docs/config).

### [Port](https://opencode.ai/docs/web/#port)

By default, OpenCode picks an available port. You can specify a port:

Terminal window

`opencode web --port 4096`

### [Hostname](https://opencode.ai/docs/web/#hostname)

By default, the server binds to `127.0.0.1` (localhost only). To make OpenCode accessible on your network:

Terminal window

`opencode web --hostname 0.0.0.0`

When using `0.0.0.0`, OpenCode will display both local and network addresses:

`Local access:       http://localhost:4096  Network access:     http://192.168.1.100:4096`

### [mDNS Discovery](https://opencode.ai/docs/web/#mdns-discovery)

Enable mDNS to make your server discoverable on the local network:

Terminal window

`opencode web --mdns`

This automatically sets the hostname to `0.0.0.0` and advertises the server as `opencode.local`.

You can customize the mDNS domain name to run multiple instances on the same network:

Terminal window

`opencode web --mdns --mdns-domain myproject.local`

### [CORS](https://opencode.ai/docs/web/#cors)

To allow additional domains for CORS (useful for custom frontends):

Terminal window

`opencode web --cors https://example.com`

### [Authentication](https://opencode.ai/docs/web/#authentication)

To protect access, set a password using the `OPENCODE_SERVER_PASSWORD` environment variable:

Terminal window

`OPENCODE_SERVER_PASSWORD=secret opencode web`

The username defaults to `opencode` but can be changed with `OPENCODE_SERVER_USERNAME`.

* * *

[Using the Web Interface](https://opencode.ai/docs/web/#using-the-web-interface)
--------------------------------------------------------------------------------

Once started, the web interface provides access to your OpenCode sessions.

### [Sessions](https://opencode.ai/docs/web/#sessions)

View and manage your sessions from the homepage. You can see active sessions and start new ones.

![Image 4: OpenCode Web - Active Session](https://opencode.ai/docs/_astro/web-homepage-active-session.BbK4Ph6e_Z1O7nO1.webp)

### [Server Status](https://opencode.ai/docs/web/#server-status)

Click “See Servers” to view connected servers and their status.

![Image 5: OpenCode Web - See Servers](https://opencode.ai/docs/_astro/web-homepage-see-servers.BpCOef2l_ZB0rJd.webp)

* * *

[Attaching a Terminal](https://opencode.ai/docs/web/#attaching-a-terminal)
--------------------------------------------------------------------------

You can attach a terminal TUI to a running web server:

Terminal window

```
# Start the web serveropencode web --port 4096
# In another terminal, attach the TUIopencode attach http://localhost:4096
```

This allows you to use both the web interface and terminal simultaneously, sharing the same sessions and state.

* * *

[Config File](https://opencode.ai/docs/web/#config-file)
--------------------------------------------------------

You can also configure server settings in your `opencode.json` config file:

`{  "server": {    "port": 4096,    "hostname": "0.0.0.0",    "mdns": true,    "cors": ["https://example.com"]  }}`

Command line flags take precedence over config file settings.

[Edit page](https://github.com/anomalyco/opencode/edit/dev/packages/web/src/content/docs/web.mdx)[Found a bug? Open an issue](https://github.com/anomalyco/opencode/issues/new)[Join our Discord community](https://opencode.ai/discord)Select language 

© [Anomaly](https://anoma.ly/)

Last updated: Feb 13, 2026
