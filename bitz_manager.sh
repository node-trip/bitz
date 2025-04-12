#!/bin/bash

# Цвета для вывода сообщений
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Вспомогательные функции ---

# Вывод сообщений
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Проверка наличия команды
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Запрос подтверждения у пользователя
confirm() {
    local message=$1
    local default=${2:-n} # По умолчанию 'n', если не указано
    local prompt=" (y/N)"
    if [[ "$default" == "y" || "$default" == "Y" ]]; then
        prompt=" (Y/n)"
    fi

    while true; do
        read -p "$(print_message $YELLOW "$message")${prompt}: " yn
        yn=${yn:-$default} # Если введен пустой ответ, используем значение по умолчанию
        case $yn in
            [Yy]* ) return 0;; # Success (true)
            [Nn]* ) return 1;; # Failure (false)
            * ) print_message $RED "Пожалуйста, ответьте 'y' или 'n'.";;
        esac
    done
}

# Проверка и установка системных зависимостей (для Debian/Ubuntu)
check_and_install_deps() {
    print_message $YELLOW "Проверка системных зависимостей..."
    local missing_deps=()
    local deps=("build-essential" "pkg-config" "libssl-dev" "clang" "curl" "screen") # nproc обычно входит в coreutils, не ставим отдельно

    if ! command_exists apt; then
         print_message $RED "Менеджер пакетов apt не найден. Скрипт предназначен для Debian/Ubuntu. Установите зависимости вручную."
         return 1
    fi

    for dep in "${deps[@]}"; do
        # Используем dpkg-query для более надежной проверки
        if ! dpkg-query -W -f='${Status}' "$dep" 2>/dev/null | grep -q "ok installed"; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_message $YELLOW "Обнаружены недостающие зависимости: ${missing_deps[*]}"
        if confirm "Установить их сейчас?"; then
            print_message $GREEN "Установка зависимостей..."
            # Проверяем, запущен ли скрипт от root
            if [ "$EUID" -eq 0 ]; then
                apt update || { print_message $RED "Не удалось обновить список пакетов (запуск от root)."; return 1; }
                apt install -y "${missing_deps[@]}" || { print_message $RED "Не удалось установить зависимости (запуск от root)."; return 1; }
            else
                 # Используем sudo, если не от root
                sudo apt update || { print_message $RED "Не удалось обновить список пакетов (требуется sudo)."; return 1; }
                sudo apt install -y "${missing_deps[@]}" || { print_message $RED "Не удалось установить зависимости (требуется sudo)."; return 1; }
            fi
            print_message $GREEN "Зависимости успешно установлены."
        else
            print_message $RED "Установка зависимостей отменена. Продолжение невозможно."
            return 1
        fi
    else
        print_message $GREEN "Все необходимые системные зависимости установлены."
    fi
    return 0
}

