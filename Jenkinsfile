pipeline {
  agent any

  options {
    disableConcurrentBuilds()
  }

  environment {
    APACHE_PORT = '18080'
    APACHE_ROOT = "${WORKSPACE}/.apache-run"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Install Apache') {
      steps {
        sh 'chmod +x scripts/apache-lab.sh && scripts/apache-lab.sh install'
      }
    }

    stage('Start Apache') {
      steps {
        sh 'scripts/apache-lab.sh start'
      }
    }

    stage('Fake 4xx and 5xx') {
      steps {
        sh 'scripts/apache-lab.sh errors'
      }
    }

    stage('Scan Apache logs') {
      steps {
        sh 'scripts/apache-lab.sh scan'
      }
    }
  }

  post {
    always {
      sh 'scripts/apache-lab.sh stop || true'
      archiveArtifacts artifacts: '.apache-run/logs/*', allowEmptyArchive: true
    }
  }
}
