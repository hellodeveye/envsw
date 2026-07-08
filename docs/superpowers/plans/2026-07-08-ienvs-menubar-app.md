# iEnvs 菜单栏 App 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 envsw CLI 构建 macOS 原生菜单栏 App「iEnvs」，点选即切换 `~/.envsw` 环境变量配置组。

**Architecture:** 单个 Swift Package（位于 `app/`）：`iEnvsCore` 纯逻辑库（ProfileStore / DirectoryWatcher / HookInstaller，全部单元测试覆盖）+ `iEnvs` SwiftUI 可执行目标（MenuBarExtra 菜单、AppKit 编辑窗口、NSAlert 交互）。文件系统（`~/.envsw`）是唯一数据源，与 CLI 完全互通。

**Tech Stack:** Swift 5.9+ / SwiftUI `MenuBarExtra` / FSEvents / XCTest / ServiceManagement (SMAppService) / UserNotifications。零第三方依赖。

## Global Constraints

- 目标平台 macOS 13+；`Package.swift` 写 `platforms: [.macOS(.v13)]`；swift-tools-version 5.9。
- 零第三方依赖，只用系统框架。
- 文件权限与 CLI 一致：目录 `0o700`，`.env` 文件 `0o600`。
- danger 配置名列表与 CLI 逐字一致：`prod`、`production`、`online`、`live`。
- 根目录取 `ENVSW_ROOT` 环境变量，未设置时用 `~/.envsw`。
- `current` 软链接的目标必须是**相对路径**（如 `dev.env`），与 CLI 的 `ln -sfn "$profile.env"` 一致。
- shell 钩子 marker 与 `install.sh` 逐字一致：`# envsw: auto-load the active env profile`；zsh 写 `~/.zshenv`，bash 写 `~/.bashrc`，钩子片段内容与 `install.sh` 相同。
- 新建配置文件的模板与 CLI `edit` 一致：`# <group> / <profile> — KEY=VALUE per line, no "export"`（注意是 em-dash `—`）。
- UI 文案用英文；分组/配置名校验：非空、不含 `/`、不以 `.` 开头、不等于 `current`。
- 所有命令从仓库根目录 `/Users/kim/projects/envsw` 执行，用 `--package-path app`。
- 提交信息末尾带 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`。

---

### Task 1: Swift Package 脚手架 + Danger 模型

**Files:**
- Create: `app/Package.swift`
- Create: `app/Sources/iEnvsCore/Models.swift`
- Create: `app/Sources/iEnvs/main.swift`（占位，Task 7 删除）
- Test: `app/Tests/iEnvsCoreTests/ModelsTests.swift`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 无
- Produces: `Danger.isDangerous(_ profileName: String) -> Bool`；`Profile(name: String, url: URL)`，属性 `name`、`url`、`isDangerous: Bool`；`ProfileGroup(name: String, profiles: [Profile], activeProfileName: String?)`，属性同名 + `hasDangerActive: Bool`。均为 `public`，`Profile`/`ProfileGroup` 遵循 `Hashable`。

- [ ] **Step 1: 创建包结构与失败测试**

`app/Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "iEnvs",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "iEnvsCore"),
        .executableTarget(name: "iEnvs", dependencies: ["iEnvsCore"]),
        .testTarget(name: "iEnvsCoreTests", dependencies: ["iEnvsCore"]),
    ]
)
```

`app/Sources/iEnvsCore/Models.swift`（先只放 import，让测试编译失败）:

```swift
import Foundation
```

`app/Sources/iEnvs/main.swift`:

```swift
print("iEnvs placeholder — replaced in Task 7")
```

`app/Tests/iEnvsCoreTests/ModelsTests.swift`:

```swift
import XCTest
@testable import iEnvsCore

final class ModelsTests: XCTestCase {
    func testDangerNamesMatchCLI() {
        for name in ["prod", "production", "online", "live"] {
            XCTAssertTrue(Danger.isDangerous(name), "\(name) should be dangerous")
        }
        for name in ["dev", "staging", "prd", "Prod"] {
            XCTAssertFalse(Danger.isDangerous(name), "\(name) should not be dangerous")
        }
    }

    func testProfileAndGroupDanger() {
        let dev = Profile(name: "dev", url: URL(fileURLWithPath: "/tmp/g/dev.env"))
        let prod = Profile(name: "prod", url: URL(fileURLWithPath: "/tmp/g/prod.env"))
        XCTAssertFalse(dev.isDangerous)
        XCTAssertTrue(prod.isDangerous)

        let idle = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: nil)
        let safe = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: "dev")
        let hot = ProfileGroup(name: "g", profiles: [dev, prod], activeProfileName: "prod")
        XCTAssertFalse(idle.hasDangerActive)
        XCTAssertFalse(safe.hasDangerActive)
        XCTAssertTrue(hot.hasDangerActive)
    }
}
```

`.gitignore` 追加两行：

```
app/.build/
app/build/
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'Danger' in scope`

- [ ] **Step 3: 实现 Models.swift**

替换 `app/Sources/iEnvsCore/Models.swift` 全部内容：

```swift
import Foundation

public enum Danger {
    /// Must match the CLI's is_danger(): prod|production|online|live
    public static let names: Set<String> = ["prod", "production", "online", "live"]
    public static func isDangerous(_ profileName: String) -> Bool { names.contains(profileName) }
}

