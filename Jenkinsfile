// ── CI Pipeline: test-frontend ───────────────────────────────────────────────
// Repo 1: test-frontend-app
//
// Flow:
//   1. Checkout code
//   2. Derive next semver tag from git tags
//   3. Build Docker image (nginx:alpine based)
//   4. Push to Docker Hub
//   5. Trigger CD job → updates GitOps repo → ArgoCD syncs to minikube
// ─────────────────────────────────────────────────────────────────────────────

pipeline {
    agent any

    environment {
        // ── Configure these in Jenkins Credentials ────────────────────────
        DOCKER_HUB_CREDS   = credentials('docker-hub-creds')   // Username + Password
        DOCKER_HUB_USER    = "${DOCKER_HUB_CREDS_USR}"
        // ─────────────────────────────────────────────────────────────────

        IMAGE_NAME         = "${DOCKER_HUB_USER}/test-frontend"
        SERVICE_FOLDER     = 'test-app/frontend'               // Path in GitOps repo
        CD_JOB_NAME        = 'test-app-CD'                     // Jenkins CD job name
    }

    stages {

        stage('SCM Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Derive Next Version Tag') {
            steps {
                script {
                    // Get latest git tag; default to v0.0.0 if none exist
                    def latestTag = sh(
                        script: "git tag --sort=-v:refname | head -n1 || echo 'v0.0.0'",
                        returnStdout: true
                    ).trim()

                    if (!latestTag || latestTag == '') latestTag = 'v0.0.0'

                    // Bump patch version: v1.2.3 → v1.2.4
                    def parts  = latestTag.replaceAll('^v', '').tokenize('.')
                    def major  = parts[0].toInteger()
                    def minor  = parts[1].toInteger()
                    def patch  = parts[2].toInteger() + 1

                    env.LATEST_TAG = latestTag
                    env.NEXT_TAG   = "v${major}.${minor}.${patch}"

                    echo "Latest tag : ${env.LATEST_TAG}"
                    echo "Next tag   : ${env.NEXT_TAG}"
                }
            }
        }

        stage('Docker Login') {
            steps {
                script {
                    sh "echo '${DOCKER_HUB_CREDS_PSW}' | docker login -u '${DOCKER_HUB_CREDS_USR}' --password-stdin"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                    docker build \
                        --build-arg APP_VERSION=${env.NEXT_TAG} \
                        -t ${env.IMAGE_NAME}:${env.NEXT_TAG} \
                        -t ${env.IMAGE_NAME}:latest \
                        .
                    """
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                script {
                    sh """
                    docker push ${env.IMAGE_NAME}:${env.NEXT_TAG}
                    docker push ${env.IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Create Git Tag') {
            steps {
                script {
                    sh """
                    git tag ${env.NEXT_TAG}
                    git push origin ${env.NEXT_TAG} || echo 'Tag push skipped (no remote auth in test)'
                    """
                }
            }
        }

        stage('Trigger CD Job') {
            steps {
                script {
                    build job: env.CD_JOB_NAME,
                        parameters: [
                            string(name: 'SERVICE_FOLDER', value: env.SERVICE_FOLDER),
                            string(name: 'NEW_IMAGE_TAG',  value: env.NEXT_TAG)
                        ],
                        wait: false   // fire and forget — ArgoCD takes it from here
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
            echo "CI pipeline complete"
        }
        success {
            echo "✅ Built and pushed ${env.IMAGE_NAME}:${env.NEXT_TAG} — CD job triggered"
        }
        failure {
            echo "❌ Pipeline failed — check logs above"
        }
    }
}
