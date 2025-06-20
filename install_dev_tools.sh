#!/bin/bash

command_exists() {
    command -v "$1" &> /dev/null
}

check_python_version() {
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    if [[ "$python_version" < "3.9" ]]; then
        return 1
    else
        return 0
    fi
}

OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_TYPE=linux;;
    Darwin*)    OS_TYPE=mac;;
    *)          echo "Ця ОС не підтримується"; exit 1;;
esac

echo "Початок встановлення DevOps інструментів на $OS_TYPE..."

if [ "$OS_TYPE" = "mac" ]; then
    export PATH="/usr/local/bin:$PATH"
    echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
    source ~/.zshrc
fi

if [ "$OS_TYPE" = "linux" ]; then
    sudo apt update -y

    if ! command_exists docker; then
        echo "Встановлення Docker..."
        sudo apt install -y docker.io
        sudo systemctl enable --now docker
        sudo usermod -aG docker $USER
        echo "Docker успішно встановлено"
    else
        echo "Docker вже встановлений"
    fi

    if ! command_exists docker-compose; then
        echo "Встановлення Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose успішно встановлено"
    else
        echo "Docker Compose вже встановлений"
    fi

    if ! command_exists python3 || ! check_python_version; then
        echo "Встановлення Python 3.9+..."
        sudo apt install -y software-properties-common
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        sudo apt update
        sudo apt install -y python3.9 python3-pip
        echo "Python 3.9+ успішно встановлено"
    else
        echo "Python 3.9+ вже встановлений"
    fi

elif [ "$OS_TYPE" = "mac" ]; then
    if ! command_exists brew; then
        echo "Встановлення Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo "Homebrew успішно встановлено"
    else
        echo "Homebrew вже встановлений"
    fi

    brew update

    if ! command_exists docker; then
        echo "Встановлення Docker..."
        brew install --cask docker
        echo "Docker успішно встановлено. Будь ласка, завершіть налаштування в графічному інтерфейсі."
    else
        echo "Docker вже встановлений"
    fi

    if ! command_exists docker-compose; then
        echo "Встановлення Docker Compose..."
        brew install docker-compose
        brew link --overwrite docker-compose
        echo "Docker Compose успішно встановлено"
    else
        echo "Docker Compose вже встановлений"
    fi

    if ! command_exists python3 || ! check_python_version; then
        echo "Встановлення Python 3.9+..."
        brew install python
        brew link --overwrite python
        echo "Python 3.9+ успішно встановлено"
    else
        echo "Python 3.9+ вже встановлений"
    fi
fi

if ! command_exists pip3; then
    echo "Встановлення pip..."
    if [ "$OS_TYPE" = "linux" ]; then
        sudo apt install -y python3-pip
    else
        brew install pip
    fi
    echo "pip успішно встановлено"
else
    echo "pip вже встановлений"
fi

DJANGO_VENV="$HOME/django_venv"
if ! python3 -c "import django" &> /dev/null; then
    echo "Встановлення Django у віртуальному середовищі..."

    python3 -m venv "$DJANGO_VENV"

    source "$DJANGO_VENV/bin/activate"

    pip install django

    deactivate

    echo "Django успішно встановлено у віртуальному середовищі: $DJANGO_VENV"
    echo ""
    echo "Щоб використовувати Django:"
    echo "1. Активуйте віртуальне середовище: source $DJANGO_VENV/bin/activate"
    echo "2. Виконайте команду django-admin"
    echo "3. Деактивуйте середовище командою: deactivate"
else
    echo "Django вже встановлено"
fi

echo "✅ Усі інструменти успішно встановлено та налаштовано!"
echo ""
echo "Перевірка версій:"
docker --version || echo "Docker не встановлено"
docker-compose --version || echo "Docker Compose не встановлено"
python3 --version || echo "Python не встановлено"
pip3 --version || echo "pip не встановлено"

if [ -f "$DJANGO_VENV/bin/activate" ]; then
    echo ""
    echo "Перевірка версії Django у віртуальному середовищі:"
    source "$DJANGO_VENV/bin/activate"
    python -m django --version || echo "Django не встановлено у віртуальному середовищі"
    deactivate
fi

if [ "$OS_TYPE" = "mac" ] && ! command_exists docker; then
    echo ""
    echo "ВАЖЛИВО: Для завершення встановлення Docker на macOS:"
    echo "1. Відкрийте Docker з папки Applications"
    echo "2. Надайте необхідні дозволи в системних налаштуваннях"
    echo "3. Перезапустіть термінал після встановлення"
fi

if [ "$OS_TYPE" = "linux" ]; then
    echo ""
    echo "ВАЖЛИВО: Для роботи з Docker без sudo:"
    echo "1. Виконайте команду: newgrp docker"
    echo "2. Або перезайдіть в систему"
fi