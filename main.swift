#!/usr/bin/swift

import Foundation

struct TaskError: Error, CustomStringConvertible {
    var description: String {
        return self._description
    }
    
    let _description: String
    
    init(description: String = "",
         _ file: String = #file,
         _ function: String = #function,
         _ line: Int = #line)
    {
        self._description = """
        ------ Error ------
        file: \(file)
        function: \(function)
        line: \(line)
        description: \(description)
        ------ End --------
        """
    }
}

class Task {
    let task: Process = Process()
    
    init(launchPath: String, arguments: [String] = []) {
        self.task.launchPath = launchPath
        if !arguments.isEmpty {
            self.task.arguments = arguments
        }
        self.task.standardOutput = Pipe()
        self.task.standardError = Pipe()
    }
    
    func excute(
        printOutput: Bool = true,
        _ completion: ((Process) -> Void)? = nil)
        -> Bool
    {
        var success: Bool = false
        let group = DispatchGroup()
        group.enter()
        do {
            self.task.terminationHandler = {
                success = ($0.terminationStatus == 0)
                if let error = String(
                    data: ($0.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) {
                    print(error)
                }
                if printOutput, let output = String(
                    data: ($0.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8) {
                    print(output)
                }
                completion?($0)
                group.leave()
            }
            print("Run Task: \(self.task.arguments?[0] ?? "") \(self.task.arguments?[1] ?? "") ...")
            try self.task.run()
            self.task.waitUntilExit()
        } catch {
            print(error)
            group.leave()
        }
        group.wait()
        return success
    }
}

class OpenTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["open"] + arguments)
    }
    
    static func url(_ urlString: String) throws {
        guard let _ = URL(string: urlString),
            OpenTask(arguments: [urlString]).excute() else {
                throw TaskError()
        }
    }
}

class XcodebuildTask: Task {
    static let projectPath = "./LeanCloud.xcodeproj"
    
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/xcrun",
            arguments: ["xcodebuild"] + arguments)
    }
    
    static func version() throws {
        guard XcodebuildTask(arguments: ["-version"]).excute() else {
            throw TaskError()
        }
    }
    
    struct Xcodeproj: Decodable {
        let project: Project
        
        struct Project: Decodable {
            let configurations: [String]
            let name: String
            let schemes: [String]
            let targets: [String]
        }
    }
    
    static func getXcodeproj(name: String) throws -> Xcodeproj {
        var project: Xcodeproj!
        var taskError: Error?
        _ = XcodebuildTask(arguments: ["-list", "-project", name, "-json"])
            .excute(printOutput: false, {
                do {
                    let data = ($0.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
                    project = try JSONDecoder().decode(Xcodeproj.self, from: data)
                } catch {
                    taskError = error
                }
            })
        if let error = taskError {
            throw error
        } else {
            return project
        }
    }
    
    static func building(
        project: String,
        scheme: String,
        configuration: String,
        destination: String? = nil)
        throws
    {
        var arguments: [String] = [
            "-project", project,
            "-scheme", scheme,
            "-configuration", configuration]
        if let destination = destination {
            arguments += ["-destination", destination]
        }
        arguments += ["clean", "build", "-quiet"]
        let success = XcodebuildTask(arguments: arguments).excute {
            let argumentsString = String(
                data: try! JSONSerialization.data(
                    withJSONObject: ($0.arguments ?? []),
                    options: [.prettyPrinted]),
                encoding: .utf8)
            print("""
                ------ Build Task ------
                Completion Status: \($0.terminationStatus == 0 ? "Complete Success 🎉" : "\($0.terminationStatus)")
                Launch Path: \($0.launchPath ?? "")
                Arguments: \(argumentsString ?? "")
                ------ End -------------
                """)
        }
        if !success {
            throw TaskError()
        }
    }
    
    enum Platform: String {
        case iOS
        case macOS
        case tvOS
        case watchOS
    }
    
    static func building(
        project: String = XcodebuildTask.projectPath,
        platforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS])
        throws
    {
        try version()
        let xcodeproj = try getXcodeproj(name: project)
        let start = Date()
        try platforms.forEach { (platform) in
            try xcodeproj.project.configurations.forEach { (configuration) in
                try building(
                    project: project,
                    scheme: "LeanCloud",
                    configuration: configuration,
                    destination: platform == .macOS
                        ? "platform=\(platform.rawValue)"
                        : "generic/platform=\(platform.rawValue)")
            }
        }
        print("\nBuilding Time Cost: \(Date().timeIntervalSince(start) / 60.0) minutes.\n")
    }
}

class GitTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["git"] + arguments)
    }
    
    static func commitAll(with message: String) throws {
        guard GitTask(arguments: ["commit", "-a", "-m", message]).excute() else {
            throw TaskError()
        }
    }
    
    static func lastReleasableMessage() -> String? {
        var message: String?
        _ = GitTask(
            arguments: ["log", "-16", "--pretty=%B|cat"])
            .excute(printOutput: false) {
                let data = ($0.standardOutput as! Pipe).fileHandleForReading.readDataToEndOfFile()
                message = String(data: data, encoding: .utf8)?
                    .components(separatedBy: .newlines)
                    .map({ s in s.trimmingCharacters(in: .whitespacesAndNewlines) })
                    .first(where: { (s) -> Bool in
                        s.hasPrefix("release") ||
                            s.hasPrefix("feat") ||
                            s.hasPrefix("fix") ||
                            s.hasPrefix("refactor") ||
                            s.hasPrefix("docs")
                    })
        }
        return message
    }
}

class HubTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["hub"] + arguments)
    }
    
    static func version() throws {
        guard HubTask(arguments: ["version"]).excute() else {
            throw TaskError()
        }
    }
    
    enum ReleaseDrafterLabel: String {
        case breakingChanges = "feat!"
        case newFeatures = "feat"
        case bugFixes = "fix"
        case maintenanceRefactor = "refactor"
        case maintenanceDocs = "docs"
    }
    
    static func pullRequest(with message: String) throws {
        try version()
        var label: String?
        if message.hasPrefix(ReleaseDrafterLabel.breakingChanges.rawValue) {
            label = ReleaseDrafterLabel.breakingChanges.rawValue
        } else if message.hasPrefix(ReleaseDrafterLabel.newFeatures.rawValue) {
            label = ReleaseDrafterLabel.newFeatures.rawValue
        } else if message.hasPrefix(ReleaseDrafterLabel.bugFixes.rawValue) {
            label = ReleaseDrafterLabel.bugFixes.rawValue
        } else if message.hasPrefix(ReleaseDrafterLabel.maintenanceRefactor.rawValue) {
            label = ReleaseDrafterLabel.maintenanceRefactor.rawValue
        } else if message.hasPrefix(ReleaseDrafterLabel.maintenanceDocs.rawValue) {
            label = ReleaseDrafterLabel.maintenanceDocs.rawValue
        }
        guard HubTask(arguments: [
            "pull-request",
            "--base", "leancloud:master",
            "--message", message,
            "--force", "--push", "--browse"]
            + (label != nil ? ["--labels", label!] : []))
            .excute() else {
                throw TaskError()
        }
    }
}

class PodTask: Task {
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["pod"] + arguments)
    }
    
    static func version() throws {
        guard PodTask(arguments: ["--version"]).excute() else {
            throw TaskError()
        }
    }
    
    static func trunkPush(
        path: String,
        repoUpdate: Bool,
        wait: Bool)
        throws
    {
        if repoUpdate {
            _ = PodTask(arguments: ["repo", "update"]).excute()
        }
        if PodTask(arguments: ["trunk", "push", path, "--allow-warnings"]).excute() {
            if wait {
                print("wait for 10 minutes ...")
                sleep(60 * 10)
            }
        } else {
            print("[?] try pod trunk push \(path) again? [yes/no]")
            if let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
                ["y", "ye", "yes"].contains(input) {
                try PodTask.trunkPush(
                    path: path,
                    repoUpdate: repoUpdate,
                    wait: wait)
            } else {
                throw TaskError()
            }
        }
    }
    
    static func trunkPush(paths: [String]) throws {
        try version()
        for (index, path) in paths.enumerated() {
            try PodTask.trunkPush(
                path: path,
                repoUpdate: (index != 0),
                wait: (index != (paths.count - 1)))
        }
    }
}

