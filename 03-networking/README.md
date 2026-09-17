# Networking Homework Tasks

## Task 1 — Practise the commands and the repo shared in the `devops-heros` GitHub repo

The class repo is **[MineshShaw/devops-heros](https://github.com/MineshShaw/devops-heros)**.
Its networking material is in `session4-networking/` — `ip.md` (IP addressing, address
classes, subnet masks, private ranges, host counts) plus `session2-linux/Linux Networking
Cheat Sheet.pdf` (the `ip` command reference) and a list of networking repos to read.

Both were worked through:

* **The theory** — address classes A–E, subnet masks and CIDR, how to work out the
  network address, broadcast address and usable host count, and the private ranges — is
  written up as **section 1** of [`networking-commands.md`](networking-commands.md),
  applied to this machine's own `192.168.5.15/24`.
* **The `ip` command reference from the cheat sheet** — `ip addr`, `ip link`, `ip route`,
  `ip neigh`, `ip route get` — was executed, along with the rest of the standard
  troubleshooting set.

Commands practised:

`ip addr` · `ip -brief addr` · `ip link` · `ifconfig` · `hostname` · `hostname -I` ·
`ip route` · `route -n` · `ip route get` · `ping` · `traceroute` · `nslookup` · `dig` ·
`dig MX` · `dig NS` · `dig -x` · `host` · `/etc/resolv.conf` · `/etc/hosts` · `ss -tuln` ·
`ss -tulnp` · `ss -s` · `netstat -tuln` · `netstat -tulnp` · `lsof -i` · `ip neigh` ·
`arp -n` · `curl` · `curl -I` · `wget` · `nc -zv` (open **and** closed ports) · `telnet` ·
`nmap -F` · `tcpdump` · `whois`

## Task 2 — Markdown file with the output and an explanation of each command

**→ [`networking-commands.md`](networking-commands.md)**

For each group of commands that file contains:

* the exact command that was run,
* its **real captured output** (Ubuntu 26.04, `console` blocks),
* a **"What I understood"** section explaining what the command is for, how to read its
  output, and when I would reach for it.

It ends with a quick-reference table and the order I would actually work through when
debugging a network problem.

## Screenshot

![networking commands in the terminal](screenshots/09-networking-commands.png)

## Environment

```bash
limactl start --name=devops --cpus 4 --memory 8 template://ubuntu-lts
sudo apt install -y net-tools dnsutils traceroute iputils-ping curl wget \
                    netcat-openbsd telnet whois tcpdump nmap
```

Machine used: user `kunal`, hostname `kunal-devops`, interface `eth0`, IP
`192.168.5.15/24`, gateway `192.168.5.2`.

**Two commands were run on the host machine rather than in the VM: `ping` and
`traceroute`.** The VM sits behind a user-mode network stack that answers ICMP itself
instead of forwarding it, so inside the VM `ping 8.8.8.8` returns an impossible `ttl=64`
at 0.2 ms and `traceroute` returns `* * *` for every hop. Both the real host output and
the misleading VM output are in the file, with an explanation of why they differ — a
successful ping only proves that *something* replied.

The traceroute's first three hops (this connection's own last-mile routers) are redacted
because the repository is public; everything from hop 4 onwards is untouched.
