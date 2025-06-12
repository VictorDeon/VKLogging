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

    init(label: String, version: String, dtFormat: String, destination: URL) {
        self.label = label
        self.version = version
        self.dateFormatter.dateFormat = dtFormat
        let fm = FileManager.default

        let dirURL = destination.deletingLastPathComponent()
        // 1. Garante que a pasta exista
        if !fm.fileExists(atPath: dirURL.path) {
            do {
                try fm.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Could not create directory \(dirURL.absoluteString): \(error)")
            }
        }
        
        // 2. Cria o arquivo vazio se ainda não existir
        if !fm.fileExists(atPath: destination.path) {
            fm.createFile(atPath: destination.path, contents: nil, attributes: nil)
        }

        // abre para escrever e posiciona no fim
        do {
            fileHandle = try FileHandle(forWritingTo: destination)
            fileHandle.seekToEndOfFile()
        } catch {
            print("Could not open log file at \(destination.path): \(error)")
            exit(1)
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
        var msg = "\(timestamp) [\(level)] \(version):"

        if let trace = metadata?["trace"] {
            msg = "\(timestamp) [\(level)] \(version) trace=\(trace):"
        }

        msg += " \(message)\n"

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
        var msg = "\(timestamp) [\(level)] \(version):"

        if let trace = metadata?["trace"] {
            msg = "\(timestamp) [\(level)] \(version) trace=\(trace):"
        }

        print(msg + " \(message)")
    }
}

@MainActor
public final class LoggerSingleton {
    /// Instancia única de log
    public static var shared: LoggerSingleton?
    private var logger: Logger?

    /// Singleton de logger
    /// - Parameters:
    ///     - level: Level do log, pode ser: debug, info, warning ou error.
    ///     - version: Versão que ira aparecer nos logs.
    ///     - label: Nome do arquivo que ira aparecer em /tmp/<label>.log.
    ///     - dateTimeFormat: Formato da data e hora do log.
    ///     - destination: Para onde vai o log dentro do sistema.
    public init(level: String, version: String?, label: String?, dateTimeFormat: String?, destination: URL?) {
        self.initialize(level, version, label, dateTimeFormat, destination)
    }

    /// Singleton de logger
    /// - Parameters:
    ///     - level: Level do log, pode ser: debug, info, warning ou error.
    ///     - version: Versão que ira aparecer nos logs.
    ///     - label: Nome do arquivo que ira aparecer em /tmp/<label>.log.
    ///     - dateTimeFormat: Formato da data e hora do log.
    public init(level: String, version: String?, label: String?, dateTimeFormat: String?) {
        self.initialize(level, version, label, dateTimeFormat, nil)
    }
    
    /// Singleton de logger
    /// - Parameters:
    ///     - level: Level do log, pode ser: debug, info, warning ou error.
    ///     - version: Versão que ira aparecer nos logs.
    ///     - label: Nome do arquivo que ira aparecer em /tmp/<label>.log.
    ///     - destination: Para onde vai o log dentro do sistema.
    public init(level: String, version: String?, label: String?, destination: URL?) {
        self.initialize(level, version, label, nil, destination)
    }

    /// Singleton de logger
    /// - Parameters:
    ///     - level: Level do log, pode ser: debug, info, warning ou error.
    ///     - version: Versão que ira aparecer nos logs.
    ///     - label: Nome do arquivo que ira aparecer em /tmp/<label>.log.
    public init(level: String, version: String?, label: String?) {
        self.initialize(level, version, label, nil, nil)
    }

    private func initialize(
        _ level: String,
        _ version: String?,
        _ label: String?,
        _ dateTimeFormat: String?,
        _ destination: URL?) {
        if LoggerSingleton.shared == nil {
            let version = version ?? "v1.0.0"
            let label = label ?? "tech.vksoftware.example"
            let dateTimeFormat = dateTimeFormat ?? "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let destination: URL = destination ?? FileManager.default.temporaryDirectory
              .appendingPathComponent("tech.rocketman.tempadmin.log")
            
            print("Log save at: \(destination.path)")

            let level: Logger.Level = {
                switch level.uppercased() {
                case "INFO":     return .info
                case "WARNING":  return .warning
                case "ERROR":    return .error
                default:         return .debug
                }
            }()

            LoggingSystem.bootstrap { label in
                let file = FileLogHandler(
                    label: label,
                    version: version,
                    dtFormat: dateTimeFormat,
                    destination: destination
                )
                let console = ConsoleLogHandler(
                    label: label,
                    level: level,
                    version: version,
                    dtFormat: dateTimeFormat
                )
                return MultiplexLogHandler([console, file])
            }

            self.logger = Logger(label: label)
            LoggerSingleton.shared = self
        } else {
            print("O singleton de logger já foi inicializado. Utilize o LoggerSingleton.shared para obter o logger.")
            exit(1)
        }
    }

