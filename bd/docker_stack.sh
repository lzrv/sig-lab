#!/bin/bash

# Original author: KenM
# set -e

# set some variables
# HUBVER is BlackDuck version (ie 2022.4.2) 
# STACK is current running stack 
# STACKNAME is optionall name of new stack (will default to version ie. 202242) 
# default stack name used for getting api token for scan wrapper script
export HUBVER=$1
export TMPFILE=/tmp/$HUBVER
export HUBHOME=/opt/blackduck
export STACK=`docker stack ls --format "{{.Name}}"`
export STACKNAME=$2
if [ -z $STACKNAME ]; then
 export STACKNAME="${HUBVER//.}"
fi

# user help
if [ -z "$HUBVER" ];then
  echo ""
  echo "usage: starthub.sh version stack"
  echo "stack is optional and a name will be generated if not provided"
  echo "version must be one of:"
  ls -d $HUBHOME/hub-*|cut -f2 -d-
  exit
fi

# check if version already downloaded or go fetch from github for released versions or artifactory for pre-release
# extract to $HUBHOME (ie. /opt/blackduck)
if [ -d $HUBHOME/hub-$HUBVER ]; then
  echo "found"
else
  echo "go fetch" $HUBVER
  if wget --quiet -O $TMPFILE  https://github.com/blackducksoftware/hub/archive/v$HUBVER.tar.gz && [[ -s $TMPFILE ]]; then tar zxf $TMPFILE  -C /opt/blackduck
  else
  export HUBVER=$HUBVER-rc
  echo "go fetch"  $HUBVER
  wget -qO- https://artifactory.internal.synopsys.com:443/artifactory/bds-hub-nightly/com/blackducksoftware/hub/hub-docker/$HUBVER/hub-docker-$HUBVER.tar |  tar xf - -C /opt/blackduck
  mv /opt/blackduck/hub-docker-$HUBVER /opt/blackduck/hub-$HUBVER
  fi
\rm $TMPFILE
fi

# stop running stack(s)
if [ -n "$STACK" ]; then
  echo "STOPPING" $STACK
  docker stack rm $STACK
  docker stack rm alert
  sleep 20
fi

# start new instance
echo "STARTING" $HUBVER
if [ $STACKNAME = "hub" ]; then
  docker stack deploy -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.yml \
    -c $HUBHOME/hub-$HUBVER/docker-swarm/sizes-gen02/resources.yaml \
    -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.local-overrides.yml \
    -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.bdba.yml $STACKNAME
  docker stack deploy -c $HUBHOME/alert/docker-swarm/standalone/docker-compose.yml \
    -c $HUBHOME/alert/docker-swarm/docker-compose.local-overrides.yml alert
  else
  docker stack deploy -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.yml \
    -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.local-overrides.yml \
    -c $HUBHOME/hub-$HUBVER/docker-swarm/docker-compose.bdba.yml  $STACKNAME
fi

