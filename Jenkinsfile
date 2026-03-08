pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "caramensuachua"
        IMAGE_NAME = "ecommerce-backend"
        DOCKER_HUB_CREDS = "docker-hub-creds" // ID credentials Docker Hub trong Jenkins
        GITOPS_CREDS = "github-token"      // ID credentials GitHub PAT trong Jenkins
        GITOPS_REPO = "github.com/CaramenSuaChua/ecommerce-gitops.git"
    }

    stages {
        stage('Checkout & Metadata') {
            steps {
                checkout scm
                script {
                    // Lấy mã hash ngắn của commit để làm tag
                    env.IMAGE_TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    echo "Backend Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }
    }

    post {
        failure {
            echo "Backend Pipeline failed!"
            sh "docker logout || true"
        }
    }
}