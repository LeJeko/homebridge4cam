#!/bin/bash
## © @LeJeko
##
## 2019.04.10 : v1.0 : First release
##
## Homebridge4cam : ready for IP Camera and Web UI
## 

# Initializing variables
SECONDS=0
LAST_TIME=0
ELAPSED_TIME=0
USERNAME=pi
INSTALL_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
LOG_PATH="$INSTALL_PATH/homebridge4cam.log"
SOURCES_PATH="https://github.com/LeJeko/homebridge4cam/raw/master/assets"
RANDOMTWODIGITS=""
RANDOMTHREEDIGITS=""

cd $INSTALL_PATH

# Check sudo
if [ "$USER" != "root" ]; then
        echo "Script must be run as root."
        echo "`date`  ==  Script must be run as root." >> $LOG_PATH
        echo "Use: $ sudo ./homebridge4cam.sh"
        echo "`date`  ==  Use: $ sudo ./homebridge4cam.sh" >> $LOG_PATH
        exit -1
fi

# Set function
show_time () {
    num=$1
    min=0
    hour=0
    day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    # formatting 00
    if [ ${#day} = 1 ];then day="0$day";fi
    if [ ${#hour} = 1 ];then hour="0$hour";fi
    if [ ${#min} = 1 ];then min="0$min";fi
    if [ ${#sec} = 1 ];then sec="0$sec";fi
#    echo "$day"d "$hour"h "$min"m "$sec"s
    echo "$hour"h "$min"m "$sec"s
}

print_time () {
	TIMESTAMP=$SECONDS
	ELAPSED_TIME=$(($TIMESTAMP - $LAST_TIME))
	echo -e "`date`  ==  Duration: `show_time $ELAPSED_TIME` | Total: `show_time $SECONDS`\n"
	echo -e "`date`      `show_time $ELAPSED_TIME` | Total: `show_time $SECONDS`\n" >> $LOG_PATH
	LAST_TIME=$((TIMESTAMP))
}

# Starting install
echo "***************************************************"
echo "Homebridge4cam => INSTALLATION STARTING"
echo "`date`"
echo "***************************************************"
echo "=================================" >> $LOG_PATH
echo "==       homebridge4cam        ==" >> $LOG_PATH
echo "=================================" >> $LOG_PATH
echo "`date`  ==  ** Starting install**" >> $LOG_PATH

# Ensure silent install
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# Check user rights
SUDOERS="/etc/sudoers"
if grep -q "$USERNAME ALL=(ALL) NOPASSWD: ALL" "$SUDOERS"; then
	echo "Sudoers entry exist"
else
	echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" >> $SUDOERS
fi
# Install gpio if none
if [ "`which gpio`" = "" ]; then
	echo "***************************************************"
	echo "INSTALLING GPIO"
	echo "***************************************************"
	echo ""
	echo "`date`  ==  Start installing gpio" >> $LOG_PATH
	wget https://lion.drogon.net/wiringpi-2.50-1.deb
	sudo dpkg -i wiringpi-2.50-1.deb
	rm -f wiringpi-2.50-1.deb
fi

# Preparation in case of reinstallation (otherwhise cp node js will crash)
killall homebridge

echo "***************************************************"
echo "PI INFORMATION"
echo "***************************************************"
echo "`date`  ==  `gpio -v | grep "*-->"`" >> $LOG_PATH
gpio -v | grep "*-->"
uname -a

print_time
# Pi Camera - Loading driver before upgrading system to avoid module installation error
get_camera=`vcgencmd get_camera`
camera_states=($get_camera)
echo "`date`  ==  Pi cam $get_camera"
echo "`date`  ==  Pi cam $get_camera" >> $LOG_PATH

if [ "${camera_states[@]:0:1}" = "supported=1" ]; then
	echo "***************************************************"
	echo "INSTALLING PI CAMERA DRIVER"
	echo "***************************************************"
	echo -e "`date`  ==  Installing PiCam driver\n" >> $LOG_PATH
	modprobe bcm2835-v4l2
	if ! grep -Fxq "bcm2835-v4l2" /etc/modules; then
		echo "bcm2835-v4l2" >> /etc/modules
	fi
fi

echo -e "\n***************************************************"
echo "UPDATING & UPGRADING"
echo "***************************************************"
echo "`date`  ==  Start updating & upgrading" >> $LOG_PATH
apt-get -yq update
apt-get -yq upgrade --show-progress

# Remove lock file to make sure installations succeed
rm /var/cache/apt/archives/lock
rm /var/lib/dpkg/lock
dpkg --configure -a

# Prevent Unable to locate package Errors --> homebridge: command not found
apt-get -yq update

print_time
# Important installations
echo "***************************************************"
echo "INSTALLING OTHER SOFTWARE PACKAGES AND COMPILER"
echo "***************************************************"
echo "`date`  ==  Start installing other software packages and compiler" >> $LOG_PATH
apt-get -yq install git make --show-progress
apt-get -yq install sysstat --show-progress

# Install Compiler
apt-get -yq install gcc-4.9 g++-4.9 --show-progress
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 60 --slave /usr/bin/g++ g++ /usr/bin/g++-4.9
update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.6 40 --slave /usr/bin/g++ g++ /usr/bin/g++-4.7

print_time
# Install FFmpeg

echo "***************************************************"
echo "INSTALLING FFMPEG"
echo "***************************************************"
echo "`date`  ==  Start installing FFMpeg" >> $LOG_PATH

sudo apt-get -yq install ffmpeg --show-progress

# Handle broken installation and try to fix
if [ "`which ffmpeg`" = "" ] || [ -f debug ]; then
	print_time
	if ! [ -f retry ]; then
		touch retry
		rm debug
		echo "`date`  ==  *ERROR* : Installation failed. Trying to fix...." >> $LOG_PATH
		echo -e "\n==> *ERROR* !! : Installation failed. Trying to fix...."
		apt -yq --fix-broken install
		print_time
		echo "`date`  ==  Relaunching script..." >> $LOG_PATH
		echo -e "\n==> Relaunching script..."
		$0
		exit 0
	else
		echo "`date`  ==  *ERROR* : Installation failed. See full log." >> $LOG_PATH
		echo -e "\n==> *ERROR* !! : Installation failed. See full log."
		echo -e "==> or try $ sudo apt --fix-broken install and relaunch script\n"
		rm retry
		print_time
		exit 1
	fi
fi

if [ -f retry ]; then
	rm retry
fi

print_time
# Install NODE JS
echo "***************************************************"
echo "INSTALLING NODE JS"
echo "***************************************************"
echo "`date`  ==  Start installing node js" >> $LOG_PATH
arch=`uname -m`
node_version=`node --version`
if ! [ "$node_version" = "v9.9.0" ]; then
	if [ "$arch" = "armv6l" ]; then
    	echo "Hardware: RaspberryPi Zero or 1"
    	wget https://nodejs.org/dist/v9.9.0/node-v9.9.0-linux-armv6l.tar.gz
		tar -xf node-v9.9.0-linux-armv6l.tar.gz
		rm node-v9.9.0-linux-armv6l.tar.gz
		cd node-v9.9.0-linux-armv6l
	else
    	echo "Hardware: RaspberryPi 2 or higher"
    	wget https://nodejs.org/dist/v9.9.0/node-v9.9.0-linux-armv7l.tar.gz
		tar -xf node-v9.9.0-linux-armv7l.tar.gz
		rm node-v9.9.0-linux-armv7l.tar.gz
		cd node-v9.9.0-linux-armv7l
	fi

	echo "***************************************************"
	echo "COPYING NODE FILES"
	echo "***************************************************"
	killall homebridge
	cp -R * /usr/local/
	cd ..
	rm -rf node-v9.9.0-linux-armv*
fi

echo " INSTALLED NODE WITH NPM VERSION: "
npm -v
echo ""

print_time
# Install Libs
echo "***************************************************"
echo "INSTALLING LIBS"
echo "***************************************************"
echo "`date`  ==  Start installing libs" >> $LOG_PATH
apt-get -yq install avahi-daemon --show-progress
apt-get -yq install avahi-discover --show-progress
apt-get -yq install libnss-mdns --show-progress
apt-get -yq install libavahi-compat-libdnssd-dev --show-progress
apt-get -yq install build-essential --show-progress
apt-get -yq install git --show-progress

print_time
# Install Homebridge
echo "***************************************************"
echo "INSTALLING HOMEBRIDGE "
echo "***************************************************"
echo "`date`  ==  Start installing homebridge" >> $LOG_PATH
npm install -g --unsafe-perm homebridge

print_time
# Install Homebridge plugins
echo "***************************************************"
echo "INSTALLING HOMEBRIDGE PLUGINS"
echo "***************************************************"
echo "`date`  ==  Start installing homebridge plugins" >> $LOG_PATH
npm install --unsafe-perm -g homebridge-config-ui-x
npm install --unsafe-perm -g homebridge-raspberrypi-temperature
npm install --unsafe-perm -g homebridge-camera-ffmpeg
npm install --unsafe-perm -g homebridge-people

# back to user home
cd /home/$USERNAME

print_time
# homebridge config json
if ! [ -f .homebridge/config.json ]
then
	echo "`date`  ==  Start configuring config.json" >> $LOG_PATH
	echo "***************************************************"
	echo "CREATING CONFIG.JSON"
	echo "***************************************************"
	
	mkdir .homebridge
	
	if [ "${camera_states[@]:1:1}" = "detected=1" ]; then
		wget $SOURCES_PATH/config_picam.json -O .homebridge/config.json
	else
		wget $SOURCES_PATH/config.json -O .homebridge/config.json
		wget $SOURCES_PATH/FakeCamera.png -O .homebridge/FakeCamera.png
		wget $SOURCES_PATH/FakeCamera.gif -O .homebridge/FakeCamera.gif
	fi
	
	RANDOMTWODIGITS=$(shuf -i 10-99 -n 1)
	RANDOMTHREEDIGITS=$(shuf -i 100-999 -n 1)
	
	sed -i "s#!RANDOMTWODIGITS!#$RANDOMTWODIGITS#g" .homebridge/config.json
	sed -i "s#!RANDOMTHREEDIGITS!#$RANDOMTHREEDIGITS#g" .homebridge/config.json
else
	echo "`date`  ==  ** config.json exist, no modifications done!"
	echo "`date`  ==  ** config.json exist, no modifications done!" >> $LOG_PATH
fi

# homebridge service
echo "`date`  ==  Start configuring homebridge service" >> $LOG_PATH
echo "***************************************************"
echo "CREATING HOMEBRIDGE SERVICE (SYSTEMD)"
echo "***************************************************"

wget $SOURCES_PATH/homebridge -O /etc/default/homebridge
wget $SOURCES_PATH/homebridge.service -O /etc/systemd/system/homebridge.service
chmod 755 /etc/default/homebridge
chmod 755 /etc/systemd/system/homebridge.service
systemctl daemon-reload
systemctl enable homebridge

# owning some paths to ensure can be managed by other tools
echo -e "\n`date`  ==  Owning paths\n" >> $LOG_PATH
chown -R $USERNAME:$USERNAME /home/$USERNAME
chown -R $USERNAME:$USERNAME /etc/wpa_supplicant/wpa_supplicant.conf

echo "***************************************************"
echo "STARTING HOMEBRIDGE"
echo "***************************************************"
echo "`date`  ==  Starting homebridge" >> $LOG_PATH
systemctl start homebridge

wait_time=5 # seconds
temp_cnt=${wait_time}
while [[ ${temp_cnt} -gt 0 ]];
do
	printf "\r==>> waiting homebridge to start (%2d sec)" ${temp_cnt}
	sleep 1
	((temp_cnt--))
done; echo ""

running=`systemctl status homebridge |grep -e "active (running)"`

if [ "$running" = "" ]
	then
		echo -e "`date`  ==  *ERROR* : Homebridge can't start\n" >> $LOG_PATH
		echo -e "\n==================================================="
		echo -e "==> *ERROR* !! : Homebridge can't start"
		echo -e "==> See log below or $ journalctl -u homebridge\n"
		echo -e "===================================================\n"
	else
		raspi_ip=`hostname -I | sed 's/ //g'`
		echo -e "\n`date`  ==  *SUCCESS* : Homebridge is up and running" >> $LOG_PATH
		echo -e "\n==================================================="
		echo -e "\n==>   *SUCCESS* !! : Homebridge is up and running"
		
		if ! [ $RANDOMTHREEDIGITS = "" ]; then
			echo -e "`date`  ==  PIN : 031-45-$RANDOMTHREEDIGITS" >> $LOG_PATH
			echo -e "==>   PIN : 031-45-$RANDOMTHREEDIGITS"
		fi

		echo -e "`date`  ==  Web UI: http://$raspi_ip:8080 (admin/admin)\n" >> $LOG_PATH
		echo -e "==>   Web UI: http://$raspi_ip:8080 (admin/admin)\n"
		echo "==================================================="
fi

# Finish
echo "`date`  ==  Cleaning logs..." >> $LOG_PATH
cat /dev/null > ~/.bash_history
echo "FINISH!"
echo "`date`  ==  ** Script finished!**" >> $LOG_PATH
print_time
