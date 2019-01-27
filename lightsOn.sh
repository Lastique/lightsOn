#!/bin/bash
# lightsOn.sh

# Copyright (c) 2013 iye.cba at gmail com
# url: https://github.com/iye/lightsOn
# This script is licensed under GNU GPL version 2.0 or above

# Description: Bash script that prevents the screensaver and display power
# management (DPMS) to be activated when you are watching Flash Videos
# fullscreen on Firefox and Chromium.
# Can detect mpv, mplayer, smplayer, minitube, and VLC when they are fullscreen too.
# lightsOn.sh needs xscreensaver, kscreensaver or gnome-screensaver to work.

# HOW TO USE: Start the script with the number of seconds you want the checks
# for fullscreen to be done. Example:
# "./lightsOn.sh 120 &" will Check every 120 seconds if Mplayer, Minitube
# VLC, Firefox or Chromium are fullscreen and delay screensaver and Power Management if so.
# You want the number of seconds to be ~10 seconds less than the time it takes
# your screensaver or Power Management to activate.
# If you don't pass an argument, the checks are done every 50 seconds.
#
# An optional array variable exists here to add the names of programs that will delay the screensaver if they're running.
# This can be useful if you want to maintain a view of the program from a distance, like a music playlist for DJing,
# or if the screensaver eats up CPU that chops into any background processes you have running,
# such as realtime music programs like Ardour in MIDI keyboard mode.
# If you use this feature, make sure you use the name of the binary of the program (which may exist, for instance, in /usr/bin).


# Modify these variables if you want this script to detect if Mplayer,
# mpv, smplayer, VLC or Minitube, or Firefox or Chromium Flash Video are Fullscreen and disable
# screensaver and PowerManagement. any_fullscreen will disable the screensaver if there
# is any fullscreen application running, which is useful for games with a gamepad.
any_fullscreen=1
mpv_detection=1
mplayer_detection=1
smplayer_detection=1
vlc_detection=1
firefox_flash_detection=1
chromium_flash_detection=1
minitube_detection=1
html5_detection=1 #checks if the browser window is fullscreen; will disable the screensaver if the browser window is in fullscreen so it doesn't work correctly if you always use the browser (Firefox or Chromium) in fullscreen

# Names of programs which, when running, you wish to delay the screensaver.
delay_progs=() # For example ('ardour2' 'gmpc')


# YOU SHOULD NOT NEED TO MODIFY ANYTHING BELOW THIS LINE

# If argument is not integer quit.
if [[ $1 = *[^0-9]* ]]
then
    echo "The Argument \"$1\" is not valid, not an integer"
    echo "Please use the time in seconds you want the checks to repeat."
    echo "You want it to be ~10 seconds less than the time it takes your screensaver or DPMS to activate"
    exit 1
fi

delay=$1

# If argument empty, use 50 seconds as default.
if [ -z "$1" ]
then
    delay=50
fi

sleep $delay

# enumerate all the attached screens
displays=""
while read id
do
    displays="$displays $id"
done < <(xvinfo | sed -n 's/^screen #\([0-9]\+\)$/\1/p')

# Detect screensaver been used (powerdevil, xscreensaver, kscreensaver, gnome-screensaver, cinnamon-screensaver or none)
if [ `pgrep -lc org_kde_powerde` -ge 1 ]
then
    screensaver=powerdevil
elif [ `pgrep -lc xscreensaver` -ge 1 ]
then
    screensaver=xscreensaver
elif [ `pgrep -lc gnome-screensav` -ge 1 ]
then
    screensaver=gnome-screensaver
elif [ `pgrep -lc kscreensaver` -ge 1 ]
then
    screensaver=kscreensaver
elif [ `pgrep -lc cinnamon-screen` -ge 1 ]
then
    screensaver=cinnamon-screensaver
else
    screensaver=None
    echo "No screensaver detected"
fi

