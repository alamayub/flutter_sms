# School Local Area Network (LAN) Setup

## Overview

This document guides administrators and school IT coordinators in setting up local Wi-Fi connectivity for the School Management System.

No internet subscription, broadband modem, or WAN connection is required. All that is needed is a standard wireless router or access point powered on in the school premises.

---

## 1. Hardware Requirements

1. **Any Wi-Fi Router or Access Point**:
   - A standard commercial or consumer Wi-Fi router (TP-Link, D-Link, Netgear, Mikrotik, Asus, etc.).
   - An active internet cable into the WAN port is **NOT** required. The router operates purely as a local DHCP server and wireless switch.
2. **Server Computer**:
   - Desktop PC, laptop, or mini-PC running Windows, macOS, or Linux.
   - Recommended: Connected to the router via Ethernet cable for stable latency, although Wi-Fi is also supported.
3. **Client Devices**:
   - Teacher smartphones or tablets running Android 7+ or iOS 13+.
   - Staff laptops or desktops running Windows, macOS, or Linux.

---

## 2. Network Topology & Addressing

```
              ┌─────────────────────────────┐
              │     Local Wi-Fi Router      │
              │  (No Internet Cable Needed) │
              │     DHCP Server Enabled     │
              │    Subnet: 192.168.1.0/24   │
              └──────────────┬──────────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       │ (Ethernet / Wi-Fi)  │ (Wi-Fi)             │ (Wi-Fi)
       ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│School Server │      │Teacher Phone │      │Teacher Phone │
│192.168.1.100 │      │192.168.1.101 │      │192.168.1.102 │
│Port 8080/52400      └──────────────┘      └──────────────┘
└──────────────┘
```

### Static IP Recommendation for Server

For easiest manual connection fallback:

- Assign a static IP or DHCP reservation to the School Server host machine (e.g. `192.168.1.100`).
- Alternatively, note the IP address assigned to the server machine:
  - Windows: `ipconfig` (look for IPv4 Address)
  - macOS/Linux: `ifconfig` or `ip addr` (look for `inet 192.168.x.x`)

---

## 3. Zero-Configuration UDP Auto-Discovery

The School Management System includes built-in auto-discovery so teachers do not need to memorize IP addresses:

1. When the user taps **Scan LAN for School Server** in **LAN Sync Settings**:
   - The app sends a UDP broadcast packet containing `SMS_DISCOVER_SERVER` to `255.255.255.255:52400`.
2. The School Server responds with a JSON packet containing its IP address, HTTP port, and school name.
3. The app populates the server address automatically and initiates the connection handshake.

---

## 4. Manual IP Fallback

If UDP broadcast is blocked by the router's AP isolation or firewall rules:

1. Open the Flutter app on the client device.
2. Navigate to **LAN Sync** in the sidebar.
3. Enter the server's LAN address manually in the **Manual Server Connection** card:
   - Format: `http://192.168.1.100:8080`
4. Tap **Connect**.

---

## 5. Firewall & Port Rules on Server Host

Ensure the server machine allows incoming connections on the following ports:

| Port    | Protocol | Purpose                                    |
| ------- | -------- | ------------------------------------------ |
| `8080`  | TCP      | HTTP REST API & WebSocket Real-Time Sync   |
| `52400` | UDP      | Zero-configuration server discovery beacon |

### Windows Defender Firewall:

```cmd
netsh advfirewall firewall add rule name="School Sync Server TCP" dir=in action=allow protocol=TCP localport=8080
netsh advfirewall firewall add rule name="School Sync Server UDP" dir=in action=allow protocol=UDP localport=52400
```

### Ubuntu / Debian Linux (`ufw`):

```bash
sudo ufw allow 8080/tcp
sudo ufw allow 52400/udp
```

### macOS Firewall:

When prompted, allow incoming network connections for the Dart runtime or School Server binary.

---

## 6. Router Setting: Disable "AP Client Isolation"

Certain enterprise or guest Wi-Fi networks have **"AP Isolation"** or **"Client Isolation"** enabled. This prevents Wi-Fi devices from communicating with one another.

- Ensure **AP Isolation** is **DISABLED** in the router admin panel (`Wireless Settings > Advanced`).
