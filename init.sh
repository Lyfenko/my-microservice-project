#!/bin/bash

# Configuration variables
BUCKET_NAME_PREFIX="lesson-5-tfstate-"
AWS_REGION="us-east-1"
DYNAMODB_TABLE_NAME="terraform-locks"
TFSTATE_KEY="lesson-5/terraform.tfstate"

# Отримання ID облікового запису AWS
echo "Отримання ID облікового запису AWS..."
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$ACCOUNT_ID" ]; then
  echo "Помилка: Не вдалося отримати ID облікового запису AWS. Перевірте свої AWS CLI налаштування."
  exit 1
fi

UNIQUE_BUCKET_NAME="${BUCKET_NAME_PREFIX}${ACCOUNT_ID}"
echo "Буде використано S3-бакет: $UNIQUE_BUCKET_NAME"

# Додавання та оновлення Helm-репозиторіїв
echo "Додавання Helm-репозиторіїв..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add jenkins https://charts.jenkins.io
helm repo update
echo "Helm-репозиторії оновлено!"

# --- Етап 1: Створення S3-бакету та таблиці DynamoDB ---

echo "--- Етап 1: Створення S3-бакету та таблиці DynamoDB ---"

echo "Очищення попередніх артефактів Terraform..."
rm -rf .terraform .terraform.lock.hcl tfplan_backend tfplan_main tfplan_helm
rm -f backend.tf.temp_bak main.tf.bak outputs.tf.bak

if [ -f backend.tf ]; then
    mv backend.tf backend.tf.temp_bak
fi

echo "Ініціалізація Terraform для створення ресурсів бекенду..."
terraform init -backend=false || { echo "Помилка: Початкова ініціалізація бекенду не вдалася."; exit 1; }

echo "Перевірка наявності S3 бакету..."
if aws s3 ls "s3://${UNIQUE_BUCKET_NAME}" &> /dev/null; then
  echo "S3 бакет ${UNIQUE_BUCKET_NAME} вже існує. Імпортуємо в Terraform..."
  terraform import module.s3_backend_bootstrap.aws_s3_bucket.terraform_state ${UNIQUE_BUCKET_NAME}
else
  echo "S3 бакет ${UNIQUE_BUCKET_NAME} не існує. Буде створено Terraform."
fi

echo "Перевірка наявності DynamoDB таблиці..."
if aws dynamodb describe-table --table-name ${DYNAMODB_TABLE_NAME} --region ${AWS_REGION} &> /dev/null; then
  echo "DynamoDB таблиця ${DYNAMODB_TABLE_NAME} вже існує. Імпортуємо в Terraform..."
  terraform import module.s3_backend_bootstrap.aws_dynamodb_table.terraform_locks ${DYNAMODB_TABLE_NAME}
else
  echo "DynamoDB таблиця ${DYNAMODB_TABLE_NAME} не існує. Буде створено Terraform."
fi

echo "Планування та застосування створення S3-бакету та таблиці DynamoDB..."
terraform apply -target=module.s3_backend_bootstrap -auto-approve -no-color || { echo "Помилка: Примусове застосування для створення ресурсів бекенду не вдалося."; exit 1; }

# --- Етап 2: Налаштування основного бекенду та розгортання інфраструктури ---

echo "--- Етап 2: Налаштування основного бекенду та розгортання інфраструктури ---"

echo "Заповнення backend.tf для повної конфігурації бекенду..."
cat <<EOF > backend.tf
terraform {
  backend "s3" {
    bucket         = "${UNIQUE_BUCKET_NAME}"
    key            = "${TFSTATE_KEY}"
    region         = "${AWS_REGION}"
    dynamodb_table = "${DYNAMODB_TABLE_NAME}"
    encrypt        = true
  }
}
EOF

echo "Очищення артефактів Terraform для розгортання основної інфраструктури..."
rm -rf .terraform .terraform.lock.hcl tfplan_main tfplan_helm

echo "Повторна ініціалізація Terraform з повним бекендом..."
echo -e "yes\nyes" | terraform init -migrate-state -force-copy || { echo "Помилка: Повторна ініціалізація основного бекенду не вдалося."; exit 1; }

echo "Перевірка наявності ECR репозиторію..."
if aws ecr describe-repositories --repository-names lesson7-django-repo --region ${AWS_REGION} &> /dev/null; then
  echo "ECR репозиторій lesson7-django-repo вже існує. Імпортуємо в Terraform..."
  terraform import module.ecr.aws_ecr_repository.repo lesson7-django-repo
else
  echo "ECR репозиторій lesson7-django-repo не існує. Буде створено Terraform."
fi

echo "Перевірка наявності IAM ролі..."
if aws iam get-role --role-name lesson7-eks-role --region ${AWS_REGION} &> /dev/null; then
  echo "IAM роль lesson7-eks-role вже існує. Імпортуємо в Terraform..."
  terraform import module.eks.aws_iam_role.eks_cluster_role lesson7-eks-role
else
  echo "IAM роль lesson7-eks-role не існує. Буде створено Terraform."
fi

echo "Планування розгортання інфраструктури без Helm-релізів..."
terraform plan -out=tfplan_main -target=module.vpc -target=module.ecr -target=module.eks || { echo "Помилка: Планування основної інфраструктури не вдалося."; exit 1; }

echo "Запуск terraform apply для розгортання інфраструктури без Helm-релізів..."
terraform apply "tfplan_main" || { echo "Помилка: Застосування основної інфраструктури не вдалося."; exit 1; }

echo "Оновлення kubeconfig для EKS..."
aws eks update-kubeconfig --region ${AWS_REGION} --name lesson7-eks || { echo "Помилка: Не вдалося оновити kubeconfig."; exit 1; }

echo "Перевірка доступу до EKS-кластера..."
kubectl cluster-info || { echo "Помилка: Не вдалося підключитися до EKS-кластера."; exit 1; }

echo "Перевірка наявності AWS EBS CSI драйвера..."
if ! kubectl get pods -n kube-system | grep ebs-csi-controller &> /dev/null; then
  echo "Встановлення AWS EBS CSI драйвера..."
  kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.35"
else
  echo "AWS EBS CSI драйвер уже встановлено."
fi

echo "Планування розгортання Helm-релізів (Argo CD і Jenkins)..."
terraform plan -out=tfplan_helm -target=module.argocd -target=module.jenkins || { echo "Помилка: Планування Helm-релізів не вдалося."; exit 1; }

echo "Запуск terraform apply для розгортання Helm-релізів..."
terraform apply "tfplan_helm" || { echo "Помилка: Застосування Helm-релізів не вдалося."; exit 1; }

# --- Етап 3: Застосування Argo CD Application ---

echo "--- Етап 3: Налаштування EKS та Helm ---"
echo "Застосування Argo CD Application..."
kubectl apply -f charts/django-app/argocd-application.yaml || { echo "Помилка: Не вдалося застосувати Argo CD Application."; exit 1; }

if [ -f backend.tf.temp_bak ]; then
    rm backend.tf.temp_bak
fi

echo "Розгортання завершено!"