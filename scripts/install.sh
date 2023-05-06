#!/bin/bash

set -e
clear

function set_globals(){
  green=$(echo -en "\e[92m")
  yellow=$(echo -en "\e[93m")
  magenta=$(echo -en "\e[35m")
  red=$(echo -en "\e[91m")
  cyan=$(echo -en "\e[96m")
  white=$(echo -en "\e[39m")
  
  SYSTEMD="/etc/systemd/system"
  INITD="/etc/init.d"
  ETCDEF="/etc/default"
  
  KLIPPER_REPO="https://github.com/Klipper3d/klipper.git"
}

function status_msg() { 
  echo -e "\n\n\n${green}                >>>>>> ${1} <<<<<<${white}\n\n\n"
}

function error_msg() {
  echo -e "\n\n\n${red}           >>>>>> ${1} <<<<<<${white}\n\n\n"
}

function ok_msg() {
  echo -e "${green}[✓ OK] ${1}${white}"
}

function setting_host(){
  sudo echo "klipper ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/klipper
  
  status_msg "Update Host"
  sudo apt update -y
  sudo apt upgrade -y
  sleep 10
  clear
  
  status_msg "Install libraries"
  sudo apt-get install gpiod sendemail libnet-ssleay-perl libio-socket-ssl-perl -y
  sleep 10
  clear
  
  status_msg "Settings libraries"
  sudo usermod -a -G tty klipper
  sudo usermod -a -G dialout klipper

  sudo /bin/sh -c "cat > /etc/udev/rules.d/99-gpio.rules" <<EOF
# Corrects sys GPIO permissions so non-root users in the gpio group can manipulate bits
#
SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c '\
 chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\
 chown -R root:gpio /sys/devices/virtual/gpio && chmod -R 770 /sys/devices/virtual/gpio;\
 chown -R root:gpio /sys$devpath && chmod -R 770 /sys$devpath\'"
EOF

  sudo groupadd gpio
  sudo usermod -a -G gpio klipper
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  sleep 10
  clear
}

function create_required_folders() {
  local printer_data=${1} folders
  folders=("backup" "certs" "config" "database" "gcodes" "comms" "logs" "systemd")

  for folder in "${folders[@]}"; do
    local dir="${printer_data}/${folder}"

    ### remove possible symlink created by moonraker
    if [[ -L "${dir}" && -d "${dir}" ]]; then
      rm "${dir}"
    fi

    if [[ ! -d "${dir}" ]]; then
      status_msg "Creating folder '${dir}' ..."
      mkdir -p "${dir}"
      ok_msg "Folder '${dir}' created!"
    fi
  done
}

function do_action_service() {
  local services action=${1} service=${2}
  services=$(find "${SYSTEMD}" -maxdepth 1 -regextype posix-extended -regex "${SYSTEMD}/${service}(-[0-9a-zA-Z]+)?.service" | sort)

  if [[ -n ${services} ]]; then
    for service in ${services}; do
      service=$(echo "${service}" | rev | cut -d"/" -f1 | rev)
      status_msg "${action^} ${service} ..."

      if sudo systemctl "${action}" "${service}"; then
        log_info "${service}: ${action} > success"
        ok_msg "${action^} ${service} successfull!"
      else
        log_warning "${service}: ${action} > failed"
        warn_msg "${action^} ${service} failed!"
      fi
    done
  fi
}

function write_example_printer_cfg() {
  local cfg=${1}
  local cfg_template

  cfg_template="${HOME}/KIS/resources/example.printer.cfg"

  status_msg "Creating minimal example printer.cfg ..."
  if cp "${cfg_template}" "${cfg}"; then
    ok_msg "Minimal example printer.cfg created!"
  else
    error_msg "Couldn't create minimal example printer.cfg!"
  fi
}

