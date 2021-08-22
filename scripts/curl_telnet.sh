#!/bin/sh

curl "telnet://${1}:${2}" < "$3"