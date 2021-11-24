#!/bin/bash

# 判断是否为root
user=$(whoami)
if [ ! "${user}" = "root" ]; then
  echo "权限拒绝，sudo试试"
  exit 0
fi

# 判断操作系统
. /etc/os-release
os_release_id=$ID$VERSION_ID
case $os_release_id in
ubuntu16.04)
  child_version=$(echo "$VERSION" | awk '{print $1}' | cut -d "." -f 3)
  if [[ $child_version -lt 4 ]]; then
    echo "当前脚本支持16.04.4及以上，更新系统后重试"
    exit 0
  fi
  ;;
centos7) ;;

*) echo "当前系统无法使用此脚本" ;;
esac

######################
# install entrypoint #
######################
function install() {
  install_arg=$1
  case ${install_arg} in
  -a)
    install_docker-ce
    install_nvidia-docker2
    install_docker-compose
    ;;
  *)
    until
      echo
      echo "1. 安装docker-ce"
      echo "2. 安装nvidia-docker2"
      echo "3. 安装docker-compose"
      echo "4. 退出"
      echo
      read -r -p "请输入[1-4]：" install_input
      test "$install_input" == 4
    do
      case $install_input in
      # 0)  install_docker-ce;install_nvidia-docker2;install_docker-compose     ;;
      1) install_docker-ce ;;
      2) install_nvidia-docker2 ;;
      3) install_docker-compose ;;
      esac
    done
    ;;
  esac
}

