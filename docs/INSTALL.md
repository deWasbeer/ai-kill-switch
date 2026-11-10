# Install

Reference setup: an OpenWrt router running AdGuard Home, and a Raspberry Pi (Raspberry Pi OS /
Debian, Python 3.9+) as the switch host. Everything runs as the normal user (`pi` below), not as root.
Using Pi-hole instead of AdGuard? Read the Pi-hole section of [ARCHITECTURE.md](ARCHITECTURE.md) first.

Replace `192.168.1.1` (router) with your own address everywhere below.

**Do every step on the switch host itself.** Don't run them from a machine where AI agents run,
and don't give such a machine SSH access to the switch host or the router.

## 1. Router: force DNS through AdGuard

The Pi needs root SSH access to the router to manage the firewall table:

```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519
ssh root@192.168.1.1 "cat >> /etc/dropbear/authorized_keys" < ~/.ssh/id_ed25519.pub
ssh root@192.168.1.1 true && echo ok      # must print ok without asking for a password
```

Force every DNS lookup through AdGuard and reject DNS-over-TLS (skip the redirect if your router
already has one, for example an `Intercept-DNS` rule):

```bash
ssh root@192.168.1.1 '
uci add firewall redirect
uci set firewall.@redirect[-1].name="Force DNS to AdGuard"
uci set firewall.@redirect[-1].src="lan"
uci set firewall.@redirect[-1].src_dport="53"
uci set firewall.@redirect[-1].dest_port="53"
uci set firewall.@redirect[-1].proto="tcp udp"
uci set firewall.@redirect[-1].target="DNAT"
uci add firewall rule
uci set firewall.@rule[-1].name="Block DNS-over-TLS"
uci set firewall.@rule[-1].src="lan"
uci set firewall.@rule[-1].dest="wan"
uci set firewall.@rule[-1].dest_port="853"
uci set firewall.@rule[-1].proto="tcp udp"
uci set firewall.@rule[-1].target="REJECT"
uci commit firewall
service firewall restart'
```

In AdGuard (**Filters → Custom filtering rules**), turn off the browsers' own encrypted DNS and Apple's relay:

```
||use-application-dns.net^
||mask.icloud.com^
||mask-h2.icloud.com^
```

Android phones with **Private DNS** set to a hostname lose DNS on this network after this
step. Set it to *Automatic*.

## 2. The switch

```bash
sudo install -m 755 bin/ai-switch bin/ai-news-watch bin/ai-status-http /usr/local/bin/
cd /usr/local/bin
for c in ai-on ai-off ai-status ai-update ai-idle ai-whitelist ai-unwhitelist; do sudo ln -sf ai-switch $c; done
cd -

mkdir -p ~/.config/ai-switch
printf '%s' 'adguard-user:adguard-password' > ~/.config/ai-switch/agh-auth
chmod 600 ~/.config/ai-switch/agh-auth
cp examples/ai-switch.config ~/.config/ai-switch/config     # then edit it

ai-status          # first run creates ~/.config/ai-switch/providers/
ai-off             # test: everything blocked
ai-on              # and back
```

Optional:
- `ai-whitelist mistral`: never block this provider.
- A free [Cert Spotter](https://sslmate.com/certspotter/) API key in
  `~/.config/ai-switch/certspotter-key` lets `ai-update` check every domain in the certificate logs on each run.

## 3. News watch (optional)

```bash
mkdir -p ~/.config/ai-news-watch
cp examples/ai-news-watch.config ~/.config/ai-news-watch/config   # set the Gotify URL and token, or remove them
ai-news-watch --dry-run       # shows matching headlines, changes nothing
ai-news-watch --test-alert    # sends a test notification
```

## 4. Status page, cron, logs

```bash
sudo mkdir -p /var/lib/ai-switch-status
sudo chown pi:pi /var/lib/ai-switch-status && sudo chmod 755 /var/lib/ai-switch-status

sudo install -m 644 etc/ai-switch.cron /etc/cron.d/ai-switch           # edit the user name/paths first if not "pi"
sudo install -m 644 etc/ai-switch.logrotate /etc/logrotate.d/ai-switch
sudo install -m 644 etc/ai-switch-help.sh /etc/profile.d/ai-switch-help.sh
sudo install -m 644 etc/ai-status-http.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now ai-status-http

# after a minute:
curl -i http://localhost:8099/status     # 200 allowed / 503 blocked
```

Dashboard: add an app tile with URL `http://<switch-host>:8099/` and turn on its status check.
Green means AI is allowed, red means it's blocked.

## Updating and undoing

- Back up `/usr/local/bin/ai-switch` before replacing it.
- `ai-on` lifts every block. To remove the switch completely, also delete the cron file and
  disable the service. AdGuard rules are only added while a provider is off, and the router
  firewall table only exists then too.
