#!/bin/bash

#
# Version 1.1.2
#

#
# todo
# --------------------------------------
#  - ask for extension vendor and replace all vendor strings
#  - automate the TYPO3 installation, so there's no need for FIRST_INSTALL process
#    with "typo3cms install:setup"
#  - set a backend admin user
#    with "typo3cmd backend:createadmin"
#  - ask for "path" where ddev should be set up
#  - Get Git host/account name,
#    then init a new GIT repository and
#    push it to Bitbucket / GitHub or GitLab
#  - naming of domain(s)?
#

#
# define colors
# --------------------------------------
# Black        0;30     Dark Gray     1;30
# Red          0;31     Light Red     1;31
# Green        0;32     Light Green   1;32
# Brown/Orange 0;33     Yellow        1;33
# Blue         0;34     Light Blue    1;34
# Purple       0;35     Light Purple  1;35
# Cyan         0;36     Light Cyan    1;36
# Light Gray   0;37     White         1;37
NOTE='\033[0;36m' #cyan
WARNING='\033[1;31m' #red
INPUT='\033[0;35m' #purple
SUCCESS='\033[0;32m' #green
INFO='\033[0;34m' #blue
NC='\033[0m\n' # set no color and line end



OPTIONAL_EXTENSIONS=("mask/mask" "georgringer/news")
OPTIONAL_EXTENSIONS_INSTALL=()


print_line() {
   printf "${NOTE}—————————————————————${NC}"
}

#
# helper functions
# --------------------------------------
ask_continue () {
    printf "${INPUT}Continue? [y/N]: ${NC}"
    read -r i
    case $i in
        [yY])
            ok=1
            return;;
        [nN])
            ok=0
            return;;
        *)
            printf "${WARNING}Invalid Option!${NC}"
            ask_continue
            ;;
    esac
}

# This function makes the substitutions more robust
# comes from https://stackoverflow.com/a/40167919
expandVarsStrict(){
  local line lineEscaped
  while IFS= read -r line || [[ -n $line ]]; do  # the `||` clause ensures that the last line is read even if it doesn't end with \n
    # Escape ALL chars. that could trigger an expansion..
    IFS= read -r -d '' lineEscaped < <(printf %s "$line" | tr '`([$' '\1\2\3\4')
    # ... then selectively reenable ${ references
    lineEscaped=${lineEscaped//$'\4'{/\${}
    # Finally, escape embedded double quotes to preserve them.
    lineEscaped=${lineEscaped//\"/\\\"}
    eval "printf '%s\n' \"$lineEscaped\"" | tr '\1\2\3\4' '`([$'
  done
}

ask_typo3version_options() {
    PS3="Set the desired TYPO3 version: "

    printf "${INPUT}Select typo3 version:${NC}"
    printf "${INPUT}9) 9.5${NC}"
    printf "${INPUT}10) 10.4${NC}"
    printf "${INPUT}11) 11.5${NC}"
    read -r -p "Enter version [11]: " ver
    case $ver in
        9)
            setup_typo3version_minor="9.5";;
        10)
            setup_typo3version_minor="10.4";;
        11)
            setup_typo3version_minor="11.5";;
        *)
            setup_typo3version_minor="11.5";;
    esac
}

ask_newbasedirectory() {
   printf "${NOTE}Enter new path name (relative to current - ${INPUT}to move up use ../${NOTE}):${NC}"
   read -r -p "${pwd}/" setup_basedirectory
   if ! [[ $setup_basedirectory =~ ^[a-zA-Z_0-9\/\.\-]+$ ]] ; then
      printf "${WARNING}Please, don't use spaces or special chars other than '_' or '-' !${NC}"
      ask_newbasedirectory
   fi

   if [ "$(ls -A $setup_basedirectory)" ] ; then
      printf "${WARNING}The target directory ${setup_basedirectory} is not empty! Please select a different path.${NC}"
      ask_newbasedirectory
   fi

   cur_dir="${pwd}/"
   mkdir -p $setup_basedirectory

   abs_setup_basedirectory="$(cd "$(dirname "${cur_dir}/${setup_basedirectory}")"; pwd)/$(basename "${cur_dir}/${setup_basedirectory}")"
   printf "${SUCCESS}Created directory ${abs_setup_basedirectory} !${NC}"
   cd "${cur_dir}"
}

