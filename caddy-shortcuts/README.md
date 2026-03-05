# Caddy Local Shortcuts

Use Caddy to create local shortcut domains.

## Design

- `/etc/caddy/Caddyfile`: keep minimal, only `import /etc/caddy/shortcuts.caddy`
- `/etc/caddy/shortcuts.caddy`: all shortcut domains in one file

## Included examples

- `http://clouddrive.lan` -> `reverse_proxy 192.168.100.1:19798`
- `http://news.economist` -> `redir https://www.economist.com 302`

## Install

```bash
cd /home/aerith/archlinux/workshop/github/archlinux/caddy-shortcuts
./install.sh
```

By default, `install.sh` keeps existing `/etc/caddy/shortcuts.caddy`.
Use `./install.sh --reset-routes` only if you want to overwrite routes with template defaults.

The script will:

1. ensure `/etc/caddy/Caddyfile` imports `/etc/caddy/shortcuts.caddy` (append if missing)
2. backup existing files before replacing `shortcuts.caddy`
3. copy templates to `/etc/caddy/`
4. add required host entries into `/etc/hosts`
5. validate config
6. enable/reload Caddy service

## Interactive panel (recommended)

```bash
cd /home/aerith/archlinux/workshop/github/archlinux/caddy-shortcuts
./shortcut-manager.sh
```

The panel uses clear-screen + colored banner on each loop.
`list/modify/delete` now display a wide table with index numbers for selection.

Menu option `1` asks:

1. target URL (`http://...` or `https://...`)
2. new local domain (`nas.lan`, `news.wsj`, ...)

Menu option `2`: modify existing entry (choose by index, then you can change domain and/or target).

Menu option `3`: delete domain (choose by index, then confirm).

Then it will:

- update `/etc/caddy/shortcuts.caddy`
- ensure host entry in `/etc/hosts`
- validate and reload Caddy

Route mode selection is automatic:

- private/local target (for example `http://192.168.x.x:port`) -> `reverse_proxy`
- public website target (for example `https://www.economist.com`) -> `redir 302`

## Add a new shortcut manually

Edit `/etc/caddy/shortcuts.caddy`, for example:

```caddyfile
http://news.bbc {
	redir https://www.bbc.com/news 302
}
```

Reload:

```bash
sudo systemctl reload caddy
```
