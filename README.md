# Better Screenshot

Convenient screenshots for macOS, the way Windows does it: pick an area / window / screen, get a thumbnail in the corner and a simple editor. Free and open source.

**English** | [Русский](#русская-версия)

![Editor](docs/screenshots/editor.jpg)

| | |
|---|---|
| ![Capture: area / window / screen](docs/screenshots/capture.jpg) | ![Thumbnail in the corner](docs/screenshots/thumbnail.jpg) |
| ![Settings](docs/screenshots/settings.png) | |

## Features

- Global hotkey (default **⇧⌘S**, configurable in Settings).
- Capture modes: **area**, **window**, **full screen** (keys 1 / 2 / 3, Esc to cancel).
- The screenshot goes to the clipboard immediately; a thumbnail appears in a screen corner (corner and duration are configurable). Click it to open the editor.
- Editor: pencil, highlighter, line, arrow, rectangle, oval, **text** (⌥/⌘/⇧ + Enter for a new line, double-click to edit), step numbers, **mosaic** (hide passwords and other secrets) and crop.
- **Shape straightening**: a hand-drawn circle, rectangle, line or arrow becomes a clean one. ⌘Z brings back exactly what you drew.
- Hold **Shift** while drawing for straight lines (15° steps) and squares / circles.
- **Copy** (to the clipboard, closes the editor) and **Save…** (PNG) buttons.
- **Launch at login** (on by default after the first run, can be turned off in Settings).
- **Languages**: English (default), Русский, Українська, Deutsch, Français, Español, 简体中文, 日本語 — pick one in Settings. Translations were made with AI; corrections are welcome.

## Install

1. Download `Better-Screenshot-*.dmg` from [Releases](../../releases) and drag the app into Applications. Requires macOS 14 or newer; runs on Apple Silicon and Intel.
2. The app is not signed with an Apple Developer certificate, so on first launch: right-click → **Open**. If macOS says the app is damaged:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Better Screenshot.app"
   ```
3. Allow it in System Settings → Privacy & Security → **Screen Recording**, then restart the app.

The app lives in the menu bar (camera icon) and has no Dock icon.

## Build from source

Needs Swift 5.9+ (Command Line Tools are enough).

```bash
./build.sh              # builds "Better Screenshot.app"
./package.sh 0.1.0      # universal .dmg installer in dist/
```

## Support the author

The app is free. If it is useful to you and you want to say thanks: [DonationAlerts](https://www.donationalerts.com/r/chopor). Thank you!

## Made with AI

This project was created with the help of an AI assistant (Claude by Anthropic) under the author's direction. As with any software, read the code and test it before relying on it.

## License

[MIT](LICENSE) — use it freely.

---

<a id="русская-версия"></a>

# Русская версия

[↑ English](#better-screenshot)

![Редактор](docs/screenshots/editor.jpg)

Удобные скриншоты для macOS, как в Windows: выбор области / окна / экрана, миниатюра в углу и простой редактор. Бесплатно и с открытым кодом.

## Возможности

- Глобальная горячая клавиша (по умолчанию **⇧⌘S**, меняется в настройках).
- Режимы: **область**, **окно**, **весь экран** (клавиши 1 / 2 / 3, Esc — отмена).
- Снимок сразу попадает в буфер обмена; миниатюра появляется в углу экрана (угол и время показа настраиваются). Клик по ней открывает редактор.
- Редактор: карандаш, маркер, линия, стрелка, прямоугольник, овал, **текст** (⌥/⌘/⇧ + Enter — новая строка, двойной клик — правка), нумерация шагов, **мозаика** (скрыть пароли и другие секреты) и обрезка.
- **Выпрямление фигур**: нарисованные от руки круг, прямоугольник, линия и стрелка становятся ровными. ⌘Z возвращает штрих как был нарисован.
- **Shift** при рисовании — ровные линии (шаг 15°), квадраты и круги.
- Кнопки **«Копировать»** (в буфер, редактор закрывается) и **«Сохранить…»** (PNG).
- **Автозапуск при входе** (после первого запуска включён, выключается в настройках).
- **Языки**: English (по умолчанию), Русский, Українська, Deutsch, Français, Español, 简体中文, 日本語 — выбираются в настройках. Переводы сделаны нейросетью, исправления приветствуются.

## Установка

1. Скачайте `Better-Screenshot-*.dmg` на странице [Releases](../../releases) и перетащите приложение в «Программы». Нужна macOS 14 или новее; работает на Apple Silicon и Intel.
2. Приложение не подписано сертификатом Apple Developer, поэтому при первом запуске: правый клик → **Открыть**. Если macOS пишет, что приложение повреждено:
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Better Screenshot.app"
   ```
3. Разрешите доступ в Системные настройки → Конфиденциальность и безопасность → **Запись экрана** и перезапустите приложение.

Приложение живёт в строке меню (иконка камеры), значка в Dock нет.

## Сборка из исходников

Нужен Swift 5.9+ (хватит Command Line Tools).

```bash
./build.sh              # собирает "Better Screenshot.app"
./package.sh 0.1.0      # универсальный .dmg в dist/
```

## Поддержать автора

Приложение бесплатное. Если оно вам пригодилось и хочется сказать спасибо: [DonationAlerts](https://www.donationalerts.com/r/chopor). Спасибо!

## Создано с помощью нейросети

Проект создан с помощью нейросети (Claude от Anthropic) под руководством автора. Как и любое другое ПО, прочитайте код и проверьте его, прежде чем на него полагаться.

## Лицензия

[MIT](LICENSE) — используйте свободно.
