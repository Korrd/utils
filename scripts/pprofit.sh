#!/bin/bash
# This script was designed to run on a docker for azure node which has alpine installed.

function allSystemsGo() {
  # Params: RESULTCODE, MESSAGE_OK, MESSAGE_FAIL
  # echo "Params received: Resultcode: $1, MESSAGE_OK: $2, MESSAGE_FAIL: $3"
  if [ "$1" = "0" ]; then
    echo "$2"
  else
    echo "$3"
    exit "$1"
  fi
}

# =====================================================================================================================
# Setup ===============================================================================================================
# =====================================================================================================================

# Repo add done the UGLY way, as arrays do not work on alpine... <.<
echo "Adding required repos..."

REPOFILE="/etc/apk/repositories"
REPO_A="http://dl-2.alpinelinux.org/alpine/edge/community"
REPO_B="http://dl-3.alpinelinux.org/alpine/edge/community"
REPO_C="http://dl-4.alpinelinux.org/alpine/edge/community"
REPO_D="http://dl-5.alpinelinux.org/alpine/edge/community"

grep -Fxq $REPO_A $REPOFILE
if [ "$?" = "1" ]; then
  echo $REPO_A >> $REPOFILE
  allSystemsGo $? "Repo updated successfully!" "Could not update repos. Check permissions and stuff :("
fi

grep -Fxq $REPO_B $REPOFILE
if [ "$?" = "1" ]; then
  echo $REPO_B >> $REPOFILE
  allSystemsGo $? "Repo updated successfully!" "Could not update repos. Check permissions and stuff :("
fi

grep -Fxq $REPO_C $REPOFILE
if [ "$?" = "1" ]; then
  echo $REPO_C >> $REPOFILE
  allSystemsGo $? "Repo updated successfully!" "Could not update repos. Check permissions and stuff :("
fi

grep -Fxq $REPO_D $REPOFILE
if [ "$?" = "1" ]; then
  echo $REPO_D >> $REPOFILE
  allSystemsGo $? "Repo updated successfully!" "Could not update repos. Check permissions and stuff :("
fi

# Add required packages
echo "Updating repositories..."
apk update
allSystemsGo $? "Repos updated successfully!" "Could not update repos. Check permissions and stuff :("

echo "Adding go and tools..."
apk add go socat graphviz libc-dev
allSystemsGo $? "We are GO for launch!" "Could not add GO and stuff. :("

# Set env vars so GO and pprof do work properly
echo "Setting env vars..."
export PATH=$PATH:$(go env GOPATH)/bin \
  && export GOPATH=$(go env GOPATH)
allSystemsGo $? "Env vars set: \n PATH=$PATH \n GOPATH=$GOPATH" "Could not set env vars. :("

# Go get me the profiling tool boy!
echo "Adding pprof..."
go get github.com/google/pprof
allSystemsGo $? "Pprof installed!" "Unable to add pprof. :("

echo "All set for GO pprofiling!"

# =====================================================================================================================
# Streaming app stuff with Socat ======================================================================================
# =====================================================================================================================
PORT="8081"
echo "Starting socat on port $PORT..."

socat -d -d TCP-LISTEN:$PORT,fork,bind=localhost UNIX:/var/run/docker.sock &
allSystemsGo $? "Socat streaming OK on port $PORT!" "Socat failed to start. Check if the port is available :("

# =====================================================================================================================
# Get profiling graphics - Memory =====================================================================================
# =====================================================================================================================

ALLOC_OBJECTS="alloc_objects"
ALLOC_SPACE="alloc_space"
INUSE_OBJECTS="inuse_objects"
INUSE_SPACE="inuse_space"
TYPE="heap"
echo "Profiling docker daemon..."
DATETIME=`date '+%Y-%m-%d-%H-%m-%S'`
go tool pprof -svg -$ALLOC_OBJECTS http://localhost:$PORT/debug/pprof/$TYPE > $TYPE-$DATETIME-$ALLOC_OBJECTS.svg \
  && go tool pprof -svg -$ALLOC_SPACE http://localhost:$PORT/debug/pprof/$TYPE > $TYPE-$DATETIME-$ALLOC_SPACE.svg \
  && go tool pprof -svg -$INUSE_OBJECTS http://localhost:$PORT/debug/pprof/$TYPE > $TYPE-$DATETIME-$INUSE_OBJECTS.svg \
  && go tool pprof -svg -$INUSE_SPACE http://localhost:$PORT/debug/pprof/$TYPE > $TYPE-$DATETIME-$INUSE_SPACE.svg
allSystemsGo $? "Profiling OK" "Profiling command failed to execute :("

echo "Killing socat"
pkill socat

exit 0