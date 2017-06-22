# docker-tribler-vnc

## How to build docker image
```
git clone --recursive https://github.com/pimlie/docker-tribler-vnc
docker build -t pimlie/docker-tribler-vnc docker-tribler-vnc
```

## How to run
```
sudo docker run -d \
	--network=host
	-v /home/tribler/.Tribler:/home/tribler/.Tribler \
	-v /my/download/folder:/TriblerDownloads \
	--name docker-tribler-vnc \
	pimlie/docker-tribler-vnc
```

Tribler runs as a new user tribler in the docker container, this user will have uid `1000`. When binding folders you need to make sure the user tribler in the docker container has write access to those folders

Then browse to http://<host_ip>:6081 or open a connection to port 5902 with your favorite vnc viewer
