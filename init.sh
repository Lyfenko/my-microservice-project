#!/bin/bash

# Змінні конфігурації
BUCKET_NAME_PREFIX="lesson-5-tfstate-"
AWS_REGION="us-east-1"
DYNAMODB_TABLE_NAME="terraform-locks"
TFSTATE_KEY="lesson-5/terraform.tfstate"

echo "Отримання ID облікового запису AWS..."
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$ACCOUNT_ID" ]; then
  echo "Помилка: Не вдалося отримати ID облікового запису AWS. Перевірте свої AWS CLI налаштування."
  exit 1
fi

UNIQUE_BUCKET_NAME="${BUCKET_NAME_PREFIX}${ACCOUNT_ID}"
echo "Буде використано S3-бакет: $UNIQUE_BUCKET_NAME"

# --- Етап 1: Створення S3-бакету та таблиці DynamoDB ---

echo "--- Етап 1: Створення S3-бакету та таблиці DynamoDB ---"

# Очищення будь-яких залишкових файлів стану Terraform або планів від попередніх запусків
echo "Очищення попередніх артефактів Terraform..."
rm -rf .terraform .terraform.lock.hcl tfplan_backend tfplan_main
rm -f backend.tf.temp_bak # Видалення тимчасової резервної копії backend.tf
rm -f main.tf.bak outputs.tf.bak # Видалення старих резервних копій, якщо вони залишилися

# Переміщення backend.tf, щоб примусово використовувати локальний стан для першого init
# Це запобігає спробам Terraform використовувати віддалений бекенд, якого ще не існує
if [ -f backend.tf ]; then
    mv backend.tf backend.tf.temp_bak # Тимчасово перемістити його
fi

echo "Ініціалізація Terraform для створення ресурсів бекенду (спочатку використовується локальний стан)..."
# Використання -backend=false для першого init дозволяє створювати S3/DynamoDB
terraform init -backend=false || { echo "Помилка: Початкова ініціалізація бекенду не вдалася."; exit 1; }

echo "Планування та примусове застосування створення S3-бакету та таблиці DynamoDB..."
# Використовуємо -destroy для модуля, щоб переконатися, що Terraform бачить потребу у "створенні",
# а потім відразу -apply для відновлення, форсуючи створення.
# ЦЕ ДУЖЕ АГРЕСИВНИЙ СПОСІБ, НЕ ДЛЯ ПРОДАКШЕНУ!
terraform destroy -target=module.s3_backend_bootstrap -auto-approve -no-color || true
echo "Зачекайте 10 секунд після спроби знищення..."
sleep 10 # Короткочасна пауза, щоб AWS відреагував на destroy (хоча його не було)

echo "Застосування для створення S3-бакету та таблиці DynamoDB (примусово)..."
terraform apply -target=module.s3_backend_bootstrap -auto-approve -no-color || { echo "Помилка: Примусове застосування для створення ресурсів бекенду не вдалося."; exit 1; }

# --- Етап 2: Налаштування основного бекенду та розгортання інфраструктури ---

echo "--- Етап 2: Налаштування основного бекенду та розгортання інфраструктури ---"

# Заповнення backend.tf фактичною конфігурацією S3
echo "Заповнення backend.tf для повної конфігурації бекенду..."
cat <<EOF > backend.tf
terraform {
  backend "s3" {
    bucket         = "${UNIQUE_BUCKET_NAME}"
    key            = "${TFSTATE_KEY}"
    region         = "${AWS_REGION}"
    use_lockfile   = true
    dynamodb_table = "${DYNAMODB_TABLE_NAME}"
    encrypt        = true
  }
}
EOF

# Очищення артефактів Terraform знову для свіжої повторної ініціалізації
echo "Очищення артефактів Terraform для розгортання основної інфраструктури..."
rm -rf .terraform .terraform.lock.hcl tfplan_main

echo "Повторна ініціалізація Terraform з повним бекендом (міграція стану)..."
# Тепер terraform init виявить зміну бекенду і запросить міграцію
terraform init -migrate-state || { echo "Помилка: Повторна ініціалізація основного бекенду не вдалася."; exit 1; }

echo "Планування розгортання решти інфраструктури..."
terraform plan -out=tfplan_main || { echo "Помилка: Планування основної інфраструктури не вдалося."; exit 1; }

echo "Запуск terraform apply для розгортання решти інфраструктури..."
terraform apply "tfplan_main" || { echo "Помилка: Застосування основної інфраструктури не вдалося."; exit 1; }

# Очищення тимчасової резервної копії backend.tf, якщо вона існує
if [ -f backend.tf.temp_bak ]; then
    rm backend.tf.temp_bak
fi

echo "Розгортання завершено!"