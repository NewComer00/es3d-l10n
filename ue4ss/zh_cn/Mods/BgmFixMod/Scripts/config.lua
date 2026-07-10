local Config = {}

Config.LOG_PREFIX = "[BgmFixMod] "

Config.RESTORE_DELAY_MS = 500
Config.START_DELAY_MS = 2000
Config.RETRY_INTERVAL_MS = 1000
Config.RETRY_MAX = 15
Config.PERIODIC_INTERVAL_MS = 10000

Config.SETTINGS_SAVE_RELATIVE = "Everlasting_summer\\Saved\\SaveGames\\setting.sav"
Config.SAVE_SLOT = "setting"
Config.SAVE_USER_INDEX = 0
Config.SAVE_DETECT_POLL_MS = 200
Config.SAVE_DETECT_MAX = 25

Config.OPTIONS_CLASS_PATH = "/Game/main/hud/options7.options7_C"
Config.MYSAVEGAME_CLASS = "/Game/main/bp/mysavegame.mysavegame_C"

Config.FN_CREATE = "создать"
Config.FN_AUDIO = "аудио"
Config.FN_VIDEO = "видео"
Config.FN_SAVE_AUDIO = "сохранения звука(настроки)"
Config.DELEGATE_VOLUME_DISPA = "volume dispa"
Config.PROP_VOLUME_GAME = "volume game"
Config.PROP_MOUSE_SENS = "чуствительность мыши"
Config.VOLUME_NUDGE_STEP = 0.01

Config.VOLUME_CHANNEL = {
    label = "Music",
    giProp = "volume game",
    slider = "Sliderмузыка",
    handler = "BndEvt__Slider_630_K2Node_ComponentBoundEvent_401_OnFloatValueChangedEvent__DelegateSignature",
}

return Config
