#!/usr/bin/env bash

set -e

ssh app@curio-arch-lb-101.df-iad-int.37signals.com \
  docker exec curio-arch-load-balancer kamal-proxy rm curio-arch-admin

ssh app@curio-arch-lb-01.sc-chi-int.37signals.com \
  docker exec curio-arch-load-balancer kamal-proxy rm curio-arch-admin

ssh app@curio-arch-lb-401.df-ams-int.37signals.com \
  docker exec curio-arch-load-balancer kamal-proxy rm curio-arch-admin
