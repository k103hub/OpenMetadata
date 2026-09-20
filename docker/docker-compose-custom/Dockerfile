#  Copyright 2021 Collate
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#  http://www.apache.org/licenses/LICENSE-2.0
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# PROD 专用构建 Dockerfile。
#
# 目标：让 prod 使用本地（含定制修改如 UserResource.java）构建的 server 镜像，
# 而不是官方 push 的 docker.getcollate.io/openmetadata/server 镜像。
#
# 构建流程与 docker/development/Dockerfile 保持一致（从本地 Maven 打包
# openmetadata-dist/target/openmetadata-*.tar.gz 解包），唯一区别是最终基础
# 镜像（FROM）改用南京大学镜像源 gcr.nju.edu.cn，以便在大陆网络环境下顺利
# pull 到 distroless 基础镜像（gcr.io 在大陆常被墙/超时）。
#
# 构建方式（在仓库根目录执行）：
#   1) 先生成发行包：mvn -DskipTests clean package
#   2) 再构建镜像：  docker build -t openmetadata-server:custom \
#                       -f docker/docker-compose-custom/Dockerfile .
#   3) 让 compose 使用该镜像：在 docker/docker-compose-custom/.env 中设置
#        OPENMETADATA_SERVER_IMAGE=openmetadata-server:custom
#       （或按需要 commit 后的完整 tag，如 openmetadata-server:2.0.0-custom）
#
# 说明：本 Dockerfile 仅用于"开发机构建 → 镜像传 prod"的场景。若不需要大陆
# 镜像源，可改回 gcr.io。保持与 docker/development/Dockerfile 同步。

FROM alpine:3 AS dist

COPY openmetadata-dist/target/openmetadata-*.tar.gz /

RUN mkdir -p /opt/openmetadata && \
    tar zxvf openmetadata-*.tar.gz -C /opt/openmetadata --strip-components 1 && \
    rm openmetadata-*.tar.gz && \
    mkdir -p /opt/openmetadata/logs && \
    chown -R 65532:65532 /opt/openmetadata/logs && \
    mkdir -p /shim/bin && \
    ln -s /busybox/sh /shim/bin/sh && \
    printf '#!/busybox/sh\nexec /busybox/sh "$@"\n' > /shim/bin/bash && \
    chmod 755 /shim/bin/bash

FROM eclipse-temurin:21-jdk AS jre-builder

RUN jlink \
      --add-modules ALL-MODULE-PATH \
      --strip-debug \
      --no-man-pages \
      --no-header-files \
      --compress=zip-6 \
      --output /javaruntime

RUN find /javaruntime/bin -type f \
      ! -name java ! -name jcmd ! -name jstack ! -name jmap \
      ! -name jinfo ! -name jps ! -name jstat ! -name jfr ! -name keytool \
      -delete

FROM gcr.nju.edu.cn/distroless/cc-debian13:debug-nonroot

ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY --from=jre-builder /javaruntime ${JAVA_HOME}
COPY --from=dist /shim/bin /bin
COPY --from=dist /opt/openmetadata /opt/openmetadata
COPY --chmod=755 docker/openmetadata-start.sh /

USER 65532:65532

WORKDIR /opt/openmetadata
EXPOSE 8585 8586

ENTRYPOINT [ "/bin/bash" ]
CMD ["/openmetadata-start.sh"]
