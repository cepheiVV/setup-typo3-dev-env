#!/bin/bash

#
# Version 1.1.2
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
YELLOW='\033[1;33m' #yellow
NC='\033[0m\n' # set no color and line end


OPTIONAL_EXTENSIONS=("mask/mask" "georgringer/news")
OPTIONAL_EXTENSIONS_INSTALL=()


# Source the functions file
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/functions.sh"

print_line() {
   printf "${NOTE}—————————————————————${NC}"
}

# This function makes the substitutions more robust
# comes from https://stackoverflow.com/a/40167919
expandVarsStrict(){
  local line lineEscaped
  while IFS= read -r line || [[ -n $line ]]; do
    IFS= read -r -d '' lineEscaped < <(printf %s "$line" | tr '`([$' '\1\2\3\4')
    lineEscaped=${lineEscaped//$'\4'{/\${}
    lineEscaped=${lineEscaped//\"/\\\"}
    eval "printf '%s\n' \"$lineEscaped\"" | tr '\1\2\3\4' '`([$'
  done
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
        # use mask version 9+ for both TYPO3 12 and 13
         sed -i "" 's|^\        "typo3/cms-core\".*|&,\n        "mask\/mask\": \"^9\"|' packages/sitepackage/composer.json
         sed -i "" "s|^\            \'typo3\'.*|&,\n            \'mask\' => \'\'|" packages/sitepackage/ext_emconf.php
         sleep 1
         ddev composer req $EXTENSION:^9 --no-interaction
      elif [ "${EXTENSION}" = "georgringer/news" ] ; then
         # use news version 12+ for both TYPO3 12 and 13
         ddev composer req $EXTENSION:^12 --no-interaction
      else
         ddev composer req $EXTENSION --no-interaction
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
ask_repository_question
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
ddev config --php-version 8.2
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
mkdir -p Resources/Public/RTE


touch composer.json
touch ext_emconf.php
touch ext_tables.php
touch ext_localconf.php
cp "${SCRIPT_DIR}/templates/CustomRte.yaml" Configuration/RTE/CustomRte.yaml
cp "${SCRIPT_DIR}/templates/CustomRte.css" Resources/Public/RTE/CustomRte.css
cp -r "${SCRIPT_DIR}/templates/TsConfig" Configuration/
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
/var/
/vendor/
/config/system/settings.php
/config/system/additional.php

EOM


printf "${SUCCESS} - added .gitignore ${NC}"

touch composer.json
# write composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/main-composer.json" > composer.json
printf "${SUCCESS} - Main composer.json of the project created${NC}"



printf "${NOTE}Starting composer install${NC}"
printf "${WARNING}This may take a while!${NC}"
printf "${WARNING}Keep calm and have a coffee!${NC}"
ddev composer install --no-interaction
printf "${NOTE}Installing additional extensions${NC}"

# Install TYPO3 console v8+ for TYPO3 12/13 compatibility
ddev composer req helhum/typo3-console:^8 --no-interaction

# Install other extensions
ddev composer req tpwd/ke_search:^6 --no-interaction

if [ $install_bootstrap = true ] ; then
   ddev composer req bk2k/bootstrap-package --no-interaction
fi

install_optional_extensions

#
# Prepare TYPO3
# --------------------------------------
printf "${NOTE}Preparing TYPO3${NC}"
mkdir -p config/system
touch config/system/additional.php
/bin/cat <<EOM >config/system/additional.php
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

# Create public directory if it doesn't exist
mkdir -p public
touch public/FIRST_INSTALL

printf "${NOTE}Starting up ddev${NC}"
printf "${WARNING}Docker must be running at this point!${NC}"
cd "${abs_setup_basedirectory}"
ddev start



#
# Install TYPO3
# --------------------------------------
generate_password
printf "${NOTE}Installing TYPO3${NC}"
ddev exec ./vendor/bin/typo3 install:setup --no-interaction --admin-user-name admin --admin-password $admin_password --database-user-name db --database-user-password db --site-name ${setup_projectname}
ddev exec ./vendor/bin/typo3 install:fixfolderstructure

# add template record
ddev exec mysql --user=db --password=db db << EOF
INSERT INTO sys_template (pid, title, root, clear, constants, config) VALUES (1, 'Bootstrap Package', 1, 3, "@import 'EXT:sitepackage/Configuration/TypoScript/constants.typoscript'", "@import 'EXT:sitepackage/Configuration/TypoScript/setup.typoscript'");
EOF

printf "${SUCCESS}Created typoscript record in sys_template table${NC}"


#
# Activate extensions
# --------------------------------------
printf "${NOTE}Activating extensions${NC}"
ddev exec ./vendor/bin/typo3 install:extensionsetupifpossible


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

if [ ! -z $repository_url ] ; then
   printf "${NOTE}Setting up git${NC}"
   git init
   git add .
   git commit -m 'Initial commit'
   git remote add upstream "${repository_url}"
   git push --set-upstream upstream main
fi

#
# final instructions after install
# --------------------------------------
ddev describe
printf "${SUCCESS}Setup complete!${NC}"
printf "${NOTE}Open the ddev URL in a browser${NC}"
printf "${NOTE}Admin user is: admin${NC}"
printf "${NOTE}Admin password is: ${admin_password} ${NC}"

printf "${NOTE}and follow the TYPO3 install process.${NC}"
printf "${SUCCESS}Have fun with your new ddev env!${NC}"
exit 1