# docker-ce 18.03.0
function install_docker-ce() {
  case ${os_release_id} in
  ubuntu16.04) dpkg -i docker-ce*.deb ;;
  centos7) rpm -ivh docker-ce_rpms/* && systemctl start docker.service && systemctl enable docker.service ;;
  esac
  # echo -e "\e[1;32m已安装docker-ce\e[0m"
}

# nvidia-docker2 2.0.3
function install_nvidia-docker2() {
  case ${os_release_id} in
  ubuntu16.04) dpkg -i nvidia-docker2_debs/* ;;
  centos7) rpm -ivh nvidia-docker2_rpms/* ;;
  esac
  # echo -e "\e[1;32m已安装nvidia-docker2\e[0m"
}

# docker-compose 1.21.0
function install_docker-compose() {
  cp docker-compose* /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  # echo -e "\e[1;32m已安装docker-compose\e[0m"
}

#####################
# config entrypoint #
#####################
function config() {
  if [ -e /lib/systemd/system/docker.service ]; then
    line_number=$(sed -n "/ExecStart/=" /lib/systemd/system/docker.service)
    until
      echo
      echo "0. 【慎重】 恢复所有配置"
      echo "1. 【推荐】 将你的用户添加进docker用户组"
      echo "2. 【推荐】 配置国内镜像仓库 (加快在国内拉取镜像的速度)"
      echo "3. 【可选】 配置局域网私有仓库IP地址或域名地址（有需要还是联系本地私有仓库管理员）"
      echo "4. 【可选】 暴露2375端口到局域网"
      echo "5. 【可选】 使 dockerd 默认使用nvidia运行时，并支持swarm调度"
      echo "6. 退出并重载 dockerd 服务"
      echo
      read -r -p "请输入[0-6]：" config_input
      test "$config_input" == 6
    do
      clear
      case $config_input in
      "0") config_recover ;;
      "1") add_docker_user ;;
      "2") config_registry-mirror ;;
      "3") config_registry_url ;;
      "4") config_port ;;
      "5") config_runtime ;;
      esac
    done
    systemctl daemon-reload
    systemctl restart docker.service
  else
    echo "未找到启动 dockerd 的配置文件！检查docker-ce是否已安装！"
  fi
}

function add_docker_user() {
  read -r -p "输入你的用户名：" user_name
  usermod -aG docker "${user_name}"
  echo "已将${user_name}添加进docker用户组"
  echo -e "\e[1;31m提示：重新登录后生效\e[0m"
}

function config_registry-mirror() {
  sed -i "${line_number}s/$/ --registry-mirror=https:\/\/registry.docker-cn.com\//" /lib/systemd/system/docker.service
  echo "已添加国内镜像仓库 https://registry.docker-cn.com"
}

function config_registry_url() {
  read -r -p "输入私有仓库的地址：" registry_url
  sed -i "${line_number}s/$/ --insecure-registry=${registry_url}:5000/" /lib/systemd/system/docker.service
  echo "已添加私有仓库地址：${registry_url}，如果添加的是域名，还需要配置 /etc/hosts，将域名解析成 IP 地址"
}

function config_port() {
  add_string=" -H tcp:\/\/0.0.0.0:2375"
  sed -i "${line_number}s/$/${add_string}/" /lib/systemd/system/docker.service
  echo "已允许任意ip地址远程操作 dockerd 服务"
}

function config_runtime() {
  GPU_ID=$(nvidia-smi -a | grep UUID | awk '{print substr($4,0,12)}')
  sed -i "${line_number}s/$/ --default-runtime=nvidia/" /lib/systemd/system/docker.service
  sed -i "${line_number}s/$/ --node-generic-resource=gpu=${GPU_ID}/" /lib/systemd/system/docker.service
  sed -i '1iswarm-resource = "DOCKER_RESOURCE_GPU"' /etc/nvidia-container-runtime/config.toml
}

function config_recover() {
  read -r -p "确认要恢复所有配置吗？[y/n]：" recover_input
  if [[ ${recover_input} == y ]]; then
    case ${os_release_id} in
    ubuntu16.04) sed -i "${line_number}c ExecStart=/usr/bin/dockerd -H fd://" /lib/systemd/system/docker.service ;;
    centos7) sed -i "${line_number}c ExecStart=/usr/bin/dockerd" /lib/systemd/system/docker.service ;;
    esac
  fi
  echo "已恢复为初始配置文件，重载 dockerd 服务后生效"
}

#####################
# remove entrypoint #
#####################
function remove() {
  remove_arg=$1
  case ${remove_arg} in
  -a)
    remove_nvidia-docker2
    remove_docker-ce
    remove_docker-compose
    ;;
  *)
    until
      echo
      echo "1. 卸载nvidia-docker2(优先)"
      echo "2. 卸载docker-ce"
      echo "3. 卸载docker-compose"
      echo "4. 退出"
      echo
      read -r -p "请输入[1-4]：" remove_input
      test "$remove_input" == 4
    do
      case $remove_input in
      # 0)  remove_nvidia-docker2;remove_docker-ce;remove_docker-compose    ;;
      1) remove_nvidia-docker2 ;;
      2) remove_docker-ce ;;
      3) remove_docker-compose ;;
      esac
    done
    ;;
  esac
}

function remove_nvidia-docker2() {
  case ${os_release_id} in
  ubuntu16.04) dpkg -P nvidia-docker2 nvidia-container-runtime nvidia-container-runtime-hook libnvidia-container-tools libnvidia-container1 ;;
  centos7) rpm -e nvidia-docker2 nvidia-container-runtime nvidia-container-runtime-hook libnvidia-container-tools libnvidia-container1 ;;
  esac
  # echo -e "\e[1;33m已删除nvidia-docker2\e[0m"
}

function remove_docker-ce() {
  case ${os_release_id} in
  ubuntu16.04) dpkg -P docker-ce ;;
  centos7) rpm -e docker-ce container-selinux pigz ;;
  esac
  # echo -e "\e[1;33m已删除docker-ce\e[0m"
}

function remove_docker-compose() {
  rm -f /usr/local/bin/docker-compose
  # echo -e "\e[1;33m已删除docker-compose\e[0m"
}

####################
# check entrypoint #
####################
function check() {
  docker_ce_version=$(docker -v 2>/dev/null)
  nvidia_docker_version=$(nvidia-docker version 2>/dev/null | sed -n '1p;1q')
  docker_compose_version=$(/usr/local/bin/docker-compose -v 2>/dev/null)
  if [[ -n ${docker_ce_version} ]]; then
    echo "${docker_ce_version},已安装"
  else
    echo "docker-ce not installed,未安装"
  fi
  if [[ -n ${nvidia_docker_version} ]]; then
    echo "${nvidia_docker_version},已安装"
  else
    echo "nvidia-docker not installed,未安装"
  fi
  if [[ -n ${docker_compose_version} ]]; then
    echo "${docker_compose_version},已安装"
  else
    echo "docker-compose not installed,未安装"
  fi
}

###################
# help entrypoint #
###################
function show_help() {
  cat <<EOF

Usage: sudo $0 Command [arg]

Commands:
  install [-a]    安装管理菜单 [-a 一键安装全部]
  remove [-a]     卸载管理菜单 [-a 一键移除所有安装]
  config          配置管理菜单
  check           检查各软件是否已安装
  -h, --help      显示此帮助页

EOF
}

###################
# main entrypoint #
###################
function main() {
  Command=$1
  shift
  case "${Command}" in
  -h) show_help ;;
  --help) show_help ;;
  install) install "$@" ;;
  config) config ;;
  remove) remove "$@" ;;
  check) check ;;
  *) echo -e "需要执行命令，后面加上 --help 查看可执行命令的更多信息" ;;
  esac
}

main "$@"