checkDelayProgs()
{
    for prog in "${delay_progs[@]}"
    do
        if [ `pgrep -lfc "$prog"` -ge 1 ]
        then
            echo "Delaying the screensaver because a program on the delay list, \"$prog\", is running..."
            delayScreensaver
            break
        fi
    done
}

checkFullscreen()
{
    # loop through every display looking for a fullscreen window
    local active_win_id_re=".*window id #\\s*([0-9xXa-fA-F]+).*"
    local display
    for display in $displays
    do
        #get id of active window and clean output
        active_win_id=`DISPLAY=:0.${display} xprop -root _NET_ACTIVE_WINDOW`
        #active_win_id=${active_win_id#*# } #gives error if xprop returns extra ", 0x0" (happens on some distros)
        if [[ "$active_win_id" =~ $active_win_id_re ]]
        then
            active_win_id="${BASH_REMATCH[1]}"
        else
            echo "Failed to parse window id from: $active_win_id"
            continue
        fi
        # Skip invalid window ids (commented as I could not reproduce a case
        # where invalid id was returned, plus if id invalid
        # isActivWinFullscreen will fail anyway.)
        #if [ "$active_win_id" = "0x0" ]
        #then
        #     continue
        #fi

        # Check if Active Window (the foremost window) is in fullscreen state
        isActivWinFullscreen=`DISPLAY=:0.${display} xprop -id "$active_win_id" _NET_WM_STATE`
        if [[ "$isActivWinFullscreen" = *NET_WM_STATE_FULLSCREEN* ]]
        then
            local -i delay_needed=0
            if [ $any_fullscreen = 1 ]
            then
                delay_needed=1
            else
                isAppRunning
                delay_needed=$?
            fi
            if [ $delay_needed -ne 0 ]
            then
                delayScreensaver
                break
            fi
        fi
    done
}




# check if active windows is mplayer, vlc or firefox
#TODO only window name in the variable active_win_id, not whole line. 
#Then change IFs to detect more specifically the apps "<vlc>" and if process name exist

isAppRunning()
{
    #Get title of active window
    local active_win_title=`xprop -id "$active_win_id" WM_CLASS`   # I used WM_NAME(STRING) before, WM_CLASS more accurate.

    # Check if user want to detect Video fullscreen on Firefox, modify variable firefox_flash_detection if you dont want Firefox detection
    if [ $firefox_flash_detection = 1 ]
    then
        if [[ "$active_win_title" = *unknown* || "$active_win_title" = *plugin-container* ]]
        then
            # Check if plugin-container process is running
            local flash_process=`pgrep -lc plugin-containe`
            if [[ $flash_process -ge 1 ]]
            then
                return 1
            fi
        fi
    fi


    # Check if user want to detect Video fullscreen on Chromium, modify variable chromium_flash_detection if you dont want Chromium detection
    if [ $chromium_flash_detection = 1 ]
    then
        if [[ "$active_win_title" = *exe* ]]
        then
            # Check if Chromium/Chrome Flash process is running
            local flash_process=`pgrep -lfc ".*((c|C)hrome|chromium).*flashp.*"`
            if [[ $flash_process -ge 1 ]]
            then
                return 1
            fi
        fi
    fi

    # html5 (Firefox, Chrome or Chromium full-screen)
    if [ $html5_detection = 1 ]
    then
        if [[ "$active_win_title" = *Google-chrome* ]]
        then
            if [[ `pgrep -lc chrome` -ge 1 ]]
            then
                return 1
            fi
        elif [[ "$active_win_title" = *Firefox* ]]
        then
            if [[ `pgrep -lc firefox` -ge 1 ]]
            then
                return 1
            fi
        elif [[ "$active_win_title" = *chromium-browser* ]]
        then
            if [[ `pgrep -lc chromium-browse` -ge 1 ]]
            then
                return 1
            fi
        fi
    fi


    # Check if user want to detect mpv fullscreen, modify variable mpv_detection
    if [ $mpv_detection = 1 ]
    then
        if [[ "$active_win_title" = *mpv* ]]
        then
            #check if mpv is running.
            local mpv_process=`pgrep -lc mpv`
            if [ $mpv_process -ge 1 ]
            then
                return 1
            fi
        fi
    fi

    # Check if user want to detect mplayer fullscreen, modify variable mplayer_detection
    if [ $mplayer_detection = 1 ]
    then
        if [[ "$active_win_title" = *mplayer* || "$active_win_title" = *MPlayer* ]]
        then
            #check if mplayer is running.
            local mplayer_process=`pgrep -l mplayer | grep -v smplayer | grep -wc mplayer`
            if [ $mplayer_process -ge 1 ]
            then
                return 1
            fi
        fi
    fi

    # Check if user want to detect smplayer fullscreen, modify variable smplayer_detection
    if [ $smplayer_detection = 1 ]
    then
        if [[ "$active_win_title" = *smplayer* ]]
        then
            #check if smplayer is running.
            local smplayer_process=`pgrep -lc smplayer`
            if [ $smplayer_process -ge 1 ]
            then
                return 1
            fi
        fi
    fi

    # Check if user want to detect vlc fullscreen, modify variable vlc_detection
    if [ $vlc_detection = 1 ]
    then
        if [[ "$active_win_title" = *vlc* ]]
        then
            #check if vlc is running.
            #local vlc_process=`pgrep -l vlc | grep -wc vlc`
            local vlc_process=`pgrep -lc vlc`
            if [ $vlc_process -ge 1 ]
            then
                return 1
            fi
        fi
    fi

    # Check if user want to detect minitube fullscreen, modify variable minitube_detection
    if [ $minitube_detection = 1 ]
    then
        if [[ "$active_win_title" = *minitube* ]]
        then
            #check if minitube is running.
            #minitube_process=`pgrep -l minitube | grep -wc minitube`
            minitube_process=`pgrep -lc minitube`
            if [ $minitube_process -ge 1 ]
            then
                return 1
            fi
        fi
    fi

    return 0
}


