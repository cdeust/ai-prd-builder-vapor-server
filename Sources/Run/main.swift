import App
import Vapor
import Foundation

// Load .env.development file if it exists
func loadEnvironmentFile() {
    let fileManager = FileManager.default
    let envFiles = [".env.development", ".env"]

    // Try multiple possible locations
    let possiblePaths = [
        fileManager.currentDirectoryPath, // Current working directory
        URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path // Project root from source file
    ]

    for basePath in possiblePaths {
        for envFile in envFiles {
            let envPath = basePath + "/\(envFile)"

            guard fileManager.fileExists(atPath: envPath),
                  let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else {
                continue
            }

            print("📝 Loading environment from: \(envPath)")

            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

                let parts = trimmed.components(separatedBy: "=")
                guard parts.count >= 2 else { continue }

                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)

                setenv(key, value, 1) // Allow overwriting env vars from .env file
            }
            return // Successfully loaded, exit
        }
    }

    print("⚠️ No .env file found in any expected location")
}

// Load environment variables before detecting environment
loadEnvironmentFile()

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = try await Application.make(env)

do {
    try configure(app)
    try await app.execute()
} catch {
    app.logger.report(error: error)
    try? await app.asyncShutdown()
    throw error
}

try await app.asyncShutdown()