    /// Gera log de nivel debug
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    ///     - json: Dicionarios com chave e valor que pode ser inserido no log,
    public func debug(_ msg: String, trace: String?, json: [String: Any]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonSafe,
                    options: .prettyPrinted
                )
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logger?.debug("\(msg)\n\(jsonString)", metadata: metadata)
                }
            } catch {
                logger?.debug("\(msg)", metadata: metadata)
            }
            return
        }
        logger?.debug("\(msg)", metadata: metadata)
    }

    /// Gera log de nivel debug
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    public func debug(_ msg: String, trace: String) {
        self.debug(msg, trace: trace, json: nil)
    }

    /// Gera log de nivel debug
    /// - Parameters:
    ///     - msg: Mensagem do log
    public func debug(_ msg: String) {
        self.debug(msg, trace: nil, json: nil)
    }

    /// Gera log de nivel info
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    ///     - json: Dicionarios com chave e valor que pode ser inserido no log,
    public func info(_ msg: String, trace: String?, json: [String: Any]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonSafe,
                    options: .prettyPrinted
                )
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logger?.info("\(msg)\n\(jsonString)", metadata: metadata)
                }
            } catch {
                logger?.info("\(msg)", metadata: metadata)
            }
            return
        }
        logger?.info("\(msg)", metadata: metadata)
    }

    /// Gera log de nivel info
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    public func info(_ msg: String, trace: String) {
        self.info(msg, trace: trace, json: nil)
    }

    /// Gera log de nivel info
    /// - Parameters:
    ///     - msg: Mensagem do log
    public func info(_ msg: String) {
        self.info(msg, trace: nil, json: nil)
    }

    /// Gera log de nivel warning
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    ///     - json: Dicionarios com chave e valor que pode ser inserido no log,
    public func warning(_ msg: String, trace: String?, json: [String: Any]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonSafe,
                    options: .prettyPrinted
                )
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logger?.warning("\(msg)\n\(jsonString)", metadata: metadata)
                }
            } catch {
                logger?.warning("\(msg)", metadata: metadata)
            }
            return
        }
        logger?.warning("\(msg)", metadata: metadata)
    }

    /// Gera log de nivel warning
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    public func warning(_ msg: String, trace: String) {
        self.warning(msg, trace: trace, json: nil)
    }

    /// Gera log de nivel warning
    /// - Parameters:
    ///     - msg: Mensagem do log
    public func warning(_ msg: String) {
        self.warning(msg, trace: nil, json: nil)
    }
    
    /// Gera log de nivel error
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    ///     - json: Dicionarios com chave e valor que pode ser inserido no log,
    public func error(_ msg: String, trace: String?, json: [String: Any]?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }

        if let jsonSafe = json {
            do {
                let jsonData = try JSONSerialization.data(
                    withJSONObject: jsonSafe,
                    options: .prettyPrinted
                )
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logger?.error("\(msg)\n\(jsonString)", metadata: metadata)
                }
            } catch {
                logger?.error("\(msg)", metadata: metadata)
            }
            return
        }
        logger?.error("\(msg)", metadata: metadata)
    }

    /// Gera log de nivel error
    /// - Parameters:
    ///     - msg: Mensagem do log
    ///     - trace: Trace ID do log
    public func error(_ msg: String, trace: String) {
        self.error(msg, trace: trace, json: nil)
    }

    /// Gera log de nivel error
    /// - Parameters:
    ///     - msg: Mensagem do log
    public func error(_ msg: String) {
        self.error(msg, trace: nil, json: nil)
    }

    /// Gera log de nivel error
    /// - Parameters:
    ///     - error: Objeto de Error
    ///     - trace: Trace ID do log
    public func error(_ error: Error, trace: String?) {
        var metadata: [String: Logger.MetadataValue] = [:]
        if let traceSafe = trace {
            metadata["trace"] = .string(traceSafe)
        }
        logger?.error("\(error.localizedDescription)", metadata: metadata)
    }

    /// Gera log de nivel error
    /// - Parameters:
    ///     - error: Objeto de Error
    public func error(_ error: Error) {
        self.error(error, trace: nil)
    }
}
