local Config = {}

Config.LOG_PREFIX = "[LightingFixMod] "

Config.RESTORE_DELAY_MS = 500
Config.AUTO_RETRY_INTERVAL_MS = 1000
Config.AUTO_RETRY_MAX = 10
Config.HOOK_POLL_MS = 1000
Config.LOAD_FROM_SLOT_POLL_MS = 200

Config.SCENES = {
    in_game = {
        delay_ms = 2000,
        mode = "full",
    },
}

Config.OPTIONS_CLASS_PATH = "/Game/main/hud/options7.options7_C"
Config.VISUAL_EFFECTS_LABEL = "Визульные эффекты"

Config.FN_APPLY_SETTINGS = "применяем"
Config.FN_VIDEO = "видео"
Config.DELEGATE_VOLUME_DISPA = "volume dispa"
Config.PROP_VOLUME_GAME = "volume game"
Config.PROP_SOVEN = "совен"

Config.HOOK_LOAD_STREAMED = "/Game/StoryAdvTemplate/Blueprints/BP_GameController.BP_GameController_C:LoadStreamedLevelsFromSlot"
Config.HOOK_DISPLAY_HUD_TEXT = "/Game/StoryAdvTemplate/Blueprints/BP_GameController.BP_GameController_C:DisplayHUDText"

Config.MYGAMEINSTANS_CLASS = "mygameinstans_C"
Config.PROP_LOAD_FROM_SLOT = "LoadFromSlot?"

Config.LOAD_COMPLETE_MARKERS = {
    "загружена",
    "loaded",
    "加载",
}

return Config
