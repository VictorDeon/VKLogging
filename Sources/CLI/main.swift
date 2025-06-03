import VKLogging

let logger = LoggerSingleton(
    level: "debug",
    version: "v1.5.5",
    label: "tech.vksoftware.myapp"
)

let newLogger = LoggerSingleton.shared

logger.debug("Ola mundo debug!")
newLogger!.info("Ola mundo info!", trace: "abcd1234")
newLogger!.warning("Ola mundo warning!", trace: "abcd1234", json: ["Test": ["value": 1]])
