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
import SemanticVersion


class TwitterTests: AppTestCase {
    
    func test_versionUpdateMessage() throws {
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: "This is a test package"),
            """
            ⬆️ owner just released packageName v2.6.4 – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // no summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: nil),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // empty summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: ""),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )

        // whitespace summary
        XCTAssertEqual(
            Twitter.versionUpdateMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                version: .init(2, 6, 4),
                summary: " \n"),
            """
            ⬆️ owner just released packageName v2.6.4

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """
        )
    }

    func test_versionUpdateMessage_trimming() throws {
        let msg = Twitter.versionUpdateMessage(
            packageName: "packageName",
            repositoryOwnerName: "owner",
            url: "http://localhost:8080/owner/SuperAwesomePackage",
            version: .init(2, 6, 4),
            summary: String(repeating: "x", count: 280)
        )

        XCTAssertEqual(msg.count, 260)
        XCTAssertEqual(msg, """
            ⬆️ owner just released packageName v2.6.4 – xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx…

            http://localhost:8080/owner/SuperAwesomePackage#releases
            """)
    }

    func test_newPackageMessage() throws {
        XCTAssertEqual(
            Twitter.newPackageMessage(
                packageName: "packageName",
                repositoryOwnerName: "owner",
                url: "http://localhost:8080/owner/SuperAwesomePackage",
                summary: "This is a test package"),
            """
            📦 owner just added a new package, packageName – This is a test package

            http://localhost:8080/owner/SuperAwesomePackage
            """
        )
    }

    func test_firehoseMessage_new_version() async throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "owner",
                             summary: "This is a test package").save(on: app.db)
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await version.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()

        // MUT
        let res = Twitter.firehoseMessage(package: jpr, version: version)

        // validate
        XCTAssertEqual(res, """
            ⬆️ owner just released MyPackage v1.2.3 – This is a test package

            http://localhost:8080/owner/repoName#releases
            """)
    }

    func test_firehoseMessage_new_package() async throws {
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .new)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "owner",
                             summary: "This is a test package").save(on: app.db)
        let version = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await version.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()

        // MUT
        let res = Twitter.firehoseMessage(package: jpr, version: version)

        // validate
        XCTAssertEqual(res, """
            📦 owner just added a new package, MyPackage – This is a test package

