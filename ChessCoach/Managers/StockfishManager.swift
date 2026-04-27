import Foundation

// UCI subprocess wrapper for Stockfish. Runs as a persistent process for the lifetime
// of the app — never restarted per move. All I/O is actor-isolated to prevent pipe contention.
actor StockfishManager {
    static let shared = StockfishManager()

    private var process: Process?
    private var stdin: FileHandle?
    private var isReady = false

    // Line stream: background reader publishes newline-terminated lines from Stockfish stdout.
    private var lineStream: AsyncStream<String>?
    private var lineContinuation: AsyncStream<String>.Continuation?
    private let readQueue = DispatchQueue(label: "com.chesscoach.stockfish.reader", qos: .userInitiated)

    private init() {}

    // MARK: - Lifecycle

    func launch() async throws {
        guard let url = Bundle.main.url(forResource: "stockfish", withExtension: nil) else {
            throw StockfishError.binaryNotFound
        }

        let proc = Process()
        proc.executableURL = url

        let inPipe = Pipe()
        let outPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = Pipe()

        try proc.run()
        process = proc
        stdin = inPipe.fileHandleForWriting

        startLineReader(handle: outPipe.fileHandleForReading)

        try send("uci")
        try await waitFor("uciok", timeout: 5)
        isReady = true
    }

    func newGame() async throws {
        try requireReady()
        try send("ucinewgame")
        try send("isready")
        try await waitFor("readyok", timeout: 5)
    }

    func terminate() {
        lineContinuation?.finish()
        process?.terminate()
        process = nil
        stdin = nil
        isReady = false
    }

    // MARK: - CPU move (opponent mode)

    func requestMove(fen: String, difficulty: Int) async throws -> String {
        try requireReady()
        let (skillLevel, movetime) = Self.uciParams(for: difficulty)
        try send("position fen \(fen)")
        try send("setoption name Skill Level value \(skillLevel)")
        try send("go movetime \(movetime)")
        return try await readBestMove(timeout: Double(movetime) / 1000 + 3)
    }

    // MARK: - Position evaluation (coach mode)

    func evaluate(fen: String) async throws -> Int {
        try requireReady()
        try send("position fen \(fen)")
        try send("go depth 18")
        return try await readEvaluation(timeout: 15)
    }

    // MARK: - Private I/O

    private func startLineReader(handle: FileHandle) {
        var continuation: AsyncStream<String>.Continuation?
        lineStream = AsyncStream(String.self, bufferingPolicy: .unbounded) { cont in
            continuation = cont
        }
        lineContinuation = continuation
        guard let cont = continuation else { return }

        // Read Stockfish stdout on a background queue; bridge to AsyncStream via continuation.
        readQueue.async {
            var buffer = Data()
            let newline = Data([UInt8(ascii: "\n")])
            while true {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)
                while let range = buffer.range(of: newline) {
                    let lineData = buffer[buffer.startIndex..<range.lowerBound]
                    buffer.removeSubrange(buffer.startIndex...range.lowerBound)
                    if let line = String(data: lineData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                        cont.yield(line)
                    }
                }
            }
            cont.finish()
        }
    }

    private func send(_ command: String) throws {
        guard let handle = stdin else { throw StockfishError.notRunning }
        guard let data = (command + "\n").data(using: .utf8) else { throw StockfishError.encodingFailed }
        handle.write(data)
    }

    private func waitFor(_ prefix: String, timeout: TimeInterval) async throws {
        _ = try await collectLines(until: { $0.hasPrefix(prefix) }, timeout: timeout)
    }

    // Iterates lineStream directly on the actor executor — no escaping closures, no data races.
    // Timeout is enforced via wall-clock check after each line so fast-flowing Stockfish output
    // is not artificially throttled.
    private func collectLines(until predicate: (String) -> Bool, timeout: TimeInterval) async throws -> [String] {
        guard let stream = lineStream else { throw StockfishError.notRunning }
        var collected: [String] = []
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeout))
        for await line in stream {
            collected.append(line)
            if predicate(line) { return collected }
            if ContinuousClock.now > deadline { throw StockfishError.timeout }
        }
        throw StockfishError.notRunning
    }

    private func readBestMove(timeout: TimeInterval) async throws -> String {
        let lines = try await collectLines(until: { $0.hasPrefix("bestmove") }, timeout: timeout)
        guard let bestLine = lines.last(where: { $0.hasPrefix("bestmove") }) else {
            throw StockfishError.noBestMove
        }
        let parts = bestLine.split(separator: " ")
        guard parts.count >= 2 else { throw StockfishError.noBestMove }
        return String(parts[1])
    }

    private func readEvaluation(timeout: TimeInterval) async throws -> Int {
        let lines = try await collectLines(until: { $0.hasPrefix("bestmove") }, timeout: timeout)
        for line in lines.reversed() where line.hasPrefix("info") {
            if let cp = parseCentipawn(from: line) { return cp }
        }
        throw StockfishError.noEvaluation
    }

    private func parseCentipawn(from line: String) -> Int? {
        let parts = line.split(separator: " ")
        for (i, part) in parts.enumerated() {
            guard let next = i < parts.count - 1 ? parts[i + 1] : nil else { continue }
            if part == "mate", let n = Int(next) { return n > 0 ? 10_000 : -10_000 }
            if part == "cp",   let n = Int(next) { return n }
        }
        return nil
    }

    // MARK: - Helpers

    private func requireReady() throws {
        guard isReady else { throw StockfishError.notRunning }
    }

    // Difficulty mapping per CLAUDE.md §6
    private static func uciParams(for difficulty: Int) -> (skillLevel: Int, movetime: Int) {
        switch difficulty {
        case 1:  return (0,  100)
        case 2:  return (2,  150)
        case 3:  return (4,  200)
        case 4:  return (6,  300)
        case 5:  return (8,  500)
        case 6:  return (11, 800)
        case 7:  return (14, 1200)
        case 8:  return (16, 2000)
        case 9:  return (18, 3000)
        case 10: return (20, 5000)
        default: return (8,  500)
        }
    }
}

// MARK: - Errors

enum StockfishError: LocalizedError {
    case binaryNotFound
    case notRunning
    case encodingFailed
    case timeout
    case noBestMove
    case noEvaluation

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:  return "Stockfish binary not found in app bundle"
        case .notRunning:      return "Stockfish process is not running"
        case .encodingFailed:  return "Failed to encode UCI command"
        case .timeout:         return "Stockfish response timed out"
        case .noBestMove:      return "Stockfish did not return a best move"
        case .noEvaluation:    return "Stockfish did not return an evaluation"
        }
    }
}
