#!/bin/bash

# This script serves the purpose of launching all ROS services needed
# for the IRIS lab CAMBADA@home robot.
# It checks for basic environment settings and launches all processes
# in a screen session.
#
# 2016 Guilherme Cardoso <gjc@ua.pt>


# Basic configuration

# is this script running in a ROS native distro (doesn't check for ros_catkin_ws folder) ?
ROS_NATIVE_DISTRO=true

# ROS source installation directory (ignored if above is true)
ROS_CATKIN_WS_DIR="ros_catkin_ws"

# catkin_ws containing catking workspace and cambada modules
CATKIN_WS_DIR="catkin_ws"

# python version check
REQUIRED_PYTHON_MAJOR_VERSION=2

# working ROS version target
ROS_VERSION="indigo"

# tty file
TTY_FILE="/dev/ttyS0"

# target shell (sh | zsh | bash)
TARGET_SHELL=sh

# target launching terminal ( screen | gnome-terminal )
TARGET_TERMINAL=gnome-terminal

# services to launch
services=(  "roslaunch bringup hwcomm.launch"
            "roslaunch bringup teleop.launch joy:=/dev/joy1"
            "roslaunch freenect_launch freenect.launch"
            "roslaunch rosbridge_server rosbridge_websocket.launch"
            "#roslaunch cmvision_3d color_tracker.launch"
)

# End of configuration
###########################################################

# Changelog
# 2016-04-20 1.0 Initial script with support for bash/zsh/sh and launching in screen
# 2016-04-23 1.1 Added gnome-terminal-support

SCREEN_SESSION_NAME="ros_screen"
SLEEP_BETWEEN_COMMANDS="3"
TTY_PERMISSIONS_ACCESS_GROUP=$(stat -c %G $TTY_FILE)


function environment_check
{
    # Checks for: 
    #   - ros_catkin_ws directory exists
    #   - catkin_ws directory exists
    #   - correct system python version
    #   - if screen is installed

    environment_ok=true

    # check for ros_catkin_ws folder if not a ROS native distro
    if [ $HOME/$ROS_NATIVE_DISTRO == false ]; then
        if [ ! -d $HOME/$ROS_CATKIN_WS_DIR ]; then
            echo "Error: ros_catkin_ws directory at" $HOME/$ROS_CATKIN_WS_DIR "not found"
            environment_ok=false
        fi
    fi
    
    # check for user catkin_ws folder
    if [ ! -d $HOME/$CATKIN_WS_DIR ]; then
        echo "Error: catkin_ws directory at" $HOME/$CATKIN_WS_DIR "not found"
        environment_ok=false
    fi
    
    # check for correct python version
    PYTHON_VERSION=`python -c 'import sys; print(sys.version_info[0])'`
    
    if [ $PYTHON_VERSION != $REQUIRED_PYTHON_MAJOR_VERSION ]; then
        echo "Error: Python version is" $PYTHON_VERSION "and required python is" $REQUIRED_PYTHON_MAJOR_VERSION
        environment_ok=false
    fi
    
    # check if screen is installed IF TARGET_TERMINAL is screen
    if [ $TARGET_TERMINAL == "screen" ]; then
        which screen &> /dev/null
        if [ ! $? -eq 0 ]; then
            echo "Error: screen not found. please install."
            environment_ok=false
        fi
    fi
    
    # check if gnome-terminal is installed IF TARGET_TERMINAL is screen
    if [ $TARGET_TERMINAL == "gnome-terminal" ]; then
        which gnome-terminal &> /dev/null
        if [ ! $? -eq 0 ]; then
            echo "Error: gnome-terminal not found. please install."
            environment_ok=false
        fi
    fi
    
    # everything ok?
    if [ $environment_ok == false ]; then
        exit 1
    fi
    
}

function ros_version_check
{
    # Checks for the correct target ROS version
    # just warns if not
    
    # source is needed if not a native distro
    if [ $ROS_NATIVE_DISTRO == false ]; then
        source $HOME/$ROS_CATKIN_WS_DIR/install_isolated/setup.sh
    fi
    
    if [ ! $ROS_VERSION == $ROS_DISTRO ]; then
        echo "Warning: found ROS Distro $ROS_DISTRO and expected $ROS_VERSION"
    fi
}

