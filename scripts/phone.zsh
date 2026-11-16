#!/usr/bin/env zsh
set -euo pipefail

print 'Checking the USB connection and pairing without Apple credentials.'
devices=$(idevice_id -l)
if [[ -z $devices ]]; then
  print -u2 'No iPhone or iPad is visible through usbmuxd. Connect and unlock the device, tap Trust, and ensure the host usbmuxd service is running.'
  exit 1
fi
if [[ ${#${(f)devices}} != 1 ]]; then
  print -u2 'Connect one iPhone or iPad for this check.'
  exit 1
fi
idevicepair -u "$devices" validate
ideviceinfo -u "$devices" -k ProductVersion
print 'USB and pairing are ready. Enter the signing Apple ID in iloader at the final installation step.'
