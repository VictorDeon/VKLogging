import Foundation
import VKLogging

let destination = URL(fileURLWithPath: "/var/log/tech.vksoftware.app.log")

let logger = LoggerSingleton(
    level: "debug",
    version: "v1.5.5",
    label: "tech.vksoftware.myapp",
    destination: destination
)

let newLogger = LoggerSingleton.shared!

logger.debug("Ola mundo debug!")
newLogger.info("Ola mundo info!", trace: "abcd1234")
newLogger.warning("Ola mundo warning!", trace: "abcd1234", json: ["Test": ["value": 1]])
newLogger.error("Deu ruim!", trace: "abcd1234", json: ["opaa": 123])
print(newLogger.logPath)
