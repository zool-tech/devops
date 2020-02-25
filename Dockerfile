FROM debian:buster-slim

ENV LANG=zh_CN.UTF-8 \
	JAVA_HOME=/opt/java/openjdk-8 \
	PATH=$JAVA_HOME/bin:$PATH \
	APPDATA_DIR=/devopsdata \
	DEVOPS_GROUP=devops \
	JIRA_INSTALL_DIR=/opt/jira \
	JIRA_HOME=$APPDATA_DIR/jirahome \
	JIRA_USER=jira

VOLUME $APPDATA_DIR

# java install params
ARG JAVA_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk8-upstream-binaries/releases/download/jdk8u242-b08/OpenJDK8U-jdk_x64_linux_8u242b08.tar.gz
# jira install params
ARG JIRA_PRODUCT=jira-software
ARG JIRA_VERSION=8.7.1

RUN set -eux;\
	apt-get update && apt-get install -y --no-install-recommends busybox locales ca-certificates p11-kit && rm -rf /var/lib/apt/lists/*;\
# busybox soft link
	for cmdStr in free ip less nc netstat nslookup ping ps top tracerout vi watch wget;do ln -s busybox /bin/${cmdStr};done;\
# install OPENJDK
	wget -q -O openjdk.tgz "${JAVA_DOWNLOAD_URL}";\
	mkdir -p "$JAVA_HOME";\
	tar --extract --file openjdk.tgz --directory "$JAVA_HOME" --strip-components 1 --no-same-owner;\
	rm openjdk.tgz* && rm "$JAVA_HOME/src.zip" && rm -rf "$JAVA_HOME/demo" && rm -rf "$JAVA_HOME/sample";\
# update "cacerts" bundle to use Debian's CA certificate
	mkdir -p /etc/ca-certificates/update.d;\
	{\
		echo '#!/usr/bin/env bash';\
		echo 'set -Eeuo pipefail';\
		echo 'if ! [ -d "$JAVA_HOME" ]; then echo >&2 "error: missing JAVA_HOME environment variable"; exit 1; fi';\
# 8-jdk uses "$JAVA_HOME/jre/lib/security/cacerts" and 8-jre and 11+ uses "$JAVA_HOME/lib/security/cacerts" directly (no "jre" directory)
		echo 'cacertsFile=; for f in "$JAVA_HOME/lib/security/cacerts" "$JAVA_HOME/jre/lib/security/cacerts"; do if [ -e "$f" ]; then cacertsFile="$f"; break; fi; done';\
		echo 'if [ -z "$cacertsFile" ] || ! [ -f "$cacertsFile" ]; then echo >&2 "error: failed to find cacerts file in $JAVA_HOME"; exit 1; fi';\
		echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "$cacertsFile"';\
	} > /etc/ca-certificates/update.d/docker-openjdk;\
	chmod +x /etc/ca-certificates/update.d/docker-openjdk;\
	/etc/ca-certificates/update.d/docker-openjdk;\
# https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
	find "$JAVA_HOME/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf;\
	ldconfig;\
# install JIRA
	wget -q -O jira.tar.gz https://product-downloads.atlassian.com/software/jira/downloads/atlassian-${JIRA_PRODUCT}-${JIRA_VERSION}.tar.gz \
	&& mkdir -p ${JIRA_INSTALL_DIR} ${JIRA_HOME} \
	&& tar xzf /tmp/atlassian.tar.gz -C ${JIRA_INSTALL_DIR}/ --strip-components 1 \
	&& echo "jira.home = ${JIRA_HOME}" > ${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties;\
	groupadd -r $DEVOPS_GROUP && useradd -r -g $DEVOPS_GROUP $JIRA_USER && chown -R $JIRA_USER:$DEVOPS_GROUP ${JIRA_INSTALL_DIR} ${JIRA_HOME};\
#shell config
	echo "alias ls='ls --color=auto'\nalias ll='ls -lA'" > /root/.bashrc

EXPOSE 8080

USER $JIRA_USER
WORKDIR $JIRA_INSTALL_DIR

ENTRYPOINT ["/opt/jira/bin/start-jira.sh", "-fg"]
