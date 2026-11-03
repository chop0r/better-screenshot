import Foundation

/// Languages in the order of the columns in `Strings.table`.
enum Lang {
    static let codes = ["en", "ru", "uk", "de", "fr", "es", "zh", "ja"]
    static let names = ["English", "Русский", "Українська", "Deutsch", "Français", "Español", "简体中文", "日本語"]
}

func tr(_ key: String) -> String {
    guard let row = Strings.table[key] else { return key }
    let i = Lang.codes.firstIndex(of: Settings.shared.language) ?? 0
    return i < row.count ? row[i] : row[0]
}

enum Strings {
    // Columns: en, ru, uk, de, fr, es, zh, ja
    static let table: [String: [String]] = [
        "mode.area": ["Area", "Область", "Область", "Bereich", "Zone", "Área", "区域", "範囲"],
        "mode.window": ["Window", "Окно", "Вікно", "Fenster", "Fenêtre", "Ventana", "窗口", "ウィンドウ"],
        "mode.screen": ["Screen", "Экран", "Екран", "Bildschirm", "Écran", "Pantalla", "屏幕", "画面"],
        "esc.cancel": ["Esc — cancel", "Esc — отмена", "Esc — скасувати", "Esc — abbrechen", "Échap — annuler", "Esc — cancelar", "Esc — 取消", "Esc — キャンセル"],
        "thumb.copied": ["✓ Copied", "✓ Скопировано", "✓ Скопійовано", "✓ Kopiert", "✓ Copié", "✓ Copiado", "✓ 已复制", "✓ コピーしました"],
        "thumb.edit": ["Click to edit", "Нажмите для редактирования", "Натисніть, щоб редагувати", "Zum Bearbeiten klicken", "Cliquez pour modifier", "Haz clic para editar", "点击编辑", "クリックして編集"],
        "corner.bottomLeft": ["Bottom left", "Снизу слева", "Знизу ліворуч", "Unten links", "En bas à gauche", "Abajo a la izquierda", "左下角", "左下"],
        "corner.bottomRight": ["Bottom right", "Снизу справа", "Знизу праворуч", "Unten rechts", "En bas à droite", "Abajo a la derecha", "右下角", "右下"],
        "corner.topLeft": ["Top left", "Сверху слева", "Зверху ліворуч", "Oben links", "En haut à gauche", "Arriba a la izquierda", "左上角", "左上"],
        "corner.topRight": ["Top right", "Сверху справа", "Зверху праворуч", "Oben rechts", "En haut à droite", "Arriba a la derecha", "右上角", "右上"],
        "tool.select": ["Select / move", "Выбрать / переместить", "Вибрати / перемістити", "Auswählen / verschieben", "Sélectionner / déplacer", "Seleccionar / mover", "选择 / 移动", "選択 / 移動"],
        "tool.pen": ["Pen (with shape recognition)", "Карандаш (с распознаванием фигур)", "Олівець (з розпізнаванням фігур)", "Stift (mit Formerkennung)", "Crayon (avec reconnaissance de formes)", "Lápiz (con reconocimiento de formas)", "画笔（自动识别形状）", "ペン（図形認識付き）"],
        "tool.highlighter": ["Highlighter", "Маркер", "Маркер", "Textmarker", "Surligneur", "Marcador", "荧光笔", "蛍光ペン"],
        "tool.line": ["Line", "Линия", "Лінія", "Linie", "Ligne", "Línea", "直线", "線"],
        "tool.arrow": ["Arrow", "Стрелка", "Стрілка", "Pfeil", "Flèche", "Flecha", "箭头", "矢印"],
        "tool.rect": ["Rectangle", "Прямоугольник", "Прямокутник", "Rechteck", "Rectangle", "Rectángulo", "矩形", "長方形"],
        "tool.ellipse": ["Oval", "Овал", "Овал", "Oval", "Ovale", "Óvalo", "椭圆", "楕円"],
        "tool.text": ["Text", "Текст", "Текст", "Text", "Texte", "Texto", "文字", "テキスト"],
        "tool.number": ["Step numbers", "Нумерация", "Нумерація", "Nummerierung", "Numérotation", "Numeración", "编号", "番号"],
        "tool.mosaic": ["Mosaic (hide sensitive data)", "Мозаика (скрыть данные)", "Мозаїка (приховати дані)", "Mosaik (Daten verbergen)", "Mosaïque (masquer des données)", "Mosaico (ocultar datos)", "马赛克（隐藏敏感信息）", "モザイク（情報を隠す）"],
        "tool.crop": ["Crop", "Обрезка", "Обрізання", "Zuschneiden", "Recadrer", "Recortar", "裁剪", "トリミング"],
        "ed.title": ["Screenshot Editor", "Редактор скриншота", "Редактор скриншота", "Screenshot-Editor", "Éditeur de capture", "Editor de capturas", "截图编辑器", "スクリーンショットエディタ"],
        "ed.save": ["Save…", "Сохранить…", "Зберегти…", "Sichern…", "Enregistrer…", "Guardar…", "保存…", "保存…"],
        "ed.copy": ["Copy", "Копировать", "Копіювати", "Kopieren", "Copier", "Copiar", "复制", "コピー"],
        "ed.copy.tip": ["Copy the result to the clipboard and close (⌘C)", "Скопировать результат в буфер и закрыть (⌘C)", "Скопіювати результат у буфер і закрити (⌘C)", "Ergebnis in die Zwischenablage kopieren und schließen (⌘C)", "Copier le résultat dans le presse-papiers et fermer (⌘C)", "Copiar el resultado al portapapeles y cerrar (⌘C)", "复制结果到剪贴板并关闭 (⌘C)", "結果をクリップボードにコピーして閉じる (⌘C)"],
        "ed.undo": ["Undo (⌘Z)", "Отменить (⌘Z)", "Скасувати (⌘Z)", "Widerrufen (⌘Z)", "Annuler (⌘Z)", "Deshacer (⌘Z)", "撤销 (⌘Z)", "取り消す (⌘Z)"],
        "ed.redo": ["Redo (⇧⌘Z)", "Вернуть (⇧⌘Z)", "Повернути (⇧⌘Z)", "Wiederholen (⇧⌘Z)", "Rétablir (⇧⌘Z)", "Rehacer (⇧⌘Z)", "重做 (⇧⌘Z)", "やり直す (⇧⌘Z)"],
        "size.thin": ["Thin", "Тонко", "Тонко", "Dünn", "Fin", "Fino", "细", "細"],
        "size.medium": ["Medium", "Средне", "Середньо", "Mittel", "Moyen", "Medio", "中", "中"],
        "size.thick": ["Thick", "Толсто", "Товсто", "Dick", "Épais", "Grueso", "粗", "太"],
        "ed.smart": ["Straighten shapes", "Выпрямлять фигуры", "Вирівнювати фігури", "Formen begradigen", "Redresser les formes", "Enderezar formas", "自动矫正形状", "図形を整える"],
        "ed.smart.tip": ["A hand-drawn circle, rectangle, line or arrow becomes a clean one. ⌘Z brings back your original stroke.", "Нарисованные от руки круг, прямоугольник, линия и стрелка станут ровными. ⌘Z вернёт как было.", "Намальовані від руки коло, прямокутник, лінія та стрілка стануть рівними. ⌘Z поверне як було.", "Ein von Hand gezeichneter Kreis, ein Rechteck, eine Linie oder ein Pfeil wird sauber. ⌘Z stellt den ursprünglichen Strich wieder her.", "Un cercle, rectangle, trait ou flèche dessiné à main levée est redressé. ⌘Z rétablit le tracé d'origine.", "Un círculo, rectángulo, línea o flecha dibujado a mano se vuelve limpio. ⌘Z recupera el trazo original.", "手绘的圆、矩形、直线和箭头会被矫正。⌘Z 可恢复原笔迹。", "手描きの円・長方形・線・矢印がきれいに整います。⌘Z で元の線に戻せます。"],
        "ed.shift": ["Shift — straight angles / square", "Shift — ровные углы / квадрат", "Shift — рівні кути / квадрат", "Shift — gerade Winkel / Quadrat", "Maj — angles droits / carré", "Mayús — ángulos rectos / cuadrado", "Shift — 规整角度 / 正方形", "Shift — 角度固定 / 正方形"],
        "set.title": ["Better Screenshot Settings", "Настройки Better Screenshot", "Налаштування Better Screenshot", "Einstellungen für Better Screenshot", "Réglages de Better Screenshot", "Ajustes de Better Screenshot", "Better Screenshot 设置", "Better Screenshot の設定"],
        "set.hotkey": ["Hotkey:", "Горячая клавиша:", "Гаряча клавіша:", "Tastenkürzel:", "Raccourci :", "Atajo:", "快捷键：", "ショートカット："],
        "set.thumb": ["Thumbnail:", "Миниатюра:", "Мініатюра:", "Vorschau:", "Miniature :", "Miniatura:", "缩略图：", "サムネイル："],
        "set.show": ["Show for:", "Показывать:", "Показувати:", "Anzeigedauer:", "Afficher pendant :", "Mostrar durante:", "显示时长：", "表示時間："],
        "set.lang": ["Language:", "Язык:", "Мова:", "Sprache:", "Langue :", "Idioma:", "语言：", "言語："],
        "set.press": ["Press shortcut…", "Нажмите сочетание…", "Натисніть комбінацію…", "Kürzel drücken …", "Appuyez sur le raccourci…", "Pulsa el atajo…", "请按下快捷键…", "ショートカットを押す…"],
        "set.login": ["Launch at login", "Запускать при входе", "Запускати під час входу", "Beim Anmelden starten", "Ouvrir à l'ouverture de session", "Abrir al iniciar sesión", "登录时启动", "ログイン時に起動"],
        "sec": ["%d s", "%d сек", "%d с", "%d Sek.", "%d s", "%d s", "%d 秒", "%d 秒"],
        "menu.capture": ["Take screenshot", "Сделать снимок", "Зробити знімок", "Screenshot aufnehmen", "Prendre une capture", "Hacer captura", "截图", "スクリーンショットを撮る"],
        "menu.settings": ["Settings…", "Настройки…", "Налаштування…", "Einstellungen …", "Réglages…", "Ajustes…", "设置…", "設定…"],
        "menu.quit": ["Quit", "Выйти", "Вийти", "Beenden", "Quitter", "Salir", "退出", "終了"],
        "menu.file": ["File", "Файл", "Файл", "Ablage", "Fichier", "Archivo", "文件", "ファイル"],
        "menu.close": ["Close", "Закрыть", "Закрити", "Schließen", "Fermer", "Cerrar", "关闭", "閉じる"],
        "menu.edit": ["Edit", "Правка", "Редагування", "Bearbeiten", "Édition", "Edición", "编辑", "編集"],
        "menu.undo": ["Undo", "Отменить", "Скасувати", "Widerrufen", "Annuler", "Deshacer", "撤销", "取り消す"],
        "menu.redo": ["Redo", "Вернуть", "Повернути", "Wiederholen", "Rétablir", "Rehacer", "重做", "やり直す"],
        "menu.cut": ["Cut", "Вырезать", "Вирізати", "Ausschneiden", "Couper", "Cortar", "剪切", "カット"],
        "menu.paste": ["Paste", "Вставить", "Вставити", "Einsetzen", "Coller", "Pegar", "粘贴", "ペースト"],
        "menu.selectall": ["Select All", "Выделить всё", "Вибрати все", "Alles auswählen", "Tout sélectionner", "Seleccionar todo", "全选", "すべてを選択"],
        "alert.perm.title": ["Screen Recording access needed", "Нужен доступ к записи экрана", "Потрібен доступ до запису екрана", "Zugriff auf Bildschirmaufnahme erforderlich", "Accès à l'enregistrement d'écran requis", "Se necesita acceso a la grabación de pantalla", "需要屏幕录制权限", "画面収録の許可が必要です"],
        "alert.perm.text": ["Open System Settings → Privacy & Security → Screen Recording, enable Better Screenshot and restart the app.", "Откройте Системные настройки → Конфиденциальность и безопасность → Запись экрана, включите Better Screenshot и перезапустите приложение.", "Відкрийте Системні налаштування → Конфіденційність і безпека → Запис екрана, увімкніть Better Screenshot і перезапустіть застосунок.", "Öffne Systemeinstellungen → Datenschutz & Sicherheit → Bildschirmaufnahme, aktiviere Better Screenshot und starte die App neu.", "Ouvrez Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran, activez Better Screenshot et relancez l'app.", "Abre Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla, activa Better Screenshot y reinicia la app.", "打开“系统设置”→“隐私与安全性”→“屏幕录制”，启用 Better Screenshot 后重新启动应用。", "システム設定 → プライバシーとセキュリティ → 画面収録 で Better Screenshot をオンにし、アプリを再起動してください。"],
        "alert.fail": ["Could not take the screenshot", "Не удалось сделать снимок", "Не вдалося зробити знімок", "Screenshot fehlgeschlagen", "Impossible de prendre la capture", "No se pudo hacer la captura", "截图失败", "スクリーンショットを撮れませんでした"],
    ]
}
