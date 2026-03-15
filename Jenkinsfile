pipeline {
    agent any

    environment {
        // DOCKER
        IMAGE_NAME = "ecommerce-backend"
        DOCKER_REGISTRY = "caramensuachua"
        DOCKER_HUB_CREDS = "docker-hub-creds" // ID credentials Docker Hub trong Jenkins
        // HELM
        GITOPS_CREDS = "github-token"      // ID credentials GitHub PAT trong Jenkins
        GITOPS_REPO = "github.com/CaramenSuaChua/ecommerce-gitops.git"
        // SCANCODE
        SONAR_SERVER_NAME = "SonarQube"
        // AWS_INFOR
        AWS_ECR_REPO_NAME = "de150/ecommerce-backend"
        AWS_ACCOUNT_ID = "573051981771"
        AWS_CREDS_ID   = "aws-creds"   // ID credentials AWS trong Jenkins, chứa Access Key và Secret Key
        AWS_REGION     = "ap-southeast-1"
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
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
            when {
                expression { env.action == 'opened' || env.action == 'synchronize' }
            }
            steps {
                script {
                    // Bước này để Jenkins tự động tải và sử dụng tool sonar-scanner
                    def scannerHome = tool 'sonar-scanner'
                    
                    // PHẢI CÓ TÊN 'SonarQube' TRONG NGOẶC
                    withSonarQubeEnv('SonarQube') {
                        sh "${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=Ecommerce-Backend \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=http://18.139.185.108:9000 \
                            -Dsonar.java.binaries=." 
                    }
                    
                    timeout(time: 10, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline fail do Quality Gate của SonarQube báo lỗi: ${qg.status}"
                        }
                    }
                }
            }
        }

        // stage('Build & Push Backend Image') {
        //     when {
        //         expression { env.action == 'closed'}
        //     }
        //     steps {
        //         script {
        //             def repo = "${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}"
        //             def targetTag = "${repo}:${env.IMAGE_TAG}"

        //             withCredentials([usernamePassword(credentialsId: "${env.DOCKER_HUB_CREDS}", passwordVariable: 'DOCKER_PWD', usernameVariable: 'DOCKER_USER')]) {
        //                 sh "echo \$DOCKER_PWD | docker login -u \$DOCKER_USER --password-stdin"
                        
        //                 echo "--- Building Backend Image ---"
        //                 sh "docker build -t ${targetTag} ."

        //                 echo "--- Pushing Backend Image ---"
        //                 sh "docker push ${targetTag}"
                        
        //                 sh "docker logout"
        //             }
        //         }
        //     }
        // }

        stage ("Build & Push to ECR") {
            // when {
            //     expression { env.action == 'closed'}
            // }
            when {
                expression { env.action == 'opened' || env.action == 'synchronize' }
            }
            steps {
                script {
                    def ecrRepo = "${env.ECR_REGISTRY}/${env.AWS_ECR_REPO_NAME}"
                    def ecrTag = "${ecrRepo}:${env.IMAGE_TAG}"
                    def buildTimestamp = new Date().format("yyyyMMddHHmmss")

                    withCredentials([aws(credentialsId: "${env.AWS_CREDS_ID}", secretKeyVariable: 'AWS_SECRET_KEY', accessKeyVariable: 'AWS_ACCESS_KEY')]) {
                        sh '''
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY --profile jenkins
                            aws configure set aws_secret_access_key $AWS_SECRET_KEY --profile jenkins
                            aws configure set default.region ''' + AWS_REGION + ''' --profile jenkins
        
                            # Đăng nhập ECR
                            aws ecr get-login-password --region ''' + AWS_REGION + ''' --profile jenkins | docker login --username AWS --password-stdin ''' + env.ECR_REGISTRY + '''
        
                            echo "--- Building Backend Image ---"
                            docker build --build-arg BUILD_DATE=''' + buildTimestamp + ''' -t ''' + ecrTag + ''' .
        
                            echo "--- Pushing Image to ECR ---"
                            docker push ''' + ecrTag + '''
                            
                            docker logout ''' + env.ECR_REGISTRY + '''
                        '''
                    }
                }
            }
        }

        stage('Setup ECR Secret for K8s') {
            // when {
            //     expression { env.action == 'closed' }
            // }
            when {
                expression { env.action == 'opened' || env.action == 'synchronize' }
            }
            steps {
                script {
                    withCredentials([aws(credentialsId: "${env.AWS_CREDS_ID}", secretKeyVariable: 'AWS_SECRET_KEY', accessKeyVariable: 'AWS_ACCESS_KEY')]) {
                        sh '''
                            export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
                            export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
                            export AWS_DEFAULT_REGION=''' + AWS_REGION + '''
        
                            # 1. Lấy Token từ ECR
                            TOKEN=$(aws ecr get-login-password --region ''' + AWS_REGION + ''')
        
                            # 2. Khai báo biến Kubeconfig rõ ràng
                            export KUBECONFIG=/var/lib/jenkins/.kube/config
        
                            # 3. Tạo Secret (Dùng --validate=false để tránh lỗi OpenAPI redirect)
                            kubectl delete secret ecr-registry-helper -n ecommerce --ignore-not-found=true
                            
                            kubectl create secret docker-registry ecr-registry-helper \
                                --docker-server=''' + ECR_REGISTRY + ''' \
                                --docker-username=AWS \
                                --docker-password=$TOKEN \
                                --namespace ecommerce \
                                --validate=false
                            
                            echo "--- Secret ecr-registry-helper created successfully ---"
                        '''
                    }
                }
            }
        }

        stage('Update GitOps (Backend Tag)') {
            // when {
            //     expression { env.action == 'closed'}
            // }
            when {
                expression { env.action == 'opened' || env.action == 'synchronize' }
            }
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
                                sed -i '/backend:/,/repository:/ s|repository: .*|repository: ${env.ECR_REGISTRY}/${env.AWS_ECR_REPO_NAME}|' ${valuesPath}
                                sed -i '/backend:/,/tag:/ s|tag: .*|tag: ${env.IMAGE_TAG}|' ${valuesPath}
                            """

                            sh "git add ${valuesPath}"
                            sh "git commit -m 'Update backend to ECR Image ${env.AWS_ECR_REPO_NAME} [skip ci]' || echo 'No changes'"
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
