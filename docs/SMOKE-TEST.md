# Smoke-test RC в WoW Retail

Этот чек-лист выполняет владелец в живом WoW Retail. Он не означает, что
тестирование уже прошло: следующий шаг возможен только после заполненного
блока результата ниже.

## Установка RC

1. Полностью закройте WoW.
2. Сохраните резервную копию установленной папки аддона.
3. Удалите старую папку `ShadowWordDeathExecute` из `*retail*/Interface/AddOns`.
4. На странице успешного GitHub Actions run откройте раздел **Artifacts** и
   скачайте `ShadowWordDeathExecute-RC-<short-sha>`. Это внешний ZIP artifact;
   распакуйте его в отдельную временную папку.
5. Внутри artifact возьмите installable ZIP
   `ShadowWordDeathExecute-*.zip` и рядом лежащий файл
   `ShadowWordDeathExecute-*.zip.sha256`. Сверьте SHA-256 из `.sha256` с ZIP.
6. Распакуйте внутренний installable ZIP в `*retail*/Interface/AddOns`.
   Итоговый путь обязан быть
   `*retail*/Interface/AddOns/ShadowWordDeathExecute/ShadowWordDeathExecute.toc`.
   Не должно быть дополнительной вложенной папки.
7. Сначала не удаляйте SavedVariables.
8. Включите Lua errors командой `/console scriptErrors 1` и запустите игру.

## Настройки

Проверьте:

- `/swd` открывает окно;
- Lock, Test, ручные X/Y для Position и Size, Glow и Reset работают;
- перемещение доступно только при Test ON и Lock OFF;
- закрытие окна выключает Test;
- position, size, lock и glow сохраняются после `/reload`;
- локализованные строки не накладываются друг на друга.

## Поведение в бою

Проверьте:

- вне боя иконка скрыта;
- без выбранного таланта Shadow Word: Death иконка скрыта, включая Test;
- без цели, с friendly или dead target иконка скрыта;
- выше 20% HP иконка скрыта;
- при 20% HP или ниже иконка видна, когда SW:D доступен;
- обычный GCD не скрывает иконку;
- собственный cooldown SW:D скрывает иконку;
- после cooldown иконка возвращается;
- доступная charge остаётся видимой при восстановлении другой charge;
- последняя недоступная charge скрывает иконку;
- смена цели и выход из боя обновляют состояние;
- Glow корректно включается и выключается.

## Общая стабильность

Проверьте:

- нет Lua errors;
- нет застрявшей иконки;
- нет невидимого click blocker;
- нет заметного UI lag.

## Результат

Скопируйте и заполните этот блок в следующем сообщении:

```text
Commit:
Artifact:
Installable ZIP:
SHA-256:
WoW version/build:
Interface:
Locale:
Priest spec:
Talents:

Installation: PASS/FAIL
Settings: PASS/FAIL
Persistence after /reload: PASS/FAIL
Above 20%: PASS/FAIL
At/below 20%: PASS/FAIL
GCD: PASS/FAIL
Own cooldown: PASS/FAIL
Charges: PASS/FAIL
Target/combat transitions: PASS/FAIL
Glow: PASS/FAIL
Lua errors: PASS/FAIL

Notes:
```
