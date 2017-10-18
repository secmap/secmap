#!/bin/sh

apt-get update && \
apt-get install -y ruby=1:2.3.0+1 ruby-dev=1:2.3.0+1 gcc=4:5.3.1-1ubuntu1 make=4.1-6 && \
gem install redis -v 3.3.2 && \
gem install docker-api -v 1.33.1 && \
gem install sys-filesystem -v 1.1.7
