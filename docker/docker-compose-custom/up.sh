#!/usr/bin/env bash
# OpenMetadata 定制部署管理脚本（git 跟踪）
# 用法：./up.sh up -d     启动   ./up.sh down  停止  ./up.sh config  校验
set -euo pipefail
cd "$(dirname "$0")"

# 读取 .env 里配置的 server 镜像（本地镜像则必须已经存在，否则报错退出，
# 避免 docker 用晦涩的 pull access denied 错误信息）。
server_img="${OPENMETADATA_SERVER_IMAGE:-$(grep -s '^OPENMETADATA_SERVER_IMAGE=' .env | cut -d= -f2-)}"
server_img="${server_img:-docker.getcollate.io/openmetadata/server:2.0.0}"

# 仅运行类命令需要 server 镜像；config/down/ps 等不需要
case "$1" in
  up|run|run:|create|start)
    if [[ "$server_img" != *"/"* ]] && ! docker image inspect "$server_img" >/dev/null 2>&1; then
      echo "错误：本地 server 镜像不存在：${server_img}" >&2
      echo "请在 OpenMetadata 仓库根目录执行以下命令构建镜像：" >&2
      echo "  mvn -DskipTests clean package && docker build -t ${server_img} -f docker/docker-compose-custom/Dockerfile ." >&2
      echo "构建完成后重新执行：./up.sh $*" >&2
      exit 1
    fi
    ;;
esac

docker compose -f docker-compose.yml --env-file .env "$@"
