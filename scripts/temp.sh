#!/bin/bash
echo "---------"
cpu=$(cat /sys/class/thermal/thermal_zone0/temp)
echo "CPU: $((cpu/1000))°C"
echo "---------"
