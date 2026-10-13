# Jenkinsfile notes

A typical student file uses `sudo apt-get install apache2` on port 80. That needs root and only works on Linux.

This one keeps Apache in the workspace on port 18080, works on macOS (`httpd`) and Debian (`apache2`), generates a real 404 and 500, and scans `access_log` with awk.
