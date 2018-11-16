#!/bin/bash
####################################
#		
# Install Kubernetes minion
#
####################################

#turn swap off
swapoff -a

#get and add required libraries
apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - 
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
apt update

#install docker and Kubernetes
apt-get install -y docker-ce=18.06.0~ce~3-0~ubuntu
apt-get install -y kubelet kubeadm kubectl


#set docket to start at startup
systemctl enable docker

#set join node to master
kubeadm join 192.168.10.1:6443 --token 1n4uaw.cgkvg26yowx7izjl --discovery-token-ca-cert-hash sha256:42c998d48530f155f467069bf3ddf2f72fb12cb478c141e03c0c60a4436126e1
