FROM ubuntu:trusty

RUN apt-get update && apt-get install -y unzip

RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
ENV DEBIAN_FRONTEND=noninteractive

RUN add-apt-repository ppa:webupd8team/java
RUN apt-get update
RUN apt-get -y install oracle-java8-installer



# see CA_CERTIFICATES_JAVA_VERSION notes above
RUN /var/lib/dpkg/info/ca-certificates-java.postinst configure

# If you're reading this and have any feedback on how this image could be
#   improved, please open an issue or a pull request so we can discuss it!

# Config vars
ENV BAMBOO_AGENT_HOME /usr/sbin/bamboo-agent-home
ENV BAMBOO_AGENT_INSTALL /opt/atlassian/bambooagent
ENV BAMBOO_VERSION 5.9.7
ENV BAMBOO_AGENT_JAR atlassian-bamboo-agent-installer-$BAMBOO_VERSION.jar
ENV BAMBOO_AGENT $BAMBOO_AGENT_HOME/bin/bamboo-agent.sh


RUN apt-get install curl wget

RUN curl -sL https://deb.nodesource.com/setup_5.x | bash -
RUN apt-get update && apt-get install -y nodejs


# remove several traces of debian python
RUN apt-get install -y python
RUN set -ex \
        && buildDeps=' \
                curl \
                gcc \
                libbz2-dev \
                libc6-dev \
                libncurses-dev \
                libreadline-dev \
                libsqlite3-dev \
                libssl-dev \
                make \
                xz-utils \
                zlib1g-dev \
                libpython-dev \
        ' \
        && apt-get install -y $buildDeps

RUN apt-get install -y  \
		ca-certificates \
		libsqlite3-0 \
		libssl1.0.0 \
	&& rm -rf /var/lib/apt/lists/*


RUN curl https://bootstrap.pypa.io/ez_setup.py -o - | python
RUN easy_install pip


RUN apt-get update && apt-get install -y \
		gcc \
		gettext \
		mysql-client libmysqlclient-dev \
		postgresql-client libpq-dev \
		sqlite3 \
	--no-install-recommends && rm -rf /var/lib/apt/lists/*

ENV DJANGO_VERSION 1.9.3

RUN pip install mysqlclient psycopg2 django=="$DJANGO_VERSION"
RUN apt-get install -y libxml2 libmemcached libssl2

# Copy the scripts
COPY ./run.sh /tmp/run.sh
COPY ./bamboo-capabilities.properties $BAMBOO_AGENT_HOME/bin/bamboo-capabilities.properties

# Install Atlassian Bamboo Agent and helper tools and setup initial home
# directory structure.
RUN set -x \
    && chmod -R 700            /tmp/run.sh \
    && chown -R daemon:daemon  /tmp/run.sh \
    && mkdir -p                "${BAMBOO_AGENT_HOME}" \
    && chmod -R 700            "${BAMBOO_AGENT_HOME}" \
    && chown -R daemon:daemon  "${BAMBOO_AGENT_HOME}" \
    && mkdir -p                "${BAMBOO_AGENT_INSTALL}" \
    && chmod -R 700            "${BAMBOO_AGENT_INSTALL}" \
    && chown -R daemon:daemon  "${BAMBOO_AGENT_INSTALL}" \
    && chmod -R 700            "${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties" \
    && chown -R daemon:daemon  "${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER root

# Expose web and agent ports (what ports does agent need?)
EXPOSE 8085
EXPOSE 54663

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/bambooagent"]

# Set the default working directory as the installation directory.
WORKDIR ${BAMBOO_AGENT_HOME}

# Run agent as a foreground process by default.
CMD ["/tmp/run.sh", "-fg"]