public struct Profile: Hashable {
    public let name: String
    public let url: URL
    public var isDangerous: Bool { Danger.isDangerous(name) }

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct ProfileGroup: Hashable {
    public let name: String
    public let profiles: [Profile]
    public let activeProfileName: String?

    public init(name: String, profiles: [Profile], activeProfileName: String?) {
        self.name = name
        self.profiles = profiles
        self.activeProfileName = activeProfileName
    }

    public var hasDangerActive: Bool {
        guard let active = activeProfileName else { return false }
        return Danger.isDangerous(active)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app 2>&1 | tail -5`
Expected: `Test Suite 'All tests' passed`（2 个测试通过；同时能看到 placeholder 可执行目标编译成功）

- [ ] **Step 5: Commit**

```bash
git add app .gitignore
git commit -m "feat(app): scaffold iEnvs Swift package with danger model

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: ProfileStore 扫描（groups / profiles / active）

**Files:**
- Create: `app/Sources/iEnvsCore/ProfileStore.swift`
- Test: `app/Tests/iEnvsCoreTests/ProfileStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 的 `Profile` / `ProfileGroup`
- Produces: `ProfileStore` 类 — `init(root: URL = ProfileStore.defaultRoot())`、`let root: URL`、`static func defaultRoot() -> URL`、`func scan() -> [ProfileGroup]`（按组名排序，组内 profile 按名排序；根目录不存在返回 `[]`；坏软链接视为未激活）。后续 Task 3/4 在同一文件追加方法。

- [ ] **Step 1: 写失败测试**

`app/Tests/iEnvsCoreTests/ProfileStoreTests.swift`:

```swift
import XCTest
@testable import iEnvsCore

final class ProfileStoreTests: XCTestCase {
    var root: URL!
    var store: ProfileStore!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory
            .appendingPathComponent("ienvs-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        store = ProfileStore(root: root)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    /// Fixture: create <group>/<profile>.env files, optionally a current symlink.
    func makeGroup(_ group: String, profiles: [String], active: String? = nil) throws {
        let dir = root.appendingPathComponent(group, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for p in profiles {
            try "KEY=\(p)\n".write(to: dir.appendingPathComponent("\(p).env"),
                                   atomically: true, encoding: .utf8)
        }
        if let active {
            try fm.createSymbolicLink(atPath: dir.appendingPathComponent("current").path,
                                      withDestinationPath: "\(active).env")
        }
    }

    // MARK: scan

    func testScanMissingRootReturnsEmpty() {
        let ghost = ProfileStore(root: root.appendingPathComponent("nope"))
        XCTAssertEqual(ghost.scan(), [])
    }

    func testScanFindsGroupsProfilesAndActiveSorted() throws {
        try makeGroup("zoo", profiles: ["dev"], active: nil)
        try makeGroup("myapp", profiles: ["prod", "dev"], active: "dev")

        let groups = store.scan()
        XCTAssertEqual(groups.map(\.name), ["myapp", "zoo"])          // groups sorted
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev", "prod"]) // profiles sorted
        XCTAssertEqual(groups[0].activeProfileName, "dev")
        XCTAssertNil(groups[1].activeProfileName)
    }

    func testScanIgnoresBrokenSymlinkAndNonEnvFiles() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        let dir = root.appendingPathComponent("myapp")
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("current").path,
                                  withDestinationPath: "gone.env") // broken link
        try "junk".write(to: dir.appendingPathComponent("notes.txt"),
                         atomically: true, encoding: .utf8)

        let groups = store.scan()
        XCTAssertEqual(groups.count, 1)
        XCTAssertNil(groups[0].activeProfileName)                 // broken → not active
        XCTAssertEqual(groups[0].profiles.map(\.name), ["dev"])   // .txt ignored
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'ProfileStore' in scope`

- [ ] **Step 3: 实现 ProfileStore.swift**

`app/Sources/iEnvsCore/ProfileStore.swift`:

```swift
import Foundation

public enum ProfileStoreError: Error, Equatable, LocalizedError {
    case invalidName(String)
    case profileNotFound(group: String, profile: String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let n):
            return "Invalid name “\(n)” — must be non-empty, without “/”, not start with “.”, and not be “current”."
        case .profileNotFound(let g, let p):
            return "Profile “\(p)” not found in group “\(g)”."
        }
    }
}

/// All state lives under `root` (default ~/.envsw), shared with the envsw CLI.
public final class ProfileStore {
    public let root: URL
    private let fm = FileManager.default

    public init(root: URL = ProfileStore.defaultRoot()) {
        self.root = root
    }

    public static func defaultRoot() -> URL {
        if let custom = ProcessInfo.processInfo.environment["ENVSW_ROOT"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".envsw", isDirectory: true)
    }

    // MARK: - Scan

    public func scan() -> [ProfileGroup] {
        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        var groups: [ProfileGroup] = []
        for dir in entries {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            let profiles = files
                .filter { $0.pathExtension == "env" }
                .map { Profile(name: $0.deletingPathExtension().lastPathComponent, url: $0) }
                .sorted { $0.name < $1.name }
            groups.append(ProfileGroup(name: dir.lastPathComponent,
                                       profiles: profiles,
                                       activeProfileName: activeProfile(inGroupDir: dir)))
        }
        return groups.sorted { $0.name < $1.name }
    }

    private func activeProfile(inGroupDir dir: URL) -> String? {
        let link = dir.appendingPathComponent("current")
        guard let dest = try? fm.destinationOfSymbolicLink(atPath: link.path) else { return nil }
        let destURL = URL(fileURLWithPath: dest, relativeTo: dir)
        guard fm.fileExists(atPath: destURL.path) else { return nil } // broken link
        return destURL.deletingPathExtension().lastPathComponent
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 3 个测试全部 PASS

- [ ] **Step 5: Commit**

```bash
git add app/Sources/iEnvsCore/ProfileStore.swift app/Tests/iEnvsCoreTests/ProfileStoreTests.swift
git commit -m "feat(app): ProfileStore scan of groups, profiles, active symlink

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: ProfileStore 切换（use / off）

**Files:**
- Modify: `app/Sources/iEnvsCore/ProfileStore.swift`（追加方法）
- Modify: `app/Tests/iEnvsCoreTests/ProfileStoreTests.swift`（追加测试）

**Interfaces:**
- Consumes: Task 2 的 `ProfileStore`、`ProfileStoreError`、测试 fixture `makeGroup`
- Produces: `func use(group: String, profile: String) throws`（软链接目标为相对路径 `<profile>.env`；目标文件不存在抛 `.profileNotFound`）、`func off(group: String)`（幂等，不抛错）

- [ ] **Step 1: 追加失败测试**

在 `ProfileStoreTests` 类末尾追加：

```swift
    // MARK: use / off

    func testUseRepointsSymlinkWithRelativeDestination() throws {
        try makeGroup("myapp", profiles: ["dev", "prod"], active: "dev")

        try store.use(group: "myapp", profile: "prod")

        let link = root.appendingPathComponent("myapp/current")
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: link.path), "prod.env")
        XCTAssertEqual(store.scan()[0].activeProfileName, "prod")
    }

    func testUseMissingProfileThrows() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        XCTAssertThrowsError(try store.use(group: "myapp", profile: "ghost")) { error in
            XCTAssertEqual(error as? ProfileStoreError,
                           .profileNotFound(group: "myapp", profile: "ghost"))
        }
    }

    func testOffRemovesCurrentAndIsIdempotent() throws {
        try makeGroup("myapp", profiles: ["dev"], active: "dev")

        store.off(group: "myapp")
        XCTAssertNil(store.scan()[0].activeProfileName)
        store.off(group: "myapp") // second call must not crash
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 编译失败，`value of type 'ProfileStore' has no member 'use'`

- [ ] **Step 3: 实现 use / off**

在 `ProfileStore` 类内（`activeProfile` 之前）追加：

```swift
    // MARK: - Switch

    public func use(group: String, profile: String) throws {
        let dir = root.appendingPathComponent(group, isDirectory: true)
        let file = dir.appendingPathComponent("\(profile).env")
        guard fm.fileExists(atPath: file.path) else {
            throw ProfileStoreError.profileNotFound(group: group, profile: profile)
        }
        let link = dir.appendingPathComponent("current")
        try? fm.removeItem(at: link) // ln -sfn semantics
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "\(profile).env")
    }

    public func off(group: String) {
        try? fm.removeItem(at: root.appendingPathComponent(group).appendingPathComponent("current"))
    }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 6 个测试全部 PASS

- [ ] **Step 5: Commit**

```bash
git add app/Sources/iEnvsCore/ProfileStore.swift app/Tests/iEnvsCoreTests/ProfileStoreTests.swift
git commit -m "feat(app): ProfileStore use/off with CLI-compatible symlink semantics

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: ProfileStore 增删读写 + 权限 + 名称校验

**Files:**
- Modify: `app/Sources/iEnvsCore/ProfileStore.swift`（追加方法）
- Modify: `app/Tests/iEnvsCoreTests/ProfileStoreTests.swift`（追加测试）

**Interfaces:**
- Consumes: Task 2/3 的既有成员
- Produces:
  - `func createGroup(_ name: String) throws`（root 与组目录 `0o700`）
  - `@discardableResult func createProfile(group: String, profile: String) throws -> URL`（不存在时写模板；文件 `0o600`；自动创建组）
  - `func deleteProfile(group: String, profile: String) throws`（删除激活中的配置时同时移除 `current`）
  - `func deleteGroup(_ name: String) throws`
  - `func readProfile(group: String, profile: String) throws -> String`
  - `func writeProfile(group: String, profile: String, contents: String) throws`（保存后保持 `0o600`）
  - 名称校验：`use`/`createGroup`/`createProfile` 对非法名（空、含 `/`、以 `.` 开头、等于 `current`）抛 `.invalidName`

- [ ] **Step 1: 追加失败测试**

在 `ProfileStoreTests` 类末尾追加：

```swift
    // MARK: create / delete / read / write

    private func perms(_ url: URL) throws -> Int {
        let attrs = try fm.attributesOfItem(atPath: url.path)
        return (attrs[.posixPermissions] as! NSNumber).intValue
    }

    func testCreateProfileWritesTemplateWithPermissions() throws {
        let file = try store.createProfile(group: "myapp", profile: "dev")

        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(text, "# myapp / dev — KEY=VALUE per line, no \"export\"\n")
        XCTAssertEqual(try perms(file), 0o600)
        XCTAssertEqual(try perms(root.appendingPathComponent("myapp")), 0o700)
        XCTAssertEqual(try perms(root), 0o700)
    }

    func testCreateProfileDoesNotOverwriteExisting() throws {
        try makeGroup("myapp", profiles: ["dev"], active: nil)
        let file = try store.createProfile(group: "myapp", profile: "dev")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "KEY=dev\n")
    }

    func testWriteAndReadProfileKeepsPermissions() throws {
        try store.createProfile(group: "myapp", profile: "dev")

        try store.writeProfile(group: "myapp", profile: "dev", contents: "A=1\nB=2\n")

        XCTAssertEqual(try store.readProfile(group: "myapp", profile: "dev"), "A=1\nB=2\n")
        XCTAssertEqual(try perms(root.appendingPathComponent("myapp/dev.env")), 0o600)
    }

    func testDeleteActiveProfileClearsCurrent() throws {
        try makeGroup("myapp", profiles: ["dev", "prod"], active: "dev")

        try store.deleteProfile(group: "myapp", profile: "dev")

        let group = store.scan()[0]
        XCTAssertEqual(group.profiles.map(\.name), ["prod"])
        XCTAssertNil(group.activeProfileName)
    }

    func testDeleteGroupRemovesDirectory() throws {
        try makeGroup("myapp", profiles: ["dev"], active: "dev")
        try store.deleteGroup("myapp")
        XCTAssertEqual(store.scan(), [])
    }

    func testInvalidNamesThrow() {
        for bad in ["", "a/b", ".hidden", "current"] {
            XCTAssertThrowsError(try store.createGroup(bad), "group “\(bad)”")
            XCTAssertThrowsError(try store.createProfile(group: "ok", profile: bad), "profile “\(bad)”")
            XCTAssertThrowsError(try store.use(group: bad, profile: "dev"), "use group “\(bad)”")
        }
    }
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 编译失败，`no member 'createProfile'`

- [ ] **Step 3: 实现增删读写与校验**

在 `ProfileStore` 类内追加，并在 `use(group:profile:)` 开头插入两行校验（见下）：

```swift
    // MARK: - Create / delete / read / write

    public func createGroup(_ name: String) throws {
        try validate(name)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        let dir = root.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    @discardableResult
    public func createProfile(group: String, profile: String) throws -> URL {
        try validate(group)
        try validate(profile)
        try createGroup(group)
        let file = root.appendingPathComponent(group).appendingPathComponent("\(profile).env")
        if !fm.fileExists(atPath: file.path) {
            // Same template as the CLI's `envsw edit` (note the em-dash)
            let template = "# \(group) / \(profile) — KEY=VALUE per line, no \"export\"\n"
            try template.write(to: file, atomically: true, encoding: .utf8)
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    public func deleteProfile(group: String, profile: String) throws {
        let dir = root.appendingPathComponent(group, isDirectory: true)
        let file = dir.appendingPathComponent("\(profile).env")
        guard fm.fileExists(atPath: file.path) else {
            throw ProfileStoreError.profileNotFound(group: group, profile: profile)
        }
        if activeProfile(inGroupDir: dir) == profile { off(group: group) }
        try fm.removeItem(at: file)
    }

    public func deleteGroup(_ name: String) throws {
        try fm.removeItem(at: root.appendingPathComponent(name, isDirectory: true))
    }

    public func readProfile(group: String, profile: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(group).appendingPathComponent("\(profile).env"),
                   encoding: .utf8)
    }

    public func writeProfile(group: String, profile: String, contents: String) throws {
        let file = root.appendingPathComponent(group).appendingPathComponent("\(profile).env")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    private func validate(_ name: String) throws {
        let bad = name.isEmpty || name.contains("/") || name.hasPrefix(".") || name == "current"
        if bad { throw ProfileStoreError.invalidName(name) }
    }
```

同时修改 `use(group:profile:)`，在方法体第一行前插入：

```swift
        try validate(group)
        try validate(profile)
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app --filter ProfileStoreTests 2>&1 | tail -5`
Expected: 12 个测试全部 PASS

- [ ] **Step 5: 运行全部测试并 Commit**

Run: `swift test --package-path app 2>&1 | tail -3` → 全部 PASS

```bash
git add app/Sources/iEnvsCore/ProfileStore.swift app/Tests/iEnvsCoreTests/ProfileStoreTests.swift
git commit -m "feat(app): ProfileStore CRUD with 600/700 permissions and name validation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: DirectoryWatcher（FSEvents 实时同步）

**Files:**
- Create: `app/Sources/iEnvsCore/DirectoryWatcher.swift`
- Test: `app/Tests/iEnvsCoreTests/DirectoryWatcherTests.swift`

**Interfaces:**
- Consumes: 无（独立单元）
- Produces: `DirectoryWatcher` 类 — `init?(url: URL, latency: TimeInterval = 0.3, onChange: @escaping () -> Void)`（onChange 在主队列回调；FSEvents 自带 latency 合并即去抖）、`func stop()`（幂等）

- [ ] **Step 1: 写失败测试**

`app/Tests/iEnvsCoreTests/DirectoryWatcherTests.swift`:

```swift
import XCTest
@testable import iEnvsCore

final class DirectoryWatcherTests: XCTestCase {
    func testFiresOnFileCreationInSubdirectory() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("ienvs-watch-\(UUID().uuidString)", isDirectory: true)
        let sub = dir.appendingPathComponent("myapp", isDirectory: true)
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let exp = expectation(description: "change detected")
        exp.assertForOverFulfill = false
        let watcher = DirectoryWatcher(url: dir, latency: 0.1) { exp.fulfill() }
        XCTAssertNotNil(watcher)

        // FSEvents needs a beat to start delivering; then touch a file.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            try? "X=1\n".write(to: sub.appendingPathComponent("dev.env"),
                               atomically: true, encoding: .utf8)
        }

        wait(for: [exp], timeout: 10)
        watcher?.stop()
        watcher?.stop() // idempotent
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app --filter DirectoryWatcherTests 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'DirectoryWatcher' in scope`

- [ ] **Step 3: 实现 DirectoryWatcher.swift**

```swift
import CoreServices
import Foundation

/// Watches a directory tree via FSEvents; fires onChange (main queue) after
/// `latency` seconds of coalescing. Used to keep the menu in sync with the CLI.
public final class DirectoryWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void

    public init?(url: URL, latency: TimeInterval = 0.3, onChange: @escaping () -> Void) {
        self.onChange = onChange

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { watcher.onChange() }
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            nil, callback, &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency, flags
        ) else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit { stop() }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app --filter DirectoryWatcherTests 2>&1 | tail -5`
Expected: 1 个测试 PASS（注意该测试依赖真实 FSEvents，偶发慢，超时上限 10s）

- [ ] **Step 5: Commit**

```bash
git add app/Sources/iEnvsCore/DirectoryWatcher.swift app/Tests/iEnvsCoreTests/DirectoryWatcherTests.swift
git commit -m "feat(app): FSEvents directory watcher with coalesced callbacks

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: HookInstaller（shell 钩子检测与安装）

**Files:**
- Create: `app/Sources/iEnvsCore/HookInstaller.swift`
- Test: `app/Tests/iEnvsCoreTests/HookInstallerTests.swift`

**Interfaces:**
- Consumes: 无（独立单元）
- Produces: `HookInstaller` 结构体 — `init(home: URL = FileManager.default.homeDirectoryForCurrentUser, shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")`、`static let marker: String`（与 install.sh 逐字一致）、`let targetFile: URL`（zsh → `<home>/.zshenv`，bash → `<home>/.bashrc`）、`func isInstalled() -> Bool`、`func install() throws`（追加钩子；已装则 no-op；文件不存在则创建）

- [ ] **Step 1: 写失败测试**

`app/Tests/iEnvsCoreTests/HookInstallerTests.swift`:

```swift
import XCTest
@testable import iEnvsCore

final class HookInstallerTests: XCTestCase {
    var home: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        home = fm.temporaryDirectory
            .appendingPathComponent("ienvs-home-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: home)
    }

    func testTargetFilePerShell() {
        XCTAssertEqual(HookInstaller(home: home, shell: "/bin/zsh").targetFile.lastPathComponent, ".zshenv")
        XCTAssertEqual(HookInstaller(home: home, shell: "/opt/homebrew/bin/bash").targetFile.lastPathComponent, ".bashrc")
    }

    func testInstallCreatesFileAndIsDetected() throws {
        let installer = HookInstaller(home: home, shell: "/bin/zsh")
        XCTAssertFalse(installer.isInstalled())

        try installer.install()

        XCTAssertTrue(installer.isInstalled())
        let text = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertTrue(text.contains(HookInstaller.marker))
        XCTAssertTrue(text.contains(#"/.envsw/*/current(N)"#)) // zsh variant
    }

    func testInstallAppendsToExistingFileAndIsIdempotent() throws {
        let installer = HookInstaller(home: home, shell: "/bin/bash")
        try "export FOO=bar\n".write(to: installer.targetFile, atomically: true, encoding: .utf8)

        try installer.install()
        let once = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertTrue(once.hasPrefix("export FOO=bar\n")) // existing content preserved
        XCTAssertTrue(once.contains(#"[ -f "$_envsw_f" ]"#)) // bash variant

        try installer.install() // second install must not duplicate
        let twice = try String(contentsOf: installer.targetFile, encoding: .utf8)
        XCTAssertEqual(once, twice)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `swift test --package-path app --filter HookInstallerTests 2>&1 | tail -5`
Expected: 编译失败，`cannot find 'HookInstaller' in scope`

- [ ] **Step 3: 实现 HookInstaller.swift**

钩子文本与 `install.sh` 第 40–51 行逐字一致：

```swift
import Foundation

/// Detects/installs the envsw shell-startup hook, byte-compatible with install.sh.
public struct HookInstaller {
    /// Must match install.sh's MARKER exactly (grep -qF).
    public static let marker = "# envsw: auto-load the active env profile"

    public let targetFile: URL
    public let snippet: String

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh") {
        if (shell as NSString).lastPathComponent == "bash" {
            targetFile = home.appendingPathComponent(".bashrc")
            snippet = """
            \(Self.marker) of each group
            for _envsw_f in "$HOME"/.envsw/*/current; do
              [ -f "$_envsw_f" ] && { set -a; . "$_envsw_f"; set +a; }
            done
            unset _envsw_f
            """
        } else {
            targetFile = home.appendingPathComponent(".zshenv")
            snippet = """
            \(Self.marker) of each group
            for _envsw_f in "$HOME"/.envsw/*/current(N); do
              set -a; source "$_envsw_f"; set +a
            done
            unset _envsw_f
            """
        }
    }

    public func isInstalled() -> Bool {
        guard let text = try? String(contentsOf: targetFile, encoding: .utf8) else { return false }
        return text.contains(Self.marker)
    }

    public func install() throws {
        guard !isInstalled() else { return }
        let existing = (try? String(contentsOf: targetFile, encoding: .utf8)) ?? ""
        try (existing + "\n" + snippet + "\n")
            .write(to: targetFile, atomically: true, encoding: .utf8)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `swift test --package-path app --filter HookInstallerTests 2>&1 | tail -5`
Expected: 3 个测试全部 PASS

- [ ] **Step 5: 运行全部测试并 Commit**

Run: `swift test --package-path app 2>&1 | tail -3` → 全部 PASS

```bash
git add app/Sources/iEnvsCore/HookInstaller.swift app/Tests/iEnvsCoreTests/HookInstallerTests.swift
git commit -m "feat(app): shell hook installer compatible with install.sh marker

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: App 骨架 — AppState + MenuBarExtra 菜单（列表/切换/关闭）

**Files:**
- Delete: `app/Sources/iEnvs/main.swift`
- Create: `app/Sources/iEnvs/iEnvsApp.swift`
- Create: `app/Sources/iEnvs/AppState.swift`
- Create: `app/Sources/iEnvs/MenuContentView.swift`
- Create: `app/Sources/iEnvs/StatusIcon.swift`
- Create: `app/Sources/iEnvs/Prompts.swift`

**Interfaces:**
- Consumes: `iEnvsCore` 的 `ProfileStore`、`ProfileGroup`、`Profile`、`Danger`、`DirectoryWatcher`
- Produces（供 Task 8/9 使用）:
  - `AppState`（`@MainActor final class AppState: ObservableObject`）：`@Published var groups: [ProfileGroup]`、`let store: ProfileStore`、`var hasDangerActive: Bool`、`func reload()`、`func use(group:profile:)`、`func off(group:)`、`func promptNewGroup()`、`@discardableResult func run(_ body: () throws -> Void) -> Bool`
  - `Prompt.text(title:message:) -> String?`、`Prompt.confirm(title:message:actionLabel:) -> Bool`、`Prompt.error(_ error: Error)`（均 `@MainActor`）
  - `StatusIcon.image(danger: Bool) -> NSImage`
  - `MenuContentView`（含私有 `settingsButton`；Task 8 会在其中加入 Manage 子菜单的编辑/删除项）

- [ ] **Step 1: 删除占位 main.swift，创建 App 各文件**

```bash
rm app/Sources/iEnvs/main.swift
```

`app/Sources/iEnvs/iEnvsApp.swift`:

```swift
import AppKit
import SwiftUI
import iEnvsCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon (works both bundled and via `swift run`)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct iEnvsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView().environmentObject(state)
        } label: {
            Image(nsImage: StatusIcon.image(danger: state.hasDangerActive))
        }
        Settings {
            Text("Settings arrive in Task 9").padding(20) // replaced in Task 9
        }
    }
}
```

`app/Sources/iEnvs/AppState.swift`:

```swift
import Foundation
import iEnvsCore

@MainActor
final class AppState: ObservableObject {
    @Published var groups: [ProfileGroup] = []
    let store: ProfileStore
    private var watcher: DirectoryWatcher?

    init(store: ProfileStore = ProfileStore()) {
        self.store = store
        // Ensure the root exists so the watcher has something to watch.
        try? FileManager.default.createDirectory(at: store.root, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: store.root.path)
        reload()
        watcher = DirectoryWatcher(url: store.root) { [weak self] in self?.reload() }
    }

    var hasDangerActive: Bool { groups.contains { $0.hasDangerActive } }

    func reload() { groups = store.scan() }

    func use(group: String, profile: String) {
        run { try store.use(group: group, profile: profile) }
    }

    func off(group: String) {
        store.off(group: group)
        reload()
    }

    func promptNewGroup() {
        guard let name = Prompt.text(title: "New Group", message: "Group name (e.g. myapp):") else { return }
        run { try store.createGroup(name) }
    }

    /// Runs a mutation, reloads on success, shows an alert on failure.
    @discardableResult
    func run(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            reload()
            return true
        } catch {
            Prompt.error(error)
            return false
        }
    }
}
```

`app/Sources/iEnvs/MenuContentView.swift`:

```swift
import SwiftUI
import iEnvsCore

struct MenuContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.groups.isEmpty {
            Text("No profiles yet — create a group to start")
        }
        ForEach(state.groups, id: \.name) { group in
            Section(group.name) {
                ForEach(group.profiles, id: \.name) { profile in
                    Button {
                        state.use(group: group.name, profile: profile.name)
                    } label: {
                        let mark = group.activeProfileName == profile.name ? "●" : "○"
                        let warn = profile.isDangerous ? "  ⚠" : ""
                        Text("\(mark) \(profile.name)\(warn)")
                    }
                }
                manageMenu(for: group)
            }
        }
        Divider()
        Button("New Group…") { state.promptNewGroup() }
        settingsButton
        Divider()
        Button("Quit iEnvs") { NSApp.terminate(nil) }
    }

    @ViewBuilder
    private func manageMenu(for group: ProfileGroup) -> some View {
        Menu("Manage \(group.name)") {
            Button("Deactivate (off)") { state.off(group: group.name) }
                .disabled(group.activeProfileName == nil)
            // Task 8 adds: New Profile…, Edit…, Delete…, Delete Group…
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink { Text("Settings…") }
        } else {
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
```

`app/Sources/iEnvs/StatusIcon.swift`:

```swift
import AppKit

enum StatusIcon {
    /// Template icon normally; red (non-template) when a danger profile is active.
    static func image(danger: Bool) -> NSImage {
        let symbol = NSImage(systemSymbolName: "switch.2", accessibilityDescription: "iEnvs")!
        guard danger else {
            symbol.isTemplate = true
            return symbol
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
        let red = symbol.withSymbolConfiguration(config) ?? symbol
        red.isTemplate = false
        return red
    }
}
```

`app/Sources/iEnvs/Prompts.swift`:

```swift
import AppKit

@MainActor
enum Prompt {
    static func text(title: String, message: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    static func confirm(title: String, message: String, actionLabel: String = "Delete") -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: actionLabel)
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    static func error(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "iEnvs"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }
}
```

- [ ] **Step 2: 编译 + 测试**

Run: `swift build --package-path app 2>&1 | tail -3`
Expected: `Build complete!`

Run: `swift test --package-path app 2>&1 | tail -3`
Expected: 全部 PASS（core 未动，仅确认无回归）

- [ ] **Step 3: 手动验收（后台启动，验收后手动退出）**

Run: `swift run --package-path app iEnvs`（在独立终端运行，或后台运行）

验收清单：
1. 菜单栏出现 switch.2 图标，无 Dock 图标。
2. 用 CLI 造数据：`~/.local/bin/envsw edit demo dev`（或 `mkdir -p ~/.envsw/demo && printf 'K=1\n' > ~/.envsw/demo/dev.env`），**不重启 App**，菜单里几秒内出现 `demo` 组（验证 FSEvents）。
3. 点击 `○ dev` → 变 `●`，且 `readlink ~/.envsw/demo/current` 输出 `dev.env`。
4. 创建 `prod` 配置后点击 → 菜单栏图标变红，菜单项显示 `⚠`。
5. Manage demo → Deactivate (off) → `current` 消失、图标恢复。
6. New Group… 输入 `t1` → `~/.envsw/t1/` 目录出现（0700）。
7. Quit iEnvs 正常退出。

清理：`rm -rf ~/.envsw/t1`（demo 可留作后续任务验收）。

- [ ] **Step 4: Commit**

```bash
git add app
git commit -m "feat(app): MenuBarExtra skeleton with switch/off, danger icon, live reload

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: 编辑窗口 + 新建/删除配置与分组

**Files:**
- Create: `app/Sources/iEnvs/EditorView.swift`
- Create: `app/Sources/iEnvs/EditorWindowController.swift`
- Modify: `app/Sources/iEnvs/AppState.swift`（追加方法）
- Modify: `app/Sources/iEnvs/MenuContentView.swift`（补全 Manage 子菜单）

**Interfaces:**
- Consumes: Task 7 的 `AppState`、`Prompt`、`MenuContentView.manageMenu`；`iEnvsCore` 的读写 API
- Produces:
  - `ProfileRef(group: String, profile: String)`（`Hashable`，定义在 EditorWindowController.swift）
  - `EditorWindowController.open(_ ref: ProfileRef, state: AppState)`（`@MainActor`；同一 ref 复用窗口）
  - `AppState` 追加：`func promptNewProfile(group: String)`、`func deleteProfile(group:profile:)`（带确认）、`func deleteGroup(_ name: String)`（带确认）、`func readProfile(group:profile:) -> String?`、`func writeProfile(group:profile:contents:)`

- [ ] **Step 1: 实现编辑窗口**

`app/Sources/iEnvs/EditorWindowController.swift`:

```swift
import AppKit
import SwiftUI

struct ProfileRef: Hashable {
    let group: String
    let profile: String
}

/// Manages plain NSWindows for profile editors (reliable for menu-bar-only
/// apps, where WindowGroup scenes can open stray windows at launch).
@MainActor
enum EditorWindowController {
    private static var windows: [ProfileRef: NSWindow] = [:]

    static func open(_ ref: ProfileRef, state: AppState) {
        if let window = windows[ref] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = EditorView(ref: ref).environmentObject(state)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "\(ref.group) / \(ref.profile)"
        window.setContentSize(NSSize(width: 520, height: 380))
        window.isReleasedWhenClosed = false
        windows[ref] = window

        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                windows.removeValue(forKey: ref)
                if let token { NotificationCenter.default.removeObserver(token) }
            }
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

`app/Sources/iEnvs/EditorView.swift`:

```swift
import SwiftUI

struct EditorView: View {
    let ref: ProfileRef
    @EnvironmentObject var state: AppState
    @State private var text = ""
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
            Divider()
            HStack {
                Text("KEY=VALUE per line, no “export” — new shells only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") {
                    state.writeProfile(group: ref.group, profile: ref.profile, contents: text)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding(10)
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            text = state.readProfile(group: ref.group, profile: ref.profile) ?? ""
        }
    }
}
```

- [ ] **Step 2: AppState 追加增删读写方法**

在 `AppState` 类末尾追加：

```swift
    func promptNewProfile(group: String) {
        guard let name = Prompt.text(title: "New Profile in “\(group)”",
                                     message: "Profile name (e.g. dev, staging, prod):") else { return }
        if run({ try store.createProfile(group: group, profile: name) }) {
            EditorWindowController.open(ProfileRef(group: group, profile: name), state: self)
        }
    }

    func deleteProfile(group: String, profile: String) {
        guard Prompt.confirm(
            title: "Delete profile “\(profile)” from “\(group)”?",
            message: "This removes \(profile).env. If it is active, the group is deactivated."
        ) else { return }
        run { try store.deleteProfile(group: group, profile: profile) }
    }

    func deleteGroup(_ name: String) {
        guard Prompt.confirm(
            title: "Delete group “\(name)”?",
            message: "This removes the whole ~/.envsw/\(name) directory and all its profiles."
        ) else { return }
        run { try store.deleteGroup(name) }
    }

    func readProfile(group: String, profile: String) -> String? {
        do { return try store.readProfile(group: group, profile: profile) }
        catch { Prompt.error(error); return nil }
    }

    func writeProfile(group: String, profile: String, contents: String) {
        run { try store.writeProfile(group: group, profile: profile, contents: contents) }
    }
```

- [ ] **Step 3: 补全 Manage 子菜单**

用下面内容替换 `MenuContentView.manageMenu(for:)` 整个方法：

```swift
    @ViewBuilder
    private func manageMenu(for group: ProfileGroup) -> some View {
        Menu("Manage \(group.name)") {
            Button("New Profile…") { state.promptNewProfile(group: group.name) }
            if !group.profiles.isEmpty {
                Menu("Edit") {
                    ForEach(group.profiles, id: \.name) { p in
                        Button("\(p.name)…") {
                            EditorWindowController.open(
                                ProfileRef(group: group.name, profile: p.name), state: state)
                        }
                    }
                }
                Menu("Delete") {
                    ForEach(group.profiles, id: \.name) { p in
                        Button("\(p.name)…") {
                            state.deleteProfile(group: group.name, profile: p.name)
                        }
                    }
                }
            }
            Divider()
            Button("Deactivate (off)") { state.off(group: group.name) }
                .disabled(group.activeProfileName == nil)
            Button("Delete Group…") { state.deleteGroup(group.name) }
        }
    }
```

- [ ] **Step 4: 编译 + 手动验收**

Run: `swift build --package-path app 2>&1 | tail -3` → `Build complete!`

Run: `swift run --package-path app iEnvs`，验收清单：
1. Manage demo → New Profile… 输入 `staging` → 编辑窗口自动打开，内容为模板注释行。
2. 修改内容加一行 `FOO=bar`，⌘S 保存 → `cat ~/.envsw/demo/staging.env` 看到改动，权限仍是 `-rw-------`。
3. Manage demo → Edit → staging… 再次打开同一窗口（不重复开窗）。
4. Manage demo → Delete → staging… → 确认弹窗 → 文件消失、菜单刷新。
5. 删除处于激活状态的配置 → 该组变为未激活（`current` 消失）。
6. Manage demo → Delete Group… → 确认 → 整组消失。
7. 名称输入 `a/b` → 弹出 invalid name 错误提示。

- [ ] **Step 5: Commit**

```bash
git add app
git commit -m "feat(app): profile editor window and create/delete flows with confirmations

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: 首启钩子引导 + danger 通知 + 设置面板（开机自启）

**Files:**
- Create: `app/Sources/iEnvs/HookOnboarding.swift`
- Create: `app/Sources/iEnvs/Notifier.swift`
- Create: `app/Sources/iEnvs/SettingsView.swift`
- Modify: `app/Sources/iEnvs/iEnvsApp.swift`（接入 onboarding 与 Settings）
- Modify: `app/Sources/iEnvs/AppState.swift`（use 成功后触发 danger 通知）

**Interfaces:**
- Consumes: Task 6 的 `HookInstaller`、Task 7 的 `Prompt`/`AppState`、`Danger`
- Produces: `HookOnboarding.runIfNeeded()`、`Notifier.dangerActivated(group:profile:)`、`SettingsView`

- [ ] **Step 1: 实现三个新文件**

`app/Sources/iEnvs/HookOnboarding.swift`:

```swift
import AppKit
import iEnvsCore

@MainActor
enum HookOnboarding {
    /// On launch: if the shell hook is missing, explain and offer to install.
    static func runIfNeeded(installer: HookInstaller = HookInstaller()) {
        guard !installer.isInstalled() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Shell hook not installed"
        alert.informativeText = """
        Without the hook in \(installer.targetFile.lastPathComponent), switching profiles \
        has no effect: new shells won't auto-load the active profile.

        iEnvs can append the envsw hook to \(installer.targetFile.path) now.
        """
        alert.addButton(withTitle: "Install Hook")
        alert.addButton(withTitle: "Later")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do { try installer.install() } catch { Prompt.error(error) }
    }
}
```

`app/Sources/iEnvs/Notifier.swift`:

```swift
import Foundation
import UserNotifications

enum Notifier {
    /// System notification on danger activation. UNUserNotificationCenter
    /// requires a real bundle — silently skip under bare `swift run`.
    static func dangerActivated(group: String, profile: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "⚠ \(profile) is now active for \(group)"
            content.body = "Every NEW shell/process targets \(profile). Existing shells keep old values. Switch back when done."
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}
```

`app/Sources/iEnvs/SettingsView.swift`:

```swift
import ServiceManagement
import SwiftUI
import iEnvsCore

struct SettingsView: View {
    private let isBundled = Bundle.main.bundleIdentifier != nil
    @State private var launchAtLogin =
        Bundle.main.bundleIdentifier != nil && SMAppService.mainApp.status == .enabled
    @State private var hookInstalled = HookInstaller().isInstalled()

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .disabled(!isBundled)
                .onChange(of: launchAtLogin) { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {
                        Prompt.error(error)
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            if !isBundled {
                Text("Only available when running as iEnvs.app (see app/scripts/make-app.sh).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("Shell hook", value: hookInstalled ? "Installed ✓" : "Not installed")
            Button(hookInstalled ? "Re-check" : "Install Hook") {
                let installer = HookInstaller()
                if !installer.isInstalled() {
                    do { try installer.install() } catch { Prompt.error(error) }
                }
                hookInstalled = installer.isInstalled()
            }

            Divider()

            LabeledContent("Profiles directory", value: ProfileStore.defaultRoot().path)
            Text("Switching only affects NEW shells/processes — that's Unix, not a bug.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
```

- [ ] **Step 2: 接入 App 与 AppState**

`iEnvsApp.swift` 两处修改。`AppDelegate.applicationDidFinishLaunching` 末尾追加一行：

```swift
        HookOnboarding.runIfNeeded()
```

`Settings` scene 占位内容替换为：

```swift
        Settings {
            SettingsView()
        }
```

`AppState.use(group:profile:)` 整个方法替换为：

```swift
    func use(group: String, profile: String) {
        if run({ try store.use(group: group, profile: profile) }), Danger.isDangerous(profile) {
            Notifier.dangerActivated(group: group, profile: profile)
        }
    }
```

- [ ] **Step 3: 编译 + 手动验收**

Run: `swift build --package-path app 2>&1 | tail -3` → `Build complete!`

Run: `swift run --package-path app iEnvs`，验收清单：
1. 若 `~/.zshenv` 无钩子（可先备份后临时删除 marker 行验证）→ 启动即弹引导；点 Install Hook 后 `grep 'envsw' ~/.zshenv` 能看到钩子；再次启动不再弹。
2. Settings… 打开设置窗：钩子状态显示 Installed ✓；Launch at login 处于禁用态并显示 caption 说明（因为是 `swift run` 非 bundle）。
3. 切到 `prod` → 不崩溃（裸二进制跳过通知是预期行为；通知本体在 Task 10 打包后验收）。

- [ ] **Step 4: Commit**

```bash
git add app
git commit -m "feat(app): hook onboarding, danger notification, settings with launch-at-login

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: .app 打包脚本 + README + 最终验收

**Files:**
- Create: `app/scripts/make-app.sh`
- Modify: `README.md`（追加 Desktop app 小节）
- Modify: `README.zh-CN.md`（追加对应小节）

**Interfaces:**
- Consumes: 前面全部任务的产物
- Produces: `app/build/iEnvs.app`（ad-hoc 签名、LSUIElement、bundle id `com.hellodeveye.iEnvs`）

- [ ] **Step 1: 写打包脚本**

`app/scripts/make-app.sh`:

```bash
#!/usr/bin/env bash
# Bundles the SwiftPM release binary into app/build/iEnvs.app (ad-hoc signed).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/iEnvs.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/iEnvs "$APP/Contents/MacOS/iEnvs"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>      <string>iEnvs</string>
    <key>CFBundleIdentifier</key>      <string>com.hellodeveye.iEnvs</string>
    <key>CFBundleName</key>            <string>iEnvs</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>0.1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "built: app/$APP"
echo "run:   open app/$APP"
```

```bash
chmod +x app/scripts/make-app.sh
```

- [ ] **Step 2: 构建并做最终验收**

Run: `app/scripts/make-app.sh`
Expected: 末尾输出 `built: app/build/iEnvs.app`

Run: `open app/build/iEnvs.app`，最终验收清单（bundle 特有能力）：
1. App 以 bundle 运行：菜单栏图标出现、无 Dock 图标。
2. 切到 `prod` → 首次弹通知授权，允许后收到 "⚠ prod is now active" 系统通知。
3. Settings → Launch at login 可切换（系统设置 → 登录项里出现/消失 iEnvs）。
4. CLI `envsw use demo dev` → 菜单几秒内自动同步。
5. 全量测试收尾：`swift test --package-path app 2>&1 | tail -3` 全部 PASS。

验收后关掉 Launch at login（除非想留着），退出 App。

- [ ] **Step 3: 更新两份 README**

`README.md` 在 `## License` 小节之前插入：

````markdown
## Desktop app (iEnvs)

A native macOS menu bar companion lives in [`app/`](app/) — click to switch
profiles, red icon when a prod-like profile is active, built-in profile
editor, and it stays in sync with the CLI automatically.

```bash
app/scripts/make-app.sh && open app/build/iEnvs.app
```

Requires macOS 13+ and Xcode command line tools to build.
````

`README.zh-CN.md` 在对应的 License 小节之前插入：

````markdown
## 桌面版（iEnvs）

[`app/`](app/) 目录内置 macOS 原生菜单栏 App：点选即切换配置，激活 prod 类
配置时图标变红，内置配置编辑器，并自动与 CLI 保持同步。

```bash
app/scripts/make-app.sh && open app/build/iEnvs.app
```

构建需要 macOS 13+ 与 Xcode 命令行工具。
````

- [ ] **Step 4: Commit**

```bash
git add app/scripts/make-app.sh README.md README.zh-CN.md
git commit -m "feat(app): app bundle build script and desktop app docs

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 验收总览

- 单元测试：`swift test --package-path app` 全绿（Models 2 + ProfileStore 12 + Watcher 1 + Hook 3 = 18 个）。
- 手动验收：Task 7/8/9/10 各自的清单。
- 与 CLI 的互操作契约（软链接相对路径、模板文案、marker、权限、danger 列表）均有测试锁定。

## 明确不做（对齐 spec 二期）

结构化 KEY/VALUE 表格编辑、Developer ID 签名与公证、Homebrew Cask 分发、App 内更新、跨平台。
