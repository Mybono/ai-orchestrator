Что есть в ai-orchestrator и лучше, чем в be-agent
TriageAgent.ts — BFS на knowledge graph (более продвинутый триаж)
6-слойный pipeline более детально документирован
18 плагинов vs 16
graphify интеграция
8 документационных файлов vs 4

# AI Orchestrator — Backlog

Источник: сравнительный анализ ai-orchestrator vs be-agent (2026-05-31)

---

## Фаза 1 — Надёжность

### TICKET-001 · Fallback модели в llm-config.json

**Приоритет:** Критический  
**Оценка:** 2 ч

**Проблема:** При недоступности Ollama pipeline падает без recovery.

**Задачи:**

- [x] Добавить секцию `"fallback"` в `llm-config.json` с Claude-моделями для каждой роли
- [x] Обновить `scripts/call_ollama.sh` — перехватывать exit code Ollama и при ошибке переключаться на Claude API
- [x] Логировать fallback-вызовы в token_stats для трекинга стоимости
- [x] Добавить переменную `OLLAMA_FALLBACK=true/false` для отключения fallback

**Файлы:** `llm-config.json`, `scripts/call_ollama.sh`

---

### TICKET-002 · DiffCompressor перед review-вызовами

**Приоритет:** Высокий  
**Оценка:** 3 ч

**Проблема:** Полные диффы передаются в контекст reviewer-агента — избыточный расход токенов.

**Задачи:**

- [x] Перенести логику `DiffCompressor.ts` из be-agent в `src/core/DiffCompressor.ts`
- [x] Убирать lock-файлы (`package-lock.json`, `yarn.lock`, `*.lock`) из диффа
- [x] Схлопывать более 3 пустых строк подряд
- [x] Усекать файлы > 500 строк до первых 200 + последних 50
- [x] Встроить вызов compressor в `src/core/Orchestrator.ts` перед каждым review-шагом
- [x] Логировать коэффициент сжатия (оригинал / сжатый размер)

**Файлы:** `src/core/DiffCompressor.ts` (новый), `src/core/Orchestrator.ts`

---

## Фаза 2 — Качество кода

### TICKET-003 · Tension Loop для сложных задач (architect-first)

**Приоритет:** Высокий  
**Оценка:** 4 ч

**Проблема:** Сложные задачи (рефакторинг, новые модули) идут сразу в coder без архитектурного обсуждения — дорогостоящий rework.

**Задачи:**

- [x] Добавить маршрут `architect-first` в `src/agents/TriageAgent.ts`
- [x] Триггер-слова для этого маршрута: `refactor`, `redesign`, `new module`, `architecture`, `migrate`
- [x] Реализовать tension loop: architect пишет design → planner ставит под сомнение → architect отвечает (макс 2 раунда)
- [x] Консенсус сохраняется в `.claude/context/architect_decision.md`
- [x] Coder читает `architect_decision.md` перед стартом
- [x] Добавить документацию в `documentation/ARCHITECTURE.md`

**Файлы:** `src/agents/TriageAgent.ts`, `agents/architect.md`, `agents/planner.md`, `documentation/ARCHITECTURE.md`

---

### TICKET-004 · Required Skills — машиночитаемая секция в агентах

**Приоритет:** Средний  
**Оценка:** 3 ч

**Проблема:** Скиллы загружаются вручную или по документации — нет машиночитаемого маппинга агент→скиллы.

**Задачи:**

- [x] Добавить секцию `## Required Skills` в каждый файл `agents/*.md`
- [x] Формат: список путей к skill-файлам относительно `~/.claude/`
- [x] Обновить `agents/planner.md` — читать `## Required Skills` из агента-получателя и включать содержимое скиллов в `task_context.md`
- [x] Покрыть все 19 агентов

**Файлы:** `agents/*.md` (19 файлов), `agents/planner.md`

---

### TICKET-005 · pr-checkmate.json — формальные quality gates

**Приоритет:** Средний  
**Оценка:** 2 ч

**Проблема:** Перед коммитом нет автоматической проверки lint / security / форматирования.

**Задачи:**

- [x] Создать `pr-checkmate.json` с gate-правилами: ESLint, Prettier, security audit
- [x] Обновить `agents/commit.md` — запускать gates перед генерацией commit-сообщения
- [x] При failure — прерывать коммит и выводить конкретные ошибки
- [x] Добавить флаг `--skip-gates` для экстренных коммитов (с явным предупреждением)

**Файлы:** `pr-checkmate.json` (новый), `agents/commit.md`, `scripts/local-commit.sh`

---

### TICKET-006 · Conflict Resolution между агентами

**Приоритет:** Средний  
**Оценка:** 3 ч

**Проблема:** Если architect возвращает BLOCKED, а reviewer — APPROVED, error-coordinator не обрабатывает этот кейс явно.

**Задачи:**

- [x] Определить матрицу конфликтов: какие вердикты считаются конфликтующими
- [x] Обновить `agents/error-coordinator.md` — добавить шаг conflict detection
- [x] При конфликте: перезапустить оба агента с явным указанием blocking concern
- [x] Максимум 1 раунд разрешения, после — эскалация к пользователю
- [x] Записывать конфликты в `.claude/context/conflict_log.md`

**Файлы:** `agents/error-coordinator.md`, `src/core/Orchestrator.ts`

---

## Фаза 3 — Глобальная доступность

### TICKET-007 · Глобальные команды в ~/.claude/commands/

**Приоритет:** Средний  
**Оценка:** 2 ч

**Проблема:** Полезные команды (handoff, create-story) не симлинкуются в `~/.claude/commands/` — недоступны вне проекта.

