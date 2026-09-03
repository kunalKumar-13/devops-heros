# Linux Homework Tasks

All four tasks were carried out on a real **Ubuntu 26.04 LTS** machine (systemd 259,
aarch64) as user **`kunal`** on host **`kunal-devops`**. Every `console` block is copied
verbatim from that terminal, and every screenshot is of the same live session.

| Task | Folder | What it covers |
|---|---|---|
| 1 | [`task1-soft-hard-links/`](task1-soft-hard-links/) | soft links vs hard links, inodes, creating and deleting both, interview answers |
| 2 | [`task2-adduser-vs-useradd/`](task2-adduser-vs-useradd/) | the difference, which Ubuntu prefers and why, a test user created with the recommended command |
| 3 | [`task3-journalctl/`](task3-journalctl/) | what journalctl is for, reading system and per-service logs |
| 4 | [`task4-command-cheatsheet/`](task4-command-cheatsheet/) | the class cheat sheets (basic + advanced) with every command run |

## Quick summary

**Task 1** — a hard link is a second *name* for the same inode; a soft link is a small
file containing a *path*. Delete the original and the hard link keeps working while the
soft link dangles. Hard links cannot cross filesystems or point at directories.
Proven with inode `525715` shared by both names and a link count of 2.

**Task 2** — `useradd` is the low-level binary, `adduser` is the Debian/Ubuntu Perl
wrapper around it. **Ubuntu prefers `adduser`** for interactive use because it creates
the home directory, sets `/bin/bash`, prompts for a password and creates the user's
group. `useradd` is the right choice in scripts and Dockerfiles. Test user `testuser`
was created with `adduser` and verified with `id`, `passwd -S` and a real login.

**Task 3** — `journalctl` reads the systemd journal: one indexed, structured log for the
kernel, boot and every service. `journalctl -u <service>` is the command used daily;
a live `systemctl restart cron` was captured appearing in the journal.

**Task 4** — the class cheat sheets, restated as tables and then executed end to end.

## Environment

Docker and systemd need Linux, so the work was done in a real Ubuntu VM on a Mac:

```bash
brew install lima
limactl start --name=linuxlab --cpus 4 --memory 8 template://ubuntu-lts
limactl shell linuxlab

# a normal user account for the coursework
sudo hostnamectl set-hostname kunal-devops
sudo adduser kunal && sudo usermod -aG sudo,docker kunal
```
