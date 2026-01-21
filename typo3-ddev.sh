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
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Box drawing characters
BOX_TL='╭'
BOX_TR='╮'
BOX_BL='╰'
BOX_BR='╯'
BOX_H='─'
BOX_V='│'

OPTIONAL_EXTENSIONS=("mask/mask" "georgringer/news" "praetorius/vite-asset-collector")
OPTIONAL_EXTENSIONS_INSTALL=()


# Source the functions file
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/functions.sh"

# Visual helper functions
print_line() {
   printf "${DIM}────────────────────────────────────────────────${RESET}\n"
}

print_banner() {
   clear
   printf "\n"
   printf "${NOTE}  ╭─────────────────────────────────────────────╮${RESET}\n"
   printf "${NOTE}  │                                             │${RESET}\n"
   printf "${NOTE}  │${RESET}${BOLD}     TYPO3 + DDEV Project Setup Wizard      ${RESET}${NOTE}│${RESET}\n"
   printf "${NOTE}  │                                             │${RESET}\n"
   printf "${NOTE}  │${RESET}${DIM}             Quick & easy setup               ${RESET}${NOTE}│${RESET}\n"
   printf "${NOTE}  │                                             │${RESET}\n"
   printf "${NOTE}  ╰─────────────────────────────────────────────╯${RESET}\n"
   printf "\n"
}

print_step() {
   local step=$1
   local total=$2
   local title=$3
   printf "\n"
   printf "${YELLOW}  ▶ Step ${step}/${total}: ${title}${RESET}\n"
   print_line
}

print_substep() {
   local msg=$1
   printf "${DIM}    ├─${RESET} ${msg}\n"
}

print_substep_done() {
   local msg=$1
   printf "${SUCCESS}    ✓${RESET} ${msg}\n"
}

print_success_box() {
   local title=$1
   printf "\n"
   printf "${SUCCESS}  ╭─────────────────────────────────────────────╮${RESET}\n"
   printf "${SUCCESS}  │${RESET}${BOLD}  ✓ ${title}${RESET}\n"
   printf "${SUCCESS}  ╰─────────────────────────────────────────────╯${RESET}\n"
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
      printf "${NOTE}  │${RESET}  ${SUCCESS}✓${RESET} ${EXTENSION}\n"
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
      elif [ "${EXTENSION}" = "praetorius/vite-asset-collector" ] ; then
         ddev composer req $EXTENSION --no-interaction
         ddev add-on get s2b/ddev-vite-sidecar
         ddev restart
      else
         ddev composer req $EXTENSION --no-interaction
      fi
   done
}

generate_password() {
   # TYPO3 13 password policy requires: min 8 chars, uppercase, lowercase, digit, special char
   # Generate password with guaranteed character types (macOS compatible)
   local upper=$(openssl rand -base64 32 | tr -dc 'A-Z' | head -c 2)
   local lower=$(openssl rand -base64 32 | tr -dc 'a-z' | head -c 4)
   local num=$(openssl rand -base64 32 | tr -dc '0-9' | head -c 2)
   local spec='#!'
   # Combine in fixed pattern: Uppercase + lowercase + digits + special
   admin_password="${upper}${lower}${num}${spec}"
   return
}


#
# init
# --------------------------------------
print_banner

printf "  ${DIM}We'll guide you through setting up a new TYPO3 project.${RESET}\n"
printf "  ${DIM}You'll be asked a series of questions about your project.${RESET}\n\n"

ask_continue
if [[ $ok =~ 0 ]] ; then
    printf "\n${WARNING}  Setup cancelled.${RESET}\n"
    exit 1
fi

# System checks
printf "\n${BOLD}  Checking requirements...${RESET}\n"

# check if .ddev is installed before starting this process
if command -v ddev &> /dev/null ; then
  printf "${SUCCESS}    ✓ ddev found${RESET}\n"
else
  printf "${WARNING}    ✗ ddev not found!${RESET}\n"
  printf "${DIM}      Please install ddev first: https://ddev.readthedocs.io/en/stable/${RESET}\n"
  exit 1
fi

# check if docker CLI is available
if ! command -v docker &> /dev/null; then
    printf "${WARNING}    ✗ Docker CLI not found!${RESET}\n"
    printf "${DIM}      Please install Docker Desktop, OrbStack, Colima, or another Docker-compatible runtime.${RESET}\n"
    exit 1