ask_projectname() {
    printf "${INPUT}Set the name of the client or project in lowercase and no spaces.${NC}"
    printf "${INPUT}Project name:${NC}"
    read -r setup_projectname

    if [[ $setup_projectname =~ [A-Z] ]] ; then
        printf "${WARNING}Only use lowercase letters!${NC}"
        ask_projectname
    fi

    if ! [[ $setup_projectname =~ ^[a-z_0-9\-]+$ ]] ; then
        printf "${WARNING}Don't use spaces or special chars other than underscore!${NC}"
        ask_projectname
    fi

    return
}

ask_namespace() {
    printf "${INPUT}Please enter vendor name (used in namespace) of the client or project:${NC}"
    read -r  -p "Enter vendor [ITSC]: " setup_namespace
    setup_namespace=${setup_namespace:-ITSC}

    if ! [[ $setup_namespace =~ ^[a-zA-Z0-9]+$ ]] ; then
        printf "${WARNING}Please, don't use spaces or special characters!${NC}"
        ask_namespace
    fi

    setup_namespace_lowercase=$(tr '[:upper:]' '[:lower:]' <<< $setup_namespace)

    return
}

ask_port() {
    printf "${INPUT}Set the port on which .ddev will be accessed.${NC}"
    printf "${INPUT}Port [8080] : ${NC}"
    read -r setup_port

    # check if empty, then use default port
    if [ -z $setup_port ] ; then
        setup_port="8080"
    fi

    if ! [[ $setup_port =~ ^[0-9]+$ ]] ; then
        printf "${WARNING}Invalid Option!${NC}"
        ask_port
    fi

    return
}

ask_confirmsetup() {
    printf "${NOTE}Your setup is:${NC}"
    print_line
    printf "${NOTE}TYPO3 Version: ${SUCCESS}${setup_typo3version_minor}${NC}"
    printf "${NOTE}Directory for project and ddev: ${SUCCESS}${abs_setup_basedirectory}${NC}"
    printf "${NOTE}Project name: ${SUCCESS}${setup_projectname}${NC}"
    printf "${NOTE}Project namespace: ${SUCCESS}${setup_namespace}${NC}"
    printf "${NOTE}Port: ${SUCCESS}${setup_port}${NC}"

    if [ $install_bootstrap = true ] ; then
      printf "${NOTE}Install extension bk2k/bootstrap-package: ✅${NC}"
    fi
    display_optional_extensions
    printf "${NOTE}We will add few sample pages: ✅${NC}"
    print_line
    ask_continue
    if [[ $ok =~ 0 ]] ; then
        ask_typo3version_options
        ask_newbasedirectory
        ask_projectname
        ask_namespace
        ask_port
        ask_bootstrap_question
        ask_optional_extensions
        ask_confirmsetup
    fi

    return
}

ask_bootstrap_question () {
   printf "${INPUT}Do you want to install bk2k/bootstrap-package package? [y/N] : ${NC}"
    read -r i
    case $i in
        [yY])
            install_bootstrap=true
            return;;
        *)
            install_bootstrap=false
            return;;
    esac
}

# iterating over OPTIONAL_EXTENSIONS and
# assigning to OPTIONAL_EXTENSIONS_INSTALL array
ask_optional_extensions () {
   for EXTENSION in "${OPTIONAL_EXTENSIONS[@]}"
   do
      ask_optional_extension $EXTENSION
   done
}


ask_optional_extension () {
    printf "${INPUT}Do you want to install $1 package? [y/N] : ${NC}"
    read -r i
    case $i in
        [yY])
            OPTIONAL_EXTENSIONS_INSTALL+=($1)
            return;;
        *)
            return;;
    esac
}

# display only for confirmation
display_optional_extensions () {
   for EXTENSION in "${OPTIONAL_EXTENSIONS_INSTALL[@]}"
   do
      printf "${NOTE}Install extension $EXTENSION: ✅${NC}"
   done
}

# install extensions in OPTIONAL_EXTENSIONS_INSTALL
install_optional_extensions () {
   for EXTENSION in "${OPTIONAL_EXTENSIONS_INSTALL[@]}"
   do
      printf "${NOTE}Installing optional extension: $EXTENSION${NC}${NC}"

      if [ "${EXTENSION}" = "mask/mask" ] ; then
         if [ "${setup_typo3version_minor}" = "9.5" ] ; then
            ddev composer req $EXTENSION:^4
         else
            ddev composer req $EXTENSION
         fi
      elif [ "${EXTENSION}" = "georgringer/news" ] ; then
         if [ "${setup_typo3version_minor}" = "9.5" ] ; then
            ddev composer req $EXTENSION:^8
         else
            ddev composer req $EXTENSION
         fi
      else
         ddev composer req $EXTENSION
      fi
   done
}

