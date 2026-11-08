# Архитектура локального ИИ: macOS, Ollama и VS Code Dev Containers

**Расположение документа:** `~/.config/vscode/local-ai-architecture.md` (в репозитории dotfiles — соответствующий путь `.config/vscode/local-ai-architecture.md`). Пути ниже указаны относительно домашнего каталога macOS, если не сказано иное.

## 1. Назначение

Локальный помощник для C++ и других проектов в VS Code: Ollama использует GPU Mac через Metal, а Continue работает внутри отдельных ARM64 Dev Containers. Контейнеры Qwen не должны иметь прямого доступа к интернету и домашней сети. Для каждого проекта создаётся собственный контейнер с доступом к его `/workspace`; конфигурация моделей Continue общая и монтируется только для чтения.

## 2. Схема соединений

```text
VS Code на macOS
  └─ Dev Container Qwen (ARM64, отдельный для каждого проекта)
       ├─ /workspace — текущий проект
       ├─ Continue
       │    ├─ qwen3-coder:30b      — чат / редактирование / применение правок
       │    └─ qwen2.5-coder:1.5b — автодополнение
       └─ qwen-isolated (внутренняя сеть Docker)
              │ http://ollama-gateway:8080
              ▼
         qwen-ollama-gateway (Nginx)
              │ http://host.docker.internal:11435
              ▼
         socat на macOS (127.0.0.1:11435)
              │ перенаправление на 127.0.0.1:11434
              ▼
         Ollama на macOS (127.0.0.1:11434)
              └─ Metal; запуск под Seatbelt через Ollama Sandbox Manager
```

Nginx подключён к двум сетям: `qwen-isolated` и `qwen-uplink`. Контейнер Qwen подключён **только к `qwen-isolated`**. Порт Nginx не опубликован на хосте. `socat` слушает исключительно loopback-интерфейс macOS; Docker Desktop обращается к нему через `host.docker.internal`.

## 3. Расположение конфигурации

| Компонент | Путь или имя | Назначение |
| --- | --- | --- |
| Этот документ | `~/.config/vscode/local-ai-architecture.md` | Описание всей системы |
| Универсальный Dev Container | `~/.config/vscode/devcontainer/qwen/devcontainer.json` | Подключается к проектам как `.devcontainer` |
| Общая конфигурация Continue | `~/.config/vscode/devcontainer/qwen/continue/config.yaml` | Монтируется в `/home/vscode/.continue/config.yaml`, только чтение |
| Docker Compose шлюза | `~/.config/vscode/devcontainer/qwen/gateway/compose.yaml` | Управление Nginx; сети объявлены как внешние |
| Конфигурация Nginx | `~/.config/vscode/devcontainer/qwen/gateway/nginx.conf` | Фиксированный upstream, замена заголовка `Host` |
| Внутренняя сеть | `qwen-isolated` | Qwen и Nginx |
| Сеть шлюза с выходом наружу | `qwen-uplink` | Только Nginx |
| Контейнер шлюза | `qwen-ollama-gateway` | Nginx, внутренний порт 8080 |
| Ollama Sandbox Manager | Отдельный проект macOS | Запуск Ollama под Seatbelt; интеграцию управления `socat` необходимо проверять отдельно |

## 4. Модели и Continue

Наличие моделей подтверждено запросом `GET /api/tags`:

- `qwen3-coder:30b` — чат, редактирование и применение правок;
- `qwen2.5-coder:1.5b` — автодополнение при вводе.

Обе модели используют `apiBase: http://ollama-gateway:8080`.

Пример структуры `config.yaml` (не заменяйте рабочие дополнительные параметры без необходимости):

```yaml
name: Local Qwen
version: 1.0.0
schema: v1
models:
  - name: Qwen3 Coder 30B
    provider: ollama
    model: qwen3-coder:30b
    apiBase: http://ollama-gateway:8080
    roles: [chat, edit, apply]
  - name: Qwen2.5 Coder 1.5B
    provider: ollama
    model: qwen2.5-coder:1.5b
    apiBase: http://ollama-gateway:8080
    roles: [autocomplete]
```

