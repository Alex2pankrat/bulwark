extends Node
## Localisation service. Autoload name: `Loc`.
##
## Wraps the static `L10n` tables with the currently selected language and emits a signal so
## visible labels can retranslate themselves without reloading the screen.

signal language_changed(language: String)

var language: String = "en"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_language(code: String) -> void:
	var next := code if L10n.TABLES.has(code) else "en"
	if next == language:
		return
	language = next
	language_changed.emit(language)


func t(key: String) -> String:
	return L10n.translate(language, key)


## Replaces `{0}`, `{1}`, … placeholders: `Loc.tf("level.progress", [3])`.
## Non-string arguments are stringified first, because `String.format` only accepts strings.
func tf(key: String, args: Array) -> String:
	var text := t(key)
	for i in range(args.size()):
		text = text.replace("{%d}" % i, str(args[i]))
	return text
