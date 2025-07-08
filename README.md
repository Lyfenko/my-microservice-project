# Проєкт мікросервісу Django

Цей проєкт демонструє повний цикл розгортання Django-додатку на AWS з використанням сучасних DevOps інструментів:

- **Terraform** для інфраструктури (VPC, EKS, ECR)
- **Kubernetes** для оркестрації контейнерів
- **Helm** для керування розгортанням додатку
- **Docker** для контейнеризації додатку

## 📋 Основні характеристики

- Автоматизоване створення інфраструктури AWS (VPC, EKS, ECR)
- Розгортання Django-додатку в Kubernetes кластері
- Горизонтальне автомасштабування (HPA) для обробки навантаження
- Використання ConfigMap для керування змінними середовища
- Інтеграція PostgreSQL як сервісу бази даних
- Автоматизовані міграції бази даних при розгортанні

## ⚙️ Архітектура

![System Architecture Diagram](https://via.placeholder.com/800x400?text=System+Architecture+Diagram)

```
AWS Infrastructure (Terraform)
├── VPC (Public/Private Subnets)
├── EKS Cluster
└── ECR Repository

Kubernetes Deployment (Helm)
├── Django App
│   ├── Deployment (2-6 pods)
│   ├── Service (LoadBalancer)
│   ├── HPA (CPU-based scaling)
│   └── ConfigMap (Environment variables)
└── PostgreSQL
    ├── Deployment
    └── Service (ClusterIP)
```

## 📂 Структура проєкту

```
my-microservice-project/
├── modules/           # Terraform modules
│   ├── ecr/           # Elastic Container Registry
│   ├── eks/           # EKS Cluster
│   ├── s3-backend/    # Terraform state storage
│   └── vpc/           # Network configuration
├── charts/            # Helm charts
│   └── django-app/
│       ├── templates/ # Kubernetes manifests
│       └── values.yaml# Configuration parameters
├── web/               # Django application source
├── main.tf            # Main Terraform configuration
├── backend.tf         # Terraform state backend
├── outputs.tf         # Terraform outputs
├── init.sh            # Infrastructure initialization script
├── setup.sh           # Tool installation script
└── Makefile           # Automation commands
```

## 🚀 Швидкий старт

### Передумови

- AWS CLI з налаштованими credentials
- Terraform v1.0+
- Helm v3.0+
- Docker
- kubectl

### Ініціалізація інструментів

```bash
# Встановлення необхідних інструментів
./setup.sh

# Ініціалізація Terraform бекенду
./init.sh
```

### Розгортання інфраструктури

```bash
# Перегляд плану розгортання
terraform plan

# Застосування змін
terraform apply -auto-approve
```

### Збірка та завантаження образу Django

```bash
# Збірка Docker образу
docker build -t lesson7-django ./web

# Авторизація в ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query "Account" --output text).dkr.ecr.us-east-1.amazonaws.com

# Завантаження образу до ECR
docker tag lesson7-django:latest $(aws sts get-caller-identity --query "Account" --output text).dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest
docker push $(aws sts get-caller-identity --query "Account" --output text).dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest
```

### Розгортання застосунку в Kubernetes

```bash
# Встановлення застосунку за допомогою Helm
helm install django-app ./charts/django-app \
  --set awsAccountId=$(aws sts get-caller-identity --query "Account" --output text)
```

### Перевірка стану розгортання

```bash
# Перегляд подів
kubectl get pods

# Перегляд сервісів
kubectl get svc

# Перегляд HPA
kubectl get hpa
```

## 🛠️ Автоматизація з Makefile

```bash
# Повний деплой інфраструктури
make init
make apply

# Збірка та завантаження образу
make docker-build
make docker-push

# Розгортання застосунку
make helm-deploy

# Видалення застосунку
make helm-delete

# Повне знищення інфраструктури
make destroy
```

## 🔍 Перевірка роботи системи

### Отримання URL застосунку

```bash
kubectl get svc django-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Health check

```bash
curl http://<ELB_DNS>/health/
```

### Перегляд логів

```bash
kubectl logs -l app=django-app -c django
```

### Створення суперкористувача Django

```bash
kubectl exec -it $(kubectl get pods -l app=django-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py createsuperuser
```

## ⚖️ Горизонтальне масштабування (HPA)

Система автоматично масштабує кількість подів Django на основі CPU використання:

```yaml
spec:
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🌐 Доступ до застосунку

Після успішного розгортання застосунок буде доступний через публічний Load Balancer:

```
http://<load-balancer-dns>/
```

Адмінка Django буде доступна за адресою:

```
http://<load-balancer-dns>/admin/
```

## ♻️ Видалення ресурсів

### Видалення Helm релізу

```bash
helm uninstall django-app
```

### Видалення інфраструктури

```bash
terraform destroy -auto-approve
```

## 📄 Документація модулів

### Terraform Modules

#### Модуль VPC

- Створює VPC з публічними та приватними підмережами
- Налаштовує NAT Gateway для виходу в інтернет з приватних підмереж
- Вихідні дані: VPC ID, ID публічних та приватних підмереж

#### Модуль EKS

- Створює Kubernetes кластер на AWS EKS
- Налаштовує IAM ролі для кластера та вузлів
- Створює Node Group з автоскейлінгом
- Генерує kubeconfig для доступу до кластера

#### Модуль ECR

- Створює приватний Docker репозиторій в AWS ECR
- Налаштовує політику доступу
- Вихідні дані: URL репозиторію

### Helm Chart

#### django-app

- **Deployment**: Django додаток з init контейнерами для очікування БД та міграцій
- **Service**: LoadBalancer для публічного доступу
- **ConfigMap**: Зберігає змінні середовища для Django
- **HPA**: Горизонтальний Pod Autoscaler для автоматичного масштабування
- **PostgreSQL Deployment**: Контейнер з PostgreSQL
- **PostgreSQL Service**: Внутрішній сервіс для доступу до БД

## 🔒 Безпека

- **ECR Policies**: Репозиторій ECR налаштований з політикою доступу лише для аутентифікованих користувачів
- **Kubernetes RBAC**: EKS кластер налаштований з IAM ролями для автентифікації
- **ConfigMap**: Чутливі дані передаються через ConfigMap

## 🧩 Модульність

Проект розроблений з високою модульністю:

- **Terraform Modules**: Окремі модулі для VPC, EKS, ECR
- **Helm Charts**: Упакована конфігурація Kubernetes
- **Docker Containers**: Ізольоване середовище виконання
