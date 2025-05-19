// Aqui vamos mostrar como utiliza os logs do swift

import Foundation
internal import Logging


/// Um LogHandler que escreve cada mensagem no final de um arquivo
struct FileLogHandler: LogHandler {
    let label: String
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .debug
    var version: String = "1.0.0"

    private let lock = NSLock()
    private let fileHandle: FileHandle

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()

    init(label: String, version: String, dtFormat: String) {
        self.label = label
        self.version = version
        self.dateFormatter.dateFormat = dtFormat

        // caminho do arquivo de log
        let path = "/var/log/\(label).log"
        let url = URL(fileURLWithPath: path)
        let fileManager = FileManager.default

        // cria o arquivo se não existir
        if !fileManager.fileExists(atPath: path) {
            fileManager.createFile(atPath: path, contents: nil, attributes: [
                // ajuste permissões se necessário
                FileAttributeKey.posixPermissions: 0o644
            ])
        }

        // abre para escrever e posiciona no fim
        do {
            fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
        } catch {
            fatalError("Não foi possível abrir o arquivo de log em \(path): \(error)")
        }
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = dateFormatter.string(from: Date())
        var msg = "\(timestamp) [\(level)] \(version)"

        if let trace = metadata!["trace"] {
            msg += " trace=\(trace)"
        }

        msg += ": \(message)\n"

        guard let data = msg.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }
        fileHandle.write(data)
    }
}

struct ConsoleLogHandler: LogHandler {
    let label: String
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .debug
    var version: String = "1.0.0"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYY-MM-dd HH:mm:ss"
        return formatter
    }()

    init(label: String, level: Logger.Level, version: String, dtFormat: String) {
        self.label = label
        self.logLevel = level
        self.version = version
        dateFormatter.dateFormat = dtFormat
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    // swiftlint:disable:next function_parameter_count
    func log(
      level: Logger.Level,
      message: Logger.Message,
      metadata: Logger.Metadata?,
      source: String,
      file: String,
      function: String,
      line: UInt
    ) {
        let timestamp = dateFormatter.string(from: Date())
        var msg = "\(timestamp) [\(level)] \(version)"

        if let trace = metadata!["trace"] {
            msg += " trace=\(trace)"
        }

        print(msg + ": \(message)")
    }
}

/// JSONFormatter que usa JSONEncoder configurado para ISO8601, sem escapar barras, etc.
struct JSONFormatter {
    private let encoder: JSONEncoder

    init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Se quiser saída compacta:
        encoder.outputFormatting = []
    }

    func stringify(_ dict: [String: AnyEncodable]) -> String {
        do {
            let data = try encoder.encode(dict)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "{\"encoding_error\": \"\(error)\"}"
        }
    }
}

/// AnyEncodable para embrulhar vários tipos em um Encodable genérico
public struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void

    public init<T: Encodable>(_ wrapped: T) {
        encodeClosure = wrapped.encode(to:)
    }

    public func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}

/// Singleton de logger
public final class LoggerSingleton {
    @MainActor public static let shared = LoggerSingleton()
    private let logger: Logger
    private let jsonFormatter = JSONFormatter()
    nonisolated(unsafe) public static var version = "v1.0.0"
    nonisolated(unsafe) public static var label = "tech.vksoftware.example"
    nonisolated(unsafe) public static var dateTimeFormat = "YYY-MM-dd HH:mm:ss"

    private init() {
        let lvlStr = ProcessInfo.processInfo.environment["LOG_LEVEL"] ?? "info"
        let level: Logger.Level = {
            switch lvlStr.uppercased() {
            case "INFO":     return .info
            case "WARNING":  return .warning
            case "ERROR":    return .error
            default:         return .debug
            }
        }()

        LoggingSystem.bootstrap { label in
            let file = FileLogHandler(
                label: label,
                version: LoggerSingleton.version,
                dtFormat: LoggerSingleton.dateTimeFormat
            )
            let console = ConsoleLogHandler(
                label: label,
                level: level,
                version: LoggerSingleton.version,
                dtFormat: LoggerSingleton.dateTimeFormat
            )
            return MultiplexLogHandler([console, file])
        }

        self.logger = Logger(label: LoggerSingleton.label)
    }

    // MARK: Métodos de logging
    public func debug(_ msg: String, trace: String?, json: [String: AnyEncodable]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            let payload = jsonFormatter.stringify(jsonSafe)
            logger.debug("\(msg) \(payload)", metadata: metadata)
            return
        }
        logger.debug("\(msg)", metadata: metadata)
    }

    public func debug(_ msg: String, trace: String) {
        self.debug(msg, trace: trace, json: nil)
    }

    public func debug(_ msg: String) {
        self.debug(msg, trace: nil, json: nil)
    }

    public func info(_ msg: String, trace: String?, json: [String: AnyEncodable]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            let payload = jsonFormatter.stringify(jsonSafe)
            logger.info("\(msg) \(payload)", metadata: metadata)
            return
        }
        logger.info("\(msg)", metadata: metadata)
    }

    public func info(_ msg: String, trace: String) {
        self.info(msg, trace: trace, json: nil)
    }

    public func info(_ msg: String) {
        self.info(msg, trace: nil, json: nil)
    }

    public func warning(_ msg: String, trace: String?, json: [String: AnyEncodable]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            let payload = jsonFormatter.stringify(jsonSafe)
            logger.warning("\(msg) \(payload)", metadata: metadata)
            return
        }
        logger.warning("\(msg)", metadata: metadata)
    }

    public func warning(_ msg: String, trace: String) {
        self.warning(msg, trace: trace, json: nil)
    }

    public func warning(_ msg: String) {
        self.warning(msg, trace: nil, json: nil)
    }

    public func error(_ error: Error, trace: String?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }
        logger.error("\(error.localizedDescription)", metadata: metadata)
    }

    public func error(_ error: Error) {
        self.error(error, trace: nil)
    }
}
