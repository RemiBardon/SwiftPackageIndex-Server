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
import Vapor


extension API {

    enum PackageController {

        static func get(req: Request) async throws -> GetRoute.Model {
            guard
                let owner = req.parameters.get("owner"),
                let repository = req.parameters.get("repository")
            else {
                throw Abort(.notFound)
            }

            return try await GetRoute.query(on: req.db, owner: owner, repository: repository).model
        }

        struct BadgeQuery: Codable {
            var type: BadgeType
        }

        static func badge(req: Request) async throws -> Badge {
            guard
                let owner = req.parameters.get("owner"),
                let repository = req.parameters.get("repository")
            else {
                throw Abort(.notFound)
            }
            let query = try req.query.decode(BadgeQuery.self)
            let significantBuilds = try await BadgeRoute.query(on: req.db, owner: owner, repository: repository)
            return Badge(significantBuilds: significantBuilds, badgeType: query.type)
        }

    }

}


extension API.PackageController {
    enum BadgeRoute {
        static func query(on database: Database, owner: String, repository: String) async throws -> SignificantBuilds {
            let buildInfo = try await Joined4<Build, Version, Package, Repository>
                .query(on: database)
                .filter(Version.self, \Version.$latest != nil)
                .filter(Repository.self, \.$owner, .custom("ilike"), owner)
                .filter(Repository.self, \.$name, .custom("ilike"), repository)
                .field(\.$platform)
                .field(\.$status)
                .field(\.$swiftVersion)
                .all()
                .map {
                    ($0.build.swiftVersion, $0.build.platform, $0.build.status)
                }
            return SignificantBuilds.init(buildInfo: buildInfo)
        }
    }
}


extension API.PackageController {
    enum ProductCount {
        static func query(on database: Database, owner: String, repository: String) async throws -> [ProductType] {
            try await Joined4<Package, Repository, Version, Product>
                .query(on: database, owner: owner, repository: repository)
                .field(Product.self, \.$type)
                .all()
                .compactMap(\.product.type)
        }
    }
}
