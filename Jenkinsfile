// Jenkins CI/CD Pipeline — Azure Infrastructure (Terraform)
// Mirrors the GitHub Actions workflow but adds approval gates and richer reporting.
//
// Required Jenkins credentials (add under Manage Jenkins → Credentials → Global):
//   terraform-cloud-token   → Secret text  → your Terraform Cloud API token
//   azure-client-id         → Secret text  → Azure service principal app ID
//   azure-client-secret     → Secret text  → Azure service principal password
//   azure-subscription-id   → Secret text  → Azure subscription ID
//   azure-tenant-id         → Secret text  → Azure tenant ID
//
// Required Jenkins plugins:
//   Pipeline, Git, Credentials Binding, AnsiColor, Timestamper

pipeline {
    agent any

    options {
        ansiColor('xterm')          // coloured Terraform output
        timestamps()                // prefix every log line with time
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    // ── Credentials injected as environment variables ──────────────────────
    environment {
        // Terraform Cloud — used by `terraform init` for remote backend
        TF_TOKEN_app_terraform_io = credentials('terraform-cloud-token')
        TF_CLOUD_ORGANIZATION     = 'terraform-learningmyway'
        TF_WORKSPACE              = 'Azure-Jenkins-Terraform'

        // Azure service principal — used by azurerm provider
        ARM_CLIENT_ID       = credentials('azure-client-id')
        ARM_CLIENT_SECRET   = credentials('azure-client-secret')
        ARM_SUBSCRIPTION_ID = credentials('azure-subscription-id')
        ARM_TENANT_ID       = credentials('azure-tenant-id')

        // Suppress colour codes in plan output saved to file
        TF_CLI_ARGS_plan = '-no-color'
    }

    stages {

        // ── 1. Checkout ────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.GIT_BRANCH}  Commit: ${env.GIT_COMMIT[0..7]}"
            }
        }

        // ── 2. Terraform Init ──────────────────────────────────────────────
        stage('Terraform Init') {
            steps {
                sh '''
                    terraform version
                    terraform init -input=false
                '''
            }
        }

        // ── 3. Terraform Validate ──────────────────────────────────────────
        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        // ── 4. Terraform Plan ──────────────────────────────────────────────
        // Runs on every branch / PR — safe, read-only
        stage('Terraform Plan') {
            steps {
                sh '''
                    terraform plan \
                        -input=false \
                        -out=tfplan \
                        2>&1 | tee plan.txt
                '''
                // Archive the plan output so it's visible in the build artefacts
                archiveArtifacts artifacts: 'plan.txt', fingerprint: true
            }
        }

        // ── 5. Approval gate — only on main branch ─────────────────────────
        stage('Approval') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def planSummary = sh(
                        script: "grep -E '^Plan:|No changes' plan.txt || echo 'See plan.txt'",
                        returnStdout: true
                    ).trim()

                    input(
                        message: "Apply this Terraform plan to Azure?\n\n${planSummary}",
                        ok: 'Apply',
                        submitter: 'admin',   // change to your Jenkins username(s)
                        parameters: [
                            booleanParam(
                                name: 'CONFIRM',
                                defaultValue: false,
                                description: 'Tick to confirm you have reviewed the plan'
                            )
                        ]
                    )
                }
            }
        }

        // ── 6. Terraform Apply — only on main branch ───────────────────────
        stage('Terraform Apply') {
            when {
                branch 'main'
            }
            steps {
                sh 'terraform apply -input=false tfplan 2>&1 | tee apply.txt'
                archiveArtifacts artifacts: 'apply.txt', fingerprint: true
            }
        }

        // ── 7. Show Outputs ────────────────────────────────────────────────
        stage('Outputs') {
            when {
                branch 'main'
            }
            steps {
                sh 'terraform output 2>&1 || true'
            }
        }
    }

    // ── Post-build actions ─────────────────────────────────────────────────
    post {
        success {
            echo "Pipeline succeeded — infrastructure is up to date."
        }
        failure {
            echo "Pipeline FAILED. Check the logs above."
        }
        always {
            // Clean workspace to avoid stale plan files on next run
            cleanWs(patterns: [[pattern: 'tfplan', type: 'INCLUDE']])
        }
    }
}
