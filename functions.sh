#!/bin/bash

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

ask_typo3version_options() {
    PS3="Set the desired TYPO3 version: "

    printf "${INPUT}Select typo3 version:${NC}"
    printf "${INPUT}12) 12.4${NC}"
    printf "${INPUT}13) 13.4${NC}"
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

ask_repository_question () {
   printf "${INPUT}What is the remote repository url?${NC}"
   printf "${INPUT}You can skip it by pressing enter${NC}"
   printf "${INPUT}If you provide a url, we'll initialize the repo${NC}"
   printf "${INPUT}and set it as upstream${NC}"
   read -r repository_url
}

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