CI/CD конвеєр для Django-додатка з Jenkins, Terraform, Helm та ArgoCD
Цей проєкт реалізує автоматизований CI/CD конвеєр для розгортання Django-додатка в AWS EKS за допомогою Jenkins, Terraform, Helm та ArgoCD. Конвеєр будує Docker-образ, пушить його в Amazon ECR, оновлює Helm-чарт і автоматично розгортає зміни в кластері через ArgoCD.

📋 Огляд проєкту

Мета: Автоматизація CI/CD для Django-додатка.
Технології:
Terraform: Створення інфраструктури (VPC, EKS, ECR, S3, DynamoDB).
Helm: Встановлення Jenkins та ArgoCD.
Jenkins: Побудова та пуш Docker-образів, оновлення Helm-чарту.
ArgoCD: Автоматична синхронізація змін із Git у кластері.


Репозиторій: https://github.com/Lyfenko/my-microservice-project.git (гілка lesson-8-9).

```
🗂 Структура проєкту
my-microservice-project/
│
├── main.tf                 # Головний файл Terraform
├── backend.tf              # Налаштування S3 та DynamoDB для стану
├── outputs.tf              # Виводи ресурсів
├── init.sh                 # Скрипт для ініціалізації та розгортання
├── Jenkinsfile             # Jenkins конвеєр для CI/CD
├── charts/
│   └── django-app/         # Helm-чарт для Django-додатка
│       ├── Chart.yaml      # Метаданий чарту
│       ├── values.yaml     # Налаштування (образ, сервіс тощо)
│       ├── templates/
│       │   ├── deployment.yaml       # Deployment для Django
│       │   ├── service.yaml          # Сервіс LoadBalancer
│       │   ├── configmap.yaml        # Змінні середовища
│       │   ├── hpa.yaml              # Горизонтальне автоскейлінг
│       │   ├── postgres-deployment.yaml  # Deployment для PostgreSQL
│       │   └── postgres-service.yaml     # Сервіс для PostgreSQL
├── web/goit/               # Джерельний код Django
│   ├── __init__.py
│   ├── asgi.py
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
├── Dockerfile              # Dockerfile для Django-додатка
├── requirements.txt        # Залежності Python
├── modules/
│   ├── s3-backend/         # S3 та DynamoDB для стану Terraform
│   ├── vpc/                # VPC та мережеві ресурси
│   ├── ecr/                # Репозиторій ECR
│   ├── eks/                # EKS-кластер
│   ├── jenkins/            # Встановлення Jenkins через Helm
│   └── argo_cd/            # Встановлення ArgoCD через Helm
└── README.md               # Документація проєкту
```

🚀 Вимоги

AWS CLI: Налаштовано (aws configure).
Terraform: Версія >= 1.5.0.
kubectl: Налаштовано для доступу до EKS.
Helm: Для встановлення чартів.
argocd CLI: Опціонально, для ручного керування ArgoCD.
Docker: Для локальної побудови образів.
GitHub Token: Для доступу Jenkins до репозиторію.


⚙️ Налаштування та запуск
1. Розгортання інфраструктури з Terraform

Клонування репозиторію:
git clone https://github.com/Lyfenko/my-microservice-project.git
cd my-microservice-project
git checkout lesson-8-9


Виконання скрипту ініціалізації:

Скрипт init.sh створює S3-бекенд, VPC, EKS, ECR, встановлює Jenkins і ArgoCD, а також застосовує ArgoCD Application.

chmod +x init.sh
./init.sh


Перевірка виводів Terraform:
terraform output

Приклад:
ecr_repository_url = "216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo"
eks_cluster_endpoint = "https://7086C70AD2CD65B1C74113E638BBE11B.gr7.us-east-1.eks.amazonaws.com"
eks_cluster_name = "lesson7-eks"
vpc_id = "vpc-07f361c8bdf420cc9"




2. Налаштування та перевірка Jenkins Pipeline

