# Homebridge4Cam

### Easy install of homebridge on a headless* Raspberry Pi to bring IP Camera stream in HomeKit

**\* Headless mean that you don't need to connect the raspi to a screen and a keyboard (nor an Ethernet cable) to configure it after restoring.**   
Following steps explain how to activate SSH and configure Wi-Fi to manage it remotely.

## Why homebridge4cam ?
There isn't a lot of HomeKit compatible IP Camera. But there are a lot of cheaper ones, even in China ;)  
Homebridge4cam will install all needed dependencies, automatically set up the homebridge server and expose it in a Web UI on port 8080.  
All you need to do before is to edit *config.json* with the Web UI and add your [specific camera configuration](https://github.com/KhaosT/homebridge-camera-ffmpeg/wiki/Tested-Configurations) in the "camera-ffmpeg" platform section.  

If you have a Pi camera connected (and activated, see below), it will be automatically added to homebridge and accessible in Home App.  
Otherwise, a *"Fake Camera"* is created so that you can check if it is visible in the Home App.

## Can I install homebridge4cam on an already setup Raspi ? 

Yes

* If you've never set up homebridge, you can jump to step 8.
* If you have already a homebridge installation, it will update it but
 leave config.json untouched.

## What will be installed ? 

* ffmpeg
* node.js
* homebridge
* homebridge-camera-ffmpeg
* homebridge-config-ui-x
* homebridge-raspberrypi-temperature
* homebridge-people

## Manage homebridge

Web UI: [http://raspberrypi.local:8080](http://raspberrypi.local:8080)

iOS App: [Homebridge for RaspberryPi](https://itunes.apple.com/us/app/homebridge-for-raspberrypi/id1123183713?mt=8).

* Crete a new connection and connect with user *pi*
* Choose ***Existing installation***
* Set config.json path ```/home/pi/.homebridge/config.json``` 
* Use systemd
* Use journalctl

#=============================
## Start install Raspi headless from scratch

You need:

* Raspi (tested with Raspberry Pi 3 Model B Plus Rev 1.3)
* WiFi or Ethernet cable with Internet connection
* Micro SD Card
* Terminal (or [PuTTY](https://www.putty.org))

[Source](https://hackernoon.com/raspberry-pi-headless-install-462ccabd75d0)

### 1. Download Raspbian Image
Head on over [here](https://www.raspberrypi.org/downloads/raspbian/) to grab a copy of the Raspbian image.

The “Lite” version will do: [https://downloads.raspberrypi.org/raspbian_lite_latest](https://downloads.raspberrypi.org/raspbian_lite_latest)

### 2. Write Image to SD Card
Write the image to SD card. You can find detailed instructions [here](https://www.raspberrypi.org/documentation/installation/installing-images/README.md).

Etcher is a graphical SD card writing tool that works on Mac OS, Linux and Windows, and is the easiest option for most users. Etcher also supports writing images directly from the zip file, without any unzipping required. To write your image with Etcher:

* Download [Etcher](https://etcher.io/) and install it.
* Connect an SD card reader with the SD card inside.
* Open Etcher and select from your hard drive the Raspberry Pi .img or .zip file you wish to write to the SD card.
* Select the SD card you wish to write your image to.
* Review your selections and click 'Flash!' to begin writing data to the SD card.

### 3. Enable SSH after install
Enable SSH by placing a file named “ssh” (without any extension) in the boot partition of the SD card.
On macOS terminal:

```
$ touch /Volumes/boot/ssh
```

### 4. Preconfiguring a WiFi network (else connect Ethernet cable)
If you already know your WiFi details, add a file named wpa_supplicant.conf in the boot partition of the SD card. It look like this:

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=CH

network={ 
    ssid="mySSID1" 
    psk="myPwd2" 
}
network={ 
    ssid="mySSID2" 
    psk="myPwd2" 
}
```

On macOS terminal:

```
$ nano /Volumes/boot/wpa_supplicant.conf
```

then adapt the code above and copy-paste.

### 5. Enabling Pi camera

To avoid one more reboot later, add *"start_x=1"* and *"gpu_mem=128"* to /boot/config.txt

On macOS terminal:


```
$ echo -e "start_x=1\ngpu_mem=128" >> /Volumes/boot/config.txt
```


## **Insert SD Card to your Pi and restore it**

*Install will take les than 1 min (Raspbian Stretch Lite on Raspberry Pi 3 Model B Plus Rev 1.3)*

## Prepare you Raspi
Open a Terminal on your computer.

### 6. Find your Pi on the network

Try to access it with its Bonjour name:

```
$ ping raspberrypi.local
```

* if your have more than one, the name ident like this:

```
$ ping raspberrypi-2.local
```

else, if host is in your ARP table, you can try find its IP with this command:

```
$ arp -an | grep -i b8:27:eb
```

### 7. Connect with SSH and configure


```
$ ssh pi@raspberrypi.local
```

(default password is *raspberry* )

For security you should change the password::

```
$ passwd
```

### 8. Configure

```
$ sudo raspi-config
```

* go to **Localisation options**
	* **Change Timezone** according to yours
	* *[optional]* **Change Locale** (default is en_GB.UTF-8).  
		
### 9. Pi Camera (if not done in step 5)

```
$ sudo raspi-config
```

* If you haven't done in step 5, ensure the Camera interface is enabled in **Interfacing options -> Camera**

	* **Activating Camera interface will require restarting. before continue**  
	The script is only able to install the driver if the camera interface is enabled.

If a Pi camera is connected, it will automatically be configured in homebridge.

[Pi camera useful link](https://github.com/KhaosT/homebridge-camera-ffmpeg/issues/93#issuecomment-314479017)

### 10. Download homebridge4cam script 

```
$ wget https://github.com/LeJeko/homebridge4cam/raw/master/homegridge4cam.sh
```

and set it executable.

```
$ chmod +x homebridge4cam.sh
```

**Do not force execution** with ```sudo sh script.sh``` because this will use *sh* shell instead of *bash* which is necessary for some features.

### 11. Launch installation

```
$ sudo ./homebridge4cam.sh
```

You can follow the full scrolling log or a light version from another session with this command:

```
ssh -t pi@raspberrypi.local 'tail -f homebridge4cam.log'
```

### 12. Wait...

Full script execution takes about 10 min with Ethernet cable (and about 30 min through Wi-Fi !?!).

Script terminates with a *SUCCESS* 

```
==>   *SUCCESS* !! : Homebridge is up and running
==>   Web UI: http://10.0.1.14:8080 (admin/admin)
```

or *ERROR* message.

```
==> *ERROR* !! : Homebridge can't start
==> See log below or $ journalctl -u homebridge
```

### 13. Add automatically created accessories to Home App

* Go to the web UI and login (admin/admin): [http://raspberry.local:8080](http://raspberry.local:8080) 
* You can now see the PIN code
* Launch Home App in your iOS Device and add an accessory
* Do not scan the QR code, choose **No code or can't scan code** option instead
* You can see a bridge named **homebridge** and a camera named **Fake Camera** or **Pi Cam**
* Add each and give PIN when asked
* The bridge includes an accessory that gives the temperature of the Raspi.

### 14. Add your own IP camera stream

Edit config.json: [http://raspberry.local:8080/config](http://raspberry.local:8080/config)

Tested IP Camera configurations:  
[https://github.com/KhaosT/homebridge-camera-ffmpeg/wiki/Tested-Configurations](https://github.com/KhaosT/homebridge-camera-ffmpeg/wiki/Tested-Configurations).
