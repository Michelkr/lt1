#!/bin/bash
apt update
apt install -y net-tools
apt install -y openssh-server
apt install -y curl

sysctl net.bridge.bridge-nf-call-iptables=1
sysctl net.ipv4.ip_forward net.ipv4.ip_forward=1
sysctl -p

nmcli con mod "Wired connection 2" ipv4.addresses 192.168.10.1/24
nmcli con mod "Wired connection 2" ipv4.method manual
nmcli con mod "Wired connection 2" connection.autoconnect yes

####################################
#		
# Install saltstack server
#
####################################

#python required for salstack
apt-get install -y python-software-properties

#update packages
apt-get update

#install saltstack roles
apt-get install -y salt-master
apt-get install -y salt-minion
apt-get install -y salt-ssh

#set salstack to correct adapter
sed -i 's/#interface: 0.0.0.0/interface: 192.168.10.1/g' /etc/salt/master

#set minion to local
sed -i 's/#master: salt/master: 127.0.0.1/g' /etc/salt/minion

#make directories
mkdir -p /srv/{salt,pillar}

#install git python plugin
apt-get install -y python-git

#set file directories
sed -i '/#####      File Server settings      #####/a\file_roots:\n  base:\n    - /srv/salt' /etc/salt/master
sed -i '/# File Server Backend/a\fileserver_backend:\n    - gitfs\n    - roots' /etc/salt/master
sed -i '/# exist in that repo as/a\fileserver_backend:\n  - git://github.com/saltstack/https://github.com/Michelkr/lt1' /etc/salt/master