# Установка Rust
install_rust() {
    # Обновим PATH на случай, если Rust уже есть, но не в текущей сессии
    [[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

    if command_exists rustc; then
        print_message $GREEN "Rust уже установлен."
        return 0
    fi
    print_message $YELLOW "Rust не найден."
    if confirm "Установить Rust сейчас?"; then
        print_message $YELLOW "Установка Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        if [ $? -ne 0 ]; then
            print_message $RED "Ошибка установки Rust."
            return 1
        fi
        # Обновляем env для текущего скрипта
        source "$HOME/.cargo/env"
        print_message $GREEN "Rust успешно установлен."
        # Добавим в .bashrc/.zshrc для будущих сессий
        if [ -f "$HOME/.bashrc" ] && ! grep -q 'source "$HOME/.cargo/env"' "$HOME/.bashrc"; then
           echo '' >> ~/.bashrc # Newline
           echo '# Add Rust to PATH' >> ~/.bashrc
           echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
        fi
         if [ -f "$HOME/.zshrc" ] && ! grep -q 'source "$HOME/.cargo/env"' "$HOME/.zshrc"; then
           echo '' >> ~/.zshrc # Newline
           echo '# Add Rust to PATH' >> ~/.zshrc
           echo 'source "$HOME/.cargo/env"' >> ~/.zshrc
        fi
        print_message $YELLOW "Для использования Rust в новых терминалах может потребоваться перезапуск терминала или 'source \$HOME/.cargo/env'."
    else
        print_message $RED "Установка Rust отменена. Bitz CLI не может быть установлен без Rust."
        return 1
    fi
    return 0
}

# Установка Solana CLI
install_solana() {
    # Обновим PATH на случай, если Solana уже есть, но не в текущей сессии
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

     if command_exists solana; then
        print_message $GREEN "Solana CLI уже установлен."
        solana --version
        return 0
    fi
    print_message $YELLOW "Solana CLI не найден."
    if confirm "Установить Solana CLI (v1.18.2) сейчас?"; then
        print_message $YELLOW "Установка Solana CLI..."
        sh -c "$(curl -sSfL https://release.solana.com/v1.18.2/install)"
         if [ $? -ne 0 ]; then
            print_message $RED "Ошибка установки Solana CLI."
            return 1
        fi
        # Добавим PATH для текущей сессии и в конфиги шелла
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
         local path_line='export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
        if [ -f "$HOME/.bashrc" ] && ! grep -q '.local/share/solana/install/active_release/bin' "$HOME/.bashrc" ; then
            echo '' >> ~/.bashrc # Newline
            echo "# Add Solana to PATH" >> ~/.bashrc
            echo "$path_line" >> ~/.bashrc
        fi
         if [ -f "$HOME/.zshrc" ] && ! grep -q '.local/share/solana/install/active_release/bin' "$HOME/.zshrc" ; then
             echo '' >> ~/.zshrc # Newline
             echo "# Add Solana to PATH" >> ~/.zshrc
            echo "$path_line" >> ~/.zshrc
        fi
        print_message $GREEN "Solana CLI успешно установлен."
        print_message $YELLOW "Для использования Solana CLI в новых терминалах может потребоваться перезапуск терминала или обновление PATH."
        solana --version || print_message $RED "Не удалось проверить версию Solana. Возможно, PATH не обновился."
    else
        print_message $RED "Установка Solana CLI отменена. Невозможно продолжить без Solana."
        return 1
    fi
    return 0
}

# Установка Bitz CLI
install_bitz() {
    # Убедимся что cargo есть в PATH
    [[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
    if ! command_exists cargo; then
        print_message $RED "Команда 'cargo' (часть Rust) не найдена. Пожалуйста, установите Rust."
        return 1
    fi

    if command_exists bitz; then
        print_message $GREEN "Bitz CLI уже установлен."
        if confirm "Хотите проверить наличие обновлений и переустановить Bitz CLI?"; then
            print_message $YELLOW "Обновление/Переустановка Bitz CLI..."
        else
            return 0 # Не обновляем
        fi
    else
        print_message $YELLOW "Bitz CLI не найден."
        if ! confirm "Установить Bitz CLI сейчас?"; then
             print_message $RED "Установка Bitz CLI отменена."
             return 1
        fi
         print_message $YELLOW "Установка Bitz CLI..."
    fi

    # Выполняем установку/обновление
    cargo install bitz
     if [ $? -ne 0 ]; then
        print_message $RED "Ошибка установки/обновления Bitz CLI."
        return 1
    fi
    print_message $GREEN "Bitz CLI успешно установлен/обновлен."
    # Убедимся, что $HOME/.cargo/bin есть в PATH
     if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
        export PATH="$HOME/.cargo/bin:$PATH"
         print_message $YELLOW "Добавили \$HOME/.cargo/bin в PATH для текущей сессии."
    fi
    return 0
}

# Создание/Проверка кошелька Solana
setup_wallet() {
    if ! command_exists solana-keygen; then
        print_message $RED "Solana CLI (solana-keygen) не найден. Установите Solana CLI."
        return 1
    fi
    local keypair_path="$HOME/.config/solana/id.json"
    if [ -f "$keypair_path" ]; then
        print_message $GREEN "Обнаружен существующий кошелек Solana:"
        solana address
        if confirm "Использовать этот кошелек?" "y"; then # Предлагаем использовать существующий по умолчанию
            print_message $GREEN "Используется существующий кошелек."
            show_wallet_info # Покажем инфо на всякий случай
            return 0
        else
             if confirm "Создать НОВЫЙ кошелек? СТАРЫЙ КЛЮЧ БУДЕТ СОХРАНЕН В БЭКАП (.bak_)" "n"; then # Новый - не по умолчанию
                # Backup existing key
                local backup_path="${keypair_path}.bak_$(date +%Y%m%d_%H%M%S)"
                mv "$keypair_path" "$backup_path"
                print_message $YELLOW "Существующий ключ сохранен в $backup_path"
                # Продолжаем создание нового ключа ниже
             else
                 print_message $RED "Создание нового кошелька отменено. Невозможно продолжить без выбора кошелька."
                 return 1
             fi
        fi
    fi

    # Создаем новый кошелек, если старого нет или пользователь отказался от старого
    print_message $YELLOW "Создание нового кошелька Solana..."
    solana-keygen new --no-passphrase
    if [ $? -ne 0 ]; then
        print_message $RED "Ошибка создания кошелька."
        # Restore backup if exists
        if [ -n "$backup_path" ] && [ -f "$backup_path" ]; then
             mv "$backup_path" "$keypair_path"
             print_message $YELLOW "Восстановлен предыдущий ключ из бэкапа."
        fi
        return 1
    fi
    print_message $GREEN "Новый кошелек успешно создан."
    print_message $RED "ВАЖНО: Сохраните вашу сид-фразу и приватный ключ (показаны выше и в $keypair_path) в надежном месте!"
    show_wallet_info
    return 0
}

# Показать информацию о кошельке (приватный ключ)
show_wallet_info() {
    local keypair_path="$HOME/.config/solana/id.json"
     if ! command_exists solana; then
        print_message $RED "Solana CLI не найден."
        return 1
    fi
    if [ ! -f "$keypair_path" ]; then
         print_message $RED "Файл кошелька $keypair_path не найден."
         return 1
    fi
    print_message $YELLOW "\n--- Информация о текущем кошельке ---"
    print_message $GREEN "Публичный ключ (Адрес): $(solana address)"
    print_message $GREEN "Файл ключа: $keypair_path"
    if confirm "Показать приватный ключ (массив чисел)? Это небезопасно на чужих глазах!" "n"; then
        print_message $GREEN "Приватный ключ:"
        cat "$keypair_path"
        echo # Newline
        print_message $RED "Никогда никому не передавайте ваш приватный ключ или сид-фразу!"
    fi
    print_message $YELLOW "--- Конец информации о кошельке ---\n"
    return 0
}

# Настройка Solana RPC для Eclipse
configure_solana_rpc() {
     if ! command_exists solana; then
        print_message $RED "Solana CLI не найден."
        return 1
    fi
    local eclipse_rpc="https://eclipse.helius-rpc.com/"
    local current_rpc=$(solana config get | grep "RPC URL" | awk '{print $3}')

    if [ "$current_rpc" == "$eclipse_rpc" ]; then
        print_message $GREEN "Solana RPC уже настроен на Eclipse ($eclipse_rpc)."
        return 0
    fi

    print_message $YELLOW "Настройка RPC Solana на Eclipse ($eclipse_rpc)..."
    solana config set --url "$eclipse_rpc"
    if [ $? -ne 0 ]; then
        print_message $RED "Не удалось установить RPC."
        return 1
    fi
    # Проверка
    current_rpc=$(solana config get | grep "RPC URL" | awk '{print $3}')
    if [ "$current_rpc" == "$eclipse_rpc" ]; then
         print_message $GREEN "RPC успешно настроен на Eclipse."
    else
         print_message $RED "Не удалось проверить настройку RPC. Текущий RPC: $current_rpc"
         return 1
    fi
    return 0
}

# Настройка ядер для майнинга
configure_mining_cores() {
     if ! command_exists bitz; then
        print_message $RED "Bitz CLI не найден."
        return 1
    fi
    if ! command_exists nproc; then
         print_message $RED "Команда nproc не найдена. Не могу определить количество ядер. Установите 'coreutils' или укажите ядра вручную в команде 'bitz collect --cores X'."
         return 1
    fi

    # Используем глобальную переменную для хранения выбранных ядер
    local current_cores=$(bitz config get cores 2>/dev/null || echo "не установлено")
    local total_cores=$(nproc)
    local suggested_cores=$((total_cores > 1 ? total_cores - 1 : 1 ))

    print_message $YELLOW "Настройка количества CPU ядер для майнинга."
    print_message $YELLOW "Всего доступно ядер: $total_cores"
    print_message $YELLOW "Текущая настройка: $current_cores"
    print_message $YELLOW "Рекомендуется оставить 1-2 ядра свободными для системы (предлагаемое: $suggested_cores)."

    local cores_to_set
    while true; do # Запрашиваем ввод у пользователя
        read -p "Введите количество ядер для использования (рекомендуется $suggested_cores) или нажмите Enter, чтобы пропустить: " cores_input
        if [ -z "$cores_input" ]; then
            print_message $YELLOW "Настройка ядер пропущена. Будут использоваться значения по умолчанию Bitz CLI или предыдущая настройка ($current_cores)."
            return 0 # Пропускаем настройку
        fi
        # Проверка, что введено число
        if [[ "$cores_input" =~ ^[0-9]+$ ]]; then
            if [ "$cores_input" -gt 0 ] && [ "$cores_input" -le "$total_cores" ]; then
                 cores_to_set=$cores_input
                 break
            else
                 print_message $RED "Пожалуйста, введите число от 1 до $total_cores."
            fi
        else
             print_message $RED "Пожалуйста, введите корректное число."
        fi
    done

    # Сохраняем выбор в глобальную переменную (или можно передавать как аргумент)
    SELECTED_CORES=$cores_to_set
    print_message $GREEN "Выбрано $SELECTED_CORES ядер. Они будут применены при запуске майнинга."

    # Теперь эта функция просто сохраняет выбор, а не применяет его
    # local new_cores_check=$(bitz config get cores 2>/dev/null || echo "$cores_to_set (проверка недоступна)") # Убрали проверку config

    return 0
}

# Запуск майнинга в screen
start_mining() {
    if ! command_exists bitz; then
        print_message $RED "Bitz CLI не найден."
        return 1
    fi
     if ! command_exists screen; then
        print_message $RED "Screen не найден."
        return 1
    fi
     local keypair_path="$HOME/.config/solana/id.json"
      if [ ! -f "$keypair_path" ]; then
         print_message $RED "Файл кошелька $keypair_path не найден."
         return 1
     fi

     print_message $YELLOW "\nЗапуск майнинга в сессии screen 'bitz_mining'..."
     # Проверяем, есть ли уже сессия
     if screen -list | grep -q "bitz_mining"; then
         print_message $YELLOW "Сессия 'bitz_mining' уже существует."
          if confirm "Подключиться к существующей сессии вместо запуска новой?"; then
              print_message $GREEN "Подключение к сессии... (Чтобы выйти из screen: Ctrl+A, затем D)"
              # Запускаем screen в текущем терминале для подключения
              screen -r bitz_mining
              return 0 # Выходим после подключения
          else
              print_message $YELLOW "Запуск новой сессии отменен. Существующая сессия продолжит работу (если была запущена)."
              print_message $YELLOW "Вы можете вручную остановить её: screen -X -S bitz_mining quit"
              return 1
          fi
     fi

     # Формируем команду запуска с учетом выбранных ядер
     local start_command="bitz collect"
     if [ -n "$SELECTED_CORES" ]; then
         print_message $YELLOW "Запуск с $SELECTED_CORES ядрами."
         start_command="$start_command --cores $SELECTED_CORES"
     fi

     # Запускаем новую сессию в фоне, вывод теперь будет внутри screen
     screen -dmS bitz_mining bash -c "$start_command" # Убрали &> $log_file
      if [ $? -ne 0 ]; then
         print_message $RED "Не удалось запустить майнинг в screen."
         return 1
     fi

     print_message $GREEN "Майнинг успешно запущен в фоновой сессии screen 'bitz_mining'."
     print_message_summary # Выводим инфо после запуска
     return 0
}

# Вывод итоговой информации
print_message_summary() {
     print_message $YELLOW "\n--- Полезные команды ---"
     print_message $NC "Подключиться к сессии майнинга: screen -r bitz_mining"
     print_message $NC "  (Внутри screen: Ctrl+C чтобы остановить, Ctrl+A затем D чтобы отключиться, оставив работать)"
     print_message $NC "Проверить баланс BITZ:        bitz account"
     print_message $NC "Клейм (забрать) BITZ:         bitz claim"
     print_message $NC "Показать инфо о кошельке:     $(basename "$0") --show-key" # Ссылка на сам скрипт
     print_message $NC "Удалить все установленное:    $(basename "$0") --uninstall" # Ссылка на сам скрипт
     print_message $GREEN "-------------------------"
}


# Удаление компонентов
run_uninstall() {
    print_message $RED "\n--- Удаление компонентов BITZ ---"
    if ! confirm "Вы уверены, что хотите УДАЛИТЬ Bitz CLI, Solana CLI, Rust и конфигурацию кошелька Solana? Это действие НЕОБРАТИМО!" "n"; then
        print_message $YELLOW "Удаление отменено."
        return 1
    fi

    # Остановить майнинг, если запущен в screen
     if command_exists screen && screen -list | grep -q "bitz_mining"; then
        print_message $YELLOW "Остановка сессии майнинга 'bitz_mining'..."
        screen -X -S bitz_mining quit
        sleep 2 # Даем время процессу завершиться
    fi

    # Удалить Bitz CLI
    if command_exists bitz; then
         print_message $YELLOW "Удаление Bitz CLI..."
         if command_exists cargo; then
             cargo uninstall bitz || print_message $RED "Не удалось удалить bitz через cargo."
         else
              print_message $YELLOW "Команда cargo не найдена, не могу удалить bitz."
         fi
    else
        print_message $YELLOW "Bitz CLI не найден для удаления."
    fi

    # Удалить Solana CLI
    # Обновляем PATH чтобы найти solana-install
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    if command_exists solana-install; then
         print_message $YELLOW "Удаление Solana CLI..."
         # Запускаем деинсталлятор Solana в неинтерактивном режиме, если возможно
         # К сожалению, `solana-install uninstall` может быть интерактивным.
         # Попробуем удалить директорию напрямую, это надежнее.
         # solana-install uninstall # Может запросить подтверждение
         print_message $YELLOW "Удаление директории Solana: $HOME/.local/share/solana"
         rm -rf "$HOME/.local/share/solana"
         # Также удалим конфиг
          if [ -d "$HOME/.config/solana" ]; then
            print_message $YELLOW "Удаление конфигурации Solana ($HOME/.config/solana)..."
            rm -rf "$HOME/.config/solana"
         fi
    elif [ -d "$HOME/.local/share/solana" ]; then
         print_message $YELLOW "Удаление папки Solana CLI ($HOME/.local/share/solana)..."
         rm -rf "$HOME/.local/share/solana"
          if [ -d "$HOME/.config/solana" ]; then
            print_message $YELLOW "Удаление конфигурации Solana ($HOME/.config/solana)..."
            rm -rf "$HOME/.config/solana"
         fi
    else
         print_message $YELLOW "Solana CLI не найден для удаления."
    fi


    # Удалить Rust
    if command_exists rustup; then
         print_message $YELLOW "Удаление Rust..."
         rustup self uninstall -y || print_message $RED "Не удалось удалить Rust через rustup."
         # Дополнительно удаляем папки, т.к. rustup может что-то оставить
         rm -rf "$HOME/.cargo"
         rm -rf "$HOME/.rustup"
    elif [ -d "$HOME/.cargo" ] || [ -d "$HOME/.rustup" ]; then
         print_message $YELLOW "Удаление папок Rust (.cargo, .rustup)..."
         rm -rf "$HOME/.cargo"
         rm -rf "$HOME/.rustup"
    else
         print_message $YELLOW "Rust не найден для удаления."
    fi

    # Очистка PATH в .bashrc / .zshrc (простая попытка)
    print_message $YELLOW "Попытка удалить строки Solana и Rust из .bashrc и .zshrc..."
    if [ -f "$HOME/.bashrc" ]; then
        sed -i.bak '/\.local\/share\/solana\/install\/active_release\/bin/d' "$HOME/.bashrc"
        sed -i.bak '/source "\$HOME\/\.cargo\/env"/d' "$HOME/.bashrc"
        sed -i.bak '/# Add Solana to PATH/d' "$HOME/.bashrc"
        sed -i.bak '/# Add Rust to PATH/d' "$HOME/.bashrc"
        # Удаляем пустые строки в конце файла
        sed -i.bak -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$HOME/.bashrc"
    fi
     if [ -f "$HOME/.zshrc" ]; then
        sed -i.bak '/\.local\/share\/solana\/install\/active_release\/bin/d' "$HOME/.zshrc"
        sed -i.bak '/source "\$HOME\/\.cargo\/env"/d' "$HOME/.zshrc"
        sed -i.bak '/# Add Solana to PATH/d' "$HOME/.zshrc"
        sed -i.bak '/# Add Rust to PATH/d' "$HOME/.zshrc"
         sed -i.bak -e :a -e '/^\n*$/{$d;N;};/\n$/ba' "$HOME/.zshrc"
    fi


    print_message $GREEN "\nУдаление завершено."
    print_message $YELLOW "Рекомендуется перезапустить терминал для полного эффекта."
    return 0
}


# --- Основная логика ---
run_install_or_manage() {
    SELECTED_CORES="" # Инициализируем переменную для ядер
    print_message $GREEN "======================================="
    print_message $GREEN "    Менеджер майнинга BITZ на Eclipse"
    print_message $GREEN "======================================="

    # 1. Зависимости
    if ! check_and_install_deps; then exit 1; fi

    # 2. Rust
    if ! install_rust; then exit 1; fi

    # 3. Solana
    if ! install_solana; then exit 1; fi

    # 4. Bitz
    if ! install_bitz; then exit 1; fi

    # 5. Кошелек
    if ! setup_wallet; then exit 1; fi

    # 6. RPC
    if ! configure_solana_rpc; then exit 1; fi

    # 7. Ядра CPU
    if ! configure_mining_cores; then
      print_message $YELLOW "Продолжаем без явной пользовательской настройки ядер..."
      # Не выходим, т.к. это не критично для запуска, bitz может использовать свои дефолты
    fi

    # 8. Запуск майнинга
    # Напоминание перед запуском
    print_message $YELLOW "\n--- Подготовка к запуску майнинга ---"
    print_message $YELLOW "Для старта майнинга требуется минимум 0.005 ETH в сети Eclipse."
    print_message $YELLOW "Убедитесь, что ваш кошелек: $(solana address) пополнен."

    if confirm "Запустить майнинг BITZ сейчас?"; then
        start_mining
    else
        print_message $YELLOW "Майнинг не был запущен."
        print_message_summary # Все равно покажем полезные команды
    fi

    print_message $GREEN "\nСкрипт завершил основную работу."
    # Добавляем сообщение о необходимости обновить PATH в текущей сессии
    print_message $YELLOW "\n------------------------------------------------------------------"
    print_message $YELLOW "ВАЖНО: Чтобы команды 'bitz' и 'solana' заработали в ЭТОМ ЖЕ терминале,"
    print_message $YELLOW "выполните:\n"
    print_message $NC "  source \$HOME/.cargo/env && export PATH=\"\$HOME/.local/share/solana/install/active_release/bin:\$PATH\""
    print_message $YELLOW "\nЛибо просто откройте НОВЫЙ терминал."
    print_message $YELLOW "------------------------------------------------------------------"
    exit 0
}


# --- Обработка аргументов командной строки и запуск ---

# Убедимся, что переменная существует глобально
SELECTED_CORES=""

# Обновим PATH для текущей сессии сразу
export PATH="$HOME/.local/share/solana/install/active_release/bin:$HOME/.cargo/bin:$PATH"
[[ -s "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"


# Проверяем аргументы
if [ "$1" == "--uninstall" ]; then
    run_uninstall
    exit $?
elif [ "$1" == "--show-key" ]; then
     if ! command_exists solana; then
         print_message $RED "Solana CLI не установлен. Не могу показать ключ."
         exit 1
     fi
     local keypair_path="$HOME/.config/solana/id.json"
     if [ ! -f "$keypair_path" ]; then
         print_message $RED "Файл кошелька $keypair_path не найден."
         exit 1
     fi
     print_message $GREEN "Адрес кошелька: $(solana address)"
     print_message $YELLOW "Содержимое файла ключа ($keypair_path):"
     cat "$keypair_path"
     echo
     print_message $RED "Никому не показывайте этот приватный ключ!"
     exit 0
elif [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
     echo "Использование: $(basename "$0") [опция]"
     echo ""
     echo "Опции:"
     echo "  (без опций)   - Запускает интерактивную установку и настройку майнера BITZ."
     echo "  --uninstall   - Удаляет BITZ, Solana, Rust и связанные конфигурации."
     echo "  --show-key    - Показывает публичный адрес и приватный ключ из файла ~/.config/solana/id.json."
     echo "  --help, -h    - Показывает это сообщение."
     echo ""
     echo "Примеры команд Bitz CLI (после установки):"
     echo "  bitz collect         - Запустить майнинг (используйте в screen)"
     echo "  bitz account         - Проверить баланс"
     echo "  bitz claim           - Клеймить токены"
     echo "  bitz config set cores <N> - Установить N ядер для майнинга"
     exit 0
fi


# Если нет аргументов или аргумент не распознан, запускаем основной сценарий или спрашиваем
if [ -z "$1" ]; then
    clear
    print_message $YELLOW "Выберите действие:"
    print_message $NC "1. Установить / Настроить / Запустить майнер BITZ"
    print_message $NC "2. Удалить все компоненты BITZ"
    print_message $NC "0. Выход"
    read -p "Ваш выбор: " main_choice

    case $main_choice in
        1) run_install_or_manage ;;
        2) run_uninstall ;;
        0) print_message $GREEN "Выход."; exit 0 ;;
        *) print_message $RED "Неверный выбор."; exit 1 ;;
    esac
else
    print_message $RED "Неизвестная опция: $1"
    print_message $YELLOW "Используйте '$(basename "$0") --help' для справки."
    exit 1
fi
