#!/usr/bin/env bash

# Remove the admin proxy from load balancers.
# Configure LB_HOSTS as a space-separated list of load balancer hostnames.
#
# Example:
#   LB_HOSTS="lb-1.example.com lb-2.example.com" bash script/remove-lb-admin-production.sh

set -e

if [ -z "$LB_HOSTS" ]; then
  echo "ERROR: LB_HOSTS not set. Provide space-separated load balancer hostnames."
  echo "Example: LB_HOSTS=\"lb-1.example.com lb-2.example.com\" bash script/remove-lb-admin-production.sh"
  exit 1
fi

LB_CONTAINER="${LB_CONTAINER:-curio-arch-load-balancer}"
PROXY_SERVICE="${PROXY_SERVICE:-curio-arch-admin}"
SSH_USER="${SSH_USER:-app}"

for host in $LB_HOSTS; do
  echo "Removing $PROXY_SERVICE from $host..."
  ssh "$SSH_USER@$host" docker exec "$LB_CONTAINER" kamal-proxy rm "$PROXY_SERVICE"
done
