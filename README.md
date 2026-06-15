# Oof Incremental — incremental/idle игра для Roblox

Система в стиле твоего скрина: **наступаешь** на кнопку-площадку → появляется NPC
(«Noob») с анимацией → раз в N секунд он **автоматически** приносит валюту (Oof) на
баланс. За Oof можно **прокачивать ноба** (кнопка над ним) или **покупать улучшения на
доске** (`SurfaceGui`). Всё сохраняется **индивидуально для каждого игрока**.

**Локация общая для всех**, но ноб и интерфейс рисуются **локально** у каждого игрока,
а вся экономика считается **на сервере** (защита от читов). Пока ноб не куплен —
у игрока только кнопка и **стрелка-маршрут** к ней.

> Rojo **не используется**. Это обычные скрипты — раскладываешь их по сервисам вручную.

---

## 1. Что входит (соответствие скрину)

- ✅ Кнопка-площадка: **наступил** (`Touched`) → купился ноб (не ProximityPrompt).
- ✅ Ноб с зацикленной анимацией, стоит на площадке (рисуется локально у каждого).
- ✅ Авто-доход раз в N секунд прямо на баланс (считает сервер).
- ✅ Прокачка ноба зелёной кнопкой **Upgrade** над ним.
- ✅ Доска **Oof Upgrades** (`SurfaceGui`): `More Oof`, `Faster Noobs`, кнопки **Buy** / **Max**.
- ✅ Верхняя панель «X/5T Oofs» + «Progress for Prestige N» со шкалой.
- ✅ **Oof справа**, **гемы слева** (капают по таймеру с обратным отсчётом), боковые кнопки, тулбар.
- ✅ **Стрелка-маршрут** (`Beam`, как пунктир на скрине): идёт от тела игрока прямо к цели.
- ✅ **Туториал из 2 шагов:** 1) купить ноба (стрелка → кнопка); 2) прокачать 5 раз (стрелка → ноб).
- ✅ Индивидуальное сохранение (`DataStore`) + автосейв + сохранение при выходе.
- ✅ Одна общая локация на всех; никто никому не мешает (ноб/доска — локальные).

---

## 2. Куда что положить (карта файлов)

Файлы лежат в папке `game/`. Имя файла в Studio = имя без `.lua`.

| Файл в репозитории | Где создать в Studio | Тип | Имя |
|---|---|---|---|
| `game/ReplicatedStorage_Shared/Config.lua`   | `ReplicatedStorage > Shared` | **ModuleScript** | `Config` |
| `game/ReplicatedStorage_Shared/Formulas.lua` | `ReplicatedStorage > Shared` | **ModuleScript** | `Formulas` |
| `game/ReplicatedStorage_Shared/Format.lua`   | `ReplicatedStorage > Shared` | **ModuleScript** | `Format` |
| `game/ServerScriptService/DataManager.lua`   | `ServerScriptService` | **ModuleScript** | `DataManager` |
| `game/ServerScriptService/GameServer.lua`    | `ServerScriptService` | **Script** | `GameServer` |
| `game/StarterPlayerScripts/ClientMain.lua`   | `StarterPlayer > StarterPlayerScripts` | **LocalScript** | `ClientMain` |

> Папку `Remotes` и саму локацию (`Workspace > GameLocation` с кнопкой, доской, спавном)
> сервер создаёт **сам** при старте. Руками строить не нужно.

---

## 3. Установка (по порядку)

### Шаг 0. Включить DataStore (для сохранений)
`Home → Game Settings → Security → Enable Studio Access to API Services` → **ВКЛ**,
и один раз **Publish to Roblox**.

### Шаг 1. ReplicatedStorage
Создай **Folder** `Shared`, внутри — три **ModuleScript**: `Config`, `Formulas`, `Format`.

### Шаг 2. ServerScriptService
**ModuleScript** `DataManager` и **Script** `GameServer`.

### Шаг 3. StarterPlayerScripts
**LocalScript** `ClientMain`.

### Шаг 4. Риг ноба — кладём в ReplicatedStorage ⚠️ (важно изменилось!)
1. **Avatar → Rig Builder → R6** → любой риг (например **Block Rig**).
2. Переименуй его в **`NoobRig`**.
3. Перетащи **`NoobRig` в `ReplicatedStorage`** (НЕ в ServerStorage — ноб теперь
   клонируется клиентом локально).

