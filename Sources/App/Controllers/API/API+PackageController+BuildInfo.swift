// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import Fluent


extension API.PackageController {
    struct BuildInfo: Equatable {
        typealias ModelBuildInfo = GetRoute.Model.BuildInfo
        typealias NamedBuildResults = GetRoute.Model.NamedBuildResults
        typealias PlatformResults = GetRoute.Model.PlatformResults
        typealias SwiftVersionResults = GetRoute.Model.SwiftVersionResults

        var platform: ModelBuildInfo<PlatformResults>?
        var swiftVersion: ModelBuildInfo<SwiftVersionResults>?

        static func query(on database: Database, owner: String, repository: String) async throws -> Self {
            // FIXME: move up from PackageController.BuildsRoute into API.PackageController.BuildsRoute
            let builds = try await PackageController.BuildsRoute.BuildInfo.query(on: database,
                                                                                 owner: owner,
                                                                                 repository: repository)
            return Self.init(
                platform: platformBuildInfo(builds: builds),
                swiftVersion: swiftVersionBuildInfo(builds: builds)
            )
        }

        static func platformBuildInfo(
            builds: [PackageController.BuildsRoute.BuildInfo]
        ) -> ModelBuildInfo<PlatformResults>? {
            .init(stable: platformBuildResults(builds: builds,
                                               kind: .release),
                  beta: platformBuildResults(builds: builds,
                                             kind: .preRelease),
                  latest: platformBuildResults(builds: builds,
                                               kind: .defaultBranch))
        }

        static func platformBuildResults(
            builds: [PackageController.BuildsRoute.BuildInfo],
            kind: Version.Kind
        ) -> NamedBuildResults<PlatformResults>? {
            let builds = builds.filter { $0.versionKind == kind}
            // builds of the same kind all originate from the same Version via a join,
            // so we can just pick the first one for the reference name
            guard let referenceName = builds.first?.reference.description else {
                return nil
            }
            // For each reported platform pick appropriate build matches
            let ios = builds.filter { $0.platform.isCompatible(with: .ios) }
            let linux = builds.filter { $0.platform.isCompatible(with: .linux) }
            let macos = builds.filter { $0.platform.isCompatible(with: .macos) }
            let tvos = builds.filter { $0.platform.isCompatible(with: .tvos) }
            let watchos = builds.filter { $0.platform.isCompatible(with: .watchos) }
            // ... and report the status
            return
                .init(referenceName: referenceName,
                      results: .init(iosStatus: ios.buildStatus,
                                     linuxStatus: linux.buildStatus,
                                     macosStatus: macos.buildStatus,
                                     tvosStatus: tvos.buildStatus,
                                     watchosStatus: watchos.buildStatus)
                )
        }

        static func swiftVersionBuildInfo(
            builds: [PackageController.BuildsRoute.BuildInfo]
        ) -> ModelBuildInfo<SwiftVersionResults>? {
            .init(stable: swiftVersionBuildResults(builds: builds,
                                                   kind: .release),
                  beta: swiftVersionBuildResults(builds: builds,
                                                 kind: .preRelease),
                  latest: swiftVersionBuildResults(builds: builds,
                                                   kind: .defaultBranch))
        }

        static func swiftVersionBuildResults(
            builds: [PackageController.BuildsRoute.BuildInfo],
            kind: Version.Kind
        ) -> NamedBuildResults<SwiftVersionResults>? {
            let builds = builds.filter { $0.versionKind == kind}
            // builds of the same kind all originate from the same Version via a join,
            // so we can just pick the first one for the reference name
            guard let referenceName = builds.first?.reference.description else {
                return nil
            }
            // For each reported swift version pick major/minor version matches
            let v5_6 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_6) }
            let v5_7 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_7) }
            let v5_8 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_8) }
            let v5_9 = builds.filter { $0.swiftVersion.isCompatible(with: .v5_9) }
            // ... and report the status
            return
                .init(referenceName: referenceName,
                      results: .init(status5_6: v5_6.buildStatus,
                                     status5_7: v5_7.buildStatus,
                                     status5_8: v5_8.buildStatus,
                                     status5_9: v5_9.buildStatus)
                )
        }
    }
}


