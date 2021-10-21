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
NC='\033[0m\n' # set no color and line end



OPTIONAL_EXTENSIONS=("bk2k/bootstrap-package" "mask/mask" "georgringer/news")
OPTIONAL_EXTENSIONS_INSTALL=()
#
# helper functions
# --------------------------------------
ask_continue () {
    printf "${INPUT}Continue? [y/n]: ${NC}"
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
    select setup_typo3version in 8.7 9.5 10.4; do
        case $setup_typo3version in
            8.7)
               setup_typo3version_minor="8.7";;
            9.5)
               setup_typo3version_minor="9.5";;
            10.4)
               setup_typo3version_minor="10.4";;
            *)
               echo "Invalid option";;
         esac
      return
    done
}

ask_newbasedirectory() {
   printf "${NOTE}Enter new path name (relative to current - ${INPUT}to move up use ../${NOTE}):${NC}"
   read -r -p "${pwd}/" setup_basedirectory
   if ! [[ $setup_basedirectory =~ ^[a-zA-Z_0-9\/\.]+$ ]] ; then
      printf "${WARNING}Please, don't use spaces or special chars!${NC}"
      ask_newbasedirectory
   fi
}

ask_projectname() {
    printf "${INPUT}Set the name of the client or project in lowercase and no spaces.${NC}"
    printf "${INPUT}Project name:${NC}"
    read -r setup_projectname

    if [[ $setup_projectname =~ [A-Z] ]] ; then
        printf "${WARNING}Only use lowercase letters!${NC}"
        ask_projectname
    fi

    if ! [[ $setup_projectname =~ ^[a-z_0-9]+$ ]] ; then
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
    printf "${NOTE}- - - - - - - - -${NC}"
    printf "${NOTE}TYPO3 Version: ${setup_typo3version_minor}${NC}"
    printf "${NOTE}Directory: ${setup_basedirectory}${NC}"
    printf "${NOTE}Project name: ${setup_projectname}${NC}"
    printf "${NOTE}Project namespace: ${setup_namespace}${NC}"
    printf "${NOTE}Port: ${setup_port}${NC}"
    printf "${WARNING}.ddev will be setup in ${pwd}/${setup_basedirectory}${NC}"
    display_optional_extensions
    if [ "$install_pages" = true ] ; then
      echo 'Add few sample pages'
    fi
    ask_continue
    if [[ $ok =~ 0 ]] ; then
        ask_typo3version_options
        ask_newbasedirectory
        ask_projectname
        ask_namespace
        ask_port
        ask_optional_extensions
        ask_pages_install
        ask_confirmsetup
    fi

    return
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
      printf "${NOTE}Install extension $EXTENSION${NC}"
   done
}

# install extensions in OPTIONAL_EXTENSIONS_INSTALL
install_optional_extensions () {
   for EXTENSION in "${OPTIONAL_EXTENSIONS_INSTALL[@]}"
   do
      printf "${NOTE}Installing optional extension: $EXTENSION${NC}${NC}"
      composer req $EXTENSION

      if [[ "$EXTENSION" == "bk2k/bootstrap-package" ]] ; then
         printf "${WARNING}Adding bootstrap template to typoscript!${NC}"
         sed -i "" -e $'1 i\\\n'"@import 'EXT:bootstrap_package/Configuration/TypoScript/constants.typoscript'" packages/sitepackage/Configuration/TypoScript/constants.typoscript
         sed -i "" -e $'1 i\\\n'"@import 'EXT:bootstrap_package/Configuration/TypoScript/setup.typoscript'" packages/sitepackage/Configuration/TypoScript/setup.typoscript
      fi

   done
}

generate_password() {
   printf "${NOTE}- - - - - - - - -${NC}"
   printf "${NOTE}Generating admin password${NC}"
   admin_password=`openssl rand -base64 12`
   printf "${NOTE}- - - - - - - - -${NC}"
   return
}

ask_pages_install () {
    printf "${INPUT}Do you want us to add few (3) sample pages? [y/N] : ${NC}"
    read -r i
    case $i in
        [yY])
            install_pages=true
            return;;
        *)
            install_pages=false
            return;;
    esac
}



#
# init
# --------------------------------------
printf "${NOTE}Preparing to spin up a new ddev environment with 🔐 TYPO3 secure web${NC}"
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
ask_optional_extensions
ask_pages_install
ask_confirmsetup



#
# start to setup .ddev
# --------------------------------------
printf "${SUCCESS}Starting to setup .ddev!${NC}"
printf "${NOTE} - Creating base directory ./${setup_basedirectory} ${NC}"
mkdir -p $setup_basedirectory
cd $setup_basedirectory

printf "${NOTE} - Initializing ddev ${NC}"
ddev config --project-name $setup_projectname
ddev config --project-type php
ddev config --http-port $setup_port
ddev config --docroot public_html --create-docroot
ddev config --project-type typo3




printf "${NOTE} - Setup project directories ${NC}"
touch .editorconfig
touch .gitignore
mkdir .vscode
touch .vscode/extensions.json
mkdir -p typo3_app
cd typo3_app
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


