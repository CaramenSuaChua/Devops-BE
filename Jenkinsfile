pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = "caramensuachua"
        IMAGE_NAME = "ecommerce-backend"
        DOCKER_HUB_CREDS = "docker-hub-creds" // ID credentials Docker Hub trong Jenkins
        GITOPS_CREDS = "github-token"      // ID credentials GitHub PAT trong Jenkins
        GITOPS_REPO = "github.com/CaramenSuaChua/ecommerce-gitops.git"
        SONAR_SERVER_NAME = "SonarQube"
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

        stage('Code Quality (SonarQube)') {
            steps {
                script {
                    // 1. Khai báo tool scanner (khớp với tên 'sonar-scanner' trong ảnh d494ef.png)
                    def scannerHome = tool 'sonar-scanner'
                    
                    // 2. Truyền chính xác tên 'SonarQube' (khớp với ảnh d50fdc.png)
                    // Lưu ý: Phải bọc trong dấu nháy đơn ''
                    withSonarQubeEnv('SonarQube') {
                        // 3. Thực hiện lệnh quét (Phải nằm TRONG khối withSonarQubeEnv)
                        sh "${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=${env.IMAGE_NAME} \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=http://18.139.185.108:9000"
                    }
                    
                    // 4. Chốt chặn Quality Gate (Yêu cầu đã cấu hình Webhook trên SonarQube)
                    timeout(time: 10, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline dừng do code không đạt chất lượng: ${qg.status}"
                        }
                    }
                }
            }
        }

        stage('Build & Push Backend Image') {
            steps {
                script {
                    def repo = "${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}"
                    def targetTag = "${repo}:${env.IMAGE_TAG}"

                    withCredentials([usernamePassword(credentialsId: "${env.DOCKER_HUB_CREDS}", passwordVariable: 'DOCKER_PWD', usernameVariable: 'DOCKER_USER')]) {
                        sh "echo \$DOCKER_PWD | docker login -u \$DOCKER_USER --password-stdin"
                        
                        echo "--- Building Backend Image ---"
                        sh "docker build -t ${targetTag} ."

                        echo "--- Pushing Backend Image ---"
                        sh "docker push ${targetTag}"
                        
                        sh "docker logout"
                    }
                }
            }
        }

        stage('Update GitOps (Backend Tag)') {
            steps {
                script {
                    sh "rm -rf ecommerce-gitops"
                    withCredentials([usernamePassword(credentialsId: "${env.GITOPS_CREDS}", passwordVariable: 'GIT_PWD', usernameVariable: 'GIT_USER')]) {
                        sh "git clone https://${GIT_USER}:${GIT_PWD}@${env.GITOPS_REPO}"
                        
                        dir('ecommerce-gitops') {
                            sh "git config user.email 'ngodungvb0304@gmail.com'"
                            sh "git config user.name 'CaramenSuaChua'"

                            // LỆNH QUAN TRỌNG: Chỉ sửa tag trong khối 'backend:'
                            // Giả sử file values.yaml nằm ở thư mục gốc hoặc charts/values.yaml
                            def valuesPath = "ecommerce-chart/values.yaml" // Thay đổi đường dẫn này nếu cần
                            
                            sh """
                                sed -i '/backend:/,/tag:/ s|tag: .*|tag: ${env.IMAGE_TAG}|' ${valuesPath}
                            """

                            sh "git add ${valuesPath}"
                            sh "git commit -m 'Update backend image to ${env.IMAGE_TAG} [skip ci]' || echo 'No changes'"
                            sh "git push https://${GIT_USER}:${GIT_PWD}@${env.GITOPS_REPO} HEAD:main"
                        }
                    }
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
