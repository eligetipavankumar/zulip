pipeline {
    agent any

    environment {
        IMAGE_NAME = "zulip-app"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        FULL_IMAGE = "eligetipavankumar/${IMAGE_NAME}:${IMAGE_TAG}"   // <--- update with your Docker Hub username
        KUBE_NAMESPACE = "zulip-app"
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                bat """
                  echo Building Docker image...
                  docker build -t %FULL_IMAGE% .
                """
            }
        }

        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'DOCKER_USER',
                                                  usernameVariable: 'DOCKER_USER',
                                                  passwordVariable: 'DOCKER_PASS')]) {
                    bat """
                      echo Logging into Docker Hub...
                      echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                      echo Pushing image to Docker Hub...
                      docker tag %FULL_IMAGE% your-dockerhub-username/zulip-app:latest
                      docker push %FULL_IMAGE%
                      docker push eligetipavankumar/zulip-app:latest
                    """
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                bat """
                  echo Deploying Zulip to Minikube...
                  kubectl create namespace %KUBE_NAMESPACE% --dry-run=client -o yaml | kubectl apply -f -
                  kubectl apply -n %KUBE_NAMESPACE% -f k8s/
                """
            }
        }
    }

    post {
        success {
            echo "✅ Zulip deployed successfully to Minikube."
        }
        failure {
            echo "❌ Pipeline failed. Check logs."
        }
    }
}