> Имя `NoobRig` задаётся в `Config.Noob.RigName`. Нет рига → ноб просто не появится
> визуально (в Output будет warning), игра не упадёт.

### Шаг 5. (Необязательно) Картинка для стрелки-маршрута
Стрелка — это `Beam` (луч от игрока к цели). Можешь задать ему текстуру-пунктир/стрелку:
загрузи картинку, вставь её ID в `Config.ArrowImageId = "rbxassetid://ТВОЙ_ID"`.
Оставишь `rbxassetid://0` — будет просто белая линия.

### Шаг 6. (Рекомендуется) Убери лишние точки спавна
Если в `Workspace` уже есть `SpawnLocation` (например, на стандартном Baseplate) —
удали его, чтобы игроков спавнило у нашей локации (`GameLocation > Spawn`).

### Шаг 7. Запуск
**Play** → ты у локации, сверху панель, справа Oof, слева гемы; от тебя к синей
площадке тянется стрелка-луч; **встаёшь на площадку** → появляется ноб с анимацией →
капает Oof; стрелка переключается на ноба и просит прокачать его 5 раз; работает доска.
После перезахода прогресс на месте.

---

## 4. Настройка баланса (всё в `Config`)

| Параметр | Что меняет |
|---|---|
| `Noob.BaseInterval` | как часто (сек) ноб приносит Oof (3) |
| `Noob.BaseReward` / `RewardPerLevel` | доход и прибавка за уровень |
| `Noob.UpgradeBaseCost` / `UpgradeCostGrowth` | цена и рост цены прокачки ноба |
| `Noob.BuyCost` | цена первого ноба (0 = бесплатно) |
| `Noob.AnimationId` | анимация ноба |
| `Upgrades[...]` | улучшения на доске |
| `Gems.Interval` / `Amount` | как часто и сколько гемов |
| `Prestige.BaseRequirement` | сколько Oof до Престижа 1 (шкала сверху) |
| `World.*` | позиции/размеры кнопки, доски, спавна общей локации |
| `Data.StoreName` | смени `_v1` → `_v2`, чтобы **обнулить все сейвы** |

Формулы — в `Formulas` (там `More Oof` = x2 каждые 15 уровней).

---

## 5. Если что-то не работает

- **Сохранения не пишутся** → не включён API Services (Шаг 0) или игра не опубликована.
- **Ноб не появляется** → нет `NoobRig` **в ReplicatedStorage** (Шаг 4). Смотри Output.
- **Ноб не двигается** → стандартная `AnimationId` не подошла ригу — поставь свою.
- **Кнопки на доске не нажимаются** → подойди ближе к доске.
- **Спавнит не там** → удали лишние `SpawnLocation` (Шаг 6).
- **UI нет** → `ClientMain` должен быть **LocalScript** в `StarterPlayerScripts`.

---

## 6. Куда расти дальше

- Своя 3D-локация: создай в `Workspace > GameLocation` части с именами `Button` и `Board`
  (и `Spawn`) — сервер увидит их и не будет строить свои.
- Престиж (сброс за множитель) — данные уже есть.
- Магазин гемов на «+», геймпассы (×2 Oof), питомцы-множители, второй ноб.

---

### Архитектура (кратко)

```
ReplicatedStorage/
  Shared/  Config, Formulas, Format   (ModuleScript)
  NoobRig                              (Model — риг, клонируется клиентом)
  Remotes/                             (создаёт сервер)
    SyncData, Notify, RequestData, UpgradeNoob, BuyUpgrade

ServerScriptService/
  DataManager  (ModuleScript)  — DataStore
  GameServer   (Script)        — общая локация, покупка по Touched, доход, покупки, сейвы

StarterPlayer/StarterPlayerScripts/
  ClientMain   (LocalScript)   — HUD, доска, локальный ноб, стрелка-Beam, туториал

Workspace/
  GameLocation/  Floor, Button, Board, Spawn   (создаёт сервер, одна на всех)
```

Сервер — главный по экономике. Ноб и доска видны/считаются локально, но деньги и
уровни хранит и проверяет только сервер — накрутить нельзя.
