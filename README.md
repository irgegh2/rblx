# Oof Incremental — incremental/idle игра для Roblox

Готовая система в стиле твоего скрина: подходишь к кнопке → нажимаешь → появляется
NPC («Noob») с анимацией → раз в N секунд он **автоматически** приносит валюту (Oof) на
баланс. За Oof можно **прокачивать ноба** (кнопка над ним) или **покупать улучшения на
доске** (SurfaceGui). Всё сохраняется **индивидуально для каждого игрока**. Пока ноб не
куплен — у игрока только кнопка и стрелка-подсказка.

> Rojo **не используется**. Это обычные скрипты — ты вручную раскладываешь их по
> сервисам в Roblox Studio (инструкция ниже, 1-в-1).

---

## 1. Что входит (соответствие скрину)

- ✅ Кнопка (ProximityPrompt «Get your Noob») — подошёл, нажал **E**, появился ноб.
- ✅ Ноб с зацикленной анимацией, стоит на площадке.
- ✅ Авто-доход раз в N секунд прямо на баланс.
- ✅ Прокачка ноба зелёной кнопкой **Upgrade** над ним (растёт уровень и доход).
- ✅ Доска **Oof Upgrades** на `SurfaceGui` с улучшениями `More Oof` и `Faster Noobs`
  (кнопки **Buy** и **Max**).
- ✅ Верхняя панель «X/5T Oofs» + «Progress for Prestige N» со шкалой.
- ✅ Счётчик **Oof справа**, **гемы слева** (капают по таймеру, с обратным отсчётом).
- ✅ Боковые кнопки (⚙️) и нижний тулбар (Shop / Tree / Inventory / Quests) — заготовки.
- ✅ Туториал-карточка снизу и **стрелка-подсказка** над кнопкой (свою картинку
  подставишь в `Config.ArrowImageId`).
- ✅ Индивидуальное сохранение через `DataStore` + автосейв + сохранение при выходе.
- ✅ У каждого игрока **свой личный плот** (строится автоматически, игроки не мешают друг другу).

---

## 2. Куда что положить (карта файлов)

В репозитории файлы лежат в папке `game/`. Имя файла в Studio = имя без `.lua`.

| Файл в репозитории | Где создать в Studio (Explorer) | Тип объекта | Имя объекта |
|---|---|---|---|
| `game/ReplicatedStorage_Shared/Config.lua`   | `ReplicatedStorage > Shared` | **ModuleScript** | `Config` |
| `game/ReplicatedStorage_Shared/Formulas.lua` | `ReplicatedStorage > Shared` | **ModuleScript** | `Formulas` |
| `game/ReplicatedStorage_Shared/Format.lua`   | `ReplicatedStorage > Shared` | **ModuleScript** | `Format` |
| `game/ServerScriptService/DataManager.lua`   | `ServerScriptService` | **ModuleScript** | `DataManager` |
| `game/ServerScriptService/GameServer.lua`    | `ServerScriptService` | **Script** (серверный) | `GameServer` |
| `game/StarterPlayerScripts/ClientMain.lua`   | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `ClientMain` |

> Папку `Remotes` в `ReplicatedStorage` создавать **НЕ нужно** — сервер делает её сам.
> Геометрию плота (пол, кнопку, площадку, доску) тоже **НЕ нужно** строить руками —
> сервер строит её автоматически.

---

## 3. Пошаговая установка (по порядку)

### Шаг 0. Включить DataStore (обязательно для сохранений)
`Home → Game Settings → Security → Enable Studio Access to API Services` → **ВКЛ**.
Игру нужно один раз **опубликовать** (`File → Publish to Roblox`), иначе DataStore не работает.

### Шаг 1. ReplicatedStorage
1. В `ReplicatedStorage` создай **Folder** и назови `Shared`.
2. Внутри `Shared` создай три **ModuleScript**: `Config`, `Formulas`, `Format`.
3. В каждый вставь содержимое одноимённого файла из репозитория (заменив шаблонный код).

### Шаг 2. ServerScriptService
1. Создай **ModuleScript** `DataManager` → вставь код из `game/ServerScriptService/DataManager.lua`.
2. Создай обычный **Script** `GameServer` → вставь код из `game/ServerScriptService/GameServer.lua`.

### Шаг 3. StarterPlayerScripts
1. Открой `StarterPlayer > StarterPlayerScripts`.
2. Создай **LocalScript** `ClientMain` → вставь код из `game/StarterPlayerScripts/ClientMain.lua`.

### Шаг 4. Сделай рига для ноба (это делаешь сам — 20 секунд)
1. Вкладка **Avatar → Rig Builder**.
2. Выбери **R6** → любой риг (например **Block Rig** или **Rthro/Man**).
3. Он появится в `Workspace`. Переименуй его в **`NoobRig`**.
4. Перетащи `NoobRig` в **`ServerStorage`**.