fi

# check if docker daemon is running, if not try to start a compatible runtime
if ! docker info > /dev/null 2>&1; then
    printf "${YELLOW}    ⏳ Docker daemon not running, attempting to start...${RESET}\n"

    # Try to find and start a container runtime (in order of preference)
    started=false

    if [ -d "/Applications/OrbStack.app" ]; then
        printf "${DIM}       Starting OrbStack...${RESET}\n"
        open -a OrbStack --background
        started=true
    elif [ -d "/Applications/Docker.app" ]; then
        printf "${DIM}       Starting Docker Desktop...${RESET}\n"
        open -a Docker --background
        started=true
    elif command -v colima &> /dev/null; then
        printf "${DIM}       Starting Colima...${RESET}\n"
        colima start &> /dev/null &
        started=true
    elif [ -d "/Applications/Rancher Desktop.app" ]; then
        printf "${DIM}       Starting Rancher Desktop...${RESET}\n"
        open -a "Rancher Desktop" --background
        started=true
    fi

    if [ "$started" = true ]; then
        # Wait for docker daemon to become available (max 60 seconds)
        counter=0
        while ! docker info > /dev/null 2>&1; do
            sleep 2
            counter=$((counter + 1))
            if [ $counter -gt 30 ]; then
                printf "${WARNING}    ✗ Timeout waiting for Docker daemon!${RESET}\n"
                exit 1
            fi
        done
        printf "${SUCCESS}    ✓ Docker daemon started${RESET}\n"
    else
        printf "${WARNING}    ✗ No supported container runtime found!${RESET}\n"
        printf "${DIM}      Please install Docker Desktop, OrbStack, Colima, or Rancher Desktop.${RESET}\n"
        exit 1
    fi
else
    printf "${SUCCESS}    ✓ Docker daemon running${RESET}\n"
fi


#
# get variables
# --------------------------------------
print_step 1 5 "Project Configuration"
printf "\n"

pwd=$(pwd)
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ask_repository_question
ask_typo3version_options
ask_newbasedirectory
ask_projectname
ask_namespace
ask_port
printf "\n  ${BOLD}Optional Extensions${RESET}\n"
ask_bootstrap_question
ask_optional_extensions
ask_phpmyadmin_question
ask_confirmsetup



#
# start to setup .ddev
# --------------------------------------
print_step 2 5 "Setting up DDEV"

cd "${abs_setup_basedirectory}"
print_substep "Configuring ddev..."
ddev config --project-name $setup_projectname >/dev/null 2>&1
ddev config --project-type php >/dev/null 2>&1
ddev config --router-http-port $setup_port >/dev/null 2>&1
ddev config --docroot public >/dev/null 2>&1
ddev config --project-type typo3 >/dev/null 2>&1
if [ "$setup_typo3version_minor" = "13.4" ] ; then
   ddev config --php-version 8.3 >/dev/null 2>&1
   ddev config --database=mariadb:11.4 >/dev/null 2>&1
else
   ddev config --php-version 8.2 >/dev/null 2>&1
fi
ddev config --web-environment="TYPO3_CONTEXT=Development/Local" >/dev/null 2>&1
print_substep_done "DDEV configured"

print_substep "Creating project structure..."
touch .editorconfig
touch .gitignore
mkdir -p .vscode
touch .vscode/extensions.json
mkdir -p packages/sitepackage
cd packages/sitepackage
mkdir -p Classes/{Hooks,ViewHelpers}
mkdir -p Configuration/{TCA/Overrides,RTE,TypoScript/{Extensions/{FluidStyledContent,KeSearch},Includes}}
mkdir -p Resources/Private/{Templates,Partials,Layouts,Language,Extensions}
mkdir -p Resources/Public/{dist,Icons,JavaScript,RTE}

