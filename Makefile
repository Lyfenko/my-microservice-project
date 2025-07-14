# ---------------------------
# Makefile для проєкту lesson-7
# ---------------------------

# Змінні
REGION = us-east-1
ACCOUNT_ID = $(shell aws sts get-caller-identity --query "Account" --output text)
ECR_REPO = lesson7-django-repo
IMAGE_NAME = lesson7-django
TAG = latest
ECR_URL = $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/$(ECR_REPO)

# ---------------------------
# Основні цілі
# ---------------------------

.PHONY: setup init plan apply destroy docker-build docker-push helm-deploy helm-delete

setup:
	@echo "🔧 Запуск setup.sh..."
	@chmod +x setup.sh
	@./setup.sh

init:
	@echo "🚀 Ініціалізація Terraform..."
	@chmod +x init.sh
	@./init.sh

plan:
	@echo "🔍 Terraform план..."
	terraform plan

apply:
	@echo "🚀 Terraform apply..."
	terraform apply -auto-approve

destroy:
	@echo "💥 Terraform destroy..."
	terraform destroy -auto-approve

docker-build:
	@echo "🐳 Збірка Docker образу..."
	docker build -t $(IMAGE_NAME) ./web

docker-tag:
	@echo "🏷️ Тегування Docker образу..."
	docker tag $(IMAGE_NAME):$(TAG) $(ECR_URL):$(TAG)

docker-login:
	@echo "🔑 Логін до ECR..."
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin $(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com

docker-push: docker-build docker-tag docker-login
	@echo "📦 Пуш Docker образу до ECR..."
	docker push $(ECR_URL):$(TAG)

helm-deploy:
	@echo "🚀 Деплой Helm-чарту..."
	helm upgrade --install django-app ./charts/django-app \
		--set awsAccountId=$(ACCOUNT_ID)

helm-delete:
	@echo "🗑️ Видалення Helm релізу..."
	helm uninstall django-app