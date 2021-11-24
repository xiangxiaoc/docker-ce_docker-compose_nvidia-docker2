# 概述

1. docker 官方不支持加载 NVIDIA 显卡的 GPU 资源，为了让容器里也有 GPU，NVIDIA 厂商官方发布了 nvidia-docker，在生成容器时，使用 ```nvidia-docker create ...``` 或者 ```nvidia-docker run ...``` 生成容器，那么这个容器就可以加载到宿主机上的 GPU 了！（前提是你宿主机上必须安装有NVIDIA的显卡驱动）；
2. 在 nvidia-docker 更新到 nvidia-docker2 后，支持 ```docker create --runtime=nvidia ...``` 或者 ```docker run --runtime=nvidia ...``` 同样来达到加载GPU的效果；
3. 既然支持原生 docker 加 runtime 就可以加载 GPU，那么就可以使用 docker-compose 来编排启动，docker-compose.yml 里面相应的选项为 ```runtime: nvidia``` ；
4. 为了支持 runtime 选项，docker-compose.yml 的 version 必须为 2.3 及以上(version: '2.3')，对应地，为了能解析2.3版本及2.4版本 yml 里面的 runtime 选项，docker-compose的版本又必须是 1.19.0 及以上，要将 docker，nvidia-docker，docker-compose 组合起来使用，所以才进行了这次的整理

## 当前版本

- docker-ce 18.03.0
- nvidia-docker2 2.0.3
- docker-compose 1.21.0

## 支持的系统

- ubuntu 16.04.4    [（16.04.2 16.04.3 点击此处下载）](https://raw.githubusercontent.com/xiangxiaoc/docker-ce_docker-compose_nvidia-docker2/master/nvidia-docker_2.0.2%2Bdocker-ce_17.12.0%2Bdocker-compose_1.19.0.tar.gz)
- centos 7.4.1708

在概述里也提到过，docker-compose 1.19.0 是支持 docker-compose 配置文件 version 2.3 的最低版本，发布docker-compose 1.19.0 时，当时最新的 Ubuntu 为 16.04.2，所以也不再做此前版本的套装整理了

## 用法

```shell
Usage: sudo ./setup.sh Command [arg]

Commands:
  install [-a]    安装管理菜单 [-a 一键安装全部]
  remove [-a]     卸载管理菜单 [-a 一键移除所有安装]
  config          配置管理菜单
  check           检查各软件是否已安装
  -h, --help      显示此帮助页
```

### 安装

```shell
sudo ./setup.sh install
```

自从 nvidia-docker 更新到了 nvidia-docker2 以后，依赖指定版本的docker-ce，不做前后版本的兼容，所以一定先安装docker-ce；docker-compose 是单独的二进制可执行文件，自由安装；可以进入交互式菜单自由选择安装，也可以使用`sudo ./setup install -a`，一键安装三件套

### 配置

```shell
sudo ./setup.sh config
```

进入交互式菜单，选择选项前面的数字，然后敲回车执行

1. 推荐选择 1 和 2，让普通用户能直接控制 docker daemon；大多中国用户直接访问原生仓库都比较慢，还是配置中国镜像站点比较好
2. 若想使用域名地址作为私有仓库镜像的前缀，还需在本地 hosts 文件中添加域名解析对应到私有镜像仓库IP地址，pull 和 push 镜像时会自动解析前缀域名

```shell
sudo sed -i "\$a ${私有仓库ip}   ${自定义域名地址}" /etc/hosts
```

### 卸载

```shell
sudo ./setup.sh remove
```

进入交互式卸载菜单后，由于nvidia-docker2依赖docker-ce，所以要先卸载nvidia-docker2，避免产生依赖问题，影响包管理工具以后的使用；同样docker-compose可以自由卸载，也可以加`sudo ./setup remove -a`，一键自动卸载