function install_klipper(){
  local printer_name
  regex="^[0-9a-zA-Z]+$"
  blacklist="mcu"
  while [[ ! ${input} =~ ${regex} || ${input} =~ ${blacklist} ]]; do
    read -p "${cyan}                Select printer name: ${white} " input

    if [[ ${input} =~ ${blacklist} ]]; then
      error_msg " Name not allowed!"
    elif [[ ${input} =~ ${regex} && ! ${input} =~ ${blacklist} ]]; then
      if [[ ${input} =~ ^[0-9]+$ ]]; then
        printer_name+=("Printer_${input}")
      else
        printer_name+=("${input}")
      fi
    else
      error_msg "Invalid Input!"
    fi
  done && input=""
  
  clear
  status_msg "Printer Name: ${printer_name}"
  
  [[ -z ${repo} ]] && repo="${KLIPPER_REPO}"
  repo=$(echo "${repo}" | sed -r "s/^(http|https):\/\/github\.com\///i; s/\.git$//")
  repo="https://github.com/${repo}"
  
  [[ -z ${branch} ]] && branch="master"
  
  KLIPPER_REP="${HOME}/${printer_name}_rep"
  KLIPPER_ENV="${HOME}/${printer_name}_env"
  
  ### force remove existing klipper dir and clone into fresh klipper dir
  [[ -d ${KLIPPER_REP} ]] && rm -rf "${KLIPPER_REP}"
  
  cd "${HOME}" || exit 1
  if git clone "${repo}" "${KLIPPER_REP}"; then
    cd "${KLIPPER_REP}" && git checkout "${branch}"
  else
    print_error "Cloning Klipper from\n ${repo}\n failed!"
    exit 1
  fi
  
  local packages
  local install_script="${KLIPPER_REP}/scripts/install-debian.sh"
  packages=$(grep "PKGLIST=" "${install_script}" | cut -d'"' -f2 | sed 's/\${PKGLIST}//g' | tr -d '\n')
  packages+=" dfu-util"
  packages="${packages//python-dev/python3-dev}"
  
  echo "${cyan}${packages}${white}" | tr '[:space:]' '\n'
  read -r -a packages <<< "${packages}"
  
  status_msg "Updating package lists..."
  if ! sudo apt-get update --allow-releaseinfo-change; then
    error_msg "Updating package lists failed!"
    exit 1
  fi
  
  status_msg "Installing required packages..."
  if ! sudo apt-get install --yes "${packages[@]}"; then
    error_msg "Installing required packages failed!"
    exit 1
  fi



  [[ -d ${KLIPPER_ENV} ]] && rm -rf "${KLIPPER_ENV}"
  
  status_msg "Installing $("python3}" -V) virtual environment..."
  
  if virtualenv -p "python3" "${KLIPPER_ENV}"; then
    "${KLIPPER_ENV}"/bin/pip install -U pip
    "${KLIPPER_ENV}"/bin/pip install -r "${KLIPPER_REP}"/scripts/klippy-requirements.txt
  else
    error_msg "Creation of Klipper virtualenv failed!"
    exit 1
  fi
  
  
  
  local printer_data
  local cfg_dir
  local cfg
  local log
  local klippy_serial
  local klippy_socket
  local env_file
  local service
  local service_template
  local env_template
  
  printer_data="${HOME}/${printer_name}_cnf"
  cfg_dir="${printer_data}/config"
  cfg="${cfg_dir}/printer.cfg"
  log="${printer_data}/logs/klippy.log"
  klippy_serial="${printer_data}/comms/klippy.serial"
  klippy_socket="${printer_data}/comms/klippy.sock"
  env_file="${printer_data}_cnf/systemd/klipper.env"

  create_required_folders "${printer_data}"

  service_template="${HOME}/KIS/resources/klipper.service"
  env_template="${HOME}/KIS/resources/klipper.env"
  service="${SYSTEMD}/klipper_${printer_name}.service"

  if [[ ! -f ${service} ]]; then
    status_msg "Create Klipper service file ..."
    
    sudo cp "${service_template}" "${service}"
    sudo cp "${env_template}" "${env_file}"
    sudo sed -i "s|%USER%|${USER}|g; s|%ENV%|${KLIPPER_ENV}|; s|%ENV_FILE%|${env_file}|" "${service}"
    sudo sed -i "s|%USER%|${USER}|; s|%LOG%|${log}|; s|%CFG%|${cfg}|; s|%PRINTER%|${klippy_serial}|; s|%UDS%|${klippy_socket}|" "${env_file}"

    ok_msg "Klipper service file created!"
  fi

  if [[ ! -f ${cfg} ]]; then
    write_example_printer_cfg "${cfg}"
  fi
  
  do_action_service "enable" "klipper"
  do_action_service "start" "klipper"

}


set_globals
#setting_host
install_klipper

