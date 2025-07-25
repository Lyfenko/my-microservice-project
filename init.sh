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
  echo "Помилка: Не вдалося отримати ID облікового запису AWS."
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

# --- Етап 4: Розгортання RDS ---
echo "--- Етап 4: Розгортання RDS ---"
DB_NAME="appdb_$(date +%s)"
DB_USER="admin_$(date +%s)"
DB_PASSWORD=$(openssl rand -base64 16)

echo "DB_PASSWORD=$DB_PASSWORD" > db_credentials.txt

echo "Ініціалізація Terraform..."
terraform init || { echo "Помилка: ініціалізація Terraform не вдалася."; exit 1; }

if aws rds describe-db-subnet-groups --db-subnet-group-name prod-db-subnet-group --region us-east-1 &> /dev/null; then
  echo "DB Subnet Group prod-db-subnet-group вже існує."
  SUBNET_VPC=$(aws rds describe-db-subnet-groups --db-subnet-group-name prod-db-subnet-group --region us-east-1 --query 'DBSubnetGroups[0].VpcId' --output text)
  TF_VPC="vpc-05e145f791ff59f9b"
  if [ "$SUBNET_VPC" != "$TF_VPC" ] && [ "$SUBNET_VPC" != "None" ]; then
    echo "Помилка: prod-db-subnet-group прив’язана до іншої VPC ($SUBNET_VPC)."
    if aws rds describe-db-instances --region us-east-1 --query 'DBInstances[?DBSubnetGroup.DBSubnetGroupName==`prod-db-subnet-group`]' | grep -q '"DBInstanceIdentifier"'; then
      echo "Помилка: prod-db-subnet-group використовується. Оновіть main.tf."
      exit 1
    else
      echo "Видаляємо prod-db-subnet-group..."
      aws rds delete-db-subnet-group --db-subnet-group-name prod-db-subnet-group --region us-east-1
      terraform state rm module.rds.aws_db_subnet_group.default
    fi
  else
    echo "Імпортуємо prod-db-subnet-group..."
    terraform import module.rds.aws_db_subnet_group.default prod-db-subnet-group
  fi
else
  echo "DB Subnet Group prod-db-subnet-group не існує."
fi

if aws rds describe-db-parameter-groups --db-parameter-group-name prod-db-param-group --region us-east-1 &> /dev/null; then
  echo "DB Parameter Group prod-db-param-group вже існує."
  terraform import module.rds.aws_db_parameter_group.default prod-db-param-group
else
  echo "DB Parameter Group prod-db-param-group не існує."
fi

echo "Планування розгортання RDS..."
terraform apply -target=module.rds -auto-approve \
  -var="db_name=$DB_NAME" \
  -var="db_user=$DB_USER" \
  -var="db_password=$DB_PASSWORD" || { echo "Помилка: Застосування RDS не вдалося."; exit 1; }

RDS_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d':' -f1)

echo "Оновлення values.yaml..."
sed -i '' "s|host: .*|host: \"$RDS_ENDPOINT\"|" charts/django-app/values.yaml
sed -i '' "s|db: .*|db: \"$DB_NAME\"|" charts/django-app/values.yaml
sed -i '' "s|user: .*|user: \"$DB_USER\"|" charts/django-app/values.yaml
sed -i '' "s|password: .*|password: \"$DB_PASSWORD\"|" charts/django-app/values.yaml

echo "Виправлення імені образу..."
sed -i '' 's|{{ .Values.awsAccountId }}.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo|216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo|' charts/django-app/values.yaml
sed -i '' 's|.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo|216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo|' charts/django-app/values.yaml
sed -i '' '/awsAccountId:/d' charts/django-app/values.yaml

echo "Обробка backend.tf..."
if [ -f backend.tf ]; then
  echo "Додавання backend.tf до репозиторію..."
  git add backend.tf
  git commit -m "Додавання backend.tf для Terraform" || echo "Немає змін для коміту"
fi

echo "Перевірка гілки..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "Перемикаємося на main і зливаємо $CURRENT_BRANCH..."
  git checkout main
  git merge $CURRENT_BRANCH || { echo "Помилка: не вдалося злити $CURRENT_BRANCH у main."; exit 1; }
fi

echo "Коміт змін..."
git config user.email "jenkins@example.com"
git config user.name "Jenkins"
git add charts/django-app/values.yaml
git commit -m "Оновлення RDS і конфігурації" || echo "Немає змін для коміту"

