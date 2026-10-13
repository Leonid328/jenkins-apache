#!/bin/sh
set -eu

PORT="${APACHE_PORT:-18080}"
ROOT="${APACHE_ROOT:-${PWD}/.apache-run}"
ACTION="${1:-all}"

mkdir -p "${ROOT}/htdocs" "${ROOT}/logs" "${ROOT}/cgi-bin"

write_tree() {
  cat > "${ROOT}/htdocs/index.html" <<'EOF'
<!doctype html>
<html><body><h1>Jenkins Apache lab</h1></body></html>
EOF
  cat > "${ROOT}/cgi-bin/boom.sh" <<'EOF'
#!/bin/sh
printf "Status: 500 Internal Server Error\r\n"
printf "Content-Type: text/plain\r\n\r\n"
echo "fake 5xx from Jenkins"
EOF
  chmod 755 "${ROOT}/cgi-bin/boom.sh"
}

detect_httpd() {
  if command -v apache2 >/dev/null 2>&1; then
    HTTPD_BIN="$(command -v apache2)"
  elif command -v httpd >/dev/null 2>&1; then
    HTTPD_BIN="$(command -v httpd)"
  elif [ -x /usr/sbin/httpd ]; then
    HTTPD_BIN=/usr/sbin/httpd
  else
    echo "Apache httpd is not installed" >&2
    exit 1
  fi

  if [ -d /usr/libexec/apache2 ]; then
    MODULES_DIR=/usr/libexec/apache2
  elif [ -d /usr/lib/apache2/modules ]; then
    MODULES_DIR=/usr/lib/apache2/modules
  else
    echo "Cannot find Apache modules" >&2
    exit 1
  fi
}

write_conf() {
  MIME=/etc/mime.types
  [ -f /etc/apache2/mime.types ] && MIME=/etc/apache2/mime.types
  cat > "${ROOT}/httpd.conf" <<EOF
ServerRoot "${ROOT}"
ServerName 127.0.0.1
Listen ${PORT}
PidFile "${ROOT}/httpd.pid"
LoadModule mpm_prefork_module ${MODULES_DIR}/mod_mpm_prefork.so
LoadModule authz_core_module ${MODULES_DIR}/mod_authz_core.so
LoadModule unixd_module ${MODULES_DIR}/mod_unixd.so
LoadModule dir_module ${MODULES_DIR}/mod_dir.so
LoadModule mime_module ${MODULES_DIR}/mod_mime.so
LoadModule log_config_module ${MODULES_DIR}/mod_log_config.so
LoadModule alias_module ${MODULES_DIR}/mod_alias.so
LoadModule cgi_module ${MODULES_DIR}/mod_cgi.so
TypesConfig ${MIME}
DocumentRoot "${ROOT}/htdocs"
<Directory "${ROOT}/htdocs">
  Require all granted
  DirectoryIndex index.html
</Directory>
ScriptAlias /cgi-bin/ "${ROOT}/cgi-bin/"
<Directory "${ROOT}/cgi-bin">
  Require all granted
  Options +ExecCGI
  SetHandler cgi-script
</Directory>
ErrorLog "${ROOT}/logs/error_log"
LogFormat "%h %l %u %t \\"%r\\" %>s %b" combined
CustomLog "${ROOT}/logs/access_log" combined
EOF
  if [ ! -f "${MIME}" ]; then
    grep -v TypesConfig "${ROOT}/httpd.conf" > "${ROOT}/httpd.conf.tmp"
    mv "${ROOT}/httpd.conf.tmp" "${ROOT}/httpd.conf"
  fi
}

stop_httpd() {
  if [ -f "${ROOT}/httpd.pid" ]; then
    "${HTTPD_BIN}" -f "${ROOT}/httpd.conf" -k stop || true
    sleep 1
  fi
}

start_httpd() {
  stop_httpd
  "${HTTPD_BIN}" -f "${ROOT}/httpd.conf" -t
  "${HTTPD_BIN}" -f "${ROOT}/httpd.conf" -k start
  sleep 1
  curl -fsS "http://127.0.0.1:${PORT}/" | grep -q "Jenkins Apache lab"
}

fake_errors() {
  curl -sS -o /dev/null -w "4xx:%{http_code}\n" "http://127.0.0.1:${PORT}/missing-page" || true
  curl -sS -o /dev/null -w "5xx:%{http_code}\n" "http://127.0.0.1:${PORT}/cgi-bin/boom.sh" || true
}

scan_logs() {
  LOG="${ROOT}/logs/access_log"
  test -f "${LOG}"
  echo "=== access_log ==="
  cat "${LOG}"
  awk '$9 ~ /^4[0-9][0-9]$/' "${LOG}" | tee "${ROOT}/logs/4xx.txt"
  awk '$9 ~ /^5[0-9][0-9]$/' "${LOG}" | tee "${ROOT}/logs/5xx.txt"
  test -s "${ROOT}/logs/4xx.txt"
  test -s "${ROOT}/logs/5xx.txt"
  echo "Found 4xx and 5xx entries"
}

install_pkg() {
  if command -v apache2 >/dev/null 2>&1 || command -v httpd >/dev/null 2>&1 || [ -x /usr/sbin/httpd ]; then
    echo "Apache already present"
    return 0
  fi
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y apache2 curl
  elif command -v brew >/dev/null 2>&1; then
    brew install httpd
  else
    echo "No package manager to install Apache" >&2
    exit 1
  fi
}

case "${ACTION}" in
  install)
    install_pkg
    write_tree
    detect_httpd
    "${HTTPD_BIN}" -v
    ;;
  start)
    detect_httpd
    write_tree
    write_conf
    start_httpd
    ;;
  errors)
    fake_errors
    ;;
  scan)
    scan_logs
    ;;
  stop)
    detect_httpd
    stop_httpd
    ;;
  all)
    install_pkg
    detect_httpd
    write_tree
    write_conf
    start_httpd
    fake_errors
    scan_logs
    stop_httpd
    ;;
  *)
    echo "usage: apache-lab.sh install|start|errors|scan|stop|all" >&2
    exit 2
    ;;
esac
