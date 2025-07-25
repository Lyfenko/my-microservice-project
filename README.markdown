# CI/CD Конвеєр для Django-додатка з Jenkins, Terraform, Helm та ArgoCD

Цей проєкт реалізує **автоматизований CI/CD конвеєр** для розгортання Django-додатка в AWS EKS за допомогою Jenkins, Terraform, Helm та ArgoCD. Конвеєр будує Docker-образ, пушить його в Amazon ECR, оновлює Helm-чарт і автоматично розгортає зміни в кластері через ArgoCD. Проєкт також включає **універсальний модуль RDS**, який дозволяє створювати Aurora Cluster або стандартний RDS разом із допоміжними ресурсами (DB Subnet Group, Security Group, Parameter Group).

---

## 📋 Огляд проєкту

**Мета**: Автоматизувати CI/CD для Django-додатка та надати гнучкий модуль для розгортання баз даних.

**Технології**:
- **Terraform**: Створення інфраструктури (VPC, EKS, ECR, S3, DynamoDB, RDS).
- **Helm**: Встановлення Jenkins, ArgoCD та розгортання Django-додатка.
- **Jenkins**: Побудова та пуш Docker-образів, оновлення Helm-чарту.
- **ArgoCD**: Автоматична синхронізація змін із Git у кластері.
- **AWS RDS**: Універсальний модуль для створення Aurora Cluster або стандартного RDS.
- **Prometheus/Grafana**: Моніторинг стану кластера та додатка.
- **HPA**: Горизонтальне автомасштабування Django-додатка.

