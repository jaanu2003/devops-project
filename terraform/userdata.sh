#!/bin/bash

apt update -y

apt install docker.io -y
apt install git -y

systemctl start docker
systemctl enable docker

usermod -aG docker ubuntu