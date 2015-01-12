# Dockerfile for ELK stack with Redis input on Ubuntu base

# Help:
# Default command: docker run -d -p 80:80 -p 3333:3333 -p 3334:3334 -p 9200:9200 -p 6379:6379 elk-redis
# Default command will start ELK and redis-server within a docker
# To send data to elk, stream to TCP port 3333
# Example: echo 'Hello ELK ' | nc HOST 3333. Host is the IP of the docker host
# To login to bash: docker exec -it elk-redis bash



FROM ubuntu
MAINTAINER Rowe Leo

# Initial update
RUN apt-get update

# This is to install add-apt-repository utility. All commands have to be non interactive with -y option
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common

# Install Oracle Java 8, accept license command is required for non interactive mode
RUN	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886 && \
	DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:webupd8team/java && \
	apt-get update && \
	echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections &&\
	DEBIAN_FRONTEND=noninteractive apt-get install -y oracle-java8-installer

# Elasticsearch installation
# Start Elasticsearch by /elasticsearch/bin/elasticsearch. This will run on port 9200.
RUN wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.3.1.tar.gz && \
	tar xf elasticsearch-1.3.1.tar.gz && \
	rm elasticsearch-1.3.1.tar.gz && \
	mv elasticsearch-1.3.1 elasticsearch 

# Logstash installation
# Create a logstash.conf and start logstash by /logstash/bin/logstash agent -f logstash.conf
RUN wget https://download.elasticsearch.org/logstash/logstash/logstash-1.4.2.tar.gz && \
	tar xf logstash-1.4.2.tar.gz && \
	rm logstash-1.4.2.tar.gz && \
	mv logstash-1.4.2 logstash

# Kibana installation
RUN wget https://download.elasticsearch.org/kibana/kibana/kibana-3.1.0.tar.gz && \
	tar xf kibana-3.1.0.tar.gz && \
	rm kibana-3.1.0.tar.gz && \
	mv kibana-3.1.0  kibana

# Install curl utility just for testing
RUN apt-get update && \
	apt-get install -y curl

# Install vim for editing config file
RUN apt-get install -y vim

# Install Nginx
# Start or stop with /etc/init.d/nginx start/stop. Runs on port 80.
# Sed command is to make the worker threads of nginx run as user root
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y nginx && \
	sed -i -e 's/www-data/root/g' /etc/nginx/nginx.conf

# Deploy kibana to Nginx
RUN mv /usr/share/nginx/html /usr/share/nginx/html_orig && \
	mkdir /usr/share/nginx/html && \
	cp -r /kibana/* /usr/share/nginx/html

# Install Redis-Server
RUN apt-get install -y redis-server

# Create a start bash script
RUN touch elk_start.sh && \
	echo '#!/bin/bash' >> elk_start.sh && \
	echo '/elasticsearch/bin/elasticsearch &' >> elk_start.sh && \
	echo '/etc/init.d/nginx start &' >> elk_start.sh && \
	echo 'redis-server &' >> elk_start.sh && \
	echo 'exec /logstash/bin/logstash agent -f /logstash.conf &' >> elk_start.sh && \
        echo 'tail -f ' >> elk_start.sh && \
	chmod 777 elk_start.sh
	

#Add add logstash.conf into images
ADD logstash.conf /logstash.conf

#Add restart-logstash.sh into images
RUN touch restart-logstash.sh && \
    echo "ps aux | grep -i logstash | awk {'print \$2'} | xargs kill -9" >> restart-logstash.sh && \
    echo 'exec /logstash/bin/logstash agent -f /logstash.conf &' >> restart-logstash.sh && \
    chmod 777 restart-logstash.sh

# 80=nginx, 9200=elasticsearch, 3333,3334=logstash tcp input 6379=redis-server
EXPOSE 80 3333 3334 9200 49021 6379

# Run the ELK boot up command
CMD /elk_start.sh