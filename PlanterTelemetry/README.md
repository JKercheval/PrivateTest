# PlanterTelemetry

## Installation

## Usage
install mosquitto

CHECK BEFORE INSTALLING
you may need to create a directory called /usr/local/sbin

```
sudo mkdir /usr/local/sbin
sudo chown $(whoami) /usr/local/sbin
```
**If you don't do this before installing then you may also need to do the following:**
```
brew link mosquitto
```

```
brew update
brew install mosquitto
```
Have to have a password file
```
sudo mosquitto_passwd -c /usr/local/etc/mosquitto/passwd tester
```

Have to change conf file
'/usr/local/etc/mosquitto/mosquitto.conf'

Shange the following settings
allow_anonymous false
password_file /usr/local/etc/mosquitto/passwd

start mosquitto
```
mosquitto -c /usr/local/etc/mosquitto/mosquitto.conf
```
