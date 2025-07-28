#!/system/bin/sh

# Magisk Module: ToyBox-Ext v1.0.9
# Copyright (c) zgfg @ xda, 2022-
# GitHub source: https://github.com/zgfg/ToyBox-Ext

# Module's own path (local path)
MODDIR=${0%/*}

# Log file for debugging
LogFile="$MODDIR/action.log"
exec 3>&1 4>&2 2>$LogFile 1>&2
set -x

if [ -z $MODDIR ]
then
  MODDIR=$(pwd)
fi

# Log info
date +%c
whoami
magisk -c
echo $APATCH
getprop ro.product.cpu.abi
getprop ro.product.cpu.abilist

# Source the original toybox binary type and last download time
cd $MODDIR
pwd
LASTDLTIME=0
TBSCRIPT='./tbtype.sh'
if [ -f $TBSCRIPT ]
then
  . $TBSCRIPT
fi

# Current time
DLTIME=$(date +"%s")

# Passed time since the last download
PASSEDTIME=$(($DLTIME - $LASTDLTIME))

# Waiting time between downloads (15 days)
WAITTIME=$((15 * 24 * 3600))
#WAITTIME=$((15  * 60))  # 15 min, for testing

# If waiting time passed, download the latest binary again
if [ -n $TBTYPE ] && [ $PASSEDTIME -gt $WAITTIME ]
then
  # Find busybox binary
  BB=busybox
  BBBIN=$(which $BB)
  if [ -z $BBBIN ]
  then
    DATA=/data/adb
    MODULES=$DATA/modules
    for Path in $MODULES/BuiltIn-BusyBox/$BB $MODULES/busybox-ndk/system/*/$BB $DATA/magisk/$BB $DATA/ap/bin/$BB $DATA/ksu/bin/$BB
    do
      if [ -x $Path ]
      then
        BBBIN=$Path
        break
      fi
    done
  fi

  # Download latest toybox binary
  $BBBIN wget -c -T 20 "http://landley.net/toybox/bin/$TBTYPE"
fi

# Test the download 
if [ -n $TBTYPE ] && [ -f $TBTYPE ]
then
  # Compare checksums for the old and new binary
  MD5Old=$(md5sum toybox-ext | head -c 32)
  MD5New=$(md5sum "$TBTYPE" | head -c 32)
  if [ "$MD5New" = "$MD5Old" ]
  then
    # Save the download time
    echo "LASTDLTIME=$DLTIME" >> $TBSCRIPT

    # Delete, same as old binary
    rm -f $TBTYPE
  else
    # Test downloaded binary
    chmod 755 $TBTYPE
    Applets=$(./$TBTYPE)
    if [ -z "$Applets" ]
    then
      # Delete, not working
      rm -f $TBTYPE
    else
      # Save the binary type and installation time
      echo "TBTYPE=$TBTYPE" > $TBSCRIPT
      echo "LASTDLTIME=$DLTIME" >> $TBSCRIPT

      # Notify user to reboot
      Version=$(./$TBTYPE --version)
      exec 1>&3 2>&4
      su -lp 2000 -c "cmd notification post -S bigtext -t 'ToyBox-Ext Module' 'Tag' 'Reboot to update ToyBox binary to $Version'" 1>/dev/null
      exec 3>&1 4>&2 2>>$LogFile 1>&2
    fi
  fi
fi

set +x
exec 1>&3 2>&4 3>&- 4>&-
