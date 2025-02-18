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

import Vapor


struct APIReportingMiddleware: AsyncMiddleware {
    var path: Plausible.Path

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)

        let user = try? request.auth.require(User.self)
        Task {
            do {
                try await Current.postPlausibleEvent(Current.httpClient(), .pageview, path, user)
            } catch {
                Current.logger().warning("Plausible.postEvent failed: \(error)")
            }
        }

        return response
    }
}
