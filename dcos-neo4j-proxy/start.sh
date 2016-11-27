#!/bin/bash -eu

service cron start

nginx -g 'daemon off;'
