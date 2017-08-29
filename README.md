# docker-tribler-vnc

## How to build docker image
use -f to specify either the ubuntu or alpine docker file
```
git clone --recursive https://github.com/pimlie/docker-tribler-vnc
docker build -f Dockerfile.alpine -t pimlie/docker-tribler-vnc --build-arg vnc=yes docker-tribler-vnc
```

### docker build args
Use by adding `--build-arg VAR=VALUE` to your docker build command
#### vnc
- Default: `no`
Specify with `yes` to build your image with vnc support

#### novnc
- Default: `no`
Specify with `yes` to build your image with novnc support (vnc though the browser)

#### dev
- Default `no`
If specified with `yes`, adds git and doesnt install a tribler release. You will need to clone the repository and checkout a branch yourself

#### UID
- Default `1000`
The uid for the tribler user in the container

#### GID
- Default `1000`
The gid for the tribler group in the container

#### tag
- Default ``
If you want to install a specific release, define the tag (see the Tribler github repository for a list of available tags). E.g. `v7.0.0`

#### prerelease
- Default `false
Specify with `true` to install the latest pre-release

#### VNC_PORT
- Default `5900`
Specify which port vnc should run on, can also be set with an environment variable

#### NOVNC_PORT
- Default `6080`
Specify which port novnc should run on, can also be set with an environment variable

#### NOVNC_PORT_INT
- Default `6081`
Specify which port novnc should use internally for websockify, you should probably not have to change this unless you run the container with `--network=host`

## How to run
### environment variables
Use by adding `-e VAR=VALUE` to your docker run command
#### VNC_PORT
- Default `5900`
Specify which port vnc should run on, can also be set with an environment variable

#### NOVNC_PORT
- Default `6080`
Specify which port novnc should run on, can also be set with an environment variable

#### SCREEN_RESOLUTION
- Default `1024x768x16`
This value is passed to Xvfb for vnc and novnc builds and specifies the resolution of the virtual window

```
sudo docker run -d --init \
	-v /home/tribler/.Tribler:/home/tribler/.Tribler \
	-v /my/download/folder:/TriblerDownloads \
        -e SCREEN_RESOLUTION="1280x1024x16" \
	--name docker-tribler-vnc \
	pimlie/docker-tribler-vnc
```

Tribler runs as a new user tribler in the docker container, this user has by default uid `1000`. When binding folders you need to make sure the local user with the same uid has write access to those folders

Then browse to http://<host_ip>:6080 or open a connection to port 5900 with your favorite vnc viewer

### To do
- add possibility to use a password for vnc
