pipeline {
  agent any
  stages {
    stage('Build Project') {
      when {
        expression {
          currentBuild.result != 'FAILURE'
        }
      }
      steps {
        powershell 'cargo build'
        powershell 'rm target/wix/*.msi'
        powershell 'cargo wix'
      }
    }

    stage('Archive Artifacts') {
      when {
        expression {
          currentBuild.result != 'FAILURE'
        }
      }
      steps {
        archiveArtifacts 'target/wix/*.msi'
      }
    }

    stage('Copy Artifacts To Windows Share') {
      when {
        expression {
          currentBuild.result != 'FAILURE'
        }
      }
      steps {
        powershell 'D:/jenkins-scripts/deploy-artifacts.ps1 -target "./target/wix/${{(ls target/wix/*.msi).Name}}" -deploymentpath "Fusion CAC 2 - CDI Alert Engine/v" -branch "${env.BRANCH_NAME}"'
      }
    }
  }
}