**Задачи:**

- [x] Создать `.claude/commands/handoff.md` — передача контекста между Claude-сессиями
- [x] Создать `.claude/commands/create-story.md` — шаблон для user story
- [x] Создать `.claude/commands/create-bug.md` — шаблон для bug report
- [x] Добавить симлинки в `scripts/install.sh`:  
  `~/.claude/commands/ → repo/.claude/commands/`
- [x] Обновить `documentation/SKILLS.md` с описанием новых команд

**Файлы:** `.claude/commands/` (новые файлы), `scripts/install.sh`, `documentation/SKILLS.md`

---

### TICKET-008 · Prompt caching для review-вызовов

**Приоритет:** Средний  
**Оценка:** 2 ч

**Проблема:** Системный промпт (standards + persona) пересылается заново на каждый review-вызов — ~60% лишних токенов.

**Задачи:**

- [x] В `src/agents/AgentRunner.ts` разделить системный промпт и user-сообщение
- [x] Выставить `cache_control: { type: "ephemeral" }` на системный блок
- [x] Убедиться что skills/standards передаются в system, а task context — в user
- [x] Добавить метрику cache hit rate в token_stats
- [x] Обновить `scripts/track_savings.sh` для учёта cache savings отдельно

**Файлы:** `src/agents/AgentRunner.ts`, `scripts/track_savings.sh`

---

## Фаза 4 — Память и знания

### TICKET-009 · Knowledge directory — кросс-проектный контекст

**Приоритет:** Средний  
**Оценка:** 3 ч

**Проблема:** При работе с несколькими взаимосвязанными репо planner не знает о зависимостях между ними.

**Задачи:**

- [x] Создать `knowledge/` директорию
- [x] Создать `knowledge/context-index.md` — шаблон индекса проектов и зависимостей
- [x] Обновить `agents/planner.md` — читать `knowledge/context-index.md` при старте (если существует)
- [x] Добавить секцию в `documentation/ARCHITECTURE.md` про knowledge layer
- [x] Создать `scripts/update-knowledge.sh` для ручного обновления индекса

**Файлы:** `knowledge/` (новая директория), `agents/planner.md`, `documentation/ARCHITECTURE.md`

---

## Фаза 5 — Дополнения

### TICKET-010 · Frontend skills

**Приоритет:** Низкий  
**Оценка:** 2 ч

**Задачи:**

- [x] Создать `skills/frontend-design/SKILL.md` — компонентная архитектура, CSS methodologies
- [x] Создать `skills/minimalist-skill/SKILL.md` — принципы минималистичного UI
- [x] Добавить auto-detection в `documentation/CLAUDE.md`: `index.html` / `vite.config.*` → frontend skills
- [x] Обновить таблицу Skills Registry в `documentation/SKILLS.md`

**Файлы:** `skills/frontend-design/SKILL.md`, `skills/minimalist-skill/SKILL.md`, `documentation/CLAUDE.md`

---

### TICKET-011 · TypeScript CLI команды (npm scripts)

**Приоритет:** Низкий  
**Оценка:** 4 ч

**Проблема:** Только shell-скрипты — нет удобных npm-команд для разработчиков.

**Задачи:**

- [x] Добавить npm scripts в `package.json`: `ao-commit`, `ao-review`, `ao-stats`, `ao-update`
- [x] Создать `src/cli/` с entry points для каждой команды
- [x] `ao-commit` — вызывает `scripts/local-commit.sh` с прогресс-индикатором
- [x] `ao-review` — запускает review pipeline на текущем диффе
- [x] `ao-stats` — форматированный вывод из token_stats.json
- [x] Обновить `README.md` с секцией CLI Usage

**Файлы:** `package.json`, `src/cli/` (новая директория), `README.md`

---

### TICKET-012 · MCP server интеграция

**Приоритет:** Низкий  
**Оценка:** 6 ч

**Задачи:**

- [x] Создать `src/mcp/` с MCP server implementation
- [x] Экспортировать инструменты: `run_pipeline`, `get_stats`, `triage_task`, `get_agent_status`
- [x] Добавить `mcp-config.json` с настройками сервера
- [x] Документировать в `documentation/MCP.md`
- [x] Добавить симлинк MCP конфига в `scripts/install.sh`

**Файлы:** `src/mcp/` (новая директория), `mcp-config.json`, `documentation/MCP.md`

---

## Статус

| Тикет | Название | Фаза | Приоритет | Статус |
|---|---|---|---|---|
| TICKET-001 | Fallback модели | 1 | Критический | 🔲 Открыт |
| TICKET-002 | DiffCompressor | 1 | Высокий | 🔲 Открыт |
| TICKET-003 | Tension Loop | 2 | Высокий | 🔲 Открыт |
| TICKET-004 | Required Skills | 2 | Средний | 🔲 Открыт |
| TICKET-005 | pr-checkmate | 2 | Средний | 🔲 Открыт |
| TICKET-006 | Conflict Resolution | 2 | Средний | 🔲 Открыт |
| TICKET-007 | Глобальные команды | 3 | Средний | 🔲 Открыт |
| TICKET-008 | Prompt caching | 3 | Средний | 🔲 Открыт |
| TICKET-009 | Knowledge directory | 4 | Средний | 🔲 Открыт |
| TICKET-010 | Frontend skills | 5 | Низкий | 🔲 Открыт |
| TICKET-011 | CLI команды | 5 | Низкий | 🔲 Открыт |
| TICKET-012 | MCP server | 5 | Низкий | 🔲 Открыт |
