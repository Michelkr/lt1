#!/bin/bash
####################################
#		
# Install Docker
#
####################################


#packages over https
apt install apt-transport-https ca-certificates curl software-properties-common

#add GPG key for docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

#add repository
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"

#update packages with new repo
apt-get update

#install docker
apt-get install -y docker-ce
