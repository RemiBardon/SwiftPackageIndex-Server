// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import App

import XCTVapor


class ErrorReportingTests: AppTestCase {
    
    func test_recordError() async throws {
        let pkg = try await savePackageAsync(on: app.db, "1")
        try await recordError(database: app.db,
                              error: AppError.invalidPackageUrl(pkg.id, "foo"),
                              stage: .ingestion)
        do {
            let pkg = try fetch(id: pkg.id, on: app.db)
            XCTAssertEqual(pkg.status, .invalidUrl)
            XCTAssertEqual(pkg.processingStage, .ingestion)
        }
    }
    
    func test_Rollbar_createItem() async throws {
        Current.rollbarToken = { "token" }
        let client = MockClient { _, resp in resp.status = .ok }
        try await Rollbar.createItem(client: client, level: .critical, message: "Test critical")
    }
    
    func test_Ingestor_error_reporting() async throws {
        // setup
        try await savePackagesAsync(on: app.db, ["1", "2"], processingStage: .reconciliation)
        Current.fetchMetadata = { _, _ in throw AppError.invalidPackageUrl(nil, "foo") }

        let reportedLevel = ActorIsolated<AppError.Level?>(nil)
        let reportedError = ActorIsolated<AppError?>(nil)
        Current.reportError = { _, level, error in
            await reportedLevel.setValue(level)
            await reportedError.setValue(error as? AppError)
        }
        
        // MUT
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))
        
        // validation
        await reportedLevel.withValue {
            XCTAssertEqual($0, .error)
        }
        await reportedError.withValue {
            XCTAssertEqual($0, AppError.invalidPackageUrl(nil, "foo"))
        }
    }
    
    func test_Analyzer_error_reporting() async throws {
        // setup
        try await savePackagesAsync(on: app.db, ["1", "2"].asGithubUrls.asURLs,
                                    processingStage: .ingestion)
        Current.fileManager.fileExists = { _ in true }
        Current.shell.run = { cmd, path in
            if cmd.string == "git tag" { return "1.0.0" }
            // returning a blank string will cause an exception when trying to
            // decode it as the manifest result - we use this to simulate errors
            return "invalid"
        }
        
        let reportedLevel = ActorIsolated<AppError.Level?>(nil)
        let reportedError = ActorIsolated<Error?>(nil)
        Current.reportError = { _, level, error in
            await reportedLevel.setValue(level)
            await reportedError.setValue(error)
        }
        
        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        
        // validation
        await reportedLevel.withValue {
            XCTAssertEqual($0, .error)
        }
        await reportedError.withValue {
            XCTAssertNotNil($0)
        }
    }
    
    func test_invalidPackageCachePath() async throws {
        // setup
        try await savePackagesAsync(on: app.db, ["1", "2"], processingStage: .ingestion)
        
        // MUT
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        
        // validation
        let packages = try await Package.query(on: app.db).sort(\.$url).all()
        XCTAssertEqual(packages.map(\.status), [.invalidCachePath, .invalidCachePath])
    }
    
    func test_AppError_Level_Comparable() throws {
        XCTAssert(AppError.Level.critical > .error)
        XCTAssert(AppError.Level.error <= .critical)
        XCTAssert(AppError.Level.error <= .error)
    }
    
}
