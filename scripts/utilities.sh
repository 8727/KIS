#!/usr/bin/env bash

set -e

function set_globals() {
  green=$(echo -en "\e[92m")
  yellow=$(echo -en "\e[93m")
  magenta=$(echo -en "\e[35m")
  red=$(echo -en "\e[91m")
  cyan=$(echo -en "\e[96m")
  white=$(echo -en "\e[39m")

}

function select_msg() { echo -e "${white}   [➔] ${1}" }
function status_msg() { echo -e "\n${magenta}###### ${1}${white}" }
function ok_msg() { echo -e "${green}[✓ OK] ${1}${white}" }
function warn_msg() { echo -e "${yellow}>>>>>> ${1}${white}" }
function error_msg() { echo -e "${red}>>>>>> ${1}${white}" }
function abort_msg() { echo -e "${red}<<<<<< ${1}${white}" }
function title_msg() { echo -e "${cyan}${1}${white}" }

function print_error() {
  [[ -z ${1} ]] && return
  echo -e "${red}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

function print_confirm() {
  [[ -z ${1} ]] && return
  echo -e "${green}"
  echo -e "#=======================================================#"
  echo -e " ${1} "
  echo -e "#=======================================================#"
  echo -e "${white}"
}