class VersionUpdater {
    static let versionFilePath: String = "./.version"
    static let packageVersionFilePath: String = "./Sources/Foundation/Version.swift"
    static let podspecFilePath: String = "./LeanCloud.podspec"
    
    static func checkFileExists(path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw TaskError(description: "\(path) not found.")
        }
    }
    
    struct Version {
        let major: Int
        let minor: Int
        let revision: Int
        let tag: (category: String, number: Int)?
        
        var versionString: String {
            var string = "\(major).\(minor).\(revision)"
            if let tag = tag {
                string = "\(string)-\(tag.category).\(tag.number)"
            }
            return string
        }
        
        init(string: String) throws {
            var versionString: String = string
            var tag: (String, Int)?
            if versionString.contains("-") {
                let components = versionString.components(separatedBy: "-")
                guard components.count == 2 else {
                    throw TaskError(description: "invalid semantic version: \(string).")
                }
                versionString = components[0]
                let tagComponents = components[1].components(separatedBy: ".")
                guard tagComponents.count == 2,
                    let tagNumber = Int(tagComponents[1]) else {
                        throw TaskError(description: "invalid semantic version: \(string).")
                }
                tag = (tagComponents[0], tagNumber)
            }
            let numbers = versionString.components(separatedBy: ".")
            guard numbers.count == 3,
                let major = Int(numbers[0]),
                let minor = Int(numbers[1]),
                let revision = Int(numbers[2]) else {
                    throw TaskError(description: "invalid semantic version: \(string).")
            }
            self.major = major
            self.minor = minor
            self.revision = revision
            self.tag = tag
        }
    }
    
    static func currentVersion() throws -> Version {
        let path = versionFilePath
        try checkFileExists(path: path)
        return try Version(string: String((try String(contentsOfFile: path))
            .trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    
    static func newVersion(_ newVersion: Version, replace oldVersion: Version) throws {
        let paths = [
            versionFilePath,
            packageVersionFilePath,
            podspecFilePath]
        for path in paths {
            try checkFileExists(path: path)
            try (try String(contentsOfFile: path))
                .replacingOccurrences(of: oldVersion.versionString, with: newVersion.versionString)
                .write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

class JazzyTask: Task {
    static let APIDocsRepoSwiftDirectory = "../api-docs/api/swift"
    static let APIDocsTempDirectory = "./api-docs"
    
    convenience init(arguments: [String] = []) {
        self.init(
            launchPath: "/usr/bin/env",
            arguments: ["jazzy"] + arguments)
    }
    
    static func version() throws {
        guard JazzyTask(arguments: ["--version"]).excute() else {
            throw TaskError()
        }
    }
    
    static func checkAPIDocsRepoSwiftDirectory() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: APIDocsRepoSwiftDirectory, isDirectory: &isDirectory),
            isDirectory.boolValue else {
                throw TaskError()
        }
    }
    
    static func checkAPIDocsTempDirectory() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: APIDocsTempDirectory, isDirectory: &isDirectory),
            isDirectory.boolValue else {
                throw TaskError()
        }
    }
    
    static func generateDocumentation(currentVersion: VersionUpdater.Version) throws {
        _ = JazzyTask(arguments: [
            "--output", APIDocsTempDirectory,
            "--build-tool-arguments",
            "-project,\(XcodebuildTask.projectPath),-scheme,LeanCloud,-configuration,Release",
            "--author", "LeanCloud",
            "--author_url", "https://leancloud.cn",
            "--module", "LeanCloud",
            "--module-version", currentVersion.versionString,
            "--github_url", "https://github.com/leancloud/swift-sdk",
            "--github-file-prefix",
            "https://github.com/leancloud/swift-sdk/tree/\(currentVersion.versionString)",
            "--root-url", "https://leancloud.cn/api-docs/swift/"]
            + (FileManager.default.fileExists(atPath: APIDocsTempDirectory) ? ["--clean"] : []))
            .excute()
        try checkAPIDocsTempDirectory()
    }
    
    static func moveGeneratedDocumentationToRepo() throws {
        try FileManager.default.removeItem(atPath: APIDocsRepoSwiftDirectory)
        try FileManager.default.moveItem(
            atPath: APIDocsTempDirectory,
            toPath: APIDocsRepoSwiftDirectory)
    }
    
    static func commitPull() throws {
        guard GitTask(arguments: [
            "-C", APIDocsRepoSwiftDirectory, "pull"])
            .excute() else {
                throw TaskError()
        }
    }
    
    static func commitPush() throws {
        guard GitTask(arguments: [
            "-C", APIDocsRepoSwiftDirectory,
            "add", "-A"])
            .excute() else {
                throw TaskError()
        }
        guard GitTask(arguments: [
            "-C", APIDocsRepoSwiftDirectory,
            "commit", "-a", "-m", "update swift sdk docs"])
            .excute() else {
                throw TaskError()
        }
        guard GitTask(arguments: [
            "-C", APIDocsRepoSwiftDirectory, "push"])
            .excute() else {
                throw TaskError()
        }
    }
    
    static func update(currentVersion: VersionUpdater.Version) throws {
        try version()
        try checkAPIDocsRepoSwiftDirectory()
        try commitPull()
        try generateDocumentation(currentVersion: currentVersion)
        try moveGeneratedDocumentationToRepo()
        try commitPush()
        try OpenTask.url("https://jenkins.leancloud.cn/job/cn-api-doc-prod-ucloud/build")
    }
}

class CLI {
    
    static func help() {
        print("""
            Actions:\n
            b, build                Building all schemes
            vu, version-update      Updating SDK version
            pr, pull-request        New pull request from current head to base master
            pt, pod-trunk           Publish all podspecs
            adu, api-docs-update    Update API Docs
            h, help                 Show help info
            """)
    }
    
    static func build() throws {
        try XcodebuildTask.building()
    }
    
    static func versionUpdate() throws {
        let currentVersion = try VersionUpdater.currentVersion()
        print("""
            Current Version is \(currentVersion.versionString)
            [?] do you want to update it ? [<new-semantic-version>/no]
            """)
        if let input = readLine()?.trimmingCharacters(in: .whitespaces).lowercased() {
            if !["n", "no", "not"].contains(input.lowercased()) {
                let newVersion = try VersionUpdater.Version(string: input)
                guard newVersion.versionString != currentVersion.versionString else {
                    throw TaskError(description: "[!] Version no change")
                }
                try VersionUpdater.newVersion(newVersion, replace: currentVersion)
                try GitTask.commitAll(with: "release: \(newVersion.versionString)")
            }
        }
    }
    
    static func pullRequest() throws {
        if let message = GitTask.lastReleasableMessage() {
            try HubTask.pullRequest(with: message)
        } else {
            throw TaskError(description: "Not get a releasable Message.")
        }
    }
    
    static func podTrunk() throws {
        try PodTask.trunkPush(paths: ["LeanCloud.podspec"])
    }
    
    static func apiDocsUpdate() throws {
        try JazzyTask.update(
            currentVersion: try VersionUpdater.currentVersion())
    }
    
    static func read() -> [String] {
        var args = CommandLine.arguments
        args.removeFirst()
        return args
    }
    
    static func process(action: String) throws {
        switch action {
        case "b", "build":
            try build()
        case "vu", "version-update":
            try versionUpdate()
        case "pr", "pull-request":
            try pullRequest()
        case "pt", "pod-trunk":
            try podTrunk()
        case "adu", "api-docs-update":
            try apiDocsUpdate()
        case "h", "help":
            help()
        default:
            print("[!] Unknown Action: `\(action)`\n")
            help()
        }
    }
    
    static func run() throws {
        let args = read()
        switch args.count {
        case 1:
            try process(action: args[0])
        default:
            print("[!] Unknown Command: `\(args.joined(separator: " "))`\n")
            help()
        }
    }
}

func main() {
    do {
        try CLI.run()
    } catch {
        print(error)
    }
}

main()
