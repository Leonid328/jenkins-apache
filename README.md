# jenkins-apache

Jenkins pipeline: install/start Apache, send fake 404 and 500 requests, fail the build if those statuses are missing from `access_log`.

- `Jenkinsfile` — Pipeline from SCM
- `scripts/apache-lab.sh` — install, start, errors, scan, stop
- Apache runs in the job workspace on port `18080`

In Jenkins: New Item → Pipeline → Pipeline script from SCM → this repo, branch `main`, Script Path `Jenkinsfile` → Build Now.