Автодополнение Continue отображается **серым текстом прямо в редакторе**: `Tab` — принять, `Esc` — отклонить. Это не выпадающий список подсказок clangd; оба механизма могут работать одновременно.

Каталог `/home/vscode/.continue` должен существовать в образе и принадлежать пользователю `vscode`; **только файл `config.yaml`** монтируется в режиме read-only. Монтирование всего каталога только для чтения приводило к проблемам с активацией Continue.

## 5. Docker-образы и происхождение

```text
local/devcontainer:trixie        ← исходный ARM64-образ Codex; не изменять
  └─ local/devcontainer-base:arm64
       └─ local/devcontainer-qwen:arm64
            └─ local/devcontainer-qwen:clean ← используется Qwen
```

- `base:arm64`: создаёт `/home/vscode/.continue` с владельцем `vscode:vscode` и правами `700`.
- `qwen:arm64`: удаляет из `/home/vscode/.bashrc` шесть экспортируемых переменных: `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `http_proxy`, `https_proxy`, `no_proxy`.
- `qwen:clean`: заменяет унаследованную метку `devcontainer.metadata` на `[]`.

**Почему это важно.** Исходный образ Codex содержал в `devcontainer.metadata` команды `postCreateCommand` и `postStartCommand`, монтирование авторизации Codex, домашнего `.docker` и `/var/run/docker.sock`. Без очистки метаданных Dev Containers наследовал эти настройки, даже когда их не было в текущем `devcontainer.json`.


Для воспроизводимости следует сохранить Dockerfile в dotfiles. Пример объединения выполненных изменений:

```dockerfile
FROM local/devcontainer:trixie
USER root
RUN install -d -o vscode -g vscode -m 700 /home/vscode/.continue \
    && sed -i -E '/^[[:space:]]*export (HTTP_PROXY|HTTPS_PROXY|NO_PROXY|http_proxy|https_proxy|no_proxy)=/d' /home/vscode/.bashrc
LABEL devcontainer.metadata="[]"
USER vscode
```

Это **пример**, а не уже сохранённый Dockerfile. При сборке используйте отдельный тег, не перезаписывая исходный образ Codex.

## 6. Изоляция Qwen Dev Container

Основные параметры универсального `devcontainer.json`:

```json
{
  "image": "local/devcontainer-qwen:clean",
  "runArgs": [
    "--security-opt=no-new-privileges",
    "--cap-drop=ALL",
    "--network=qwen-isolated"
  ],
  "remoteUser": "vscode",
  "workspaceFolder": "/workspace",
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=cached",
  "mounts": [
    "source=vscode-extensions-qwen,target=/home/vscode/.vscode-server/extensions,type=volume",
    "source=vscode-extensions-cache-qwen,target=/home/vscode/.vscode-server/extensionsCache,type=volume",
    "source=${localEnv:HOME}/.config/vscode/devcontainer/qwen/continue/config.yaml,target=/home/vscode/.continue/config.yaml,type=bind,readonly"
  ],
  "containerEnv": {"TZ": "Europe/Moscow"}
}
```

Это **фрагмент действующей конфигурации**, а не полный файл: в оригинале также заданы имя контейнера, расширения и параметры VS Code.

После пересборки были подтверждены монтирования:

```text
/vscode                                         — служебный том VS Code
/workspace                                      — текущий проект
/home/vscode/.continue/config.yaml             — общий файл, только чтение
/home/vscode/.vscode-server/extensions          — расширения VS Code
/home/vscode/.vscode-server/extensionsCache     — кэш расширений
```

**Не обнаружены** монтирования Docker socket, каталога `.docker` с Mac и томов авторизации Codex.

У контейнера нет IPv4-маршрута по умолчанию. Наблюдавшийся маршрут:

```text
172.18.0.0/16 dev eth0 proto kernel scope link src 172.18.0.3
```

Проверки подключения к домашнему роутеру и прямому адресу Docker Desktop host завершились неудачей; запрос к `ollama-gateway` прошёл. 

## 7. Nginx gateway

Compose запускает `qwen-ollama-gateway` со следующими настройками:

- `nginx:alpine`, пользователь `101:101`;
- прямой запуск `/usr/sbin/nginx` без стандартных entrypoint-скриптов образа;
- `cap_drop: [ALL]` и `no-new-privileges:true`;
- `net.ipv4.ip_forward=0` — проверено;
- сети `qwen-isolated` (алиас `ollama-gateway`) и `qwen-uplink`;
- отсутствие опубликованных портов хоста.

Nginx слушает **8080** и проксирует запросы на `http://host.docker.internal:11435`. Заголовок `Host` заменяется на `localhost:11434`, поскольку без замены upstream возвращал HTTP 403. Для потоковой генерации были отключены буферизация ответа и запроса. Временные каталоги Nginx перенесены в `/tmp`, поскольку процесс работает без root-прав и capabilities.