**Репозиторій**: [https://github.com/Lyfenko/my-microservice-project.git](https://github.com/Lyfenko/my-microservice-project.git) (гілка: `lesson-db-module`)

---

## 🗂 Структура проєкту

```
my-microservice-project/
│
├── main.tf                 # Головний файл Terraform для інтеграції модулів
├── backend.tf              # Налаштування S3 та DynamoDB для стану Terraform
├── outputs.tf              # Виводи ресурсів
├── init.sh                 # Скрипт для ініціалізації та розгортання
├── Jenkinsfile             # Jenkins-конвеєр для CI/CD
├── charts/
│   ├── django-app/         # Helm-чарт для Django-додатка
│   │   ├── Chart.yaml      # Метаданий чарту
│   │   ├── values.yaml     # Налаштування (образ, сервіс, RDS)
│   │   ├── templates/
│   │   │   ├── configmap.yaml        # Змінні середовища
│   │   │   ├── deployment.yaml       # Deployment для Django
│   │   │   ├── service.yaml          # Сервіс LoadBalancer
│   │   │   ├── hpa.yaml              # Горизонтальне автоскейлінг
│   │   │   └── argocd-application.yaml  # ArgoCD Application
│   ├── monitoring/         # Helm-чарт для Prometheus і Grafana
│   │   ├── Chart.yaml      # Метаданий чарту
│   │   ├── values.yaml     # Налаштування Prometheus/Grafana
│   │   ├── templates/
│   │   │   ├── namespace.yaml        # Простір імен monitoring
│   │   │   ├── prometheus.yaml       # Deployment/Service для Prometheus
│   │   │   └── grafana.yaml          # Deployment/Service для Grafana
├── web/goit/               # Джерельний код Django
│   ├── Dockerfile          # Dockerfile для Django-додатка
│   ├── requirements.txt    # Залежності Python
│   ├── manage.py           # Скрипт керування Django
├── modules/
│   ├── s3-backend/         # S3 та DynamoDB для стану Terraform
│   ├── vpc/                # VPC, підмережі, NAT Gateway
│   ├── ecr/                # Репозиторій ECR
│   ├── eks/                # EKS-кластер і node group
│   ├── rds/                # Універсальний модуль RDS (PostgreSQL)
│   ├── jenkins/            # Helm-встановлення Jenkins
│   ├── argocd/             # Helm-встановлення ArgoCD
│   ├── monitoring/         # Helm-встановлення Prometheus/Grafana
├── storageclass.yaml       # StorageClass для EBS
└── README.markdown         # Документація проєкту
```

---

## 🚀 Модуль RDS

Модуль `rds` — це універсальний Terraform-модуль, який створює або **AWS Aurora Cluster**, або **стандартний RDS** залежно від значення змінної `use_aurora`. Він автоматично створює необхідні ресурси, такі як DB Subnet Group, Security Group та Parameter Group, забезпечуючи гнучкість і можливість багаторазового використання.

### Основні можливості

- **Гнучкий тип бази даних**:
  - `use_aurora = true`: Створюється Aurora Cluster із writer-інстансом.
  - `use_aurora = false`: Створюється стандартний RDS-інстанс.
- **Автоматичне створення ресурсів**:
  - **DB Subnet Group**: Групує підмережі для розгортання бази даних.
  - **Security Group**: Налаштовує мережевий доступ із заданими CIDR-блоками.
  - **Parameter Group**: Застосовує параметри бази даних (наприклад, `max_connections`, `log_statement`, `work_mem`).
- **Налаштування через змінні**: Підтримує конфігурацію двигуна, версії двигуна, класу інстансу тощо.
- **Багаторазове використання**: Модуль розроблено для повторного використання з мінімальними змінами змінних.

### Приклад використання

Щоб використати модуль `rds` у вашій Terraform-конфігурації:

```hcl
module "rds" {
  source = "./modules/rds"

  use_aurora         = false  # true для Aurora, false для стандартного RDS
  identifier         = "prod-db"
  engine             = "postgres"
  engine_version     = "15.7"
  instance_class     = "db.t3.micro"
  db_name            = "mydb"
  username           = "admin"
  password           = "securepassword123"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  allowed_cidr_blocks = ["10.0.0.0/16"]
  multi_az           = false

  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "log_statement"
      value = "ddl"
    },
    {
      name  = "work_mem"
      value = "4MB"
    }
  ]

  tags = {
    Environment = "production"
    Project     = "my-microservice"
  }
}
```

### Змінні модуля RDS

Нижче наведено всі змінні для конфігурації модуля `rds` з описами, типами та значеннями за замовчуванням.

| Змінна                  | Тип                 | Опис                                                                 | Значення за замовчуванням |
|-------------------------|---------------------|----------------------------------------------------------------------|--------------------------|
| `use_aurora`            | `bool`              | Створити Aurora Cluster (`true`) або стандартний RDS (`false`)       | `false`                  |
| `identifier`            | `string`            | Унікальний ідентифікатор для ресурсу бази даних                      | Немає                    |
| `engine`                | `string`            | Тип двигуна бази даних (наприклад, `postgres`, `mysql`)              | `postgres`               |
| `engine_version`        | `string`            | Версія двигуна бази даних                                           | `15.7`                   |
| `instance_class`        | `string`            | Клас інстансу бази даних (наприклад, `db.t3.micro`)                 | `db.t3.micro`            |
| `multi_az`              | `bool`              | Увімкнути розгортання в кількох зонах доступності (для RDS)         | `false`                  |
| `db_name`               | `string`            | Назва бази даних                                                    | `mydb`                   |
| `username`              | `string`            | Ім'я головного користувача                                          | `admin`                  |
| `password`              | `string`            | Пароль головного користувача (чутливий)                             | Немає                    |
| `port`                  | `number`            | Порт бази даних                                                     | `5432`                   |
| `allocated_storage`     | `number`            | Виділений обсяг пам’яті в ГБ (лише для RDS)                         | `20`                     |
| `storage_type`          | `string`            | Тип пам’яті (лише для RDS, наприклад, `gp2`)                        | `gp2`                    |
| `skip_final_snapshot`   | `bool`              | Пропустити створення фінального знімка при знищенні бази даних       | `true`                   |
| `backup_retention_period` | `number`          | Період збереження резервних копій у днях                            | `7`                      |
| `apply_immediately`     | `bool`              | Застосувати зміни негайно                                           | `false`                  |
| `vpc_id`                | `string`            | Ідентифікатор VPC для бази даних                                    | Немає                    |
| `subnet_ids`            | `list(string)`      | Список ідентифікаторів підмереж для DB Subnet Group                 | Немає                    |
| `allowed_cidr_blocks`   | `list(string)`      | Список дозволених CIDR-блоків для доступу до бази даних             | `[]`                     |
| `parameter_group_family`| `string`            | Сімейство параметрів бази даних (наприклад, `postgres15`)           | `postgres15`             |
| `parameters`            | `list(object)`      | Список параметрів бази даних (наприклад, `max_connections`)         | Список із 3 параметрами  |
| `tags`                  | `map(string)`       | Теги для ресурсів                                                   | `{}`                     |

**Примітка**: Змінна `parameters` за замовчуванням включає:
```hcl

[
  { name = "max_connections", value = "100" },
  { name = "log_statement", value = "all" },
  { name = "work_mem", value = "4MB" }
]
```

### Налаштування типу бази даних, двигуна та класу інстансу

- **Зміна типу бази даних**:
  - Встановіть `use_aurora = true` для створення **Aurora Cluster** із writer-інстансом.
  - Встановіть `use_aurora = false` для створення **стандартного RDS-інстансу**.

- **Зміна двигуна бази даних**:
  - Змініть змінну `engine`, наприклад, на `postgres` або `mysql`.
  - Переконайтеся, що `engine_version` відповідає вибраному двигуну (наприклад, `15.7` для PostgreSQL).

- **Зміна класу інстансу**:
  - Вкажіть потрібний клас у змінній `instance_class`, наприклад, `db.t3.micro` або `db.r5.large`.

- **Додаткові налаштування**:
  - Встановіть `multi_az = true` для увімкнення розгортання в кількох зонах доступності (лише для стандартного RDS).
  - Налаштуйте `parameters` для зміни конфігурації бази даних, наприклад, збільшення `max_connections`.

---

## ⚙️ Налаштування та запуск CI/CD конвеєра

### Вимоги

- **AWS CLI**: Налаштовано командою `aws configure`.
- **Terraform**: Версія >= 1.5.0.
- **kubectl**: Налаштовано для доступу до EKS.
- **Helm**: Для встановлення чартів.
- **argocd CLI**: Опціонально, для ручного керування ArgoCD.
- **Docker**: Для локальної побудови образів.
- **GitHub Token**: Для доступу Jenkins до репозиторію.
- **argocd CLI**: Опціонально, для ручного керування ArgoCD.

### Розгортання інфраструктури з Terraform

1. **Клонуйте репозиторій**:
   ```bash
   git clone https://github.com/Lyfenko/my-microservice-project.git
   cd my-microservice-project
   git checkout final_project
   ```
   
**Налаштуйте змінні середовища:**
```
export GIT_USERNAME=<ваш_GitHub_користувач>
export GIT_PASSWORD=<ваш_GitHub_токен>
```
2. **Виконайте скрипт ініціалізації**:
   ```bash
   chmod +x init.sh
   ./init.sh
   ```
   Скрипт створює:

    S3-бакет і DynamoDB для Terraform state.
    VPC, EKS, ECR, RDS.
    Jenkins, ArgoCD, Prometheus/Grafana через Helm.
    Застосовує ArgoCD Application для Django-додатка.
    Оновлює charts/django-app/values.yaml із RDS-параметрами.
    Будує та пушить Docker-образ у ECR.


3. **Перевірте виводи Terraform**:
   ```bash
   terraform output
   ```
   **Приклад виводів**:
   ```
   ecr_repository_url = "216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo"
   eks_cluster_endpoint = "https://7086C70AD2CD65B1C74113E638BBE11B.gr7.us-east-1.eks.amazonaws.com"
   eks_cluster_name = "lesson7-eks"
   vpc_id = "vpc-07f361c8bdf420cc9"
   rds_endpoint = "prod-db.cxxxxxxxxxxx.us-east-1.rds.amazonaws.com:5432"
   ```

### Налаштування та перевірка Jenkins Pipeline

1. **Доступ до Jenkins UI**:
   - Отримайте URL:
     ```bash
     export SERVICE_IP=$(kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
     echo $SERVICE_IP:8080
     ```
     **Приклад**: `http://a866681459fef49998fac46f78ea3bd2-790719666.us-east-1.elb.amazonaws.com:8080`
   - Отримайте пароль:
     ```bash
     kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
     ```
     **Приклад**: `admin`
   - Увійдіть із логіном `admin` і отриманим паролем.

2. **Налаштування Pipeline**:
   - Встановіть плагін “GitHub” у Jenkins: **Manage Jenkins → Manage Plugins**.
   - Додайте GitHub токен:
     - Перейдіть до **Manage Jenkins → Manage Credentials → Add Credentials**.
     - Тип: **Username with password**.
     - ID: `github-token`.
     - Ім’я користувача: ваше ім’я на GitHub.
     - Пароль: ваш персональний токен GitHub.
   - Створіть Pipeline:
     - Перейдіть до **Pipeline → New Item → Pipeline**.
     - SCM: **Git**.
     - URL репозиторію: `https://github.com/Lyfenko/my-microservice-project.git`.
     - Гілка: `main`.
     - Облікові дані: `github-token`.
     - Шлях до скрипта: `Jenkinsfile`.
   - Запустіть Pipeline і перевірте:
     - Образ у ECR: `216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:<BUILD_ID>`.
     - Оновлення `charts/django-app/values.yaml`.
     - Пуш змін у гілку `main`.

3. **Перевірка ECR**:
   ```bash
   aws ecr list-images --repository-name lesson7-django-repo --region us-east-1
   ```

### Перевірка ArgoCD та Django-додатка

1. **Доступ до ArgoCD UI**:
   - Отримайте URL:
     ```bash
     export ARGOCD_IP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
     echo $ARGOCD_IP
     ```
   - Отримайте пароль:
     ```bash
     kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
     ```
   - Увійдіть із логіном `admin` і отриманим паролем.

2. **Перевірка Application**:
   - У ArgoCD UI перевірте статус `django-app` (**Synced/Healthy**).
   - Або через CLI:
     ```bash
     kubectl get application -n argocd
     ```
     **Очікуваний вивід**:
     ```
     NAME         SYNC STATUS   HEALTH STATUS
     django-app   Synced        Healthy
     ```

3. cПеревірка Django-додатка**:
   - Перевірте поди:
     ```bash
     kubectl get pods -n default
     ```
     **Очікувано**: Django та PostgreSQL поди у стані `Running`.
   - Отримайте URL сервісу:
     ```bash
     export DJANGO_IP=$(kubectl get svc -n default django-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
     echo $DJANGO_IP:80
     ```
     **Приклад**: `http://afc50e85cfd3c4819b529dcfeefb6a6f-681129598.us-east-1.elb.amazonaws.com:80`
   - Відкрийте URL у браузері.

```Prometheus/Grafana:```

```Перевірте ресурси:```
   
 ``` bash

kubectl get all -n monitoring
```

```Доступ до Grafana:```
``` bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
Відкрийте: http://localhost:3000 (логін: admin, пароль: prom-operator).
```
---

## 🔄 Схема CI/CD конвеєра

### Jenkins
- Виявляє зміни в гілці `main`.
- Будує Docker-образ із `Dockerfile`.
- Пушить образ у ECR (`216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:<BUILD_ID>`).
- Оновлює `image.tag` у `charts/django-app/values.yaml`.
- Комітить і пушить зміни в Git.

### ArgoCD
- Стежить за гілкою `main` (`https://github.com/Lyfenko/my-microservice-project.git`).
- Виявляє зміни в `charts/django-app`.
- Синхронізує Helm-чарт для розгортання оновленого Django-додатка в EKS.

---

## 🛠 Усунення несправностей

### Jenkins UI недоступне
- Перевірте логи:
  ```bash
  kubectl logs -n jenkins jenkins-0 -c jenkins
  ```
- Переконайтеся, що порт `8080` відкритий у групі безпеки EKS.

### Поди Django в стані `InvalidImageName`
- Перевірте ECR:
  ```bash
  aws ecr list-images --repository-name lesson7-django-repo --region us-east-1
  ```
- Побудуйте та запуште образ:
  ```bash
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 216612008115.dkr.ecr.us-east-1.amazonaws.com
  docker build -t 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest .
  docker push 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest
  ```
- Синхронізуйте ArgoCD:
  ```bash
  argocd app sync django-app --namespace argocd
  ```

### Проблеми із синхронізацією ArgoCD
- Перевірте статус:
  ```bash
  kubectl describe application django-app -n argocd
  ```
- Переконайтеся, що Git-репозиторій доступний у ArgoCD UI або `argocd-secret`.