#copy scripts from git
mkdir /srv/salt/temp
git clone https://github.com/Michelkr/lt1 /srv/salt/temp
cp -r /srv/salt/temp/* /srv/salt
rm -r temp

#restart salt process
service salt-master restart
service salt-minion restart

####################################
#		
# Install Kubernetes master
#
####################################

#turn swap off
swapoff -a

#get and add required libraries
apt-get update && sudo apt-get install -y apt-transport-https
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - 
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list


curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update 

#install docker and Kubernetes
apt-get install -y docker-ce=18.06.0~ce~3-0~ubuntu
apt-get install -y kubelet kubeadm kubectl

sed -i '$ a 192.168.10.1 master' /etc/hosts
sed -i '$ a 192.168.10.2 minion03' /etc/hosts
sed -i '$ a 192.168.10.3 minion04' /etc/hosts

#set network variables for Kubernetes 
export API=`ifconfig enp0s8 | grep 'inet'| cut -d':' -f2 | awk '{print $2}'`
export DOMAIN="k8s.local"
export POD="10.4.0.0/16"
export SRV="10.5.0.0/16"

#apply variables for Kubernetes 
kubeadm init --pod-network-cidr ${POD} --service-cidr ${SRV} --apiserver-advertise-address ${API}

#set config and access for non admin
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#allow bridging and forwarding
ssctl net.bridge.bridge-nf-call-iptables=1

#apply weave pods
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

#set docket to start at startup
systemctl enable docker



####################################
#		
# Install elasticstack
#
####################################
add-apt-repository -y ppa:webupd8team/java
apt-get update

sudo echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
apt-get -y install oracle-java8-installer

update-alternatives --config java

#Set JAVA_HOME
JAVA_HOME="/usr/lib/jvm/java-8-oracle"
export JAVA_HOME
PATH=$PATH:$JAVA_HOME
export PATH

#get libraries
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt-get update
apt-get -y install elasticsearch

#have to set full access elastic for ubuntu 18.04- bug
sudo chmod 777 /etc/elasticsearch/

#set  host
sed -i 's/# network.host: 192.168.0.1/ network.host: localhost/g' /etc/elasticsearch/elasticsearch.yml
sed -i 's/# http.port: 9200/ http.port: 9200/g' /etc/elasticsearch/elasticsearch.yml

service elasticsearch restart
systemctl enable elasticsearch

apt-get update
apt-get install kibana

#set  host
sed -i 's/#server.host: "localhost"/server.host: "localhost"/g' /etc/kibana/kibana.yml
sed -i 's/#server.port: 5601"localhost"/server.port: 5601/g' /etc/kibana/kibana.yml

sed -i 's/#server.host: "localhost"/server.host: "localhost"/g' /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.url: /elasticsearch.url: /g' /etc/kibana/kibana.yml

service kibana start
systemctl enable kibana

apt-get install -y nginx apache2-utils

#set config
echo "server {" > /tmp/kibana
echo "    listen 80;" >> /tmp/kibana
echo "" >> /tmp/kibana
echo "    server_name micheldash.io;" >> /tmp/kibana
echo "" >> /tmp/kibana
echo "    auth_basic \"Restricted Access\";" >> /tmp/kibana
echo "    auth_basic_user_file /etc/nginx/.kibana-user;" >> /tmp/kibana
echo "" >> /tmp/kibana
echo "    location / {" >> /tmp/kibana
echo "        proxy_pass http://localhost:5601;" >> /tmp/kibana
echo "        proxy_http_version 1.1;" >> /tmp/kibana
echo "        proxy_set_header Upgrade \$http_upgrade;" >> /tmp/kibana
echo "        proxy_set_header Connection 'upgrade';" >> /tmp/kibana
echo "        proxy_set_header Host \$host;" >> /tmp/kibana
echo "        proxy_cache_bypass \$http_upgrade;" >> /tmp/kibana       
echo "    }" >> /tmp/kibana
echo "}" >> /tmp/kibana

#set site to live
cp -fr /tmp/kibana /etc/nginx/sites-available/

#set user
htpasswd -c /etc/nginx/.kibana-user elastic

#set config
ln -s /etc/nginx/sites-available/kibana /etc/nginx/sites-enabled/

systemctl enable nginx
systemctl restart nginx

#get library and install logstash
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee /etc/apt/sources.list.d/logstash-2.2.x.list
apt-get install logstash

#set add hostname
sed -i '$ a 192.168.10.1 micheldash.io' /etc/hosts
mkdir -p /etc/pki/tls/certs

#set config
echo "input {" > /etc/logstash/conf.d/filebeat-input.conf
echo " beats {" >> /etc/logstash/conf.d/filebeat-input.conf
echo "   port => 5044" >> /etc/logstash/conf.d/filebeat-input.conf
echo "   ssl => false" >> /etc/logstash/conf.d/filebeat-input.conf
echo "   }" >> /etc/logstash/conf.d/filebeat-input.conf
echo "}" >> /etc/logstash/conf.d/filebeat-input.conf

#set config
echo "filter {" > /etc/logstash/conf.d/syslog-filter.conf
echo "  if [type] == \"syslog\" {" >> /etc/logstash/conf.d/syslog-filter.conf
echo "   grok {" >> /etc/logstash/conf.d/syslog-filter.conf
echo "     match => { \"message\" => \"%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}\" }" >> /etc/logstash/conf.d/syslog-filter.conf
echo "     add_field => [ \"received_at\", \"%{@timestamp}\" ]" >> /etc/logstash/conf.d/syslog-filter.conf
echo "     add_field => [ \"received_from\", \"%{host}\" ]" >> /etc/logstash/conf.d/syslog-filter.conf
echo "   }" >> /etc/logstash/conf.d/syslog-filter.conf
echo "   date {" >> /etc/logstash/conf.d/syslog-filter.conf
echo "     match => [ \"syslog_timestamp\", \"MMM  d HH:mm:ss\", \"MMM dd HH:mm:ss\" ]" >> /etc/logstash/conf.d/syslog-filter.conf
echo "   }" >> /etc/logstash/conf.d/syslog-filter.conf
echo " }" >> /etc/logstash/conf.d/syslog-filter.conf


#set config
echo " output {" > /etc/logstash/conf.d/elastic-filter.conf
echo "  elasticsearch { hosts => [\"localhost:9200\"]" >> /etc/logstash/conf.d/elastic-filter.conf
echo "    hosts => \"localhost:9200\"" >> /etc/logstash/conf.d/elastic-filter.conf
echo "    manage_template => false" >> /etc/logstash/conf.d/elastic-filter.conf
echo "    index => \"%{[@metadata][beat]}-%{+YYYY.MM.dd}\"" >> /etc/logstash/conf.d/elastic-filter.conf
echo "    document_type => \"%{[@metadata][type]}\"" >> /etc/logstash/conf.d/elastic-filter.conf
echo "  }" >> /etc/logstash/conf.d/elastic-filter.conf
echo "}" >> /etc/logstash/conf.d/elastic-filter.conf

#enable logstash
systemctl enable logstash
systemctl start logstash

#set install metricbeat and filebeat
apt-get install metricbeat
apt-get install filebeat

# copy configs from srv
cp -fr /srv/salt/filebeat.yml /etc/filebeat/
cp -fr /srv/salt/metricbeat.yml /etc/filebeat/

service metricbeat restart
service filebeat restart

#set kibana dashboards
filebeat setup --dashboards
metricbeat setup --dashboards

#echo the join key for kubernetes
kubeadm token create --print-join-command 