Это HTTP reverse proxy с фиксированным upstream, **не универсальный forward proxy**. Однако сеть `qwen-uplink` по-прежнему предоставляет самому шлюзу обычный исходящий доступ. Фиксированный `proxy_pass` не заменяет сетевой egress-фильтр.

**Что ещё необходимо усилить:**

1. Ограничить исходящие соединения шлюза нужным адресом и портом Docker Desktop host на сетевом уровне.
2. Рассмотреть разрешённый список API Ollama для инференса; заблокировать ненужные административные методы (`/api/pull`, `/api/push`, `/api/create`, `/api/delete` и т. п.).
3. Повторно проверить IPv6, соседние контейнеры и сетевые маршруты после обновлений Docker Desktop.
4. Проверить унаследованные файлы образа и возможности расширений VS Code.

## 8. Порядок запуска и остановки

1. Запустить Ollama через **Ollama Sandbox Manager**. Ollama должна слушать `127.0.0.1:11434` под нужным профилем Seatbelt.
2. Запустить `socat` с перенаправлением `127.0.0.1:11435` → `127.0.0.1:11434`. Планируется управление обоими процессами из Sandbox Manager; перед тем как полагаться на это, необходимо проверить реализацию.
3. Запустить шлюз (команды **macOS / fish**):

   ```fish
   set DIR "$HOME/.config/vscode/devcontainer/qwen/gateway"
   docker compose -f "$DIR/compose.yaml" up -d
   ```

4. Открыть проект в VS Code через его Qwen Dev Container.
5. Continue обращается к `http://ollama-gateway:8080` через общую конфигурацию.

Контейнер проекта останавливается через VS Code. При необходимости шлюз останавливается командой `docker compose -f "$DIR/compose.yaml" down`; внешние Docker-сети при этом сохраняются. После внедрения управления `socat` останавливать его и Ollama следует через Sandbox Manager. Параметр `restart: unless-stopped` относится к Nginx, **не к Ollama**.

## 9. Диагностика

### На macOS (fish)

```fish
set DIR "$HOME/.config/vscode/devcontainer/qwen/gateway"
docker compose -f "$DIR/compose.yaml" ps
docker exec qwen-ollama-gateway cat /proc/sys/net/ipv4/ip_forward
docker network inspect qwen-isolated --format 'Internal={{.Internal}} Driver={{.Driver}}'
curl -fsS http://127.0.0.1:11434/api/version
curl -fsS http://127.0.0.1:11435/api/version
```

Проверка фактических монтирований и сетей (имя контейнера приведено для тестового проекта):

```fish
docker inspect dc-QwenTest-qwen --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
docker inspect dc-QwenTest-qwen --format '{{json .NetworkSettings.Networks}}'
```

### Внутри Qwen Dev Container (Linux shell)