function tty_fileperms_check
{
    # Checks for tty correct permissions for interaction with microrato and joy dev

    id -nG $USER | grep -qw $TTY_PERMISSIONS_ACCESS_GROUP
    
    if [ ! $? -eq 0 ]; then
        echo "Error: user not in $TTY_PERMISSIONS_ACCESS_GROUP but with tty rw permissions."
        echo ""
        echo " Add yourself to $TTY_PERMISSIONS_ACCESS_GROUP with:"
        echo ""
        echo "  sudo useradd -G $TTY_PERMISSIONS_ACCESS_GROUP $USER"
        echo ""
        
        if [ ! -w $TTY_FILE ]; then
            echo " For a quick fix do:"
            echo ""
            echo "  sudo chmod 777" $TTY_FILE
            exit 1
        fi
    fi
}

function launch_ros_in_screen
{
    # launches the services in a screen session, one service per tab
    # it waits "$SLEEP_BETWEEN_COMMANDS" seconds between each run
    
    
    screen -ls $SCREEN_SESSION_NAME > /dev/null

    # checks if there's already an session running
    if [ $? -eq 0 ]; then
        echo "Error: There's already an screen session running"
        echo ""
        screen -ls $SCREEN_SESSION_NAME
        exit 1
    fi

    # create screen session
    screen -dmS $SCREEN_SESSION_NAME
    
    x=0
    
    # loop though services to launch
    for i in "${services[@]}"
    do
        echo "--launching service: $i"
        
        # checks if it is first windows being launched
        if [ $x != 0 ]; then
            screen -S $SCREEN_SESSION_NAME -X screen
        fi
        
        screen -S $SCREEN_SESSION_NAME -X select $x
        
        # checks if it is a native distro and if the profile needs to be sourced
        if [ $ROS_NATIVE_DISTRO == false ]; then
            screen -S $SCREEN_SESSION_NAME -X stuff $"source $HOME/$ROS_CATKIN_WS_DIR/install_isolated/setup.$TARGET_SHELL\n"
        fi
        
        
        screen -S $SCREEN_SESSION_NAME -X stuff $"source $HOME/$CATKIN_WS_DIR/devel/setup.$TARGET_SHELL\n"
        screen -S $SCREEN_SESSION_NAME -X stuff $"$i\n"
        #screen -S $SCREEN_SESSION_NAME -X title "$i"
    
        sleep $SLEEP_BETWEEN_COMMANDS
    
        ((x++))     
    done
    
    echo ""
    screen -ls
}

function launch_ros_in_gnome_terminal
{
    # launches the services in a new gnome-terminal window, one service per tab
    # it waits "$SLEEP_BETWEEN_COMMANDS" seconds between each run
    
    tab="--tab"
    gnome_terminal_concatenated_command=""
    GNOME_SLEEP_BETWEEN_COMMANDS=0
    
    # loop though services to launch
    for i in "${services[@]}"
    do
        gnome_terminal_concatenated_command+=($tab -e "bash -c \"sleep $GNOME_SLEEP_BETWEEN_COMMANDS; $i; exec bash\"")
        ((GNOME_SLEEP_BETWEEN_COMMANDS = GNOME_SLEEP_BETWEEN_COMMANDS + SLEEP_BETWEEN_COMMANDS))
    done
    
    gnome-terminal "${gnome_terminal_concatenated_command[@]}"
    
    echo ""
    echo "Done!"

}


# Running everything

echo "Checking system environment..."
environment_check

echo "Checking for ROS $ROS_VERSION..."
ros_version_check

echo "Checking for tty permissions..."
tty_fileperms_check

echo ""
echo "Launching ROS, please wait..."

case $TARGET_TERMINAL in
    'screen')    
        launch_ros_in_screen
    ;;
    'gnome-terminal')
        launch_ros_in_gnome_terminal
    ;;
esac