touch composer.json ext_emconf.php ext_tables.php ext_localconf.php
cp "${SCRIPT_DIR}/templates/CustomRte.yaml" Configuration/RTE/CustomRte.yaml
cp "${SCRIPT_DIR}/templates/CustomRte.css" Resources/Public/RTE/CustomRte.css
cp -r "${SCRIPT_DIR}/templates/TsConfig" Configuration/
cp "${SCRIPT_DIR}/templates/TsConfig/page.tsconfig" Configuration/page.tsconfig
cp "${SCRIPT_DIR}/templates/TsConfig/user.tsconfig" Configuration/user.tsconfig
echo -en '\n' > Configuration/TypoScript/constants.typoscript
echo -en '\n' > Configuration/TypoScript/setup.typoscript
touch Configuration/TypoScript/Includes/{config,page,getContent}.typoscript
touch Resources/Private/Language/{locallang,locallang_db,locallang_be}.xlf
print_substep_done "Project structure created"

print_substep "Creating sitepackage extension..."
expandVarsStrict< "${SCRIPT_DIR}/templates/composer.json" > composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/ext_emconf.php.txt" > ext_emconf.php
expandVarsStrict< "${SCRIPT_DIR}/templates/ext_localconf.php.txt" > ext_localconf.php

if [ $install_bootstrap = true ] ; then
   sed -i "" -e $'1 i\\\n'"@import 'EXT:bootstrap_package/Configuration/TypoScript/constants.typoscript'" Configuration/TypoScript/constants.typoscript
   expandVarsStrict< "${SCRIPT_DIR}/templates/setup.bootstrap.typoscript" > Configuration/TypoScript/setup.typoscript
else
   expandVarsStrict< "${SCRIPT_DIR}/templates/setup.sitepackage.typoscript" > Configuration/TypoScript/setup.typoscript
fi
print_substep_done "Sitepackage extension created"

cp "${SCRIPT_DIR}/templates/editorconfig"  "${abs_setup_basedirectory}/.editorconfig"

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
/config/system/private.php

EOM

touch composer.json
expandVarsStrict< "${SCRIPT_DIR}/templates/main-composer.json" > composer.json
print_substep_done "Project files created"

print_step 3 5 "Installing Dependencies"
printf "\n"
printf "    ${DIM}This may take a few minutes... ☕${RESET}\n\n"

ddev composer install --no-interaction
print_substep_done "Core dependencies installed"

print_substep "Installing TYPO3 extensions..."
ddev composer req helhum/typo3-console:^8 --no-interaction >/dev/null 2>&1
if [ "$setup_typo3version_minor" = "13.4" ] ; then
   ddev composer req tpwd/ke_search:^7 --no-interaction >/dev/null 2>&1
else
   ddev composer req tpwd/ke_search:^6 --no-interaction >/dev/null 2>&1
fi

if [ $install_bootstrap = true ] ; then
   ddev composer req bk2k/bootstrap-package --no-interaction >/dev/null 2>&1
fi

install_optional_extensions
print_substep_done "Extensions installed"

print_substep "Creating configuration files..."
mkdir -p config/system
expandVarsStrict< "${SCRIPT_DIR}/templates/additional.php.txt" > config/system/additional.php
expandVarsStrict< "${SCRIPT_DIR}/templates/private.example.php.txt" > config/system/private.example.php
cp config/system/private.example.php config/system/private.php
print_substep_done "Configuration files created"

mkdir -p public
touch public/FIRST_INSTALL

print_step 4 5 "Starting DDEV Environment"

cd "${abs_setup_basedirectory}"
print_substep "Starting containers..."
ddev start

if [ $install_phpmyadmin = true ] ; then
   print_substep "Installing phpMyAdmin add-on..."
   ddev add-on get ddev/ddev-phpmyadmin >/dev/null 2>&1
   ddev restart >/dev/null 2>&1
fi
print_substep_done "DDEV environment ready"

print_step 5 5 "Installing TYPO3"

generate_password
print_substep "Running TYPO3 setup..."
ddev exec ./vendor/bin/typo3 setup \
  --driver=mysqli \
  --host=db \
  --port=3306 \
  --dbname=db \
  --username=db \
  --password=db \
  --admin-username=admin \
  --admin-user-password="${admin_password}" \
  --project-name="${setup_projectname}" \
  --server-type=other \
  --create-site="https://${setup_projectname}.ddev.site/" \
  --no-interaction \
  --force >/dev/null 2>&1

# Remove FIRST_INSTALL file to skip Install Tool wizard
rm -f public/FIRST_INSTALL FIRST_INSTALL
print_substep_done "TYPO3 core installed"