Доступ до Jenkins UI:

Отримайте URL:export SERVICE_IP=$(kubectl get svc --namespace jenkins jenkins --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
echo http://$SERVICE_IP:8080

Приклад: http://a866681459fef49998fac46f78ea3bd2-790719666.us-east-1.elb.amazonaws.com:8080
Отримайте пароль:kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo

Приклад: admin
Увійдіть із логіном admin і паролем.

```
Налаштування Pipeline:

Встановіть плагін “GitHub” у Jenkins (Manage Jenkins → Manage Plugins).
Додайте GitHub токен:
Manage Jenkins → Manage Credentials → Add Credentials.
Тип: Username with password.
ID: github-token.
Ім’я користувача: ваше ім’я на GitHub.
Пароль: ваш персональний токен GitHub.
```
```
Створіть Pipeline:
Pipeline → New Item → Pipeline.
SCM: Git.
URL репозиторію: https://github.com/Lyfenko/my-microservice-project.git.
Гілка: main.
Облікові дані: github-token.
Шлях до скрипта: Jenkinsfile.
```

Запустіть Pipeline і перевірте:
Образ у ECR: 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:<BUILD_ID>.
Оновлення charts/django-app/values.yaml.
Пуш змін у гілку main.




Перевірка ECR:
aws ecr list-images --repository-name lesson7-django-repo --region us-east-1




3. Перевірка ArgoCD та Django-додатка

Доступ до ArgoCD UI:

Отримайте URL:export ARGOCD_IP=$(kubectl get svc --namespace argocd argocd-server --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
echo http://$ARGOCD_IP


Отримайте пароль:kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo


Увійдіть із логіном admin і паролем.


Перевірка Application:

У ArgoCD UI перевірте статус django-app (Synced/Healthy).
Або через CLI:kubectl get application -n argocd

Очікуваний вивід:NAME         SYNC STATUS   HEALTH STATUS
django-app   Synced        Healthy




Перевірка Django-додатка:

Перевірте поди:kubectl get pods -n default

Очікувано: Django та PostgreSQL поди у стані Running.
Отримайте URL сервісу:export DJANGO_IP=$(kubectl get svc --namespace default django-app --template "{{ range (index .status.loadBalancer.ingress 0) }}{{ . }}{{ end }}")
echo http://$DJANGO_IP:80

Приклад: http://afc50e85cfd3c4819b529dcfeefb6a6f-681129598.us-east-1.elb.amazonaws.com:80
Відкрийте URL у браузері.




🔄 Схема CI/CD конвеєра

Jenkins:

Виявляє зміни в гілці main.
Будує Docker-образ із Dockerfile.
Пушить образ у ECR (216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:<BUILD_ID>).
Оновлює image.tag у charts/django-app/values.yaml.
Комітить і пушить зміни в Git.


ArgoCD:

Стежить за гілкою main (https://github.com/Lyfenko/my-microservice-project.git).
Виявляє зміни в charts/django-app.
Синхронізує Helm-чарт для розгортання оновленого Django-додатка в EKS.




🛠 Усунення несправностей

Jenkins UI недоступне:

Перевірте логи:kubectl logs -n jenkins jenkins-0 -c jenkins


Переконайтеся, що порт 8080 відкритий у групі безпеки EKS.


Поди Django в стані InvalidImageName:

Перевірте ECR:aws ecr list-images --repository-name lesson7-django-repo --region us-east-1


Побудуйте та запуште образ:aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 216612008115.dkr.ecr.us-east-1.amazonaws.com
docker build -t 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest .
docker push 216612008115.dkr.ecr.us-east-1.amazonaws.com/lesson7-django-repo:latest


Синхронізуйте ArgoCD:argocd app sync django-app --namespace argocd




Проблеми із синхронізацією ArgoCD:

Перевірте статус:kubectl describe application django-app -n argocd


Переконайтеся, що Git-репозиторій доступний у ArgoCD UI або argocd-secret.