            http://localhost:8080/owner/repoName
            """)
    }

    func test_postToFirehose_only_release_and_preRelease() async throws {
        // ensure we only tweet about releases and pre-releases
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "repoOwner",
                             summary: "This is a test package").save(on: app.db)
        let v1 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await v1.save(on: app.db)
        let v2 = try Version(package: pkg,
                             commitDate: Date(timeIntervalSince1970: 0),
                             packageName: "MyPackage",
                             reference: .tag(2, 0, 0, "b1"))
        try await v2.save(on: app.db)
        let v3 = try Version(package: pkg, packageName: "MyPackage", reference: .branch("main"))
        try await v3.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()
        try await Analyze.updateLatestVersions(on: app.db, package: jpr).get()

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var posted = 0
        Current.twitterPostTweet = { _, _ in
            posted += 1
        }

        // MUT
        try await Twitter.postToFirehose(client: app.client,
                                         package: jpr,
                                         versions: [v1, v2, v3])

        // validate
        XCTAssertEqual(posted, 2)
    }

    func test_postToFirehose_only_latest() async throws {
        // ensure we only tweet about latest versions
        // setup
        let pkg = Package(url: "1".asGithubUrl.url, status: .ok)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "repoOwner",
                             summary: "This is a test package").save(on: app.db)
        let v1 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await v1.save(on: app.db)
        let v2 = try Version(package: pkg, packageName: "MyPackage", reference: .tag(2, 0, 0))
        try await v2.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()
        try await Analyze.updateLatestVersions(on: app.db, package: jpr).get()

        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var message: String?
        Current.twitterPostTweet = { _, msg in
            if message == nil {
                message = msg
            } else {
                XCTFail("message must only be set once")
            }
        }

        // MUT
        try await Twitter.postToFirehose(client: app.client,
                                         package: jpr,
                                         versions: [v1, v2])

        // validate
        XCTAssertTrue(message?.contains("v2.0.0") ?? false)
    }

    func test_endToEnd() async throws {
        // setup
        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var message: String?
        Current.twitterPostTweet = { _, msg in
            if message == nil {
                message = msg
            } else {
                XCTFail("message must only be set once")
            }
        }

        var tag = Reference.tag(1, 2, 3)
        let url = "https://github.com/foo/bar"
        Current.fetchMetadata = { _, pkg in .mock(for: pkg) }
        Current.fetchPackageList = { _ in [url.url] }

        Current.git.commitCount = { _ in 12 }
        Current.git.firstCommitDate = { _ in .t0 }
        Current.git.lastCommitDate = { _ in .t2 }
        Current.git.getTags = { _ in [tag] }
        Current.git.revisionInfo = { _, _ in .init(commit: "sha", date: .t0) }
        Current.git.shortlog = { _ in
            """
            10\tPerson 1
             2\tPerson 2
            """
        }

        Current.shell.run = { cmd, path in
            if cmd.string.hasSuffix("swift package dump-package") {
                return #"{ "name": "Mock", "products": [], "targets": [] }"#
            }
            return ""
        }
        // run first two processing steps
        try await reconcile(client: app.client, database: app.db)
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze, triggering the tweet
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))
        do {
            let msg = try XCTUnwrap(message)
            XCTAssertTrue(msg.hasPrefix("📦 foo just added a new package, Mock"), "was \(msg)")
        }

        // run stages again to simulate the cycle...
        message = nil
        try await reconcile(client: app.client, database: app.db)
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime) }
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze, triggering tweets if any
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate - there are no new tweets to send
        XCTAssertNil(message)

        // Now simulate receiving a package update: version 2.0.0
        tag = .tag(2, 0, 0)
        // fast forward our clock by the deadtime interval again (*2) and re-ingest
        Current.date = { Date().addingTimeInterval(Constants.reIngestionDeadtime * 2) }
        try await ingest(client: app.client, database: app.db, logger: app.logger, mode: .limit(10))

        // MUT - analyze again
        try await Analyze.analyze(client: app.client,
                                  database: app.db,
                                  logger: app.logger,
                                  mode: .limit(10))

        // validate
        let msg = try XCTUnwrap(message)
        XCTAssertTrue(msg.hasPrefix("⬆️ foo just released Mock v2.0.0"), "was: \(msg)")
    }

    func test_allowTwitterPosts_switch() async throws {
        // test ALLOW_TWITTER_POSTS environment variable
        // setup
        let pkg = Package(url: "1".asGithubUrl.url)
        try await pkg.save(on: app.db)
        try await Repository(package: pkg,
                             name: "repoName",
                             owner: "repoOwner",
                             summary: "This is a test package").save(on: app.db)
        let v = try Version(package: pkg, packageName: "MyPackage", reference: .tag(1, 2, 3))
        try await v.save(on: app.db)
        let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!).get()
        Current.twitterCredentials = {
            .init(apiKey: ("key", "secret"), accessToken: ("key", "secret"))
        }
        var posted = 0
        Current.twitterPostTweet = { _, _ in
            posted += 1
        }

        // MUT & validate - disallow if set to false
        Current.allowTwitterPosts = { false }
        do {
            try await Twitter.postToFirehose(client: app.client, package: jpr, version: v)
            XCTFail("expected error to be thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("App.Twitter.Error error 3"))
        }
        XCTAssertEqual(posted, 0)

        // MUT & validate - allow if set to true
        Current.allowTwitterPosts = { true }
        try await Twitter.postToFirehose(client: app.client, package: jpr, version: v)
        XCTAssertEqual(posted, 1)
    }

}