print_substep "Configuring database..."
# add template record
ddev exec mysql --user=db --password=db db << EOF
INSERT INTO sys_template (pid, title, root, clear, constants, config) VALUES (1, 'Bootstrap Package', 1, 3, "@import 'EXT:sitepackage/Configuration/TypoScript/constants.typoscript'", "@import 'EXT:sitepackage/Configuration/TypoScript/setup.typoscript'");
EOF

# Activate extensions
ddev exec ./vendor/bin/typo3 extension:setup >/dev/null 2>&1

# Add sample pages
ddev exec mysql --user=db --password=db db << EOF
TRUNCATE pages;
INSERT INTO pages (\`pid\`, \`title\`, \`slug\`, \`doktype\`, \`is_siteroot\`) VALUES ('0', 'Home', '/', '1', '1'),('1', 'About', '/about', '1', '0'),('1', 'Page 1', '/page-1', '1', '0'),('1', 'Page 2', '/page-2', '1', '0');
EOF

# Create default backend user groups
ddev exec mysql --user=db --password=db db << EOF
INSERT INTO be_groups (title, description, groupMods, file_permissions, tables_select, tables_modify, pagetypes_select, non_exclude_fields) VALUES
('Editor', 'Default editor user group', 'web_layout,web_list,web_info', 'readFolder,writeFolder,addFolder,renameFolder,moveFolder,deleteFolder,readFile,writeFile,addFile,renameFile,moveFile,deleteFile,copyFile,copyFolder', '', '', '', ''),
('Advanced Editor', 'Advanced editor user group', 'web_layout,web_list,web_info,web_ViewpageView', 'readFolder,writeFolder,addFolder,renameFolder,moveFolder,deleteFolder,readFile,writeFile,addFile,renameFile,moveFile,deleteFile,copyFile,copyFolder', '', '', '', '');
EOF

if [ $install_bootstrap = true ] ; then
ddev exec mysql --user=db --password=db db << EOF
UPDATE pages
SET backend_layout = "pagets__default", backend_layout_next_level = "pagets__2_columns"
WHERE uid = 1;
EOF
fi

mkdir -p "${abs_setup_basedirectory}/config/sites/${setup_projectname}"
expandVarsStrict< "${SCRIPT_DIR}/templates/siteConfiguration.yaml" >  "${abs_setup_basedirectory}/config/sites/${setup_projectname}/config.yaml"
print_substep_done "Database configured"

if [ ! -z $repository_url ] ; then
   print_substep "Initializing git repository..."
   git init >/dev/null 2>&1
   git add . >/dev/null 2>&1
   git commit -m 'Initial commit' >/dev/null 2>&1
   git remote add upstream "${repository_url}" >/dev/null 2>&1
   git push --set-upstream upstream main >/dev/null 2>&1
   print_substep_done "Git repository initialized"
fi

#
# final instructions after install
# --------------------------------------
printf "\n\n"
printf "${SUCCESS}  ╭───────────────────────────────────────────────────────────╮${RESET}\n"
printf "${SUCCESS}  │                                                           │${RESET}\n"
printf "${SUCCESS}  │${RESET}${BOLD}   ✓  Setup Complete!                                     ${RESET}${SUCCESS}│${RESET}\n"
printf "${SUCCESS}  │                                                           │${RESET}\n"
printf "${SUCCESS}  ├───────────────────────────────────────────────────────────┤${RESET}\n"
printf "${SUCCESS}  │                                                           │${RESET}\n"
printf "${SUCCESS}  │${RESET}   ${BOLD}Frontend:${RESET}  https://${setup_projectname}.ddev.site/\n"
printf "${SUCCESS}  │${RESET}   ${BOLD}Backend:${RESET}   https://${setup_projectname}.ddev.site/typo3\n"
printf "${SUCCESS}  │                                                           │${RESET}\n"
printf "${SUCCESS}  │${RESET}   ${BOLD}Username:${RESET}  admin\n"
printf "${SUCCESS}  │${RESET}   ${BOLD}Password:${RESET}  ${admin_password}\n"
printf "${SUCCESS}  │                                                           │${RESET}\n"
printf "${SUCCESS}  ╰───────────────────────────────────────────────────────────╯${RESET}\n"
printf "\n"
printf "  ${DIM}Run 'ddev describe' in the project directory for more info.${RESET}\n"
printf "  ${DIM}Happy coding! 🚀${RESET}\n\n"
exit 0
