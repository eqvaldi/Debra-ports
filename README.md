# Debra-ports
A tool to compile Source Ports

# Info
* The folder named Deb compile scripts is used to compile .deb.

### Supported Distros

* Debian Trixie (Stable)
* Debian Armbian Trixie (Stable)
* Ubuntu 26.04 (Stable)
* Ubuntu Armbian 26.04 (Stable)

### How to Start compiling on PC/Server/Raspberry PI.
### NOTE: Armbian scripts are for bash only.

### Install dependencies.
```
sudo apt update
sudo apt install dialog build-essential cmake git ninja-build nasm wget unzip xz-utils libsdl2-dev libsdl2-net-dev libsdl2-image-dev libsdl2-mixer-dev libopenal-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libvorbis-dev libmad0-dev libmpg123-dev libbz2-dev libgmp-dev libspatialindex-dev libluajit-5.1-dev libsqlite3-dev libgtk2.0-dev libgtk-3-dev libfluidsynth-dev libportmidi-dev libsndfile1-dev libpcre3-dev libvpx-dev zlib1g-dev libvulkan-dev libvulkan1 flac libflac-dev freepats openssl miniupnpc libao-dev vainfo vdpauinfo libzip-dev zipcmp zipmerge ziptool -y

```


### How to Start compiling binaries on Linux.
```
Debra-Ports.sh
```
### How to Start compiling Windows binaries on Linux.
NOTE: This is not updated.
```
Debra-Ports-Windows.sh
```