# write Configuration/TypoScript/setup.typoscript
/bin/cat <<EOM > Configuration/TypoScript/setup.typoscript
page = PAGE
page.10 = TEXT
page.10.value = Start ${setup_projectname}
EOM
printf "${SUCCESS} - Configuration/TypoScript/setup.typoscript of base extension created${NC}"


cd ../../
#
# todo
# composer packages for8.7 must be different
# not all packages supported >> test
#
# for 8.7 use:
# composer require "typo3/cms-about:^8.7" "typo3/cms-adminpanel:^8.7" "typo3/cms-backend:^8.7" "typo3/cms-belog:^8.7" "typo3/cms-beuser:^8.7" "typo3/cms-core:^8.7" "typo3/cms-extbase:^8.7" "typo3/cms-extensionmanager:^8.7" "typo3/cms-filelist:^8.7" "typo3/cms-fluid:^8.7" "typo3/cms-fluid-styled-content:^8.7" "typo3/cms-form:^8.7" "typo3/cms-frontend:^8.7" "typo3/cms-impexp:^8.7" "typo3/cms-info:^8.7" "typo3/cms-install:^8.7" "typo3/cms-lowlevel:^8.7" "typo3/cms-opendocs:^8.7" "typo3/cms-recordlist:^8.7" "typo3/cms-recycler:^8.7" "typo3/cms-reports:^8.7" "typo3/cms-rte-ckeditor:^8.7" "typo3/cms-scheduler:^8.7" "typo3/cms-setup:^8.7" "typo3/cms-tstemplate:^8.7" "typo3/cms-viewpage:^8.7"
#
touch composer.json
# write composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/main-composer.json" > composer.json
printf "${SUCCESS} - Main composer.json of the project created${NC}"



printf "${NOTE}Starting composer install${NC}"
printf "${WARNING}This may take a while!${NC}"
printf "${WARNING}Keep calm and have a coffee!${NC}"
composer install
printf "${NOTE}Installing additional extensions${NC}"
composer req fluidtypo3/vhs
composer req teaminmedias-pluswerk/ke_search
if [ "$setup_typo3version_minor" = "10.4" ] ; then
   composer req helhum/typo3-console:^6
else
   composer req helhum/typo3-console:^5
fi


install_optional_extensions

#
# Prepare TYPO3
# --------------------------------------
printf "${NOTE}Preparing TYPO3${NC}"
cd typo3-secure-web
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

cd ../../../
printf "${NOTE}Starting up ddev${NC}"
printf "${WARNING}Docker must be running at this point!${NC}"
cd $setup_basedirectory
ddev start



#
# Install TYPO3
# --------------------------------------
printf "${NOTE}Installing TYPO3${NC}"
# todo:
# only when helhum/typo3-console has been installed
# https://github.com/TYPO3-Console/TYPO3-Console/issues/825#issuecomment-582397880
# helhum:  "typo3 v10 support is planned and will be delivered."
generate_password
ddev exec ./typo3_app/vendor/bin/typo3cms install:setup --no-interaction --admin-user-name admin --admin-password $admin_password --database-user-name db --database-user-password db --site-name ${setup_projectname}
ddev exec ./typo3_app/vendor/bin/typo3cms install:fixfolderstructure

# add template record
ddev exec mysql --user=db --password=db db << EOF
INSERT INTO sys_template (pid, title, sitetitle, root, clear, constants, config) VALUES (1, 'Bootstrap Package', '${setup_projectname}', 1, 3, "@import 'EXT:sitepackage/Configuration/TypoScript/constants.typoscript'", "@import 'EXT:sitepackage/Configuration/TypoScript/setup.typoscript'");
EOF
printf "${SUCCESS}Created typoscript record in sys_template table${NC}"


#
# Activate extensions
# --------------------------------------
printf "${NOTE}Activating extensions${NC}"
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate sitepackage
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate recycler
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate opendocs
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate ke_search
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate scheduler
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate vhs



#
# Add home page to db table:pages
# --------------------------------------
printf "${NOTE}Adding Home page${NC}"
ddev exec mysql --user=db --password=db db << EOF
TRUNCATE pages;
INSERT INTO pages (\`pid\`, \`title\`, \`slug\`, \`doktype\`, \`is_siteroot\`) VALUES ('0', 'Home', '/', '1', '1');
EOF

#
# Optionally add few pages to table:pages
# --------------------------------------
if [ "$install_pages" = true ] ; then
printf "${NOTE}Adding sample pages${NC}"
   if [ "$setup_typo3version_minor" = "8.7" ] ; then
      ddev exec mysql --user=db --password=db db << EOF
      INSERT INTO pages (\`pid\`, \`title\`, \`doktype\`) VALUES ('1', 'About', '1'),('1', 'Page 1', '1'),('1', 'Page 2', '1');
EOF
   else
      ddev exec mysql --user=db --password=db db << EOF
      INSERT INTO pages (\`pid\`, \`title\`, \`slug\`, \`doktype\`) VALUES ('1', 'About', '/about', '1'),('1', 'Page 1', '/page-1', '1'),('1', 'Page 2', '/page-2', '1');
EOF
   fi
fi



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