generate_password() {
   print_line
   printf "${NOTE}Generating admin password${NC}"
   admin_password=`openssl rand -base64 12`
   printf "${NOTE}Password generated 🔐${NC}"
   print_line
   return
}


#
# init
# --------------------------------------
printf "${NOTE}Preparing to spin up a new TYPO3 website with ddev and 🔐 typo3-secure-web${NC}"
printf "${NOTE}We will ask you a series of questions about your project,${NC}"
printf "${NOTE}prepare a config, and launch it.${NC}"
ask_continue
if [[ $ok =~ 0 ]] ; then
    printf "${WARNING}exit!${NC}"
    exit 1
fi

# check if .ddev is installed before starting this process
if command -v ddev &> /dev/null ; then
  printf "${SUCCESS}ddev found${NC}"
else
  printf "${WARNING}No ddev installed!${NC}"
  exit 1
fi

# check if /Applications/Docker.app exists before starting this process
docker_path="/Applications/Docker.app"
if [ -d $docker_path ]; then
    printf "${SUCCESS}Docker found${NC}"
    # Start docker app
    if ! docker info > /dev/null 2>&1; then
      printf "${NOTE} - Startup docker ${NC}"
      open /Applications/Docker.app --background
    fi
else
    printf "${WARNING}${docker_path} not found!${NC}"
    printf "${WARNING}Make sure Docker is installed!${NC}"
    exit 1
fi



#
# get variables
# --------------------------------------
pwd=$(pwd)
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ask_typo3version_options
ask_newbasedirectory
ask_projectname
ask_namespace
ask_port
ask_bootstrap_question
ask_optional_extensions
ask_confirmsetup



#
# start to setup .ddev
# --------------------------------------
printf "${SUCCESS}Starting to setup .ddev!${NC}"
printf "${NOTE} - Switching to base directory ./${abs_setup_basedirectory} ${NC}"
cd "${abs_setup_basedirectory}"

printf "${NOTE} - Initializing ddev ${NC}"
ddev config --project-name $setup_projectname
ddev config --project-type php
ddev config --http-port $setup_port
ddev config --docroot public --create-docroot
ddev config --project-type typo3
ddev config --php-version 7.4
ddev config --web-environment="TYPO3_CONTEXT=Development/Local"


printf "${NOTE} - Setup project directories ${NC}"
touch .editorconfig
touch .gitignore
mkdir .vscode
touch .vscode/extensions.json
mkdir -p packages
cd packages
printf "${SUCCESS} - base file structure created${NC}"

mkdir -p sitepackage
cd sitepackage
mkdir -p Classes
mkdir -p Classes/Hooks
mkdir -p Classes/ViewHelpers
mkdir -p Configuration
mkdir -p Configuration/TCA
mkdir -p Configuration/TCA/Overrides
mkdir -p Configuration/RTE
mkdir -p Configuration/TsConfig
mkdir -p Configuration/TsConfig/Page
mkdir -p Configuration/TsConfig/Page/Mod
mkdir -p Configuration/TsConfig/Page/Mod/WebLayouts
mkdir -p Configuration/TsConfig/Page/Mod/WebLayouts/BackendLayouts
mkdir -p Configuration/TsConfig/Page/Mod/Wizards
mkdir -p Configuration/TsConfig/User
mkdir -p Configuration/TypoScript
mkdir -p Configuration/TypoScript/Extensions
mkdir -p Configuration/TypoScript/Extensions/FluidStyledContent
mkdir -p Configuration/TypoScript/Extensions/KeSearch
mkdir -p Configuration/TypoScript/Includes
mkdir -p Resources
mkdir -p Resources/Private
mkdir -p Resources/Private/Templates
mkdir -p Resources/Private/Partials
mkdir -p Resources/Private/Layouts
mkdir -p Resources/Private/Language
mkdir -p Resources/Private/Extensions
mkdir -p Resources/Public
mkdir -p Resources/Public/dist
mkdir -p Resources/Public/Icons
mkdir -p Resources/Public/JavaScript

