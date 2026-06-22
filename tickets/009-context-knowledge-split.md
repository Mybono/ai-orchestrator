# 009 — Разделить `.claude/context/` на временное и постоянное

## Problem

Папка `.claude/context/` содержит два принципиально разных типа файлов:
- **временные** — создаются на каждый таск и могут быть удалены без потерь
- **постоянные** — накапливают знания между тасками; удаление ломает planner, reviewer и pipeline

Сейчас оба типа лежат вместе, что делает невозможным автоматическую очистку временных файлов и путает агентов.

## Goal

Переместить все постоянные файлы в `knowledge/` (он уже существует и используется для outcomes, embeddings, github-monitoring). `.claude/context/` должна содержать **только** временные файлы — её можно целиком удалять между задачами.

## Files to move: `.claude/context/` → `knowledge/`

| Файл | Кто пишет | Кто читает |
|---|---|---|
| `project_overview.md` | `scripts/analyze_project.sh`, `agents/planner.md` | `scripts/plan_task.sh`, `scripts/research-oss.sh`, `agents/planner.md`, `commands/triage.md` |
| `analysis_delta.md` | `scripts/analyze_project.sh` | `agents/planner.md` |
| `triage_ts.md` | `src/agents/TriageAgent.ts` | `plugins/orchestrator/commands/implement.md` |
| `review_instructions.md` | (статичный шаблон) | `src/core/Orchestrator.ts` |
| `review_learn_md.md` | `/learn` command | `/learn` command |
| `review_learn_sh.md` | `/learn` command | `/learn` command |

## Scope

### 1. Переместить файлы
- [ ] Переместить существующие файлы из `.claude/context/` → `knowledge/`
- [ ] Обновить `.gitignore` / `.clineignore` если нужно (временный контекст не должен коммититься, knowledge — должен)

### 2. `scripts/plan_task.sh`
- [ ] `OVERVIEW="$PROJECT_ROOT/.claude/context/project_overview.md"` → `"$PROJECT_ROOT/knowledge/project_overview.md"`

### 3. `scripts/research-oss.sh`
- [ ] `PROJECT_OVERVIEW="$REPO_DIR/.claude/context/project_overview.md"` → `"$REPO_DIR/knowledge/project_overview.md"`

### 4. `scripts/analyze_project.sh`
- [ ] `DELTA_FILE="$CONTEXT_DIR/analysis_delta.md"` → писать в `$REPO_DIR/knowledge/analysis_delta.md`

### 5. `agents/planner.md`
- [ ] Обновить все `ls .claude/context/project_overview.md` → `knowledge/project_overview.md`
- [ ] Обновить `analysis_delta.md` → `knowledge/analysis_delta.md`
- [ ] Обновить фразу "After writing task_context.md, update `.claude/context/project_overview.md`"

### 6. `plugins/orchestrator/commands/triage.md`
- [ ] `ls .claude/context/project_overview.md` → `knowledge/project_overview.md`

### 7. `plugins/orchestrator/commands/implement.md`
- [ ] `.claude/context/triage_ts.md` → `knowledge/triage_ts.md` (2 строки)

### 8. `src/agents/TriageAgent.ts`
- [ ] Строка 426: путь записи `triage_ts.md` → `knowledge/triage_ts.md`
- [ ] Проверить `contextDir` откуда берётся — возможно нужно поменять переменную

### 9. `src/core/Orchestrator.ts`
- [ ] Строка 142: `join(this.contextDir, 'review_instructions.md')` → `join(this.repoDir, 'knowledge', 'review_instructions.md')` (или ввести `knowledgeDir`)

### 10. `documentation/AGENTS.md`
- [ ] Обновить упоминания `.claude/context/project_overview.md` → `knowledge/project_overview.md`

### 11. `commands/learn.md` (если ссылается на `review_learn_*.md`)
- [ ] Проверить и обновить пути

## Временные файлы (остаются в `.claude/context/`)

Для ориентира — эти файлы НЕ трогаем:
- `task_context_<domain>.md`
- `task_context_augmented_<domain>.md`
- `codegen_instructions.md`
- `developer_output_<domain>.md`
- `review_prompt_<domain>.md`
- `review_output_<domain>.md`
- `review_deep_<file>.md`
- `review_capture_*.md`
- `fix_loop.md`
- `triage.md`

## Acceptance criteria

- [ ] `ls .claude/context/` после чистого `/implement` показывает только временные файлы из списка выше
- [ ] `ls knowledge/` содержит `project_overview.md`, `triage_ts.md`, `review_instructions.md`, `review_learn_*.md`
- [ ] `grep -r "context/project_overview\|context/triage_ts\|context/review_instructions\|context/review_learn" . --include="*.sh" --include="*.ts" --include="*.md" | grep -v node_modules | grep -v tickets/` возвращает 0 результатов
- [ ] Pipeline `/implement` проходит end-to-end без ошибок

## Suggested execution order

1. Создать `knowledge/` структуру если нужно (папка уже есть)
2. Обновить пути в shell-скриптах (`plan_task.sh`, `research-oss.sh`, `analyze_project.sh`)
3. Обновить TypeScript источники (`TriageAgent.ts`, `Orchestrator.ts`)
4. Обновить agent/command markdown файлы
5. Переместить существующие файлы
6. Запустить acceptance grep

## Files touched

- `scripts/plan_task.sh`
- `scripts/research-oss.sh`
- `scripts/analyze_project.sh`
- `src/agents/TriageAgent.ts`
- `src/core/Orchestrator.ts`
- `agents/planner.md`
- `plugins/orchestrator/commands/triage.md`
- `plugins/orchestrator/commands/implement.md`
- `documentation/AGENTS.md`
- `commands/learn.md` (проверить)
