#!/usr/bin/bash

# IMPORTANT: IN BETA TAKE SNAPSHOT FIRST
# New MySQL User
# BASH script for creating a new MySQL user
# Also works on MariaDB
# By Nicholas Grogg

# Color variables
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
normal=$(tput sgr0)

# Help function
function helpFunction(){
    printf "%s\n" \
    "Help" \
    "----------------------------------------------------" \
    "THIS SCRIPT IS IN BETA TAKE A SNAPSHOT BEFORE RUNNING" \
    " " \
    "help/Help" \
    "* Display this help message and exit" \
    " " \
    "create/Create" \
    "* Create MySQL user" \
    "* Takes a username and IP as arguments" \
    "* Creates a username with root user permissions" \
    "Usage. ./newMysqlUser.sh create username welshIP " \
    "Ex. ./newMysqlUser.sh create jdoe_root 10.138.1.2" \
    " " \
    "For Stantz servers use localhost for welshIP:" \
    "Ex. ./newMysqlUser.sh create jdoe_root localhost" \
    " " \
    "IMPORTANT: This script is not designed for Cloud SQL! "
}

# Function to run program
function runProgram(){
    printf "%s\n" \
    "Create" \
    "----------------------------------------------------"

    ## Variables
    databaseUser=$1
    welshIP=$2

    ## Validation
    ### Is script running as root?
    printf "%s\n" \
    "Checking if user is root "\
    "----------------------------------------------------" \
    " "
    if [[ "$EUID" -eq 0 ]]; then
        printf "%s\n" \
        "${green}User is root "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    else
        printf "%s\n" \
        "${red}ISSUE DETECTED - User is NOT root "\
        "----------------------------------------------------" \
        "Re-run script as root${normal}"
        exit 1
    fi

    ### Check if MySQL/MariaDB installed
    if [[ ! -f $(which mysql) && ! -f $(which mariadb) ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - MySQL/MariaDB not found! "\
        "----------------------------------------------------" \
        "Cannot proceed!${normal}"
        exit 1
    else
        printf "%s\n" \
        "${green}MySQL/MariaDB is installed "\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    fi

    ### Check if database user was passed
    if [[ -z $databaseUser ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - A Database User wasn't passed!"  \
        "----------------------------------------------------" \
        "Script needs a Database User for site." \
        "Running help function and exiting!${normal}" \
        " "

        helpFunction
        exit 1
    fi

    ### Check if welsh IP was passed
    if [[ -z $welshIP ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - A Welsh IP wasn't passed!"  \
        "----------------------------------------------------" \
        "Script needs a Welsh IP for database user" \
        "Running help function and exiting!${normal}" \
        " "

        helpFunction
        exit 1
    fi

    ## Value confirmation
    printf "%s\n" \
    "${yellow}IMPORTANT: Value Confirmation" \
    "----------------------------------------------------" \
    "Database User: " "$databaseUser" \
    "Welsh IP: " "$welshIP" \
    "If all clear, press enter to proceed or ctrl-c to cancel${normal}" \
    " "

    read junkInput

    ## Parse MySQL root password from .mypass
    ### Older CFE mypass
    if [[ $(wc -l /root/.mypass | awk '{print $1}') -eq 1 ]]; then
            databasePass=$(cat /root/.mypass)
    ### Newer Salt mypass
    else
            databasePass=$(grep -i password /root/.mypass | sed -e "s/^Password://")
    fi

    ## Check if user exists
    ### Run query
    #checkQuery=$(mysql -u root -p"$databasePass" -e "SELECT user,host FROM mysql.user WHERE user like \"$databaseUser%\"")
    checkQuery=$(mysql -u root -p"$databasePass" -e "SELECT user,host FROM mysql.user WHERE user like \"$databaseUser\" AND host like \"$welshIP\"")

    ### Check if checkQuery null or not, exit if so
    if [[ $checkQuery ]]; then
        printf "%s\n" \
        "${red}ISSUE DETECTED - User already exists!"  \
        "----------------------------------------------------" \
        "Exiting!${normal}" \
        " "
        exit 1
    else
        printf "%s\n" \
        "${green}User doesn't exist"\
        "----------------------------------------------------" \
        "Proceeding${normal}" \
        " "
    fi

    ## Create user
    ### Generate a user password
    userPass=$(date +%s | sha256sum | base64 | head -c 30)
    userPass+=$(((RANDOM%1000+1)))
    userPass+="!"

    ### Create user
    mysql -u root -p"$databasePass" -e "CREATE USER $databaseUser@$welshIP IDENTIFIED BY \"$userPass\""

    ### Grant user permissions
    mysql -u root -p"$databasePass" -e "GRANT ALL PRIVILEGES ON *.* TO $databaseUser@$welshIP WITH GRANT OPTION"

    ### Flush Privileges
    mysql -u root -p"$databasePass" -e "FLUSH PRIVILEGES"

    ## Log username/password, output to screen
    echo "$(date)" >> /root/newdbuserOutput.log
    echo "Username: $databaseUser" >> /root/newdbuserOutput.log
    echo "Password: $userPass" >> /root/newdbuserOutput.log

    tail -n 3 /root/newdbuserOutput.log

}

# Main, read passed flags
    printf "%s\n" \
    "New DB user" \
    "----------------------------------------------------" \
    " " \
    "Checking flags passed" \
    "----------------------------------------------------"

# Check passed flags
case "$1" in
[Hh]elp)
    printf "%s\n" \
    "Running Help function" \
    "----------------------------------------------------"
    helpFunction
    exit
    ;;
[Cc]reate)
    printf "%s\n" \
    "Running script" \
    "----------------------------------------------------"
    runProgram $2 $3
    ;;
*)
    printf "%s\n" \
    "${red}ISSUE DETECTED - Invalid input detected!" \
    "----------------------------------------------------" \
    "Running help script and exiting." \
    "Re-run script with valid input${normal}"
    helpFunction
    exit
    ;;
esac
