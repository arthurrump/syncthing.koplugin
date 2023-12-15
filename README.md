# Syncthing KOReader Plugin

Run Syncthing from within KOReader. This plugin adds a menu item to start and stop the Syncthing service in the *Network* section of the KOReader menu.

Tested on Kobo Sage. It probably works on other devices if the dependencies (mainly [start-stop-daemon](https://busybox.net/downloads/BusyBox.html#start_stop_daemon), [ifconfig](https://busybox.net/downloads/BusyBox.html#ifconfig)) are available, but Kindle likely needs some firewall rules.

## Installation

1. Copy this repository (at least *_meta.lua* and *main.lua*) into the *plugins/syncthing.koplugin* directory of your KOReader installation. 
2. Download a Syncthing binary appropriate for your device from [the Syncthing website](https://syncthing.net/downloads/#base-syncthing) (most likely ARM (32-bit) for many e-readers). Extract the archive and copy the *syncthing* binary to the *plugins/syncthing.koplugin* directory.

Done! Restart KOReader and you should find the Syncthing option in the *Network* section under the gear icon in the top menu. After starting Syncthing, you can use the web GUI to configure it (see the [next section](#configuration)).

## Configuration

By default, the Syncthing GUI is only available on the localhost through <https://localhost:8384>. To access the GUI from a different device, there are two options.

1. (Preferred) Use SSH port forwarding to connect through SSH. Start the SSH Server in KOReader and connect using this command:

   ```sh
   ssh -L18384:127.0.0.1:8384 root@<your device ip>
   ```

   This forwards your local port 18384 to the e-readers port 8384 on localhost where Syncthing is listening. As long as the SSH session is open, you can access the GUI through <https://localhost:18384>.

2. Update the *gui* > *address* element in *settings/syncthing/config.xml* to have Syncthing listen on 0.0.0.0:8384:
   
   ```xml
       <gui enabled="true">
           <address>0.0.0.0:8384</address>
       </gui>
   ```

   This will make the Syncthing GUI available to all devices on the network, so make sure you set a username and strong password in the GUI!

The Syncthing configuration files, log files and other data are all stored in *settings/syncthing* in the KOReader directory.

## Troubleshooting

- The Syncthing menu item does not appear after installation.

  First, restart KOReader. If that doesn't help, check if you correctly installed the Syncthing binary. The *syncthing.koplugin* directory should contain (at least) three files: *_meta.lua*, *main.lua* and *syncthing*. Finally, it may be the case that your device does not have the *start-stop-daemon* command available, which we use to run Syncthing as a background process.

- Syncthing stops after a moment: the checkbox uncheks itself after reopening the menu.
  
  This means that Syncthing is unable to start up. Have a look at the Syncthing log files at *settings/syncthing/syncthing.log* to find out why Syncthing is unable to start.

- Syncthing is unable to connect to discovery servers.

  Your device may be missing the appropriate CA certificates. Copy the `/etc/ssl/certs/ca-certificates.crt` from any recent Linux installation to the same location on your device. ([Source](https://anarc.at/hardware/tablet/kobo-clara-hd/#install-syncthing), works on Kobo.)

---

This code is primarily based on [SSH.koplugin](https://github.com/koreader/koreader/tree/master/plugins/SSH.koplugin), available under the [AGPL-3.0 license](https://github.com/koreader/koreader/blob/master/COPYING).