touch composer.json
touch ext_emconf.php
touch ext_tables.php
touch ext_localconf.php
touch Configuration/RTE/Default.yaml
touch Configuration/TsConfig/Page/Mod/WebLayouts/BackendLayouts.tsconfig
touch Configuration/TsConfig/Page/All.tsconfig
touch Configuration/TsConfig/Page/options.tsconfig
touch Configuration/TsConfig/Page/TCAdefaults.tsconfig
touch Configuration/TsConfig/Page/TCEFORM.tsconfig
touch Configuration/TsConfig/Page/TCEMAIN.tsconfig
touch Configuration/TsConfig/User/admins.tsconfig
touch Configuration/TsConfig/User/editors.tsconfig
touch Configuration/TsConfig/User/everyone.tsconfig
touch Configuration/TypoScript/constants.typoscript
echo -en '\n' > Configuration/TypoScript/constants.typoscript
touch Configuration/TypoScript/setup.typoscript
echo -en '\n' > Configuration/TypoScript/setup.typoscript
touch Configuration/TypoScript/Includes/config.typoscript
touch Configuration/TypoScript/Includes/page.typoscript
touch Configuration/TypoScript/Includes/getContent.typoscript
touch Resources/Private/Language/locallang.xlf
touch Resources/Private/Language/locallang_db.xlf
touch Resources/Private/Language/locallang_be.xlf
printf "${SUCCESS} - file structure of sitepackage extension created${NC}"


# write composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/composer.json" > composer.json
printf "${SUCCESS} - composer.json of base extension created${NC}"


# write ext_emconf.php
expandVarsStrict< "${SCRIPT_DIR}/templates/ext_emconf.php.txt" > ext_emconf.php
printf "${SUCCESS} - ext_emconf.php of base extension created${NC}"


#write ext_localconf.php
expandVarsStrict< "${SCRIPT_DIR}/templates/ext_localconf.php.txt" > ext_localconf.php
printf "${SUCCESS} - ext_localconf.php of base extension created${NC}"

#write typoscript templates
printf "${SUCCESS} - Adding typoscript templates${NC}"
if [ $install_bootstrap = true ] ; then
   sed -i "" -e $'1 i\\\n'"@import 'EXT:bootstrap_package/Configuration/TypoScript/constants.typoscript'" Configuration/TypoScript/constants.typoscript
   expandVarsStrict< "${SCRIPT_DIR}/templates/setup.bootstrap.typoscript" > Configuration/TypoScript/setup.typoscript
else
   expandVarsStrict< "${SCRIPT_DIR}/templates/setup.sitepackage.typoscript" > Configuration/TypoScript/setup.typoscript
fi
printf "${SUCCESS} - Configuration/TypoScript/setup.typoscript of base extension created${NC}"

cp "${SCRIPT_DIR}/templates/editorconfig"  "${abs_setup_basedirectory}/.editorconfig"
printf "${SUCCESS} - added .editorconfig ${NC}"

cd "${abs_setup_basedirectory}"

/bin/cat <<EOM >.gitignore

