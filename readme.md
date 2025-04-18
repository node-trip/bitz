# Bitz Miner Manager Script

Этот скрипт упрощает установку, настройку, запуск и управление майнером BITZ для сети Eclipse

Он предназначен для систем на базе Debian/Ubuntu и автоматизирует следующие шаги:

*   Проверка и установка необходимых системных зависимостей (`build-essential`, `pkg-config`, `libssl-dev`, `clang`, `curl`, `screen`).
*   Установка Rust.
*   Установка Solana CLI (v1.18.2).
*   Установка Bitz CLI.
*   Создание или использование существующего кошелька Solana.
*   Настройка Solana RPC на эндпоинт Eclipse.
*   Интерактивный запрос количества CPU ядер для майнинга.
*   Запуск майнинга в фоновой сессии `screen`.
*   Предоставление опции для полного удаления всех установленных компонентов.

## Быстрый старт (Установка и Запуск)

Выполните следующую команду в вашем терминале, чтобы загрузить и запустить скрипт:

```bash
rm -f bitz_manager.sh && wget -nc --no-cache https://raw.githubusercontent.com/node-trip/bitz/refs/heads/main/bitz_manager.sh && chmod +x bitz_manager.sh && ./bitz_manager.sh
```

Скрипт задаст вам несколько вопросов в процессе установки и настройки.

## Опции скрипта

Вы можете запускать скрипт с дополнительными флагами:

*   `./bitz_manager.sh` (без флагов): Запускает интерактивное меню для установки/настройки или удаления.
*   `./bitz_manager.sh --uninstall`: Полностью удаляет Bitz CLI, Solana CLI, Rust и связанные конфигурации. **Используйте с осторожностью!**
*   `./bitz_manager.sh --show-key`: Показывает публичный адрес и приватный ключ текущего кошелька Solana (`~/.config/solana/id.json`). **Никому не показывайте приватный ключ!**
*   `./bitz_manager.sh --help` или `./bitz_manager.sh -h`: Показывает справку по использованию.

## Полезные команды (после установки)

*   `screen -r bitz_mining`: Подключиться к активной сессии майнинга.
    *   Внутри `screen`: `Ctrl+C` для остановки майнера, `Ctrl+A` затем `D` для отключения от сессии (майнер продолжит работать в фоне).
*   `bitz account`: Проверить баланс BITZ.
*   `bitz claim`: Заклеймить (забрать) намайненные BITZ.

**Важно:** Чтобы команды `bitz` и `solana` стали доступны в вашем терминале сразу после установки скриптом, может потребоваться выполнить `source ~/.bashrc` (или `source ~/.zshrc` для zsh) или просто открыть новое окно терминала.

## Поддержка и Обсуждение

Присоединяйтесь к обсуждению и следите за новостями в Telegram-канале: **[@nodetrip](https://t.me/nodetrip)**
