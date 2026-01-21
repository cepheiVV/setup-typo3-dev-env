#!/bin/bash

ask_continue () {
    printf "  ${INPUT}Continue? [y/N]: ${RESET}"
    read -r i
    case $i in
        [yY])
            ok=1
            return;;
        [nN])
            ok=0
            return;;
        *)
            printf "  ${WARNING}Invalid option!${RESET}\n"
            ask_continue
            ;;
    esac
}

ask_typo3version_options() {
    printf "  ${INPUT}Select TYPO3 version:${RESET}\n"
    printf "    ${DIM}12)${RESET} 12.4 LTS\n"
    printf "    ${DIM}13)${RESET} 13.4 LTS\n"
    printf "  "
    read -r -p "Enter version [13]: " ver
    case $ver in
        12)
            setup_typo3version_minor="12.4";;
        13)
            setup_typo3version_minor="13.4";;
        *)
            setup_typo3version_minor="13.4";;
    esac
}

ask_newbasedirectory() {
   printf "  ${INPUT}Project directory ${DIM}(relative path, use ../ to move up)${RESET}\n"
   printf "  "
   read -r -p "${pwd}/" setup_basedirectory
   if ! [[ $setup_basedirectory =~ ^[a-zA-Z_0-9\/\.\-]+$ ]] ; then
      printf "  ${WARNING}Please don't use spaces or special chars other than '_' or '-'${RESET}\n"
      ask_newbasedirectory
   fi

   if [ -d "$setup_basedirectory" ] && [ "$(ls -A $setup_basedirectory 2>/dev/null)" ] ; then
      printf "  ${WARNING}Directory not empty! Please select a different path.${RESET}\n"
      ask_newbasedirectory
   fi

   cur_dir="${pwd}/"
   mkdir -p $setup_basedirectory

   abs_setup_basedirectory="$(cd "$(dirname "${cur_dir}/${setup_basedirectory}")"; pwd)/$(basename "${cur_dir}/${setup_basedirectory}")"
   printf "  ${SUCCESS}✓ Directory created${RESET}\n"
   cd "${cur_dir}"
}

ask_projectname() {
    printf "  ${INPUT}Project name ${DIM}(lowercase, no spaces)${RESET}\n"
    printf "  "
    read -r -p "Name: " setup_projectname

    if [[ $setup_projectname =~ [A-Z] ]] ; then
        printf "  ${WARNING}Only use lowercase letters!${RESET}\n"
        ask_projectname
    fi

    if ! [[ $setup_projectname =~ ^[a-z_0-9\-]+$ ]] ; then
        printf "  ${WARNING}Don't use spaces or special chars other than underscore!${RESET}\n"
        ask_projectname
    fi

    return
}

ask_namespace() {
    printf "  ${INPUT}Vendor namespace ${DIM}(for PHP namespace)${RESET}\n"
    printf "  "
    read -r -p "Vendor [ITSC]: " setup_namespace
    setup_namespace=${setup_namespace:-ITSC}

    if ! [[ $setup_namespace =~ ^[a-zA-Z0-9]+$ ]] ; then
        printf "  ${WARNING}Please don't use spaces or special characters!${RESET}\n"
        ask_namespace
    fi

    setup_namespace_lowercase=$(tr '[:upper:]' '[:lower:]' <<< $setup_namespace)

    return
}

ask_port() {
    printf "  ${INPUT}DDEV router port${RESET}\n"
    printf "  "
    read -r -p "Port [8080]: " setup_port

    # check if empty, then use default port
    if [ -z $setup_port ] ; then
        setup_port="8080"
    fi

    if ! [[ $setup_port =~ ^[0-9]+$ ]] ; then
        printf "  ${WARNING}Invalid port number!${RESET}\n"
        ask_port
    fi

    return
}

ask_confirmsetup() {
    printf "\n"
    printf "${NOTE}  ╭─────────────────────────────────────────────────╮${RESET}\n"
    printf "${NOTE}  │${RESET}${BOLD}  Configuration Summary                          ${RESET}${NOTE}│${RESET}\n"
    printf "${NOTE}  ├─────────────────────────────────────────────────┤${RESET}\n"
    printf "${NOTE}  │${RESET}  TYPO3 Version:    ${SUCCESS}${setup_typo3version_minor}${RESET}\n"
    printf "${NOTE}  │${RESET}  Project Name:     ${SUCCESS}${setup_projectname}${RESET}\n"
    printf "${NOTE}  │${RESET}  Namespace:        ${SUCCESS}${setup_namespace}${RESET}\n"
    printf "${NOTE}  │${RESET}  Directory:        ${SUCCESS}${abs_setup_basedirectory}${RESET}\n"
    printf "${NOTE}  │${RESET}  Port:             ${SUCCESS}${setup_port}${RESET}\n"
    printf "${NOTE}  ├─────────────────────────────────────────────────┤${RESET}\n"
    printf "${NOTE}  │${RESET}${BOLD}  Extensions                                     ${RESET}${NOTE}│${RESET}\n"
    printf "${NOTE}  ├─────────────────────────────────────────────────┤${RESET}\n"
    if [ $install_bootstrap = true ] ; then
      printf "${NOTE}  │${RESET}  ${SUCCESS}✓${RESET} bk2k/bootstrap-package\n"
    fi
    display_optional_extensions
    if [ $install_phpmyadmin = true ] ; then
      printf "${NOTE}  │${RESET}  ${SUCCESS}✓${RESET} phpMyAdmin ${DIM}(ddev add-on)${RESET}\n"
    fi
    printf "${NOTE}  │${RESET}  ${SUCCESS}✓${RESET} Sample pages will be created\n"
    printf "${NOTE}  ╰─────────────────────────────────────────────────╯${RESET}\n"
    printf "\n"
    ask_continue
    if [[ $ok =~ 0 ]] ; then
        ask_typo3version_options
        ask_newbasedirectory
        ask_projectname
        ask_namespace
        ask_port
        ask_bootstrap_question
        ask_optional_extensions
        ask_phpmyadmin_question
        ask_confirmsetup
    fi

    return
}

ask_bootstrap_question () {
   printf "  ${INPUT}Install bk2k/bootstrap-package? [y/N]: ${RESET}"
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

ask_phpmyadmin_question () {
   printf "\n  ${BOLD}DDEV Add-ons${RESET}\n"
   printf "  ${INPUT}Install phpMyAdmin? [Y/n]: ${RESET}"
    read -r i
    case $i in
        [nN])
            install_phpmyadmin=false
            return;;
        *)
            install_phpmyadmin=true
            return;;
    esac
}

ask_repository_question () {
   printf "  ${INPUT}Git repository URL ${DIM}(press Enter to skip)${RESET}\n"
   printf "  "
   read -r -p "URL: " repository_url
}

ask_optional_extensions () {
   for EXTENSION in "${OPTIONAL_EXTENSIONS[@]}"
   do
      ask_optional_extension $EXTENSION
   done
}

ask_optional_extension () {
    printf "  ${INPUT}Install $1? [y/N]: ${RESET}"
    read -r i
    case $i in
        [yY])
            OPTIONAL_EXTENSIONS_INSTALL+=($1)
            return;;
        *)
            return;;
    esac
} 