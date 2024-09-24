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
        powershell 'cargo wix -- --nocapture'
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
        powershell "D:\\jenkins-scripts\\deploy-artifacts.ps1 -target \".\\target\\wix\\cdi-alert-engine.msi\" -deploymentpath \"Fusion CAC 2 - CDI Alert Engine\\v\" -branch \"${env.BRANCH_NAME}\""
      }
    }

  }
}
