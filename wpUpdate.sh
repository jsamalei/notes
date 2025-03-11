#!/usr/bin/bash

# wpUpdate.sh by Nicholas Grogg
# A BASH script for updating WordPress sites
# Takes a filepath as an argument, has built in checks

# Variables
filePath=$1
quiet=$2
# Help
if [[ $1 == "help" || $1 == "Help" ]]; then
    echo "Help"
    echo "-----------------------------------------------"
    echo "Script to update WordPress sites"
    echo "Takes a filepath as an argument"
    echo "Usage: wpUpdate.sh Webroot"
    echo "Ex. bash wpUpdate.sh /var/www/html"
    exit
fi

# Checks
## Check if filePath passed
if [[ -z $filePath ]]; then
    echo "ISSUE DETECTED - FILEPATH NULL"
    echo "-----------------------------------------------"
    echo "Please provide a filepath to the site's doc root"
    read filePath
fi

## Fail state for filepath
if [[ -z $filePath ]]; then
    echo "ISSUE DETECTED - FILEPATH NULL"
    echo "-----------------------------------------------"
    echo "filePath still null, exiting!"
    exit 1
fi

## Prompt user for snapshots and run through checks IF quiet null
if [[ -z $quiet ]]; then
    echo "Pre-flight checks"
    echo "-----------------------------------------------"
    ### Check if snapshots were taken
    echo "Were snapshots taken of the web/database servers?"
    echo "Press enter once snapshots are taken to proceed"
    read junkInput

    ### Check if wp-cli installed
    echo "Checking if wp-cli installed"
    echo "-----------------------------------------------"
    ### If filepath doesn't exist
    if [[ ! -f "/usr/bin/wp" ]]; then
        echo "wp-cli not installed, installing"
        echo "-----------------------------------------------"
        #### Install wp-cli if it's not
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

        #### Make wp-cli executable
        sudo chmod +x wp-cli.phar

        #### Move executable to path so it can be used with 'wp'
        sudo mv wp-cli.phar /usr/bin/wp
    else
        echo "wp-cli installed, checking for updates"
        echo "-----------------------------------------------"

        #### Get current version of wp-cli
        currentVersion=$(wp --version --allow-root | grep 'WP-CLI' | awk '{print $2}')

        #### Get latest version of wp-cli
        latestVersion=$(curl --silent "https://api.github.com/repos/wp-cli/wp-cli/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

        if [[ "$currentVersion" != "$latestVersion" ]]; then
                echo "Updating wp-cli"
            echo "-----------------------------------------------"
                sudo wp cli update --allow-root
        else
                echo "wp-cli up to date, moving on"
            echo "-----------------------------------------------"
        fi
    fi

    ### Check if user part of 'webdev' group
    echo "Checking if user in group 'webdev'"
    echo "-----------------------------------------------"
    if [[ "$EUID" -eq 0 ]]; then
        echo "User is root, not adding to webdev"
        echo "-----------------------------------------------"
    # Yes it looks "off" without brackets, this does not work with brackets!
    elif id -nG $(whoami) | grep -qw 'webdev'; then
        #### User already in webdev group
        echo "User $(whoami) in group webdev, moving on"
        echo "-----------------------------------------------"
    else
        #### Add user to webdev group if not
        echo "User $(whoami) NOT in group webdev, adding"
        echo "-----------------------------------------------"
        sudo usermod -a -G webdev $(whoami)
    fi

else
    echo "Quiet mode enabled, skipping checks"
    echo "-----------------------------------------------"
fi

# Update site
echo "Updating site"
echo "-----------------------------------------------"

## Loosen file ownership based on package manager
if [[ -f "/usr/bin/apt" ]]; then
    sudo chown www-data -R $filePath/wp-content
    sudo chmod 775 -R $filePath/wp-content
    sudo chown www-data -R $filePath/wp-admin
    sudo chmod 775 -R $filePath/wp-admin
    sudo chown www-data -R $filePath/wp-includes
    sudo chmod 775 -R $filePath/wp-includes
elif [[ -f "/usr/bin/yum" ]]; then
    sudo chown apache -R $filePath/wp-content
    sudo chmod 775 -R $filePath/wp-content
    sudo chown apache -R $filePath/wp-admin
    sudo chmod 775 -R $filePath/wp-admin
    sudo chown apache -R $filePath/wp-includes
    sudo chmod 775 -R $filePath/wp-includes
## It should not be possible to reach this message and may suggest a serious issue
else
    echo "apt/yum not found, check server"
    echo "Please submit a bug report here: https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    exit 1
fi

## Update site
echo "Updating plugins"
echo "-----------------------------------------------"

### If user is root
if [[ "$EUID" -eq 0 ]]; then
    /usr/bin/wp --path=$filePath plugin update --all --allow-root
### Else run as normal user
else
    /usr/bin/wp --path=$filePath plugin update --all
fi

echo "Updating themes"
echo "-----------------------------------------------"
### If user is root
if [[ "$EUID" -eq 0 ]]; then
    /usr/bin/wp --path=$filePath theme update --all --allow-root
### Else run as normal user
else
    /usr/bin/wp --path=$filePath theme update --all
fi

echo "Updating core"
echo "-----------------------------------------------"
### If user is root
if [[ "$EUID" -eq 0 ]]; then
    /usr/bin/wp --path=$filePath core update --allow-root
### Else run as normal user
else
    /usr/bin/wp --path=$filePath core update
fi

## Tighten permissions, account for both apache perms scripts or nginx
### If the old one only exists, use it
if [[ -f "/root/scripts/apache_perms.sh" && ! -f "/root/scripts/apache-perms.sh" ]]; then
    sudo /root/scripts/apache_perms.sh $filePath
### Else If the new one only exists, use it
elif [[ -f "/root/scripts/apache-perms.sh" && ! -f "/root/scripts/apache_perms.sh" ]]; then
    sudo /root/scripts/apache-perms.sh $filePath
### Else If both exist, use the new one
elif [[ -f "/root/scripts/apache-perms.sh" && -f "/root/scripts/apache_perms.sh" ]]; then
    sudo /root/scripts/apache-perms.sh $filePath
### Else If nginx one exists use it
elif [[ -f "/root/scripts/nginx_perms.sh" ]]; then
    sudo /root/scripts/nginx_perms.sh $filePath
### Else tell user to review perms manually
else
    echo "Perms script not found, review perms manually"
fi
