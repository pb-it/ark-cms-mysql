FROM ubuntu:22.04

RUN apt-get update && \
	apt-get install -y \
	dos2unix \
	curl \
	git \
	mysql-server \
	apache2

ARG ENV
RUN if [ "$ENV" = "development" ] ; then apt-get install -y nano openssh-server cifs-utils vsftpd subversion ; echo 'root:docker' | chpasswd ; sed -i 's/\(#\|\)PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config ; fi
#mv /etc/vsftpd.conf /etc/vsftpd.conf.orig



#su: warning: cannot change directory to /nonexistent: No such file or directory
#https://stackoverflow.com/questions/62987154/mysql-wont-start-error-su-warning-cannot-change-directory-to-nonexistent
# alternative may be https://ivangogogo.medium.com/docker-use-dockerfile-to-install-mysql-5-7-on-ubuntu-18-04-88e36436f1fd
RUN usermod -d /var/lib/mysql/ mysql

RUN sed -i 's/.*bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

RUN service mysql start && \
	mysql -u root --execute "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION; CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY ''; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES; CREATE SCHEMA cms" && \
	service mysql stop



ARG NODE_VERSION
RUN if [ -z "$NODE_VERSION" ] ; then curl -fsSL https://deb.nodesource.com/setup_18.x | bash - ; else curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash - ; fi
RUN apt-get -y install \
    nodejs
RUN echo "NODE Version:" && node --version
RUN echo "NPM Version:" && npm --version



ARG CMS_GIT_TAG
ARG API_GIT_TAG

# break docker build cache on git update
ADD "https://api.github.com/repos/pb-it/wing-cms-api/commits?per_page=1" latest_commit
RUN cd /home && \
	if [ -z "$API_GIT_TAG" ] ; then API_GIT_TAG="$CMS_GIT_TAG" ; fi && \
	if [ -z "$API_GIT_TAG" ] ; then git clone https://github.com/pb-it/wing-cms-api ; else git clone https://github.com/pb-it/wing-cms-api -b "$API_GIT_TAG" --depth 1 ; fi && \
	cd /home/wing-cms-api && \
	npm install --legacy-peer-deps

RUN mkdir /home/wing-cms-api/config/sslcert && cd /home/wing-cms-api/config/sslcert && \
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout key.pem -out cert.pem -subj "/CN=example.com" \
    -addext "subjectAltName=DNS:example.com,DNS:www.example.net,IP:10.0.0.1"

# break docker build cache on git update
ADD "https://api.github.com/repos/pb-it/wing-cms/commits?per_page=1" latest_commit
RUN cd /home && \
	if [ -z "$CMS_GIT_TAG" ] ; then git clone https://github.com/pb-it/wing-cms ; else git clone https://github.com/pb-it/wing-cms -b "$CMS_GIT_TAG" --depth 1 ; fi && \
	cd /home/wing-cms && \
	npm install

RUN mkdir /var/www/html/cdn #ln -s /var/www/html/cdn /home/cdn



WORKDIR /home

ADD start.sh ./start.sh
RUN dos2unix start.sh && chmod +x start.sh

EXPOSE 20-22 80 3002 3306 4000

CMD bash /home/start.sh && tail -f /dev/null
#ENTRYPOINT tail -f /dev/null