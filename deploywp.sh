#!/bin/bash
####################################
#		
# Deploy wordpress
#
####################################

kubectl create secret generic mysql-pass --from-literal=password=password

cd /srv/salt

kubectl create -f pv.yaml

kubectl create -f mysql.yaml

kubectl create -f wordpress.yaml