```sh
id
stat -c '%U:%G %a %n' /home/vscode/.continue
ip route
curl -fsS http://ollama-gateway:8080/api/version
env | grep -i proxy
```

Ожидается: каталог `.continue` принадлежит `vscode:vscode` с правами `700`; маршрута `default` нет; API Ollama отвечает; переменные прокси отсутствуют (последняя команда ничего не выводит).

Проверки запрета соединений без зависимости от DNS:

```sh
curl -4 --noproxy '*' --connect-timeout 3 --max-time 5 http://1.1.1.1/ -o /dev/null
curl -4 --noproxy '*' --connect-timeout 3 --max-time 5 http://192.168.1.1/ -o /dev/null
curl -4 --noproxy '*' --connect-timeout 3 --max-time 5 http://192.168.65.254:11435/api/tags -o /dev/null
```

Это адреса, использованные при исходной настройке; в другой сети они могут отличаться. Неудачное TCP-подключение — полезный тест, но не полноценный аудит безопасности.

### Типовые неисправности

| Симптом | Причина / действие |
| --- | --- |
| Continue не активируется; `.continue` имеет `root:root 755` | Создать каталог в образе с владельцем `vscode`, затем пересобрать контейнер |
| Ошибка `postCreateCommand`, хотя команды нет в JSON | Проверить унаследованную метку образа `devcontainer.metadata` |
| Неожиданно подключены тома Codex или Docker socket | Проверить метаданные образа и фактические `.Mounts` |
| Continue использует внешний прокси для `ollama-gateway` | Проверить `.bashrc`, `ENV` образа и окружение процесса |
| Nginx возвращает HTTP 403 | Проверить замену `Host` на `localhost:11434` |
| Ошибка Nginx на `/var/cache/nginx/...` | Перенести временные каталоги в `/tmp` и проверить entrypoint |
| Команда `continue.viewLogs` не найдена | Проверить активацию Continue в логах Remote Extension Host |
| `clangd`: `navigator is now a global` | Обновить устаревшее расширение VS Code clangd отдельно от language server |
| Предупреждения VS Code TAS `fetch failed` | Возможное следствие отсутствия интернета, не доказательство сбоя Continue |

## 10. Восстановление на новом Mac

1. Установить Docker Desktop, VS Code с Dev Containers, Ollama, `socat` и Sandbox Manager.
2. Восстановить Sandbox Manager и профиль Seatbelt без расширения разрешений.
3. Восстановить из dotfiles `devcontainer.json`, Continue YAML, Compose, Nginx и Dockerfile Qwen (когда он будет сохранён).
4. Собрать ARM64-образ Qwen из доверенного базового образа; проверить содержимое и `devcontainer.metadata`.
5. При отсутствии сетей создать `qwen-isolated` с `--internal` и обычную `qwen-uplink`.
6. Запустить Ollama и `socat`, проверить оба loopback-адреса.
7. Запустить Nginx через Compose, проверить `ip_forward=0` и доступ к `/api/version` из `qwen-isolated`.
8. Пересоздать Dev Container, проверить mounts, capabilities, маршруты и переменные прокси.
9. Отдельно проверить **чат Continue** и **inline autocomplete**: ответ `/api/version` ещё не подтверждает работу генерации.
10. Повторить проверки заблокированных соединений и оценить оставшиеся риски.

## 11. Безопасность и Git

- Не коммитить учётные данные прокси, авторизацию Codex, содержимое `~/.docker`, токены и секреты Ollama (если есть).
- Не коммитить генерируемые данные `.continue`, тома расширений VS Code и служебные данные Docker Desktop.
- Общий `config.yaml` доступен только для чтения **в контейнере**, но редактируется на Mac.
- Отдельный контейнер проекта не гарантирует защиту от уязвимостей расширений, Docker Desktop, Nginx, Ollama или хоста.
- **Исходящий трафик Nginx gateway пока не ограничен строгими сетевыми правилами.** Нельзя называть всю систему полностью изолированной до внедрения и проверки такого ограничения.
