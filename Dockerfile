FROM rockylinux:9-minimal

ARG USER_ID=1000
ARG GROUP_ID=1001

MAINTAINER Tomas Kovacik <kovacik@dgtfactory.com>
LABEL Description="vsftpd Docker image based on Rocky Linux 9 (minimal). Supports passive mode and virtual users." \
	License="Apache License 2.0" \
	Usage="docker run -d -p [HOST PORT NUMBER]:21 -v [HOST FTP HOME]:/home/vsftpd fauria/vsftpd" \
	Version="1.11.2026"

RUN microdnf -y update && microdnf clean all
RUN microdnf install -y \
	vsftpd \
	libdb-utils \
	libdb \
	iproute \
	logrotate \
	cronie && microdnf clean all
# eMudhra compromise (JDK-8395690 / CVE-2026-114820): blocklist all emSign roots
RUN set -e; CA_PATTERN='emsign'; \
    awk -v pat="$CA_PATTERN" ' \
      /^# / { name = substr($0, 3); keep = (tolower(name) ~ pat) } \
      keep && /BEGIN CERTIFICATE/ { gsub(/[^A-Za-z0-9._-]+/, "_", name); out = "/etc/pki/ca-trust/source/blocklist/" name ".pem" } \
      out { print > out } \
      /END CERTIFICATE/ { if (out) close(out); out = "" }' \
      /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem \
      /etc/pki/ca-trust/extracted/pem/email-ca-bundle.pem \
      /etc/pki/ca-trust/extracted/pem/objsign-ca-bundle.pem; \
    update-ca-trust extract; \
    if command -v keytool >/dev/null; then \
      keytool -list -cacerts -storepass changeit \
        | sed -n -E 's/, [A-Z][a-z]{2} [0-9]{1,2}, [0-9]{4}, trustedCertEntry, *$//p' \
        | grep -iE "$CA_PATTERN" \
        | while IFS= read -r a; do keytool -delete -cacerts -storepass changeit -alias "$a"; done; \
    fi

RUN usermod -u ${USER_ID} ftp
RUN groupmod -g ${GROUP_ID} ftp

ENV FTP_USER=
ENV FTP_PASS=
ENV PASV_ADDRESS=
ENV PASV_ADDR_RESOLVE=NO
ENV PASV_ENABLE=YES
ENV PASV_MIN_PORT=21100
ENV PASV_MAX_PORT=21110
ENV XFERLOG_STD_FORMAT=NO
ENV LOG_STDOUT=false
ENV FILE_OPEN_MODE=0666
ENV LOCAL_UMASK=077
ENV REVERSE_LOOKUP_ENABLE=YES
ENV PASV_PROMISCUOUS=NO
ENV PORT_PROMISCUOUS=NO
ENV LOG_ROTATE_ENABLE=true
ENV LOG_ROTATE_COUNT=7
ENV SSL_ENABLE=NO
ENV SSL_CERT_FILE=/etc/vsftpd/certs/vsftpd.pem
ENV SSL_KEY_FILE=/etc/vsftpd/certs/vsftpd.key
ENV IMPLICIT_SSL=NO
ENV SSL_FORCE_LOCAL_DATA=NO
ENV SSL_FORCE_LOCAL_LOGINS=NO

COPY vsftpd.conf /etc/vsftpd/
COPY vsftpd_virtual /etc/pam.d/
COPY run-vsftpd.sh /usr/sbin/

RUN chmod +x /usr/sbin/run-vsftpd.sh
RUN mkdir -p /home/vsftpd/
RUN chown -R ftp:ftp /home/vsftpd/

VOLUME /home/vsftpd
VOLUME /var/log/vsftpd
VOLUME /etc/vsftpd/certs

EXPOSE 20 21 990

CMD ["/usr/sbin/run-vsftpd.sh"]