delayScreensaver()
{
    # reset inactivity time counter so screensaver is not started
    if [ "$screensaver" = "xscreensaver" ]
    then
        # This tells xscreensaver to pretend that there has just been user activity. This means that if the screensaver is active (the screen is blanked), then this command will cause the screen to un-blank as if there had been keyboard or mouse activity.
        # If the screen is locked, then the password dialog will pop up first, as usual. If the screen is not blanked, then this simulated user activity will re-start the countdown (so, issuing the -deactivate command periodically is one way to prevent the screen from blanking.)
        xscreensaver-command -deactivate > /dev/null
    elif [ "$screensaver" = "gnome-screensaver" ]
    then
        dbus-send --session --type=method_call --dest=org.gnome.ScreenSaver --reply-timeout=20000 /org/gnome/ScreenSaver org.gnome.ScreenSaver.SimulateUserActivity > /dev/null
    elif [ "$screensaver" = "kscreensaver" -o "$screensaver" = "powerdevil" ]
    then
        qdbus org.freedesktop.ScreenSaver /ScreenSaver SimulateUserActivity > /dev/null
        # method org.freedesktop.ScreenSaver.SimulateUserActivity() in KDE 5 seems
        # to have no effect unless GetSessionIdleTime() called afterwards.
        qdbus org.freedesktop.ScreenSaver /ScreenSaver GetSessionIdleTime > /dev/null
    elif [ "$screensaver" = "cinnamon-screensaver" ]
    then
        qdbus org.cinnamon.ScreenSaver / SimulateUserActivity > /dev/null
    fi

    #Check if DPMS is on. If it is, deactivate and reactivate again. If it is not, do nothing.
    local dpmsStatus=`xset -q | grep -ce 'DPMS is Enabled'`
    if [ $dpmsStatus = 1 ]
    then
        xset -dpms
        xset dpms
    fi
}



while true
do
    checkDelayProgs
    checkFullscreen
    sleep $delay || break
done

exit 0
