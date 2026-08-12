Title: Web

URL Source: https://opencode.ai/docs/web/

Markdown Content:
Using OpenCode in your browser.

OpenCode can run as a web application in your browser, providing the same powerful AI coding experience without needing a terminal.

![Image 1: OpenCode Web - New Session](https://opencode.ai/docs/_astro/web-homepage-new-session.BB1mEdgo_Z1AT1v3.webp)

## [Getting Started](https://opencode.ai/docs/web/#getting-started)

Start the web interface by running:

`opencode web`

This starts a local server on `127.0.0.1` with a random available port and automatically opens OpenCode in your default browser.

* * *

## [Configuration](https://opencode.ai/docs/web/#configuration)

You can configure the web server using command line flags or in your [config file](https://opencode.ai/docs/config).

### [Port](https://opencode.ai/docs/web/#port)

By default, OpenCode picks an available port. You can specify a port:

`opencode web --port 4096`

### [Hostname](https://opencode.ai/docs/web/#hostname)

By default, the server binds to `127.0.0.1` (localhost only). To make OpenCode accessible on your network:

`opencode web --hostname 0.0.0.0`

When using `0.0.0.0`, OpenCode will display both local and network addresses:

`Local access:       http://localhost:4096  Network access:     http://192.168.1.100:4096`

### [mDNS Discovery](https://opencode.ai/docs/web/#mdns-discovery)

Enable mDNS to make your server discoverable on the local network:

`opencode web --mdns`

This automatically sets the hostname to `0.0.0.0` and advertises the server as `opencode.local`.

You can customize the mDNS domain name to run multiple instances on the same network:

`opencode web --mdns --mdns-domain myproject.local`

### [CORS](https://opencode.ai/docs/web/#cors)

To allow additional domains for CORS (useful for custom frontends):

`opencode web --cors https://example.com`

### [Authentication](https://opencode.ai/docs/web/#authentication)

To protect access, set a password using the `OPENCODE_SERVER_PASSWORD` environment variable:

`OPENCODE_SERVER_PASSWORD=secret opencode web`

The username defaults to `opencode` but can be changed with `OPENCODE_SERVER_USERNAME`.

* * *

## [Using the Web Interface](https://opencode.ai/docs/web/#using-the-web-interface)

Once started, the web interface provides access to your OpenCode sessions.

### [Sessions](https://opencode.ai/docs/web/#sessions)

View and manage your sessions from the homepage. You can see active sessions and start new ones.

![Image 2: OpenCode Web - Active Session](https://opencode.ai/docs/_astro/web-homepage-active-session.BbK4Ph6e_Z1O7nO1.webp)

### [Server Status](https://opencode.ai/docs/web/#server-status)

Click “See Servers” to view connected servers and their status.

![Image 3: OpenCode Web - See Servers](https://opencode.ai/docs/_astro/web-homepage-see-servers.BpCOef2l_ZB0rJd.webp)

* * *

## [Attaching a Terminal](https://opencode.ai/docs/web/#attaching-a-terminal)

You can attach a terminal TUI to a running web server:

`# Start the web serveropencode web --port 4096# In another terminal, attach the TUIopencode attach http://localhost:4096`

This allows you to use both the web interface and terminal simultaneously, sharing the same sessions and state.

* * *

## [Config File](https://opencode.ai/docs/web/#config-file)

You can also configure server settings in your `opencode.json` config file:

`{  "server": {    "port": 4096,    "hostname": "0.0.0.0",    "mdns": true,    "cors": ["https://example.com"]  }}`

Command line flags take precedence over config file settings.