node_modules
npm-debug.log
.DS_Store
.vscode/*
.idea

# TYPO3
ENABLE_INSTALL_TOOL
_processed_
uploads/*
!/public/*
/public/index.php
/public/typo3
/public/typo3conf
/public/fileadmin
/public/typo3temp
/private/index.php
/private/typo3conf/ext
/private/typo3
/private/typo3temp
/private/fileadmin
/var/
/vendor/

EOM


printf "${SUCCESS} - added .gitignore ${NC}"

touch composer.json
# write composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/main-composer.json" > composer.json
printf "${SUCCESS} - Main composer.json of the project created${NC}"



printf "${NOTE}Starting composer install${NC}"
printf "${WARNING}This may take a while!${NC}"
printf "${WARNING}Keep calm and have a coffee!${NC}"
ddev composer install
printf "${NOTE}Installing additional extensions${NC}"



if [ "${setup_typo3version_minor}" = "11.5" ] ; then
   ddev composer req helhum/typo3-console
   ddev composer req tpwd/ke_search
   printf "${NOTICE} We cannot install fluidtypo3/vhs${NC}"
   printf "${NOTICE} as there are no compatible versions yet${NC}"
elif [ "${setup_typo3version_minor}" = "10.4" ] ; then
   # we need to specify typo3-console version
   ddev composer req helhum/typo3-console:^6
   ddev composer req fluidtypo3/vhs
   ddev composer req tpwd/ke_search
else
   # we need to specify typo3-console version
   ddev composer req helhum/typo3-console:^5
   ddev composer req fluidtypo3/vhs
   ddev composer req tpwd/ke_search:^4
fi

if [ $install_bootstrap = true ] ; then
   if [ "${setup_typo3version_minor}" = "9.5" ] ; then
      ddev composer req bk2k/bootstrap-package:^11
   else
      ddev composer req bk2k/bootstrap-package
   fi
fi

install_optional_extensions

#
# Prepare TYPO3
# --------------------------------------
printf "${NOTE}Preparing TYPO3${NC}"
cd private
touch FIRST_INSTALL
cd typo3conf
touch AdditionalConfiguration.php
/bin/cat <<EOM >AdditionalConfiguration.php
<?php

    \$GLOBALS['TYPO3_CONF_VARS']['SYS']['trustedHostsPattern'] = '.*';
    \$GLOBALS['TYPO3_CONF_VARS']['DB']['Connections']['Default'] = [
        'dbname' => 'db',
        'host' => 'db',
        'password' => 'db',
        'port' => '3306',
        'user' => 'db',
        'driver' => 'mysqli',
        'charset' => 'utf8mb4',
        'tableoptions' => [
            'charset' => 'utf8mb4',
            'collate' => 'utf8mb4_unicode_ci',
         ],
    ];

    // This mail configuration sends all emails to mailhog
    \$GLOBALS['TYPO3_CONF_VARS']['MAIL']['transport'] = 'smtp';
    \$GLOBALS['TYPO3_CONF_VARS']['MAIL']['transport_smtp_server'] = 'localhost:1025';

    \$GLOBALS['TYPO3_CONF_VARS']['SYS']['devIPmask'] = '*';
    \$GLOBALS['TYPO3_CONF_VARS']['SYS']['displayErrors'] = 1;

EOM

printf "${NOTE}Starting up ddev${NC}"
printf "${WARNING}Docker must be running at this point!${NC}"
cd "${abs_setup_basedirectory}"
ddev start



#
# Install TYPO3
# --------------------------------------
generate_password
printf "${NOTE}Installing TYPO3${NC}"
ddev exec ./vendor/bin/typo3cms install:setup --no-interaction --admin-user-name admin --admin-password $admin_password --database-user-name db --database-user-password db --site-name ${setup_projectname}
ddev exec ./vendor/bin/typo3cms install:fixfolderstructure

# add template record

ddev exec mysql --user=db --password=db db << EOF
INSERT INTO sys_template (pid, title, root, clear, constants, config) VALUES (1, 'Bootstrap Package', 1, 3, "@import 'EXT:sitepackage/Configuration/TypoScript/constants.typoscript'", "@import 'EXT:sitepackage/Configuration/TypoScript/setup.typoscript'");
EOF

printf "${SUCCESS}Created typoscript record in sys_template table${NC}"


#
# Activate extensions
# --------------------------------------
printf "${NOTE}Activating extensions${NC}"
#ddev exec ./vendor/bin/typo3cms install:generatepackagestates
ddev exec ./vendor/bin/typo3cms install:extensionsetupifpossible


#
# Add home page to db table:pages
# --------------------------------------
printf "${NOTE}Adding sample pages${NC}"
ddev exec mysql --user=db --password=db db << EOF
TRUNCATE pages;
INSERT INTO pages (\`pid\`, \`title\`, \`slug\`, \`doktype\`, \`is_siteroot\`) VALUES ('0', 'Home', '/', '1', '1'),('1', 'About', '/about', '1', '0'),('1', 'Page 1', '/page-1', '1', '0'),('1', 'Page 2', '/page-2', '1', '0');
EOF

if [ $install_bootstrap = true ] ; then

ddev exec mysql --user=db --password=db db << EOF
UPDATE pages
SET backend_layout = "pagets__default", backend_layout_next_level = "pagets__2_columns"
WHERE uid = 1;
EOF
printf "${NOTE}Updated layout fields for sample pages${NC}"
fi

mkdir -p "${abs_setup_basedirectory}/config/sites/${setup_projectname}"
expandVarsStrict< "${SCRIPT_DIR}/templates/siteConfiguration.yaml" >  "${abs_setup_basedirectory}/config/sites/${setup_projectname}/config.yaml"
printf "${NOTE}Created site configuration${NC}"


#
# final instructions after install
# --------------------------------------
ddev describe
printf "${SUCCESS}Setup complete!${NC}"
printf "${NOTE}Open the ddev URL in a browser${NC}"
printf "${NOTE}Admin user is: admin${NC}"
printf "${NOTE}Admin password is: $admin_password ${NC}"

printf "${NOTE}and follow the TYPO3 install process.${NC}"
printf "${SUCCESS}Have fun with your new ddev env!${NC}"
exit 1