> Имя `NoobRig` важно — оно прописано в `Config.Noob.RigName`. Можно поменять и там, и там.
> Если рига не будет — игра не упадёт, просто ноб не появится визуально (в логах будет warning).

### Шаг 5. (Необязательно) Своя картинка-стрелка
1. Загрузи PNG-стрелку: `Asset Manager → Images → Add` (или через сайт Roblox → Create).
2. Скопируй её **Asset ID**.
3. В `Config.lua` впиши: `Config.ArrowImageId = "rbxassetid://ТВОЙ_ID"`.
   Пока не вписал — над кнопкой будет временная текстовая стрелка ⬇️.

### Шаг 6. Запуск
Нажми **Play**. Должно произойти:
- тебя телепортирует на твой плот;
- сверху панель прогресса, справа Oof, слева гемы и кнопки;
- над синей кнопкой прыгает стрелка;
- подходишь, жмёшь **E** → появляется ноб с анимацией;
- раз в 3 секунды Oof растёт, выскакивают «+X Oof»;
- кнопка **Upgrade** над нобом и доска **Oof Upgrades** работают;
- после выхода/повторного входа прогресс сохраняется.

---

## 4. Как настраивать баланс

Всё в **`ReplicatedStorage > Shared > Config`**. Самое полезное:

| Параметр | Что меняет |
|---|---|
| `Noob.BaseInterval` | как часто (сек) ноб приносит Oof (по умолчанию 3) |
| `Noob.BaseReward` / `Noob.RewardPerLevel` | базовый доход и прибавка за уровень |
| `Noob.UpgradeBaseCost` / `UpgradeCostGrowth` | цена и рост цены прокачки ноба |
| `Noob.BuyCost` | цена первого ноба (0 = бесплатно) |
| `Noob.AnimationId` | анимация ноба (поставь свою, если стандартная не нравится) |
| `Upgrades[...]` | улучшения на доске: имя, макс. уровень, цена, рост цены |
| `Gems.Interval` / `Gems.Amount` | как часто и сколько капает гемов |
| `Prestige.BaseRequirement` | сколько Oof до Престижа 1 (для верхней шкалы) |
| `Data.StoreName` | смени суффикс (`_v1` → `_v2`), чтобы **обнулить все сейвы** |

Формулы дохода/цен — в `Formulas` (там же `More Oof` даёт x2 каждые 15 уровней).

---

## 5. Если что-то не работает

- **Сохранения не пишутся** → не включён API Services (Шаг 0) или игра не опубликована.
  В Studio это нормально проверять только в опубликованном месте.
- **Ноб не появляется** → нет `NoobRig` в `ServerStorage` (Шаг 4). Смотри Output на warning.
- **Ноб появился, но не двигается** → стандартная `AnimationId` не подошла твоему ригу.
  Поставь свою анимацию в `Config.Noob.AnimationId` (любой `rbxassetid` с анимацией).
- **Кнопки на доске не нажимаются** → подойди ближе к доске; убедись, что часть `Board`
  не перекрыта другими деталями.
- **UI не появился** → `ClientMain` должен лежать именно в `StarterPlayerScripts` как
  **LocalScript** (не Script).
- **«attempt to index nil»** в Output → проверь, что все три модуля в `Shared` названы
  ровно `Config`, `Formulas`, `Format`.

---

## 6. Куда расти дальше (по желанию)

- Своя 3D-геометрия плота вместо процедурной (функция `buildPlot` в `GameServer`):
  достаточно, чтобы в плоте остались части с именами `Button`, `Pad`, `Board` и `Owner`.
- Реальная кнопка престижа (сброс прогресса за множитель) — данные под это уже есть.
- Магазин гемов на зелёный «+», геймпассы (×2 Oof), питомцы-множители.
- Несколько нобов / слотов (на скрине видна вторая пустая площадка).

---

### Архитектура (кратко)

```
ReplicatedStorage/
  Shared/
    Config      (ModuleScript)  — весь баланс
    Formulas    (ModuleScript)  — расчёт цен и дохода (сервер + клиент)
    Format      (ModuleScript)  — 1500 -> "1.5K"
  Remotes/                      — создаётся сервером в рантайме
    SyncData, Notify, RequestData, UpgradeNoob, BuyUpgrade

ServerScriptService/
  DataManager   (ModuleScript)  — DataStore: load/save/release
  GameServer    (Script)        — плоты, спавн ноба, доход, покупки, автосейв

StarterPlayer/StarterPlayerScripts/
  ClientMain    (LocalScript)   — весь UI, доска, стрелка, табличка над нобом

ServerStorage/
  NoobRig       (Model)         — риг ноба (делаешь сам через Rig Builder)

Workspace/
  Plots/                        — личные плоты игроков (создаются сервером)
```

Сервер — главный по экономике (анти-чит): клиент только просит купить, считает сервер.
