#!/bin/bash

set -e

echo "🚀 Перевірка та встановлення потрібних інструментів..."

if ! command -v brew &> /dev/null
then
  echo "❌ Homebrew не знайдено. Встановлюю Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅ Homebrew встановлений."
fi

if ! command -v terraform &> /dev/null
then
  echo "❌ Terraform не знайдено. Встановлюю Terraform..."
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
else
  echo "✅ Terraform вже встановлено."
fi

# Встановлення kubectl
if ! command -v kubectl &> /dev/null
then
  echo "❌ kubectl не знайдено. Встановлюю kubectl..."
  brew install kubectl
else
  echo "✅ kubectl вже встановлено."
fi

if ! command -v helm &> /dev/null
then
  echo "❌ Helm не знайдено. Встановлюю Helm..."
  brew install helm
else#!/bin/bash

set -e

echo "🚀 Перевірка та встановлення потрібних інструментів..."

if ! command -v brew &> /dev/null
then
  echo "❌ Homebrew не знайдено. Встановлюю Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "✅ Homebrew встановлений."
fi

if ! command -v terraform &> /dev/null
then
  echo "❌ Terraform не знайдено. Встановлюю Terraform..."
  brew tap hashicorp/tap
  brew install hashicorp/tap/terraform
else
  echo "✅ Terraform вже встановлено."
fi

if ! command -v kubectl &> /dev/null
then
  echo "❌ kubectl не знайдено. Встановлюю kubectl..."
  brew install kubectl
else
  echo "✅ kubectl вже встановлено."
fi

if ! command -v helm &> /dev/null
then
  echo "❌ Helm не знайдено. Встановлюю Helm..."
  brew install helm
else
  echo "✅ Helm вже встановлено."
fi

echo ""
echo "🔍 Перевірка версій:"
terraform version
kubectl version --client
helm version

echo ""
echo "✅ Усі необхідні інструменти готові!"

  echo "✅ Helm вже встановлено."
fi

echo ""
echo "🔍 Перевірка версій:"
terraform version
kubectl version --client
helm version

echo ""
echo "✅ Усі необхідні інструменти готові!"
