# Production baseline: v1.2.2

Основа разработки — подтверждённая пользователем production-версия `v1.2.2`:

- commit: `f65ea7559039137ba31a5270746a01f7bfddfc47`;
- ветка `main` и tag `v1.2.2` указывают на этот commit.

## Рабочие инварианты

- Начальное состояние аддона — скрытый indicator; вызов `indicator:Hide()` расположен до создания glow UI.
- Команда `/swd` открывает настройки.
- В Test-режиме icon отображается.
- Вне боя indicator скрыт.
- Для обычного показа нужна текущая hostile живая цель.
- При HP цели выше 20% indicator визуально скрыт.
- При HP цели 20% или ниже и готовом Shadow Word: Death indicator видим.
- Global Cooldown не скрывает indicator.
- Собственный cooldown Shadow Word: Death скрывает indicator; после его окончания indicator появляется снова, если остальные условия выполнены.
- Одна доступная charge остаётся usable, пока другая charge recharging.
- HP проверяется Secret-safe путём через `UnitHealthPercent` и `C_CurveUtil`; execute arithmetic через `UnitHealth / UnitHealthMax` отсутствует.
- Нет постоянного `OnUpdate`.
- Сохраняются position, size, locked и выбранный glow через `SWDExecuteDB`.

## Что требует проверки в живом WoW Retail

Статические проверки и CI не могут подтвердить поведение Blizzard API в клиенте. После изменений runtime-кода обязательно вручную проверить:

- начальную скрытность, `/swd` и Test-режим;
- все состояния target, combat и порога 20% HP;
- собственный cooldown, Global Cooldown и charge recharge;
- реакцию на события target/HP/cooldown;
- сохранение position, size, locked и glow после `/reload`.