if [ -z "$GIT_USERNAME" ] || [ -z "$GIT_PASSWORD" ]; then
  echo "Помилка: GIT_USERNAME або GIT_PASSWORD не встановлені."
  exit 1
fi
echo "Відправлення до GitHub..."
git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/Lyfenko/my-microservice-project.git main || { echo "Помилка: git push не вдався."; exit 1; }

echo "Локальна побудова Docker-образу..."
docker build -t 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest . || { echo "Помилка: не вдалося побудувати образ."; exit 1; }
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 216612008115.dkr.ecr.us-east-1.amazonaws.com || { echo "Помилка: не вдалося авторизуватися в ECR."; exit 1; }
docker push 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest || { echo "Помилка: не вдалося запушити образ."; exit 1; }

echo "Перевірка образу в ECR..."
if aws ecr describe-images --repository-name lesson7-django-repo --region us-east-1 | grep -q '"imageTag": "latest"'; then
  echo "Образ lesson7-django-repo:latest знайдено в ECR."
else
  echo "Помилка: образ lesson7-django-repo:latest відсутній у ECR."
  exit 1
fi

echo "Створення ECR секрету..."
kubectl create secret docker-registry ecr-secret \
  --docker-server=216612008115.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace default || echo "Секрет ecr-secret вже існує"

echo "Додавання imagePullSecrets до Deployment..."
kubectl patch deployment django-app -n default -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ecr-secret"}]}}}}' || echo "Не вдалося додати imagePullSecrets"

echo "Видалення застарілих ресурсів..."
kubectl delete pod -l app=django-app -n default --ignore-not-found
kubectl delete service db -n default --ignore-not-found
kubectl delete deployment postgres -n default --ignore-not-found

echo "Очищення кешу ArgoCD..."
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-application-controller -n argocd || echo "Не вдалося перезапустити контролер"
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-repo-server -n argocd || echo "Не вдалося перезапустити repo-server"

echo "Перевірка конфігурації ArgoCD..."
kubectl get application django-app -n argocd -o jsonpath='{.spec.source.repoURL}' | grep -q "https://github.com/Lyfenko/my-microservice-project.git" || {
  echo "Оновлення repoURL..."
  kubectl -n argocd patch application django-app -p '{"spec":{"source":{"repoURL":"https://github.com/Lyfenko/my-microservice-project.git","targetRevision":"main"}}}' --type merge
}

echo "Примусова синхронізація ArgoCD..."
kubectl -n argocd patch application django-app -p '{"spec":{"syncPolicy":{"syncOptions":["PruneLast=true","Force=true","ApplyOutOfSyncOnly=false"]}}}' --type merge
kubectl -n argocd wait --for=condition=Synced application django-app --timeout=900s || {
  echo "Помилка: ArgoCD не синхронізувався."
  kubectl describe application django-app -n argocd
  kubectl get pods -n default
  kubectl logs -l app.kubernetes.io/name=argocd-application-controller -n argocd --tail 100
  exit 1
}

echo "Перевірка стану django-app..."
if kubectl get application django-app -n argocd -o jsonpath='{.status.health.status}' | grep -q "Healthy"; then
  echo "django-app у стані Healthy."
else
  echo "Помилка: django-app у стані Degraded."
  kubectl get pods -n default
  for pod in $(kubectl get pods -n default -o name); do
    echo "Логи для $pod:"
    kubectl logs $pod -n default || echo "Не вдалося отримати логи"
  done
  exit 1
fi

echo "Планування Monitoring..."
terraform plan -out=tfplan_monitoring -target=module.monitoring || { echo "Помилка: Планування Monitoring не вдалося."; exit 1; }

echo "Розгортання Monitoring..."
terraform apply "tfplan_monitoring" || { echo "Помилка: Застосування Monitoring не вдалося."; exit 1; }

echo "Розгортання завершено!"

echo "Перевірка ресурсів:"
echo "Jenkins:"
kubectl get all -n jenkins
echo "ArgoCD:"
kubectl get all -n argocd
echo "Monitoring:"
kubectl get all -n monitoring
echo "Django App:"
kubectl get all -n default

echo "Інструкції для доступу:"
echo "Jenkins: kubectl port-forward svc/jenkins 8080:8080 -n jenkins; http://localhost:8080"
echo "ArgoCD: kubectl port-forward svc/argocd-server 8082:443 -n argocd; https://localhost:8082"
echo "Grafana: kubectl port-forward svc/grafana 3000:80 -n monitoring; http://localhost:3000"