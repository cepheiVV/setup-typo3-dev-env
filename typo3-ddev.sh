#!/bin/bash

# 
# Version 1.1.0
# 

# 
# todo
# --------------------------------------
#  - generate valid composer for TYPO3 8.7
#  - ask for extension vendor and replace all vendor strings
#  - automate the TYPO3 installation, so there's no need for FIRST_INSTALL process
#    with "typo3cms install:setup"
#  - set a backend admin user 
#    with "typo3cmd backend:createadmin"
#  - ask for "path" where ddev should be set up
#  - maybe add basic LocalConfiguration
#    with "typo3cmd configuration:set"
#  - Get Git host/account name, 
#    then init a new GIT repository and 
#    push it to Bitbucket / GitHub or GitLab
#  - naming of domain(s)?
#  - custom name instead of sitepackage_main ?
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



OPTIONAL_EXTENSIONS=("bk2k/bootstrap-package" "t3/dce" "georgringer/news")
OPTIONAL_EXTENSIONS_INSTALL=()
# 
# helper functions
# --------------------------------------
ask_continue () {
    printf "${INPUT}Continue? [Y/N] : ${NC}"
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

ask_typo3version() {
    printf "${INPUT}Set the desired TYPO3 version. 8, 9 or 10${NC}"
    printf "${INPUT}TYPO3 Version:${NC}"
    read -r setup_typo3version
    
    if ! [[ $setup_typo3version =~ ^[0-9]+$ ]] ; then
        printf "${WARNING}Only use numbers!${NC}"
        ask_typo3version
    fi

    if ! [[ $setup_typo3version =~ 8|9|10 ]] ; then
        printf "${WARNING}Invalid TYPO3 version!${NC}"
        ask_typo3version
    fi

    if [ $setup_typo3version == 8 ] ; then
        setup_typo3version_minor="8.7"
    fi

    if [ $setup_typo3version == 9 ] ; then
        setup_typo3version_minor="9.5"
    fi

    if [ $setup_typo3version == 10 ] ; then
        setup_typo3version_minor="10.4"
    fi

    return
}

ask_typo3version_options() {
    PS3="Set the desired TYPO3 version:"
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


ask_basedirectory() {
    printf "${INPUT}Set the name of the directory in which .ddev will be set up.${NC}"
    printf "${INPUT}Directory name:${NC}"
    read -r setup_basedirectory

    if [[ $setup_basedirectory =~ [A-Z] ]] ; then 
        printf "${WARNING}Only use lowercase letters!${NC}"
        ask_basedirectory
    fi

    if ! [[ $setup_basedirectory =~ ^[a-z0-9]+$ ]] ; then
        printf "${WARNING}Don't use spaces or special chars!${NC}"
        ask_basedirectory
    fi
    
    return
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
    printf "${NOTE}Port: ${setup_port}${NC}"
    printf "${WARNING}.ddev will be setup in ${pwd}/${setup_basedirectory}${NC}"
    display_optional_extensions
    if [ "$install_pages" = true ] ; then
      echo 'Add few sample pages'
    fi
    ask_continue
    if [[ $ok =~ 0 ]] ; then
        ask_typo3version_options
        ask_basedirectory
        ask_projectname
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
printf "${NOTE}Spin up a new ddev environment with TYPO3 secure web${NC}"
printf "${INPUT}Make sure to run this script in the directory where .ddev will be located!${NC}"
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
    printf "${NOTE} - Startup docker ${NC}"
    #killall Docker
    open /Applications/Docker.app --background
else 
    printf "${WARNING}${docker_path} not found!${NC}"
    printf "${WARNING}Make sure Docker is installed!${NC}"
    exit 1
fi




# 
# get variables
# --------------------------------------
pwd=$(pwd)
ask_typo3version_options
ask_basedirectory
ask_projectname
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

mkdir -p sitepackage_main
cd sitepackage_main 
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
touch Classes/Hooks/TsTemplateHook.php
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
touch Configuration/TypoScript/setup.typoscript
touch Configuration/TypoScript/Includes/config.typoscript
touch Configuration/TypoScript/Includes/page.typoscript
touch Configuration/TypoScript/Includes/getContent.typoscript
touch Resources/Private/Language/locallang.xlf
touch Resources/Private/Language/locallang_db.xlf
touch Resources/Private/Language/locallang_be.xlf
printf "${SUCCESS} - file structure of sitepackage extension created${NC}"


# write composer.json
/bin/cat <<EOM >composer.json
{
    "name": "itsc/sitepackage_main",
    "type": "typo3-cms-extension",
    "description": "Base extension for project ${setup_projectname}",
    "homepage": "https://sturmundbraem.ch/",
    "license": [
        "GPL-2.0-or-later"
    ],
    "keywords": [
        "TYPO3 CMS"
    ],
    "version": "1.1.0",
    "authors": [
        {
            "name": "Patrick Crausaz",
            "email": "info@its-crausaz.ch",
            "homepage": "https://its-crausaz.ch/"
        }
    ],
    "require": {
        "typo3/cms-core": "^${setup_typo3version_minor}"
    },
    "autoload": {
        "psr-4": {
            "ITSC\\\Sitepackage\\\": "Classes/"
        }
    }
}

EOM
printf "${SUCCESS} - composer.json of base extension created${NC}"



# write ext_emconf.php
/bin/cat <<EOM >ext_emconf.php
<?php
    
    \$EM_CONF[\$_EXTKEY] = [
        'title' => 'Sitepackage Main',
        'description' => 'Base extension for project: ${setup_projectname}',
        'category' => 'templates',
        'constraints' => [
            'depends' => [
                'typo3' => '${setup_typo3version_minor}.0-${setup_typo3version_minor}.99',
                'fluid_styled_content' => '${setup_typo3version_minor}.0-${setup_typo3version_minor}.99',
                'rte_ckeditor' => '${setup_typo3version_minor}.0-${setup_typo3version_minor}.99'
            ]
        ],
        'autoload' => [
            'psr-4' => [
                'ITSC\\\Sitepackage\\\' => 'Classes'
            ],
        ],
        'state' => 'stable',
        'uploadfolder' => 0,
        'createDirs' => '',
        'clearCacheOnLoad' => 1,
        'author' => 'Patrick crausaz',
        'author_email' => 'info@its-crausaz.ch',
        'author_company' => 'ITS Crausaz',
        'version' => '1.1.0',
    ];

EOM
printf "${SUCCESS} - ext_emconf.php of base extension created${NC}"


#write ext_localconf.php
/bin/cat <<EOM >ext_localconf.php
<?php
defined('TYPO3_MODE') || die();

/***************
 * Add default RTE configuration
 */
\$GLOBALS['TYPO3_CONF_VARS']['RTE']['Presets']['sitepackage_main'] = 'EXT:sitepackage_main/Configuration/RTE/Default.yaml';

/******************************
 * Register TypoScript hook
 * for automatic inclusion
 * of our setup & constants.
 ******************************/
\$GLOBALS['TYPO3_CONF_VARS']['SC_OPTIONS']['Core/TypoScript/TemplateService']['runThroughTemplatesPostProcessing'][1501684692] =
    \\ITSC\\Sitepackage\\Hooks\\TsTemplateHook::class . '->addTypoScriptTemplate';

/***************
 * PageTS
 ***************/
\\TYPO3\\CMS\\Core\\Utility\\ExtensionManagementUtility::addPageTSConfig(
    '<INCLUDE_TYPOSCRIPT: source="FILE:EXT:sitepackage_main/Configuration/TsConfig/Page/All.tsconfig">'
);

EOM
printf "${SUCCESS} - ext_localconf.php of base extension created${NC}"


# write Classes/Hooks/TsTemplateHook.php
/bin/cat <<EOM > Classes/Hooks/TsTemplateHook.php
<?php
namespace ITSC\\Sitepackage\\Hooks;

class TsTemplateHook
{

    /**
     * Hooks into TemplateService to add a TS template
     *
     * @param array \$parameters
     * @param \\TYPO3\\CMS\\Core\\TypoScript\\TemplateService \$parentObject
     */
    public function addTypoScriptTemplate(\$parameters, \\TYPO3\\CMS\\Core\\TypoScript\\TemplateService \$parentObject)
    {
        // Read any constants / setup that may have been set via an actual
        // sys_template record. Append those values later to our <INCLUDE_TYPOSCRIPT>
        // These values *override* values that may be set via the extension
        // TypoScript!
        \$constantOverrides = \$parentObject->constants;
        \$setupOverrides = \$parentObject->config;

        // Add a custom, fake 'sys_template' record
        \$row = [
            'uid' => 'templatebootstrap',
            'constants' =>
                '@import "EXT:sitepackage_main/Configuration/TypoScript/constants.typoscript"' . PHP_EOL
                . implode(PHP_EOL, \$constantOverrides) . PHP_EOL,
            'config' =>
                '@import "EXT:sitepackage_main/Configuration/TypoScript/setup.typoscript"' . PHP_EOL
                . implode(PHP_EOL, \$setupOverrides) . PHP_EOL,
            'title' => 'Virtual Sitepackage TS root template'
        ];

        \$parentObject->processTemplate(
            \$row,
            'sys_' . \$row['uid'],
            \$parameters['absoluteRootLine'][0]['uid'],
            'sys_' . \$row['uid']
        );

        // Though \$parentObject->rootId is deprecated (and protected),
        // this needs to be set (as there are no alternatives yet).
        // One of the side-effects, if not set, is that the menu
        // rendering cannot determine the current/active states.
        \$parentObject->rootId = \$parameters['absoluteRootLine'][0]['uid'];
    }
}

EOM
printf "${SUCCESS} - Classes/Hooks/TsTemplateHook.php of base extension created${NC}"


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
/bin/cat <<EOM >composer.json
{
    "name": "itsc/${setup_projectname}",
    "description": "Main configuration for ${setup_projectname} with TYPO3 v${setup_typo3version_minor}",
    "type": "project",
    "repositories": [
        {
            "type": "path",
            "url": "./packages/*",
            "options": {
                "symlink": true
            }
        }
    ],
    "require": {
        "helhum/typo3-secure-web": "^0.2.9",
        "itsc/sitepackage_main": "^1",
        "typo3/cms-about": "^${setup_typo3version_minor}",
        "typo3/cms-adminpanel": "^${setup_typo3version_minor}",
        "typo3/cms-belog": "^${setup_typo3version_minor}",
        "typo3/cms-beuser": "^${setup_typo3version_minor}",
        "typo3/cms-fluid-styled-content": "^${setup_typo3version_minor}",
        "typo3/cms-form": "^${setup_typo3version_minor}",
        "typo3/cms-impexp": "^${setup_typo3version_minor}",
        "typo3/cms-info": "^${setup_typo3version_minor}",
        "typo3/cms-lowlevel": "^${setup_typo3version_minor}",
        "typo3/cms-opendocs": "^${setup_typo3version_minor}",
        "typo3/cms-recycler": "^${setup_typo3version_minor}",
        "typo3/cms-redirects": "^${setup_typo3version_minor}",
        "typo3/cms-reports": "^${setup_typo3version_minor}",
        "typo3/cms-rte-ckeditor": "^${setup_typo3version_minor}",
        "typo3/cms-scheduler": "^${setup_typo3version_minor}",
        "typo3/cms-seo": "^${setup_typo3version_minor}",
        "typo3/cms-setup": "^${setup_typo3version_minor}",
        "typo3/cms-tstemplate": "^${setup_typo3version_minor}",
        "typo3/cms-viewpage": "^${setup_typo3version_minor}"
    },
    "autoload": {
        "psr-4": {
            "ITSC\\\Sitepackage\\\": "packages/sitepackage/Classes/"
        }
    },
    "extra": {
        "typo3/cms": {
            "root-dir": "typo3-secure-web",
            "web-dir": "../public_html"
        }
    },
    "authors": [
        {
            "name": "Patrick Crausaz",
            "email": "crausaz.patrick@gmail.com"
        }
    ]
}

EOM
printf "${SUCCESS} - Main composer.json of the project created${NC}"



printf "${NOTE}Starting composer install${NC}"
printf "${WARNING}This may take a while!${NC}"
printf "${WARNING}Keep calm and have a coffee!${NC}"
composer install
printf "${NOTE}Installing additional extensions${NC}"
composer req fluidtypo3/vhs
composer req teaminmedias-pluswerk/ke_search
if [ "$setup_typo3version_minor" = "10.4" ] ; then
      composer req helhum/typo3-console
   else
      composer req helhum/typo3-console:^5.8.6
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



cd ../../../../
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



#
# Activate extensions
# --------------------------------------
printf "${NOTE}Activating extensions${NC}"
ddev exec ./typo3_app/vendor/bin/typo3cms extension:activate sitepackage_main
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
